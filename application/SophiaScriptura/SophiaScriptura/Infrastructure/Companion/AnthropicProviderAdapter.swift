import Foundation

struct AnthropicProviderAdapter: LLMProviderAdapter {
    let id = "anthropic"
    let displayName = "Anthropic"
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func advertisedCapabilities(modelID: String) -> Set<LLMProviderCapability> {
        [.streaming, .usageReporting, .cancellation]
    }

    func validateConnection(apiKey: String, modelID: String) async throws {
        _ = try await listModels(apiKey: apiKey)
    }

    func listModels(apiKey: String) async throws -> [String] {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models")!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let (data, response) = try await session.data(for: request)
        try LLMHTTPHelpers.validateHTTP(response)
        let ids = LLMHTTPHelpers.parseOpenAIModelIDs(from: data)
        if !ids.isEmpty { return ids }
        return ProviderModelCatalog.curatedModels(adapterID: id).map(\.modelID)
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
        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var apiMessages: [[String: String]] = []
        for turn in request.turns where turn.role != .system {
            let role = turn.role == .assistant ? "assistant" : "user"
            apiMessages.append(["role": role, "content": turn.content])
        }
        let body: [String: Any] = [
            "model": request.modelID,
            "max_tokens": 4096,
            "stream": true,
            "system": request.systemInstruction,
            "messages": apiMessages
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: urlRequest)
        try LLMHTTPHelpers.validateHTTP(response)
        continuation.yield(.responseStarted)

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let type = json["type"] as? String, type == "content_block_delta",
               let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String, !text.isEmpty {
                continuation.yield(.textDelta(text))
            }
            if let type = json["type"] as? String, type == "message_stop" {
                continuation.yield(.completed)
                continuation.finish()
                return
            }
        }
        continuation.yield(.completed)
        continuation.finish()
    }
}
