import Foundation

/// OpenAI-style chat completions (`/v1/chat/completions`, SSE `data:` lines).
struct OpenAICompatibleProviderAdapter: LLMProviderAdapter {
    let id: String
    let displayName: String
    private let chatCompletionsURL: URL
    private let validationGETURL: URL?
    private let extraRequestHeaders: [String: String]
    private let session: URLSession

    init(
        id: String,
        displayName: String,
        chatCompletionsURL: URL,
        validationGETURL: URL? = nil,
        extraRequestHeaders: [String: String] = [:],
        session: URLSession = .shared
    ) {
        self.id = id
        self.displayName = displayName
        self.chatCompletionsURL = chatCompletionsURL
        self.validationGETURL = validationGETURL
        self.extraRequestHeaders = extraRequestHeaders
        self.session = session
    }

    func advertisedCapabilities(modelID: String) -> Set<LLMProviderCapability> {
        [.streaming, .usageReporting, .cancellation]
    }

    func listModels(apiKey: String) async throws -> [String] {
        if let validationGETURL {
            var request = URLRequest(url: validationGETURL)
            request.httpMethod = "GET"
            applyAuthHeaders(to: &request, apiKey: apiKey)
            let (data, response) = try await session.data(for: request)
            try LLMHTTPHelpers.validateHTTP(response)
            let ids = LLMHTTPHelpers.parseOpenAIModelIDs(from: data)
            if !ids.isEmpty { return ids }
        }
        return ProviderModelCatalog.curatedModels(adapterID: id).map(\.modelID)
    }

    func validateConnection(apiKey: String, modelID: String) async throws {
        if let validationGETURL {
            _ = try await listModels(apiKey: apiKey)
            return
        }
        var request = URLRequest(url: chatCompletionsURL)
        request.httpMethod = "POST"
        applyAuthHeaders(to: &request, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": modelID,
            "messages": [["role": "user", "content": "ping"]],
            "max_tokens": 1,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        try LLMHTTPHelpers.validateHTTP(response)
    }

    func streamCompletion(apiKey: String, request: LLMCompletionRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await stream(apiKey: apiKey, request: request, continuation: continuation)
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

    private func stream(
        apiKey: String,
        request: LLMCompletionRequest,
        continuation: AsyncThrowingStream<LLMStreamEvent, Error>.Continuation
    ) async throws {
        var urlRequest = URLRequest(url: chatCompletionsURL)
        urlRequest.httpMethod = "POST"
        applyAuthHeaders(to: &urlRequest, apiKey: apiKey)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        urlRequest.httpBody = try Self.completionBody(for: request)

        let (bytes, response) = try await session.bytes(for: urlRequest)
        try LLMHTTPHelpers.validateHTTP(response)
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
                throw mapProviderError(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: message)
            }
            guard let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String,
                  !content.isEmpty else { continue }
            continuation.yield(.textDelta(content))
        }
        continuation.yield(.completed)
        continuation.finish()
    }

    /// The same body used by live Groq/OpenAI-compatible requests, testable without a key.
    static func completionBody(for request: LLMCompletionRequest) throws -> Data {
        var messages: [[String: String]] = [["role": "system", "content": request.systemInstruction]]
        messages += request.turns.map { ["role": $0.role.rawValue, "content": $0.content] }
        return try JSONSerialization.data(withJSONObject: [
            "model": request.modelID, "messages": messages, "stream": true
        ])
    }

    private func applyAuthHeaders(to request: inout URLRequest, apiKey: String) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (key, value) in extraRequestHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private func mapProviderError(status: Int, message: String) -> LLMProviderError {
        if status == 401 { return .invalidCredential }
        if status == 429 { return .rateLimited }
        if message.localizedCaseInsensitiveContains("refus") { return .refused(message) }
        return .transport(message)
    }
}

extension OpenAICompatibleProviderAdapter {
    static func openRouter(session: URLSession = .shared) -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            id: "openrouter",
            displayName: "OpenRouter",
            chatCompletionsURL: URL(string: "https://openrouter.ai/api/v1/chat/completions")!,
            validationGETURL: URL(string: "https://openrouter.ai/api/v1/models")!,
            extraRequestHeaders: [
                "HTTP-Referer": "https://sophia-scriptura.local",
                "X-Title": "Sophia Scriptura"
            ],
            session: session
        )
    }

    static func githubModels(session: URLSession = .shared) -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            id: "github",
            displayName: "GitHub Models",
            chatCompletionsURL: URL(string: "https://models.github.ai/inference/chat/completions")!,
            validationGETURL: URL(string: "https://models.github.ai/catalog/models")!,
            session: session
        )
    }

    static func nvidia(session: URLSession = .shared) -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            id: "nvidia",
            displayName: "NVIDIA",
            chatCompletionsURL: URL(string: "https://integrate.api.nvidia.com/v1/chat/completions")!,
            validationGETURL: URL(string: "https://integrate.api.nvidia.com/v1/models")!,
            session: session
        )
    }

    static func cerebras(session: URLSession = .shared) -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            id: "cerebras",
            displayName: "Cerebras",
            chatCompletionsURL: URL(string: "https://api.cerebras.ai/v1/chat/completions")!,
            validationGETURL: URL(string: "https://api.cerebras.ai/v1/models")!,
            session: session
        )
    }

    static func groq(session: URLSession = .shared) -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            id: "groq",
            displayName: "Groq",
            chatCompletionsURL: URL(string: "https://api.groq.com/openai/v1/chat/completions")!,
            validationGETURL: URL(string: "https://api.groq.com/openai/v1/models")!,
            session: session
        )
    }

    static func mistral(session: URLSession = .shared) -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            id: "mistral",
            displayName: "Mistral",
            chatCompletionsURL: URL(string: "https://api.mistral.ai/v1/chat/completions")!,
            validationGETURL: URL(string: "https://api.mistral.ai/v1/models")!,
            session: session
        )
    }
}
