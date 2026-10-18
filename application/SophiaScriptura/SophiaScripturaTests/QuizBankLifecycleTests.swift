import XCTest
import SwiftUI
@testable import SophiaScriptura

@MainActor
final class QuizBankLifecycleTests: XCTestCase {
    private func fixture(count: Int, repository: (any CompanionRepository)? = nil) throws -> (CompanionSession, BlockingQuizAdapter.Gate, QuizQuestionCacheScope) {
        let config = ProviderConfigurationRecord(adapterID: "blocking-quiz", accountLabel: "Test", defaultModelID: "mock")
        let keys = InMemoryCompanionCredentialsStore()
        try keys.writeKey("test-key", for: config.id)
        let gate = BlockingQuizAdapter.Gate()
        let session = CompanionSession(presetCatalog: try PromptPresetCatalog.bundled(), repository: repository,
            credentials: keys, registry: ProviderRegistry(adapters: [BlockingQuizAdapter(gate: gate)]))
        let scope = QuizQuestionCacheScope(providerConfigurationID: config.id, adapterID: config.adapterID, modelID: "mock", editionID: "custom-edition")
        session.apply(CompanionSnapshot(providerConfigurations: [config], cachedQuizQuestions: questions(count, scope: scope)))
        return (session, gate, scope)
    }

    private func questions(_ count: Int, scope: QuizQuestionCacheScope, prefix: String = "Question") -> [CachedQuizQuestion] {
        (0..<count).map { index in
            CachedQuizQuestion(id: UUID(), scope: scope, difficulty: .easy, type: .bibleQuiz,
                prompt: "\(prefix) \(index)", choices: ["Correct", "Wrong"],
                answerKey: QuizAnswerKey(referenceLabel: "Genesis 1:1", choiceIndex: 0),
                explanation: "Explanation", generatedAt: Date(), promptHash: "\(prefix)-\(index)")
        }
    }

    private func waitForRequest(_ gate: BlockingQuizAdapter.Gate) async throws {
        for _ in 0..<100 {
            if gate.callCount > 0 { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Reservation must trigger refill before quiz completion")
    }

    private func stop(_ session: CompanionSession, gate: BlockingQuizAdapter.Gate) async {
        session.quizCacheWarmTask?.cancel()
        session.quizCacheRetryTask?.cancel()
        gate.failAll()
        await session.quizCacheWarmTask?.value
        session.quizCacheRetryTask?.cancel()
    }

    func testReadyQuizAndAgainReturnWhileRefillProviderIsStillBlocked() async throws {
        let (session, gate, scope) = try fixture(count: 150)
        let id = try await session.startQuiz(types: [.bibleQuiz], difficulty: .easy, editionID: scope.editionID, timed: false)
        XCTAssertEqual(session.quizQuestions(for: id).count, QuizDifficulty.easy.questionCount)
        try await waitForRequest(gate)
        XCTAssertEqual(session.quizSessions.first?.completionState, "active")
        XCTAssertEqual(session.quizCachePriorityEditionID, scope.editionID)
        let before = session.cachedQuizQuestions.count
        try await session.appendQuizRound(sessionID: id)
        XCTAssertEqual(session.cachedQuizQuestions.count, before - QuizDifficulty.easy.questionCount)
        XCTAssertEqual(session.quizQuestions(for: id).count, QuizDifficulty.easy.questionCount * 2)
        XCTAssertGreaterThan(gate.callCount, 0)
        let key = QuizQuestionCacheCoordinator.BucketKey(scope: scope, difficulty: .easy, type: .bibleQuiz)
        XCTAssertEqual(session.quizCacheRefillTargets[key], 150)
        await stop(session, gate: gate)
    }

    func testReadyExamStartsWhileProviderIsBlockedAndRefillsConsumedBuckets() async throws {
        let (session, gate, scope) = try fixture(count: 125)
        let id = try await session.startExamQuiz(questionCount: 25, editionID: scope.editionID, timed: false, sessionTimeLimitSeconds: nil)
        XCTAssertEqual(session.quizQuestions(for: id).count, 25)
        XCTAssertEqual(session.cachedQuizQuestions.count, 100)
        try await waitForRequest(gate)
        let key = QuizQuestionCacheCoordinator.BucketKey(scope: scope, difficulty: .easy, type: .bibleQuiz)
        XCTAssertEqual(session.quizCacheRefillTargets[key], 125)
        await stop(session, gate: gate)
    }

    func testReservationsAndUnusedBankSurvivePersistenceAndRepeatedLoadDoesNotResetThem() async throws {
        let repo = CompanionFileRepository(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let (session, gate, scope) = try fixture(count: 150, repository: repo)
        session.scheduleSave(); await session.flush()
        await session.load()
        let id = try await session.startQuiz(types: [.bibleQuiz], difficulty: .easy, editionID: scope.editionID, timed: false)
        await session.load() // A repeated view-load must not apply an older snapshot over live reservations.
        await session.flush()
        let loaded = try await repo.load()
        XCTAssertEqual(loaded.snapshot.cachedQuizQuestions.count, 150 - QuizDifficulty.easy.questionCount)
        XCTAssertEqual(loaded.snapshot.quizQuestions.filter { $0.sessionID == id }.count, QuizDifficulty.easy.questionCount)
        XCTAssertTrue(Set(loaded.snapshot.cachedQuizQuestions.map(\.id)).isDisjoint(with: Set(session.quizQuestions(for: id).map(\.id))))
        await stop(session, gate: gate)
    }

    func testSuccessfulRefillBatchIsOnDiskBeforeNextProviderRequestCompletes() async throws {
        let repo = CompanionFileRepository(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let config = ProviderConfigurationRecord(adapterID: "blocking-quiz", accountLabel: "Test", defaultModelID: "mock")
        let keys = InMemoryCompanionCredentialsStore(); try keys.writeKey("test-key", for: config.id)
        let gate = BlockingQuizAdapter.Gate(firstBatchSucceeds: true)
        let session = CompanionSession(presetCatalog: try PromptPresetCatalog.bundled(), repository: repo,
            credentials: keys, registry: ProviderRegistry(adapters: [BlockingQuizAdapter(gate: gate)]))
        session.apply(CompanionSnapshot(providerConfigurations: [config]))
        let warming = Task { await session.warmQuizCache(types: [.bibleQuiz]) }
        for _ in 0..<100 {
            if gate.callCount >= 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(gate.callCount, 2)
        let loaded = try await repo.load()
        XCTAssertEqual(loaded.snapshot.cachedQuizQuestions.count, QuizDifficulty.easy.questionCount)
        XCTAssertEqual(loaded.snapshot.cachedQuizQuestions, session.cachedQuizQuestions)
        warming.cancel(); gate.failAll(); _ = await warming.value
    }

    func testQuizSummaryPortraitAndLandscapeRendering() async throws {
        let (session, gate, _) = try fixture(count: 150)
        let id = UUID()
        session.quizSessions = [QuizSession(id: id, createdAt: Date(), difficulty: .easy, types: [.bibleQuiz],
            editionID: "custom-edition", timed: false, recordReviewing: false,
            providerAdapterID: "blocking-quiz", modelID: "mock", scoreEarned: 0, scoreAvailable: 0, completionState: "active")]
        for (name, size) in [("portrait", CGSize(width: 820, height: 1180)), ("landscape", CGSize(width: 1180, height: 820))] {
            let host = UIHostingController(rootView: NavigationStack { QuizSessionView(session: session, quizID: id) })
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.rootViewController = host; window.isHidden = false
            host.view.frame = window.bounds
            try await Task.sleep(for: .milliseconds(300))
            host.view.layoutIfNeeded()
            let snapshot = UIGraphicsImageRenderer(size: size).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: snapshot)
            attachment.name = "Quiz summary \(name)"; attachment.lifetime = .keepAlways; add(attachment)
            window.isHidden = true
        }
        gate.failAll()
    }

    func testBankRetainsMoreThanMinimumAndCapsEachBucketAtTwoHundred() throws {
        let (session, gate, scope) = try fixture(count: 150)
        session.mergeCachedQuestions(questions(100, scope: scope, prefix: "Additional"))
        XCTAssertEqual(session.cachedQuizQuestions.count, 200)
        session.mergeCachedQuestions(questions(20, scope: scope, prefix: "Overflow"))
        XCTAssertEqual(session.cachedQuizQuestions.count, 200)
        XCTAssertTrue(session.hasCachedQuestions(types: [.bibleQuiz], difficulty: .easy, editionID: scope.editionID))
        XCTAssertFalse(session.hasCachedQuestions(types: [.bibleQuiz], difficulty: .easy, editionID: "another-edition"))
        gate.failAll()
    }

    func testBelowMinimumReservationRequestsHighWaterRefillWithoutWaitingForFinish() async throws {
        let (session, gate, scope) = try fixture(count: 100)
        _ = try await session.startQuiz(types: [.bibleQuiz], difficulty: .easy, editionID: scope.editionID, timed: false)
        let key = QuizQuestionCacheCoordinator.BucketKey(scope: scope, difficulty: .easy, type: .bibleQuiz)
        XCTAssertEqual(session.quizCacheRefillTargets[key], 200)
        try await waitForRequest(gate)
        await stop(session, gate: gate)
    }
}

private struct BlockingQuizAdapter: LLMProviderAdapter {
    final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var pending: [AsyncThrowingStream<LLMStreamEvent, Error>.Continuation] = []
        private var calls = 0
        private let firstBatchSucceeds: Bool
        init(firstBatchSucceeds: Bool = false) { self.firstBatchSucceeds = firstBatchSucceeds }
        var callCount: Int { lock.lock(); defer { lock.unlock() }; return calls }
        func add(_ continuation: AsyncThrowingStream<LLMStreamEvent, Error>.Continuation) {
            lock.lock(); calls += 1
            let succeed = firstBatchSucceeds && calls == 1
            if !succeed { pending.append(continuation) }
            lock.unlock()
            if succeed {
                let payload = AIQuizQuestionGenerator.Payload(questions: (0..<QuizDifficulty.easy.questionCount).map { index in
                    .init(type: QuizType.bibleQuiz.rawValue, prompt: "Durable generated question \(index)",
                        choices: ["Correct", "Wrong"], correctIndex: 0, referenceLabel: "Genesis 1:1", explanation: "Explanation")
                })
                let data = try! JSONEncoder().encode(payload)
                continuation.yield(.textDelta(String(decoding: data, as: UTF8.self)))
                continuation.yield(.completed); continuation.finish()
            }
        }
        func failAll() {
            lock.lock(); let continuations = pending; pending.removeAll(); lock.unlock()
            for continuation in continuations { continuation.finish(throwing: LLMProviderError.offline) }
        }
    }
    let gate: Gate
    let id = "blocking-quiz"
    let displayName = "Blocked test provider"
    func advertisedCapabilities(modelID: String) -> Set<LLMProviderCapability> { [.streaming] }
    func validateConnection(apiKey: String, modelID: String) async throws {}
    func listModels(apiKey: String) async throws -> [String] { ["mock"] }
    func streamCompletion(apiKey: String, request: LLMCompletionRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in gate.add(continuation) }
    }
}
