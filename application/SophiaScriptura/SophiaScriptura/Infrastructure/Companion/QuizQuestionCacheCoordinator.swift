import Foundation

actor QuizQuestionCacheCoordinator {
    struct BucketKey: Hashable, Sendable {
        var scope: QuizQuestionCacheScope
        var difficulty: QuizDifficulty
        var type: QuizType
    }

    private var inFlight: [BucketKey: Task<[CachedQuizQuestion], Error>] = [:]

    func generate(
        key: BucketKey,
        count: Int,
        excludedPrompts: [String],
        adapter: any LLMProviderAdapter,
        apiKey: String
    ) async throws -> [CachedQuizQuestion] {
        if let task = inFlight[key] {
            return try await task.value
        }

        let task = Task<[CachedQuizQuestion], Error> {
            let request = AIQuizQuestionGenerator.request(
                modelID: key.scope.modelID,
                types: [key.type],
                difficulty: key.difficulty,
                count: count,
                nonce: UUID()
            )
            var response = ""
            for try await event in adapter.streamCompletion(apiKey: apiKey, request: request) {
                switch event {
                case .textDelta(let text): response += text
                case .refused(let reason): throw LLMProviderError.refused(reason)
                case .failed(let error): throw error
                default: break
                }
            }
            return try AIQuizQuestionGenerator.decodeCached(
                response,
                scope: key.scope,
                difficulty: key.difficulty,
                plannedTypes: Array(repeating: key.type, count: count),
                excludedPrompts: [key.type: excludedPrompts]
            )
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }
}
