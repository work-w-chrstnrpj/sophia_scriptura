import Foundation

enum AIQuizQuestionGenerator {
    struct GeneratedQuestion: Codable, Sendable {
        var type: String
        var prompt: String
        var choices: [String]
        var correctIndex: Int
        var referenceLabel: String
        var explanation: String
    }

    struct Payload: Codable, Sendable {
        var questions: [GeneratedQuestion]
    }

    enum GenerationError: Error, LocalizedError {
        case empty
        case malformed
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .empty:
                return "The provider returned no quiz questions. Try again."
            case .malformed:
                return "The provider returned an unreadable quiz. Try again or choose another model."
            case .invalid(let reason):
                return "The generated quiz was not safe to use: \(reason)"
            }
        }
    }

    static func request(
        modelID: String,
        types: [QuizType],
        difficulty: QuizDifficulty,
        count: Int,
        recentPrompts _: [QuizType: [String]] = [:],
        nonce: UUID
    ) -> LLMCompletionRequest {
        let plannedTypes = questionTypePlan(types: types, count: count)
        let typePlan = plannedTypes.map(\.rawValue).joined(separator: ", ")

        let instruction = """
        Generate a Bible quiz as strict JSON only. Do not use Markdown fences or commentary.

        Return this shape:
        {"questions":[{"type":"identifyVerse","prompt":"...","choices":["..."],"correctIndex":0,"referenceLabel":"Book 1:1","explanation":"..."}]}

        Requirements:
        - Return exactly \(count) questions in this exact type order: \(typePlan).
        - Use only these type identifiers: \(types.map(\.rawValue).joined(separator: ", ")).
        - Every question must have 2 to 4 choices and exactly one unambiguously correct choice.
        - For bibleOrFalse and scriptureOrCap, choices must be exactly ["True","False"] and ["Scripture","Cap"] respectively.
        - For identifyVerse, quote enough public-domain Scripture wording to identify the passage, then provide reference choices.
        - referenceLabel must identify the supporting Bible passage, or a concise primary historical source for christianHistory. Explanations must state why the keyed answer is correct.
        - Avoid trick wording, disputed interpretations, denominational distinctives, and questions whose answer depends on translation wording.
        - Make every question materially distinct from the other questions in this response.
        - Randomization nonce: \(nonce.uuidString). Use it to vary books, people, events, and sections of the canon.

        Difficulty rubric:
        \(difficultyRubric(difficulty))

        """
        return LLMCompletionRequest(
            modelID: modelID,
            systemInstruction: instruction,
            turns: [LLMChatTurn(role: .user, content: "Generate the quiz now as JSON only.")]
        )
    }

    static func decode(
        _ text: String,
        sessionID: UUID,
        plannedTypes: [QuizType],
        recentPrompts: [QuizType: [String]]
    ) throws -> [QuizQuestionRecord] {
        let scope = QuizQuestionCacheScope(
            providerConfigurationID: UUID(),
            adapterID: "legacy-decode",
            modelID: "legacy-decode",
            editionID: "legacy-decode"
        )
        let cached = try decodeCached(
            text,
            scope: scope,
            difficulty: .easy,
            plannedTypes: plannedTypes,
            excludedPrompts: recentPrompts
        )
        return materialize(cached, sessionID: sessionID)
    }

    static func decodeCached(
        _ text: String,
        scope: QuizQuestionCacheScope,
        difficulty: QuizDifficulty,
        plannedTypes: [QuizType],
        excludedPrompts: [QuizType: [String]]
    ) throws -> [CachedQuizQuestion] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GenerationError.empty }
        guard let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") else {
            throw GenerationError.malformed
        }
        let json = String(trimmed[start...end])
        guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(json.utf8)) else {
            throw GenerationError.malformed
        }
        guard payload.questions.count == plannedTypes.count else {
            throw GenerationError.invalid("The question count did not match the selected difficulty.")
        }

        var seenPrompts: [String] = []
        return try zip(payload.questions, plannedTypes).map { pair in
            let item = pair.0
            let expectedType = pair.1
            guard let type = QuizType(rawValue: item.type), type == expectedType else {
                throw GenerationError.invalid("A question did not match the requested game type.")
            }
            let prompt = item.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let reference = item.referenceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let explanation = item.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty, !reference.isEmpty, !explanation.isEmpty else {
                throw GenerationError.invalid("A question was missing its prompt, reference, or explanation.")
            }
            guard (2...4).contains(item.choices.count), item.choices.indices.contains(item.correctIndex) else {
                throw GenerationError.invalid("A question had invalid answer choices.")
            }
            guard Set(item.choices.map(normalizedPrompt)).count == item.choices.count else {
                throw GenerationError.invalid("A question repeated an answer choice.")
            }
            if type == .bibleOrFalse, item.choices != ["True", "False"] {
                throw GenerationError.invalid("Bible or False must use True and False choices.")
            }
            if type == .scriptureOrCap, item.choices != ["Scripture", "Cap"] {
                throw GenerationError.invalid("Scripture or Cap must use Scripture and Cap choices.")
            }
            let normalized = normalizedPrompt(prompt)
            guard !seenPrompts.contains(where: { promptsAreTooSimilar(normalized, $0) }) else {
                throw GenerationError.invalid("The provider repeated or closely paraphrased a question in the same response.")
            }
            let excluded = excludedPrompts[type, default: []].map(normalizedPrompt)
            guard !excluded.contains(where: { promptsAreTooSimilar(normalized, $0) }) else {
                throw GenerationError.invalid("The provider repeated or closely paraphrased a previously used question.")
            }
            seenPrompts.append(normalized)
            let canonical: String? = type == .scriptureOrCap
                ? item.choices[item.correctIndex].lowercased()
                : (type == .bibleOrFalse ? (item.correctIndex == 0 ? "true" : "false") : nil)
            return CachedQuizQuestion(
                id: UUID(),
                scope: scope,
                difficulty: difficulty,
                type: type,
                prompt: prompt,
                choices: item.choices,
                answerKey: QuizAnswerKey(
                    canonicalText: canonical,
                    referenceLabel: reference,
                    choiceIndex: item.correctIndex
                ),
                explanation: explanation,
                generatedAt: Date(),
                promptHash: CompanionContentHash.digest(normalized)
            )
        }
    }

    static func materialize(_ cached: [CachedQuizQuestion], sessionID: UUID, indexOffset: Int = 0) -> [QuizQuestionRecord] {
        cached.enumerated().map { index, item in
            let questionIndex = indexOffset + index
            let positioned = positionedChoices(
                item.choices,
                correctIndex: item.answerKey.choiceIndex ?? 0,
                type: item.type,
                sessionID: sessionID,
                questionIndex: questionIndex
            )
            return QuizQuestionRecord(
                id: UUID(),
                sessionID: sessionID,
                index: questionIndex,
                type: item.type,
                prompt: item.prompt,
                choices: positioned.choices,
                answerKey: QuizAnswerKey(
                    canonicalText: item.answerKey.canonicalText,
                    referenceLabel: item.answerKey.referenceLabel,
                    choiceIndex: positioned.correctIndex
                ),
                explanation: item.explanation,
                sourceIDs: [],
                fixtureKey: "ai:\(item.type.rawValue):\(item.promptHash)"
            )
        }
    }

    static func difficultyRubric(_ difficulty: QuizDifficulty) -> String {
        switch difficulty {
        case .easy:
            return "Easy: test direct recall of widely known people, events, teachings, and passages. Use clearly distinct distractors and avoid minor details."
        case .average:
            return "Average: require contextual recall across both Testaments, sequence, speaker, audience, or event details. Use plausible related distractors; do not reuse basic easy-level facts."
        case .difficult:
            return "Difficult: require precise canonical context, less-prominent people or events, cross-book distinctions, or close reading. Use highly plausible distractors, but never ambiguity, trivia outside Scripture, or disputed interpretation."
        }
    }

    static func questionTypePlan(types: [QuizType], count: Int) -> [QuizType] {
        guard !types.isEmpty, count > 0 else { return [] }
        return (0..<count).map { types[$0 % types.count] }
    }

    static func positionedChoices(
        _ choices: [String],
        correctIndex: Int,
        type: QuizType,
        sessionID: UUID,
        questionIndex: Int
    ) -> (choices: [String], correctIndex: Int) {
        guard choices.indices.contains(correctIndex), choices.count > 1,
              type != .bibleOrFalse, type != .scriptureOrCap else {
            return (choices, correctIndex)
        }
        var reordered = choices
        let correct = reordered.remove(at: correctIndex)
        let offset = Int(ScriptureQuizEngine.seed(from: sessionID) % UInt64(choices.count))
        let target = (offset + questionIndex) % choices.count
        reordered.insert(correct, at: target)
        return (reordered, target)
    }

    static func normalizedPrompt(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func promptsAreTooSimilar(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        let left = Set(lhs.split(separator: " ").map(String.init))
        let right = Set(rhs.split(separator: " ").map(String.init))
        guard min(left.count, right.count) >= 4 else { return false }
        let overlap = left.intersection(right).count
        let union = left.union(right).count
        return union > 0 && Double(overlap) / Double(union) >= 0.82
    }
}
