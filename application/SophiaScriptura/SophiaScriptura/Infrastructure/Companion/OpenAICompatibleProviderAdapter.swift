import Foundation

/// OpenAI-style chat completions (`/v1/chat/completions`, SSE `data:` lines).
struct OpenAICompatibleProviderAdapter: LLMProviderAdapter {
    let id: String
    let displayName: String
    private let chatCompletionsURL: URL
    private let validationGETURL: URL?
    private let extraRequestHeaders: [String: String]
    private let session: URLSession
    /// When true, connection tests post a one-token completion for the selected model.
    /// A successful model list is not treated as proof that the token can infer.
    private let requiresInferenceValidation: Bool
    private let classifyStatus: (@Sendable (Int, Data) -> LLMProviderError)?

    init(
        id: String,
        displayName: String,
        chatCompletionsURL: URL,
        validationGETURL: URL? = nil,
        extraRequestHeaders: [String: String] = [:],
        session: URLSession = .shared,
        requiresInferenceValidation: Bool = false,
        classifyStatus: (@Sendable (Int, Data) -> LLMProviderError)? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.chatCompletionsURL = chatCompletionsURL
        self.validationGETURL = validationGETURL
        self.extraRequestHeaders = extraRequestHeaders
        self.session = session
        self.requiresInferenceValidation = requiresInferenceValidation
        self.classifyStatus = classifyStatus
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
            try validateResponse(response, body: data)
            let ids = LLMHTTPHelpers.parseOpenAIModelIDs(from: data)
            if !ids.isEmpty { return ids }
        }
        return ProviderModelCatalog.curatedModels(adapterID: id).map(\.modelID)
    }

    func validateConnection(apiKey: String, modelID: String) async throws {
        let trimmedModel = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        if requiresInferenceValidation && trimmedModel.isEmpty {
            throw LLMProviderError.refused("Enter an exact model id before testing this connection.")
        }
        do {
            if requiresInferenceValidation {
                try await postInferenceProbe(apiKey: apiKey, modelID: trimmedModel)
                return
            }
            if validationGETURL != nil {
                _ = try await listModels(apiKey: apiKey)
                return
            }
            try await postInferenceProbe(apiKey: apiKey, modelID: trimmedModel)
        } catch let error as LLMProviderError {
            throw error
        } catch is CancellationError {
            throw LLMProviderError.cancelled
        } catch let error as URLError where Self.isOffline(error) {
            throw LLMProviderError.offline
        }
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
                } catch let error as URLError where Self.isOffline(error) {
                    continuation.yield(.failed(.offline))
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
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            var body = Data()
            for try await byte in bytes {
                body.append(byte)
                if body.count >= 8_192 { break }
            }
            try validateResponse(response, body: body)
        }
        continuation.yield(.responseStarted)

        var sawSSE = false
        var nonSSE = ""
        for try await line in bytes.lines {
            try Task.checkCancellation()
            if line.hasPrefix("data: ") {
                sawSSE = true
                let payload = String(line.dropFirst(6))
                if payload == "[DONE]" {
                    continuation.yield(.completed)
                    continuation.finish()
                    return
                }
                guard let data = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw LLMProviderError.malformedResponse
                }
                if json["error"] != nil {
                    throw mapProviderError(status: (response as? HTTPURLResponse)?.statusCode ?? 400, message: "")
                }
                guard let choices = json["choices"] as? [[String: Any]],
                      let content = Self.streamText(from: choices.first),
                      !content.isEmpty else { continue }
                continuation.yield(.textDelta(content))
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                nonSSE += line
            }
        }
        if !sawSSE && !nonSSE.isEmpty {
            throw LLMProviderError.malformedResponse
        }
        continuation.yield(.completed)
        continuation.finish()
    }

    private func postInferenceProbe(apiKey: String, modelID: String) async throws {
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
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, body: data)
    }

    private func validateResponse(_ response: URLResponse, body: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw LLMProviderError.malformedResponse }
        if (200...299).contains(http.statusCode) { return }
        if let classifyStatus {
            throw classifyStatus(http.statusCode, body)
        }
        try LLMHTTPHelpers.validateHTTP(response)
    }

    private static func isOffline(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .cannotFindHost, .cannotConnectToHost, .timedOut:
            return true
        default:
            return false
        }
    }

    /// The same body used by live Groq/OpenAI-compatible requests, testable without a key.
    static func completionBody(for request: LLMCompletionRequest) throws -> Data {
        var messages: [[String: String]] = [["role": "system", "content": request.systemInstruction]]
        messages += request.turns.map { ["role": $0.role.rawValue, "content": $0.content] }
        var body: [String: Any] = ["model": request.modelID, "messages": messages, "stream": true, "max_tokens": 4096]
        if request.preferJSONObject {
            body["response_format"] = ["type": "json_object"]
        }
        return try JSONSerialization.data(withJSONObject: body)
    }

    static func streamText(from choice: [String: Any]?) -> String? {
        guard let choice else { return nil }
        if let delta = choice["delta"] as? [String: Any],
           let content = delta["content"] as? String, !content.isEmpty { return content }
        if let message = choice["message"] as? [String: Any],
           let content = message["content"] as? String, !content.isEmpty { return content }
        if let text = choice["text"] as? String, !text.isEmpty { return text }
        return nil
    }

    private func applyAuthHeaders(to request: inout URLRequest, apiKey: String) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (key, value) in extraRequestHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private func mapProviderError(status: Int, message: String) -> LLMProviderError {
        if let classifyStatus {
            return classifyStatus(status == 0 ? 400 : status, Data(message.utf8))
        }
        if status == 401 { return .invalidCredential }
        if status == 429 { return .rateLimited }
        if message.localizedCaseInsensitiveContains("refus") { return .refused(message) }
        if message.isEmpty { return .malformedResponse }
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

    /// Official Inference Providers router. Model ids keep any `:provider` routing suffix.
    /// Connection tests call chat completions; listing models is not an inference proof.
    static func huggingface(session: URLSession = .shared) -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            id: "huggingface",
            displayName: "Hugging Face",
            chatCompletionsURL: URL(string: "https://router.huggingface.co/v1/chat/completions")!,
            validationGETURL: URL(string: "https://router.huggingface.co/v1/models")!,
            session: session,
            requiresInferenceValidation: true,
            classifyStatus: Self.huggingFaceStatus
        )
    }

    static func huggingFaceStatus(status: Int, _: Data) -> LLMProviderError {
        switch status {
        case 401:
            return .invalidCredential
        case 403:
            return .refused("The Hugging Face token needs the Inference Providers permission.")
        case 400, 404, 422:
            return .refused("That model is unavailable. Enter the exact model id, including any routing suffix.")
        case 402, 429:
            return .rateLimited
        default:
            return .transport("Hugging Face could not complete the request (HTTP \(status)).")
        }
    }

    /// Alibaba Cloud Model Studio (DashScope) — China (Beijing) API keys.
    static func qwenChina(session: URLSession = .shared) -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            id: "qwen-cn",
            displayName: "Qwen (China)",
            chatCompletionsURL: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!,
            validationGETURL: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/models")!,
            session: session,
            classifyStatus: Self.qwenStatus
        )
    }

    /// Alibaba Cloud Model Studio (DashScope) — international region API keys.
    static func qwenInternational(session: URLSession = .shared) -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            id: "qwen-intl",
            displayName: "Qwen (International)",
            chatCompletionsURL: URL(string: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions")!,
            validationGETURL: URL(string: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/models")!,
            session: session,
            classifyStatus: Self.qwenStatus
        )
    }

    static func qwenStatus(status: Int, body: Data) -> LLMProviderError {
        let message = String(data: body, encoding: .utf8) ?? ""
        switch status {
        case 401:
            if message.localizedCaseInsensitiveContains("incorrect api key")
                || message.contains("invalid_api_key") {
                return .refused(
                    "That API key does not match this Qwen region. Use Qwen (China) for Beijing keys or Qwen (International) for Singapore and other intl keys."
                )
            }
            return .invalidCredential
        case 403:
            return .refused("Enable the model in Alibaba Cloud Model Studio, or confirm your trial quota is still active.")
        case 400, 404, 422:
            return .refused("That Qwen model id is unavailable on this endpoint. Refresh models or pick another model.")
        case 429:
            return .rateLimited
        default:
            return .transport("Qwen could not complete the request (HTTP \(status)).")
        }
    }
}
