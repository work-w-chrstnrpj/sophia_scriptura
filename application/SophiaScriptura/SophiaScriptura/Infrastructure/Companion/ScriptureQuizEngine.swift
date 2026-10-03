import Foundation

enum ScriptureQuizEngine {
    /// Deterministic shuffle so each quiz session draws fixtures in a varied order.
    static func shuffledIndices(count: Int, seed: UInt64) -> [Int] {
        guard count > 0 else { return [] }
        var indices = Array(0..<count)
        var state = seed == 0 ? 0xDEADBEEF : seed
        if indices.count > 1 {
            for i in stride(from: indices.count - 1, through: 1, by: -1) {
                state = state &* 6_364_136_223_846_793_005 &+ 1
                let j = Int(state % UInt64(i + 1))
                indices.swapAt(i, j)
            }
        }
        return indices
    }

    static func seed(from uuid: UUID) -> UInt64 {
        withUnsafeBytes(of: uuid.uuid) { raw in
            guard raw.count >= 8 else { return 0xA11CE }
            return raw.load(as: UInt64.self)
        }
    }

    static func mixedSeed(sessionID: UUID) -> UInt64 {
        seed(from: sessionID) &+ UInt64(Date().timeIntervalSince1970 * 1000)
    }

    static func shuffledTypes(_ types: [QuizType], count: Int, seed: UInt64) -> [QuizType] {
        guard !types.isEmpty, count > 0 else { return [] }
        var slots: [QuizType] = []
        slots.reserveCapacity(count)
        while slots.count < count {
            slots.append(types[slots.count % types.count])
        }
        let order = shuffledIndices(count: slots.count, seed: seed &+ 99)
        return order.map { slots[$0] }
    }

    static func nextIndex(from order: inout [Int], cursor: inout Int, count: Int, reseed: UInt64) -> Int {
        guard count > 0 else { return 0 }
        if cursor >= order.count {
            order = shuffledIndices(count: count, seed: reseed &+ UInt64(cursor &+ 11))
            cursor = 0
        }
        let value = order[cursor]
        cursor += 1
        return value
    }

    static func pickIndex(
        from order: inout [Int],
        cursor: inout Int,
        count: Int,
        reseed: UInt64,
        recentKeys: Set<String>,
        fixtureKey: (Int) -> String
    ) -> Int {
        guard count > 0 else { return 0 }
        let attempts = min(count, max(3, count))
        for attempt in 0..<attempts {
            let candidate = nextIndex(from: &order, cursor: &cursor, count: count, reseed: reseed &+ UInt64(attempt &+ 1))
            if !recentKeys.contains(fixtureKey(candidate)) { return candidate }
        }
        return nextIndex(from: &order, cursor: &cursor, count: count, reseed: reseed)
    }

    static func normalizeVerseText(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func gradeCompleteVerse(answer: String, key: String) -> QuizAnswerResult {
        let normalizedAnswer = normalizeVerseText(answer)
        let normalizedKey = normalizeVerseText(key)
        if normalizedAnswer == normalizedKey { return .correct }
        if normalizedAnswer.isEmpty { return .unanswered }
        if normalizedKey.contains(normalizedAnswer) || normalizedAnswer.contains(normalizedKey) {
            return .nearlyCorrect
        }
        return .incorrect
    }

    static func gradeMultipleChoice(selected: Int?, keyIndex: Int?) -> QuizAnswerResult {
        guard let selected, let keyIndex else { return .unanswered }
        return selected == keyIndex ? .correct : .incorrect
    }

    static func scriptureOrCapIsScripture(prompt: String, fixture: ScriptureOrCapFixture) -> Bool {
        fixture.scripturePrompts.contains(prompt)
    }
}

struct ScriptureOrCapFixture: Codable {
    var scripturePrompts: [String]
    var capPrompts: [String]
}

struct ChristianHistoryFixture: Codable, Identifiable {
    var id: String
    var prompt: String
    var choices: [String]
    var correctIndex: Int
    var sourceTitle: String
    var sourceAuthor: String
    var sourceURL: String?
}

struct ChristianHistorySeed: Codable {
    var questions: [ChristianHistoryFixture]
}

struct ScriptureQuizSeed: Codable {
    var completeVerse: [CompleteVerseFixture]
    var identifyVerse: [IdentifyVerseFixture]
    var whoSaidIt: [WhoSaidFixture]
    var bibleQuiz: [BibleQuizFixture]
    var bibleOrFalse: [BibleOrFalseFixture]
    var scriptureOrCap: ScriptureOrCapFixture
}

struct CompleteVerseFixture: Codable, Identifiable {
    var id: String
    var referenceLabel: String
    var prefix: String
    var answer: String
}

struct IdentifyVerseFixture: Codable, Identifiable {
    var id: String
    var quote: String
    var choices: [String]
    var correctIndex: Int
    var referenceLabel: String
}

struct WhoSaidFixture: Codable, Identifiable {
    var id: String
    var quote: String
    var choices: [String]
    var correctIndex: Int
    var referenceLabel: String
}

struct BibleQuizFixture: Codable, Identifiable {
    var id: String
    var prompt: String
    var choices: [String]
    var correctIndex: Int
    var explanation: String
    var referenceLabel: String
}

struct BibleOrFalseFixture: Codable, Identifiable {
    var id: String
    var statement: String
    var isTrue: Bool
    var explanation: String
    var referenceLabel: String
}

enum QuizFixtureCatalog {
    static func scripture() throws -> ScriptureQuizSeed {
        let url = Bundle.main.url(forResource: "scripture-quiz", withExtension: "seed.json")!
        return try JSONDecoder().decode(ScriptureQuizSeed.self, from: Data(contentsOf: url))
    }

    static func christianHistory() throws -> ChristianHistorySeed {
        let url = Bundle.main.url(forResource: "christian-history-quiz", withExtension: "seed.json")!
        return try JSONDecoder().decode(ChristianHistorySeed.self, from: Data(contentsOf: url))
    }
}
