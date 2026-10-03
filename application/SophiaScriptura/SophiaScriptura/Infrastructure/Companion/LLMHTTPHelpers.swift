import Foundation

enum LLMHTTPHelpers {
    static func parseOpenAIModelIDs(from data: Data) -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = json["data"] as? [[String: Any]] else { return [] }
        var ids: [String] = []
        for row in rows {
            guard let raw = row["id"] as? String else { continue }
            let id = raw.replacingOccurrences(of: "models/", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !ids.contains(id) else { continue }
            ids.append(id)
        }
        return ids
    }

    static func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw LLMProviderError.malformedResponse }
        switch http.statusCode {
        case 200...299: return
        case 401: throw LLMProviderError.invalidCredential
        case 429: throw LLMProviderError.rateLimited
        default: throw LLMProviderError.transport("Provider HTTP \(http.statusCode).")
        }
    }

    static func streamingTask(
        work: @escaping () async throws -> Void,
        onCancel: @escaping () -> LLMProviderError = { .cancelled },
        onFailure: @escaping (Error) -> LLMProviderError
    ) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await work()
                } catch is CancellationError {
                    continuation.yield(.failed(onCancel()))
                    continuation.finish()
                } catch let error as LLMProviderError {
                    continuation.yield(.failed(error))
                    continuation.finish()
                } catch {
                    continuation.yield(.failed(onFailure(error)))
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
