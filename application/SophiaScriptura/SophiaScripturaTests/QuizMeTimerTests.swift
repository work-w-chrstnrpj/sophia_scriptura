import XCTest
@testable import SophiaScriptura

@MainActor
final class QuizMeTimerTests: XCTestCase {
    func testTimerConsumesOnlyElapsedSeconds() {
        var timer = QuizQuestionTimer(limitSeconds: 60)
        timer.tick()
        timer.tick()
        XCTAssertEqual(timer.remainingSeconds, 58)
        XCTAssertEqual(timer.consumedSeconds, 2)
    }

    func testTimerExpireMarksUnansweredAttempt() async throws {
        let catalog = try PromptPresetCatalog.bundled()
        let session = CompanionSession(
            presetCatalog: catalog,
            repository: nil,
            credentials: InMemoryCompanionCredentialsStore(),
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter(id: "mock", scriptedChunks: [try identifyVerseQuizJSON()])])
        )
        try session.saveProviderKey("key", adapterID: "mock", accountLabel: "Test", defaultModelID: "mock")
        let quizID = try await session.startQuiz(types: [.identifyVerse], difficulty: .easy, editionID: "web-engwebp", timed: true, recordReviewing: false)
        let question = try XCTUnwrap(session.quizQuestions.first { $0.sessionID == quizID })
        session.submitQuizAnswer(sessionID: quizID, questionID: question.id, answer: "", choiceIndex: nil)
        let attempt = try XCTUnwrap(session.quizAttempts.first { $0.questionID == question.id })
        XCTAssertEqual(attempt.result, .unanswered)
        XCTAssertEqual(attempt.pointsEarned, 0)
    }

    func testActiveQuestionSecondsAccumulateForReviewing() async throws {
        let catalog = try PromptPresetCatalog.bundled()
        let session = CompanionSession(
            presetCatalog: catalog,
            repository: nil,
            credentials: InMemoryCompanionCredentialsStore(),
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter(id: "mock", scriptedChunks: [try identifyVerseQuizJSON()])])
        )
        try session.saveProviderKey("key", adapterID: "mock", accountLabel: "Test", defaultModelID: "mock")
        let quizID = try await session.startQuiz(types: [.identifyVerse], difficulty: .easy, editionID: "web-engwebp", timed: false, recordReviewing: true)
        session.addQuizQuestionActiveTime(sessionID: quizID, seconds: 42)
        for question in session.quizQuestions where question.sessionID == quizID {
            session.submitQuizAnswer(sessionID: quizID, questionID: question.id, answer: "Genesis 1:1", choiceIndex: 0)
        }
        session.finishQuiz(sessionID: quizID, intentional: true)
        let link = try XCTUnwrap(session.reviewingLinks.first { $0.quizSessionID == quizID })
        XCTAssertEqual(link.activeSeconds, 42)
    }

    func testResultSummaryCounts() {
        let attempts = [
            QuizAttemptRecord(id: UUID(), questionID: UUID(), ownerAnswer: "a", choiceIndex: 0, result: .correct, pointsEarned: 1, answeredAt: Date()),
            QuizAttemptRecord(id: UUID(), questionID: UUID(), ownerAnswer: "", choiceIndex: nil, result: .unanswered, pointsEarned: 0, answeredAt: Date())
        ]
        let counts = QuizResultSummary.counts(for: attempts)
        XCTAssertEqual(counts.correct, 1)
        XCTAssertEqual(counts.unanswered, 1)
    }

    private func identifyVerseQuizJSON() throws -> String {
        let questions = (0..<QuizDifficulty.easy.questionCount).map { index in
            AIQuizQuestionGenerator.GeneratedQuestion(
                type: QuizType.identifyVerse.rawValue,
                prompt: "Public-domain verse wording \(index)",
                choices: ["Genesis \(index + 1):1", "Exodus \(index + 1):1"],
                correctIndex: 0,
                referenceLabel: "Genesis \(index + 1):1",
                explanation: "The wording is from the listed Genesis reference."
            )
        }
        return String(decoding: try JSONEncoder().encode(AIQuizQuestionGenerator.Payload(questions: questions)), as: UTF8.self)
    }
}
