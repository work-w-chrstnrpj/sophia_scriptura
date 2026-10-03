import Foundation

extension CompanionSession {
    private var quizCacheReserveMultiplier: Int { 2 }

    func hasCachedQuestions(
        types: [QuizType],
        difficulty: QuizDifficulty,
        editionID: String
    ) -> Bool {
        guard let configuration = resolvedQuizProviderConfiguration() else { return false }
        let scope = quizCacheScope(configuration: configuration, editionID: editionID)
        let plan = AIQuizQuestionGenerator.questionTypePlan(types: types, count: difficulty.questionCount)
        return canReserve(plan: plan, difficulty: difficulty, scope: scope)
    }

    func scheduleQuizCacheWarmup(
        prioritizedTypes: [QuizType] = [],
        prioritizedDifficulty: QuizDifficulty? = nil
    ) {
        let selectable = QuizType.quizMeSelectable
        let priority = prioritizedTypes.filter { selectable.contains($0) }
        if !priority.isEmpty {
            var seen = Set<QuizType>()
            quizCachePriorityTypes = priority.filter { seen.insert($0).inserted }
        }
        if let prioritizedDifficulty { quizCachePriorityDifficulty = prioritizedDifficulty }
        quizCacheReconcilePending = true
        if quizCacheWarmTask != nil || quizCacheRetryTask != nil { return }
        quizCacheWarmTask = Task { [weak self] in
            guard let self else { return }
            while self.quizCacheReconcilePending && !Task.isCancelled {
                self.quizCacheReconcilePending = false
                let ordered = self.quizCachePriorityTypes + selectable.filter {
                    !self.quizCachePriorityTypes.contains($0)
                }
                let succeeded = await self.warmQuizCache(types: ordered, priorityDifficulty: self.quizCachePriorityDifficulty)
                if !succeeded {
                    self.scheduleQuizCacheRetry()
                    break
                }
                self.quizCacheRetryAttempts = 0
            }
            self.quizCacheWarmTask = nil
        }
    }

    @discardableResult
    func warmQuizCache(
        types: [QuizType],
        editionID: String = "web-engwebp",
        priorityDifficulty: QuizDifficulty? = nil
    ) async -> Bool {
        guard let configuration = resolvedQuizProviderConfiguration(),
              let adapter = registry.adapter(id: configuration.adapterID),
              let apiKey = try? credentials.readKey(for: configuration.id),
              !apiKey.isEmpty else { return true }

        quizCacheRefilling = true
        defer { quizCacheRefilling = false }
        let scope = quizCacheScope(configuration: configuration, editionID: editionID)
        let difficulties = priorityDifficulty.map { priority in
            [priority] + QuizDifficulty.allCases.filter { $0 != priority }
        } ?? QuizDifficulty.allCases
        // Make every type playable before spending provider calls on spare sessions.
        for level in 1...quizCacheReserveMultiplier {
            for type in types where !Task.isCancelled {
                for difficulty in difficulties where !Task.isCancelled {
                    let succeeded = await refillBucket(
                        scope: scope,
                        type: type,
                        difficulty: difficulty,
                        target: difficulty.questionCount * level,
                        adapter: adapter,
                        apiKey: apiKey
                    )
                    if !succeeded { return false }
                    // A newly selected game or a finished quiz takes priority at the next batch boundary.
                    if quizCacheReconcilePending { return true }
                }
            }
        }
        return true
    }

    private func scheduleQuizCacheRetry() {
        guard quizCacheRetryAttempts < 3, quizCacheRetryTask == nil else { return }
        quizCacheRetryAttempts += 1
        let delaySeconds = UInt64(5 * (1 << (quizCacheRetryAttempts - 1)))
        quizCacheRetryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delaySeconds))
            guard let self, !Task.isCancelled else { return }
            self.quizCacheRetryTask = nil
            self.scheduleQuizCacheWarmup()
        }
    }

    func generatedQuestionsForColdStart(
        missingPlan: [QuizType],
        scope: QuizQuestionCacheScope,
        difficulty: QuizDifficulty,
        adapter: any LLMProviderAdapter,
        apiKey: String
    ) async throws -> [CachedQuizQuestion] {
        guard !missingPlan.isEmpty else { return [] }
        let excluded = excludedQuizPrompts(types: Array(Set(missingPlan)), scope: scope)
        let request = AIQuizQuestionGenerator.request(
            modelID: scope.modelID,
            types: missingPlan,
            difficulty: difficulty,
            count: missingPlan.count,
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
            scope: scope,
            difficulty: difficulty,
            plannedTypes: missingPlan,
            excludedPrompts: excluded
        )
    }

    func reserveCachedQuestions(
        plan: [QuizType],
        difficulty: QuizDifficulty,
        scope: QuizQuestionCacheScope
    ) -> [CachedQuizQuestion]? {
        guard canReserve(plan: plan, difficulty: difficulty, scope: scope) else { return nil }
        var reserved: [CachedQuizQuestion] = []
        var usedIDs = Set<UUID>()
        for type in plan {
            guard let item = cachedQuizQuestions.first(where: {
                $0.scope == scope && $0.difficulty == difficulty && $0.type == type && !usedIDs.contains($0.id)
            }) else { return nil }
            usedIDs.insert(item.id)
            reserved.append(item)
        }
        cachedQuizQuestions.removeAll { usedIDs.contains($0.id) }
        return reserved
    }

    func missingQuestionPlan(
        for plan: [QuizType],
        difficulty: QuizDifficulty,
        scope: QuizQuestionCacheScope
    ) -> [QuizType] {
        var available: [QuizType: Int] = [:]
        for item in cachedQuizQuestions where item.scope == scope && item.difficulty == difficulty {
            available[item.type, default: 0] += 1
        }
        var missing: [QuizType] = []
        for type in plan {
            if available[type, default: 0] > 0 {
                available[type, default: 0] -= 1
            } else {
                missing.append(type)
            }
        }
        return missing
    }

    func mergeCachedQuestions(_ questions: [CachedQuizQuestion]) {
        let existingKeys = Set(cachedQuizQuestions.map { "\($0.scope)|\($0.type.rawValue)|\($0.promptHash)" })
        var addedKeys = Set<String>()
        let unique = questions.filter {
            let key = "\($0.scope)|\($0.type.rawValue)|\($0.promptHash)"
            return !existingKeys.contains(key) && addedKeys.insert(key).inserted
        }
        for question in unique {
            let count = cachedQuizQuestions.filter {
                $0.scope == question.scope && $0.type == question.type && $0.difficulty == question.difficulty
            }.count
            if count < question.difficulty.questionCount * quizCacheReserveMultiplier {
                cachedQuizQuestions.append(question)
            }
        }
    }

    private func canReserve(
        plan: [QuizType],
        difficulty: QuizDifficulty,
        scope: QuizQuestionCacheScope
    ) -> Bool {
        missingQuestionPlan(for: plan, difficulty: difficulty, scope: scope).isEmpty
    }

    private func quizCacheScope(
        configuration: ProviderConfigurationRecord,
        editionID: String
    ) -> QuizQuestionCacheScope {
        QuizQuestionCacheScope(
            providerConfigurationID: configuration.id,
            adapterID: configuration.adapterID,
            modelID: quizDefaultModelID ?? configuration.defaultModelID,
            editionID: editionID
        )
    }

    private func refillBucket(
        scope: QuizQuestionCacheScope,
        type: QuizType,
        difficulty: QuizDifficulty,
        target: Int,
        adapter: any LLMProviderAdapter,
        apiKey: String
    ) async -> Bool {
        let key = QuizQuestionCacheCoordinator.BucketKey(scope: scope, difficulty: difficulty, type: type)
        let current = cachedQuizQuestions.filter {
            $0.scope == scope && $0.difficulty == difficulty && $0.type == type
        }.count
        let deficit = max(0, target - current)
        guard deficit > 0 else { return true }
        let excluded = excludedQuizPrompts(types: [type], scope: scope)[type, default: []]
        do {
            let generated = try await quizCacheCoordinator.generate(
                key: key,
                count: deficit,
                excludedPrompts: excluded,
                adapter: adapter,
                apiKey: apiKey
            )
            mergeCachedQuestions(generated)
            scheduleSave()
            return true
        } catch {
            // A refill failure never removes usable cached questions or interrupts a quiz.
            return false
        }
    }

    private func excludedQuizPrompts(
        types: [QuizType],
        scope: QuizQuestionCacheScope
    ) -> [QuizType: [String]] {
        var result: [QuizType: [String]] = [:]
        for type in types {
            var seen = Set<String>()
            let cached = cachedQuizQuestions.filter { $0.scope == scope && $0.type == type }.map(\.prompt)
            let history = quizQuestions.reversed().filter { $0.type == type }.map(\.prompt)
            result[type] = (cached + history).filter {
                seen.insert(AIQuizQuestionGenerator.normalizedPrompt($0)).inserted
            }
        }
        return result
    }
}
