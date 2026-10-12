import Foundation

struct OpenAIProviderAdapter: LLMProviderAdapter {
    let id = "openai"
    let displayName = "OpenAI"
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func advertisedCapabilities(modelID: String) -> Set<LLMProviderCapability> {
        [.streaming, .usageReporting, .cancellation]
    }

    func validateConnection(apiKey: String, modelID: String) async throws {
        _ = try await listModels(apiKey: apiKey)
    }

    func listModels(apiKey: String) async throws -> [String] {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try Self.validateHTTP(response)
        return LLMHTTPHelpers.parseOpenAIModelIDs(from: data)
    }

    func streamCompletion(apiKey: String, request: LLMCompletionRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Self.stream(apiKey: apiKey, request: request, session: session, continuation: continuation)
                } catch is CancellationError {
                    continuation.yield(.failed(.cancelled))
                    continuation.finish()
                } catch let error as LLMProviderError {
                    continuation.yield(.failed(error))
                    continuation.finish()
                } catch {
                    continuation.yield(.failed(.transport(error.localizedDescription)))
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func stream(
        apiKey: String,
        request: LLMCompletionRequest,
        session: URLSession,
        continuation: AsyncThrowingStream<LLMStreamEvent, Error>.Continuation
    ) async throws {
        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var messages: [[String: String]] = [["role": "system", "content": request.systemInstruction]]
        for turn in request.turns {
            messages.append(["role": turn.role.rawValue, "content": turn.content])
        }
        var body: [String: Any] = [
            "model": request.modelID,
            "messages": messages,
            "stream": true,
            "max_tokens": 4096
        ]
        if request.preferJSONObject {
            body["response_format"] = ["type": "json_object"]
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: urlRequest)
        try validateHTTP(response)
        continuation.yield(.responseStarted)

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" {
                continuation.yield(.completed)
                continuation.finish()
                return
            }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                throw mapOpenAIError(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: message)
            }
            guard let choices = json["choices"] as? [[String: Any]],
                  let content = OpenAICompatibleProviderAdapter.streamText(from: choices.first),
                  !content.isEmpty else { continue }
            continuation.yield(.textDelta(content))
        }
        continuation.yield(.completed)
        continuation.finish()
    }

    private static func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw LLMProviderError.malformedResponse }
        switch http.statusCode {
        case 200...299: return
        case 401: throw LLMProviderError.invalidCredential
        case 429: throw LLMProviderError.rateLimited
        default: throw LLMProviderError.transport("Provider HTTP \(http.statusCode).")
        }
    }

    private static func mapOpenAIError(status: Int, message: String) -> LLMProviderError {
        if status == 401 { return .invalidCredential }
        if status == 429 { return .rateLimited }
        if message.localizedCaseInsensitiveContains("refus") { return .refused(message) }
        return .transport(message)
    }
}

struct MockLLMProviderAdapter: LLMProviderAdapter {
    let id: String
    let displayName: String
    var scriptedChunks: [String]
    var failure: LLMProviderError?

    init(id: String = "mock", displayName: String = "Mock", scriptedChunks: [String] = ["Hello", " from", " Sophia."], failure: LLMProviderError? = nil) {
        self.id = id
        self.displayName = displayName
        self.scriptedChunks = scriptedChunks
        self.failure = failure
    }

    func advertisedCapabilities(modelID: String) -> Set<LLMProviderCapability> {
        [.streaming, .cancellation]
    }

    func validateConnection(apiKey: String, modelID: String) async throws {
        guard !apiKey.isEmpty else { throw LLMProviderError.missingCredential }
    }

    func listModels(apiKey: String) async throws -> [String] {
        ["mock", "mock-fast"]
    }

    func streamCompletion(apiKey: String, request: LLMCompletionRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                if let failure {
                    continuation.yield(.failed(failure))
                    continuation.finish()
                    return
                }
                continuation.yield(.responseStarted)
                for chunk in scriptedChunks {
                    try? await Task.sleep(nanoseconds: 5_000_000)
                    continuation.yield(.textDelta(chunk))
                }
                continuation.yield(.completed)
                continuation.finish()
            }
        }
    }
}
