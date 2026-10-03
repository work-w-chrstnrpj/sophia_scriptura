import Foundation

struct GeminiProviderAdapter: LLMProviderAdapter {
    let id = "gemini"
    let displayName = "Gemini"
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func advertisedCapabilities(modelID: String) -> Set<LLMProviderCapability> {
        [.streaming, .usageReporting, .cancellation]
    }

    func validateConnection(apiKey: String, modelID: String) async throws {
        _ = try await listModels(apiKey: apiKey)
    }

    func listModels(apiKey: String) async throws -> [String] {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        try LLMHTTPHelpers.validateHTTP(response)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = json["models"] as? [[String: Any]] else {
            return ProviderModelCatalog.curatedModels(adapterID: id).map(\.modelID)
        }
        var ids: [String] = []
        for row in rows {
            guard let name = row["name"] as? String else { continue }
            let modelID = name.replacingOccurrences(of: "models/", with: "")
            if let methods = row["supportedGenerationMethods"] as? [String],
               !methods.contains("generateContent") { continue }
            if !modelID.isEmpty, !ids.contains(modelID) { ids.append(modelID) }
        }
        return ids.isEmpty ? ProviderModelCatalog.curatedModels(adapterID: id).map(\.modelID) : ids
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
        let model = request.modelID
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var contents: [[String: Any]] = []
        for turn in request.turns {
            let role = turn.role == .assistant ? "model" : "user"
            contents.append(["role": role, "parts": [["text": turn.content]]])
        }
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": request.systemInstruction]]],
            "contents": contents
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
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String, !text.isEmpty else { continue }
            continuation.yield(.textDelta(text))
        }
        continuation.yield(.completed)
        continuation.finish()
    }
}
