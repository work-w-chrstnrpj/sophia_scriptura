import XCTest
@testable import SophiaScriptura

@MainActor final class PlanBackupTests: XCTestCase {
    private struct Harness {
        var root: URL
        var notes: NotesSession
        var ink: AnnotationSession
        var activity: ActivityStore
        var collections: CollectionsStore
        var companion: CompanionSession
    }
    private func harness(interrupt: (@Sendable (AnnotationFileRepository.Boundary) throws -> Void)? = nil) async throws -> Harness {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let notes = NotesSession(repository: NotesFileRepository(directory: root.appendingPathComponent("notes")))
        let ink = AnnotationSession(repository: AnnotationFileRepository(directory: root.appendingPathComponent("ink"), interrupt: interrupt))
        let activity = ActivityStore(repository: ActivityFileRepository(directory: root.appendingPathComponent("activity")))
        let collections = CollectionsStore(repository: CollectionsFileRepository(directory: root.appendingPathComponent("collections")))
        let companion = CompanionSession(presetCatalog: PromptPresetCatalog(seed: PromptPresetSeedFile(sharedGuardrail: "Study faithfully.",
            presets: [PromptPresetDefinition(id: "study", name: "Study", isBuiltIn: true, systemInstruction: "Study faithfully.", reviewStatus: "approved")], contextVersion: 1)),
            repository: nil, credentials: InMemoryCompanionCredentialsStore())
        await notes.load(); await ink.open(nil); await activity.load(); await collections.load()
        notes.collections = collections; collections.planNotes = notes
        return .init(root: root, notes: notes, ink: ink, activity: activity, collections: collections, companion: companion)
    }
    private func export(_ h: Harness) async throws -> Data {
        try await StudyBackupService.export(notes: h.notes, annotations: h.ink, activity: h.activity, collections: h.collections, companion: h.companion)
    }
    private func restore(_ data: Data, to h: Harness) async throws {
        try await StudyBackupService.restore(data, notes: h.notes, annotations: h.ink, activity: h.activity,
            collections: h.collections, companion: h.companion, readerDocument: nil)
    }
    private func cleanJournal(_ data: Data) {
        let directory = StudyRestoreJournal.root().appendingPathComponent(StudyRestoreJournal.digest(data))
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    }
    func testPlanBackupRoundTripPreservesIdentityOrderAndProgress() async throws {
        let source = try await harness(), target = try await harness()
        var plan = StudyPlan(title: "Gospel Plan", preferredEditionID: ScriptureReferenceIdentity.bundledEditionID,
            referenceSystemID: "org.sophia.web.engwebp", sections: [.init(items: [
                .init(payload: .scripture(referenceSystemID: "org.sophia.web.engwebp", book: "MRK", chapter: 1, start: 1), completedAt: Date()),
                .init(payload: .init(kind: .link, targetID: UUID()))])])
        plan.cursor = .init(kind: .sectionSummary, sectionID: plan.sections[0].id)
        let result = await source.collections.submit(.init(intent: .savePlan(plan, collectionID: nil)))
        XCTAssertNotNil(result.receipt)
        let data = try await export(source); cleanJournal(data)
        try await restore(data, to: target)
        let restored = try XCTUnwrap(target.collections.plans.first)
        XCTAssertEqual(restored.id, plan.id); XCTAssertEqual(restored.items.map(\.id), plan.items.map(\.id))
        XCTAssertEqual(restored.completedCount, 1); XCTAssertEqual(restored.cursor, plan.cursor)
        XCTAssertFalse(target.collections.studyMutationBlocked)
    }
    func testFailedAnnotationPhaseStopsRestoreAndResumeDoesNotRewriteCompletedNotes() async throws {
        let source = try await harness()
        let document = try await BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self)).chapter(book: "JHN", number: 3)
        await source.ink.open(document)
        await source.ink.create(document: document, preferences: ReaderPreferences(), width: 820)
        XCTAssertNotNil(source.notes.create(title: "Imported reflection")); await source.notes.save()
        let data = try await export(source); cleanJournal(data)
        let fault = RestoreFault()
        let target = try await harness { boundary in if boundary == .staged { try fault.check() } }
        fault.setEnabled(true)
        do { try await restore(data, to: target); XCTFail("The annotation failure must stop dependent restore phases") } catch {}
        XCTAssertTrue(target.collections.studyMutationBlocked)
        XCTAssertEqual(target.notes.snapshot.notes.first?.title, "Imported reflection")
        let importedNotesRevision = target.notes.snapshot.revision
        fault.setEnabled(false)
        try await restore(data, to: target)
        XCTAssertEqual(target.notes.snapshot.revision, importedNotesRevision)
        XCTAssertEqual(target.ink.snapshot.groups.count, 1)
        XCTAssertFalse(target.collections.studyMutationBlocked)
        let journal = try StudyRestoreJournal(input: data, previous: Data())
        XCTAssertTrue(try journal.load().complete)
    }
}
private final class RestoreFault: @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = false
    func setEnabled(_ value: Bool) { lock.lock(); enabled = value; lock.unlock() }
    func check() throws { lock.lock(); let fail = enabled; lock.unlock(); if fail { throw AnnotationError.interrupted } }
}
