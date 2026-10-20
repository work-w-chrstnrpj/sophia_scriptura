import XCTest
@testable import SophiaScriptura

@MainActor final class PlanTests: XCTestCase {
    private func plan(title: String = "My Plan") -> StudyPlan {
        StudyPlan(title: title, preferredEditionID: ScriptureReferenceIdentity.bundledEditionID,
            referenceSystemID: "org.sophia.web.engwebp", sections: [
                .init(items: [.init(payload: .scripture(referenceSystemID: "org.sophia.web.engwebp", book: "MRK", chapter: 1, start: 1)),
                              .init(payload: .scripture(referenceSystemID: "org.sophia.web.engwebp", book: "JHN", chapter: 1, start: 1, end: 3))]),
                .init(items: [.init(payload: .scripture(referenceSystemID: "org.sophia.web.engwebp", book: "MRK", chapter: 2, start: 4, end: 8))])])
    }
    func testAuthoringPersistsExampleAndCompletionWithoutCopyingScripture() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CollectionsStore(repository: CollectionsFileRepository(directory: directory)); await store.load()
        var draft = plan(); draft.sections[0].items[0].completedAt = Date()
        let result = await store.submit(.init(intent: .savePlan(draft, collectionID: nil)))
        XCTAssertNotNil(result.receipt)
        let reopened = CollectionsStore(repository: CollectionsFileRepository(directory: directory)); await reopened.load()
        let saved = try XCTUnwrap(reopened.plans.first)
        XCTAssertEqual(saved.sections, draft.sections); XCTAssertEqual(saved.completedCount, 1)
        XCTAssertEqual(saved.title, "My Plan"); XCTAssertEqual(saved.sectionTitle(1), "Day 2")
        XCTAssertEqual(try reopened.exportBackupSnapshot().schemaVersion, 4)
        let current = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("current.json"))) as! [String: Any]
        XCTAssertEqual(current["schemaVersion"] as? Int, 2)
    }
    func testRetrySameCommandIsIdempotentAndChangedIntentRejected() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        let id = UUID(); var draft = plan()
        let request = StudyMutationRequest(commandID: id, intent: .savePlan(draft, collectionID: nil))
        let first = await store.submit(request); let second = await store.submit(request)
        XCTAssertEqual(first, second); XCTAssertEqual(store.plans.count, 1)
        draft.title = "Changed"
        let mismatch = await store.submit(.init(commandID: id, intent: .savePlan(draft, collectionID: nil)))
        XCTAssertEqual(mismatch, .rejected(.invalid)); XCTAssertEqual(store.plans.first?.title, "My Plan")
    }
    func testStaleSaveCannotOverwriteProgressAndReplacementReopensOnlyChangedItem() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        _ = await store.submit(.init(intent: .savePlan(plan(), collectionID: nil)))
        var saved = try XCTUnwrap(store.plans.first)
        saved.sections[0].items[0].completedAt = Date(); saved.sections[0].items[1].completedAt = Date()
        _ = await store.submit(.init(expectedPlanRevision: saved.revision, intent: .savePlan(saved, collectionID: nil)))
        let stale = await store.submit(.init(expectedPlanRevision: saved.revision, intent: .savePlan(saved, collectionID: nil)))
        XCTAssertEqual(stale, .rejected(.stale))
        saved = try XCTUnwrap(store.plans.first); saved.sections[0].items[0].payload.chapter = 2
        _ = await store.submit(.init(expectedPlanRevision: saved.revision, intent: .savePlan(saved, collectionID: nil)))
        XCTAssertNil(store.plans[0].sections[0].items[0].completedAt)
        XCTAssertNotNil(store.plans[0].sections[0].items[1].completedAt)
    }
    func testPlanSummaryCursorSurvivesCommitAndReopen() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        _ = await store.submit(.init(intent: .savePlan(plan(), collectionID: nil)))
        var saved = try XCTUnwrap(store.plans.first)
        saved.cursor = .init(kind: .planSummary)
        let result = await store.submit(.init(expectedPlanRevision: saved.revision, intent: .savePlan(saved, collectionID: nil)))
        XCTAssertNotNil(result.receipt)
        XCTAssertEqual(store.plans.first?.cursor?.kind, .planSummary)
        let reopened = try JSONDecoder().decode(StudyPlan.self, from: JSONEncoder().encode(try XCTUnwrap(store.plans.first)))
        XCTAssertEqual(reopened.cursor?.kind, .planSummary)
    }
    func testResetAndDuplicateKeepReferenceTargetsButClearProgressAndIdentity() throws {
        var original = plan(); original.sections[0].items.append(.init(payload: .init(kind: .note, targetID: UUID())))
        original.sections[0].items[0].completedAt = Date(); original.sections[1].items[0].completedAt = Date()
        let copy = original.duplicated()
        XCTAssertNotEqual(copy.id, original.id); XCTAssertNotEqual(copy.sections[0].id, original.sections[0].id)
        XCTAssertEqual(copy.items.map(\.payload), original.items.map(\.payload)); XCTAssertEqual(copy.completedCount, 0)
        original.reset(sectionID: original.sections[0].id)
        XCTAssertEqual(original.completedCount, 1); XCTAssertEqual(original.items.count, 4)
    }
    func testTitleUnicodeBoundsAndMalformedPayloads() throws {
        XCTAssertNoThrow(try plan(title: String(repeating: "👩🏽‍💻", count: 80)).validate())
        XCTAssertThrowsError(try plan(title: String(repeating: "👩🏽‍💻", count: 81)).validate())
        var invalid = plan(); invalid.sections[0].items[0].payload.endVerse = 0
        XCTAssertThrowsError(try invalid.validate())
        invalid = plan(); invalid.sections[0].items.append(invalid.sections[0].items[0])
        XCTAssertThrowsError(try invalid.validate())
    }
    func testLegacyCollectionsDecodeAndNewSchemaRequiresPlanFields() throws {
        let legacy = Data(#"{"schemaVersion":1,"revision":0}"#.utf8)
        XCTAssertTrue(try JSONDecoder().decode(CollectionsSnapshot.self, from: legacy).plans.isEmpty)
        XCTAssertThrowsError(try JSONDecoder().decode(CollectionsSnapshot.self, from: Data(#"{"schemaVersion":4,"revision":0}"#.utf8)))
    }
    func testMissingMaterialSurvivesRoundTripAndProtectedPlanFailsClosed() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        var missing = plan(); missing.sections[0].items.append(.init(payload: .init(kind: .link, targetID: UUID())))
        let missingResult = await store.submit(.init(intent: .savePlan(missing, collectionID: nil)))
        XCTAssertNotNil(missingResult.receipt)
        var locked = try XCTUnwrap(store.plans.first); locked.access.collectionsCredentialIDs.insert(UUID())
        let denied = await store.submit(.init(expectedPlanRevision: locked.revision, intent: .savePlan(locked, collectionID: nil)))
        XCTAssertEqual(denied, .rejected(.accessDenied))
        // A caller cannot introduce an unknown binding and then retrieve private previews.
        XCTAssertFalse(store.planAccessAllowed(locked))
        let decoded = try JSONDecoder().decode(StudyPlan.self, from: JSONEncoder().encode(missing))
        XCTAssertEqual(decoded.sections, missing.sections)
    }
    func testLegacyPatchDoesNotClobberConcurrentPlan() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        let folder = try XCTUnwrap(store.createCollection(name: "Folder", detail: "", parentID: nil, accent: .sage))
        let draft = plan()
        async let saved = store.submit(StudyMutationRequest(intent: .savePlan(draft, collectionID: folder)))
        _ = store.addLink(title: "Article", url: "https://example.com/study")
        let result = await saved; await store.flush()
        XCTAssertNotNil(result.receipt); XCTAssertEqual(store.plans.count, 1); XCTAssertEqual(store.links.count, 1)
        XCTAssertTrue(store.contains(draft.id, in: folder))
    }
}

extension PlanTests {
    func testFailedSaveDoesNotPublishPlanAndRetryUsesSameCommand() async throws {
        let repo = PlanFaultRepository()
        let store = CollectionsStore(repository: repo); await store.load()
        let request = StudyMutationRequest(intent: .savePlan(plan(), collectionID: nil))
        await repo.failNext()
        let failed = await store.submit(request)
        XCTAssertEqual(failed, .rejected(.persistence)); XCTAssertTrue(store.plans.isEmpty)
        let saved = await store.submit(request)
        XCTAssertNotNil(saved.receipt); XCTAssertEqual(store.plans.count, 1)
    }
    func testSaveAfterPublicationFailureFindsDurableReceipt() async throws {
        let repo = PlanFaultRepository(); let store = CollectionsStore(repository: repo); await store.load()
        let request = StudyMutationRequest(intent: .savePlan(plan(), collectionID: nil))
        await repo.failAfterPublication()
        let result = await store.submit(request)
        XCTAssertNotNil(result.receipt); XCTAssertEqual(store.plans.count, 1)
        let retry = await store.submit(request); XCTAssertEqual(result, retry)
    }
    func testCorruptActivatedCurrentRecoversVersionedPreviousWithoutDowngrade() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CollectionsFileRepository(directory: directory)
        let store = CollectionsStore(repository: repository); await store.load()
        let result = await store.submit(.init(intent: .savePlan(plan(), collectionID: nil)))
        XCTAssertNotNil(result.receipt)
        var draft = try XCTUnwrap(store.plans.first); draft.detail = "second generation"
        _ = await store.submit(.init(expectedPlanRevision: draft.revision, intent: .savePlan(draft, collectionID: nil)))
        try Data("broken".utf8).write(to: directory.appendingPathComponent("current.json"))
        let recovered = try await repository.load()
        XCTAssertTrue(recovered.recovered); XCTAssertEqual(recovered.snapshot.schemaVersion, 4)
        XCTAssertTrue(recovered.snapshot.planFormatActivated); XCTAssertEqual(recovered.snapshot.plans.first?.id, draft.id)
    }
    func testNotesV5OrphanAccessSurvivesSaveArchiveAndLegacyRestore() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NotesFileRepository(directory: directory)
        var note = NoteDocument(kind: .page); let credential = UUID()
        note.access.collectionsCredentialIDs.insert(credential); note.planOrigin = .init(planID: UUID(), creationOperationID: UUID())
        let saved = try await repository.save(.init(notes: [note]), expectedRevision: 0)
        XCTAssertEqual(saved.schemaVersion, 5)
        let data = try await repository.exportArchive()
        let inspected = try NotesFileRepository.inspectArchive(data)
        XCTAssertEqual(inspected.notes.first?.access.collectionsCredentialIDs, [credential])
        var legacy = NotesSnapshot(notes: [note]); legacy.notes[0].access = .init(); legacy.notes[0].planOrigin = nil
        let other = NotesFileRepository(directory: directory.appendingPathComponent("legacy"))
        _ = try await other.save(legacy, expectedRevision: 0)
        let legacyData = try await other.exportArchive()
        let restored = try await repository.restore(legacyData, expectedRevision: saved.revision)
        XCTAssertEqual(restored.schemaVersion, 5)
        XCTAssertEqual(restored.notes.first?.access.collectionsCredentialIDs, [credential])
    }
    func testRestoreCheckpointRetainsOriginalInputAndPhaseState() throws {
        let input = Data(UUID().uuidString.utf8), previous = Data("prior study".utf8)
        let journal = try StudyRestoreJournal(input: input, previous: previous)
        defer { try? FileManager.default.removeItem(at: journal.directory) }
        try journal.completed("notes", hash: "expected")
        let reopened = try StudyRestoreJournal(input: input, previous: Data("do not replace original".utf8))
        XCTAssertEqual(try reopened.load().completedPhases, ["notes"])
        XCTAssertEqual(try Data(contentsOf: reopened.directory.appendingPathComponent("previous.json")), previous)
        try reopened.finish(); XCTAssertTrue(try reopened.load().complete)
    }
}
private actor PlanFaultRepository: CollectionsRepository {
    private var current = CollectionsSnapshot()
    private var before = false, after = false
    func failNext() { before = true }
    func failAfterPublication() { after = true }
    func load() -> CollectionsLoad { .init(snapshot: current, recovered: false) }
    func save(_ snapshot: CollectionsSnapshot, expectedRevision: Int) throws -> CollectionsSnapshot {
        guard current.revision == expectedRevision else { throw CollectionsError.stale }
        if before { before = false; throw CollectionsError.damaged }
        var next = snapshot; next.revision += 1; current = next
        if after { after = false; throw CollectionsError.damaged }
        return next
    }
}

extension PlanTests {
    func testNotesV5RejectsMissingAccessAndUnknownDomainBindingsStayHidden() throws {
        var note = NoteDocument(kind: .page); note.access.collectionsCredentialIDs.insert(UUID())
        let snapshot = NotesSnapshot(schemaVersion: 5, notes: [note])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        var documents = try XCTUnwrap(object["notes"] as? [[String: Any]])
        documents[0].removeValue(forKey: "access"); object["notes"] = documents
        XCTAssertThrowsError(try JSONDecoder().decode(NotesSnapshot.self, from: JSONSerialization.data(withJSONObject: object)))
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        store.link(notes: [note])
        XCTAssertTrue(store.concealsNote(note.id)); XCTAssertEqual(store.searchableNoteText(note), "")
        XCTAssertFalse(store.canRevealNoteMetadata(note))
        XCTAssertFalse(store.presentedArtifacts(notes: [note]).contains { $0.id == note.id })
    }
    func testPlanNoteCreationReturnsDurableTargetAndRetriesWithoutDuplicates() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NotesFileRepository(directory: directory)
        let notes = NotesSession(repository: repository); await notes.load()
        let operationID = UUID(), noteID = UUID(), planID = UUID()
        let result = await notes.createPlanNote(planID: planID, operationID: operationID, noteID: noteID,
            title: "Reflection", kind: .page, access: .init())
        guard case .committed = result else { return XCTFail("Creation needs a durable receipt") }
        let retry = await notes.createPlanNote(planID: planID, operationID: operationID, noteID: noteID,
            title: "Reflection", kind: .page, access: .init())
        guard case .committed = retry else { return XCTFail("Retry must find the saved target") }
        XCTAssertEqual(notes.snapshot.notes.count, 1)
        let saved = try await repository.load().snapshot
        XCTAssertEqual(saved.notes.first?.id, noteID); XCTAssertEqual(saved.schemaVersion, 5)
        XCTAssertEqual(saved.notes.first?.planOrigin?.creationOperationID, operationID)
        var inaccessible = StudyAccessRequirements(); inaccessible.collectionsCredentialIDs.insert(UUID())
        let denied = await notes.createPlanNote(planID: planID, operationID: UUID(), noteID: UUID(),
            title: "Denied", kind: .canvas, access: inaccessible)
        XCTAssertEqual(denied, .rejected(.accessDenied)); XCTAssertEqual(notes.snapshot.notes.count, 1)
    }
    func testReferenceValidatorRejectsUnavailablePassageBeforeCommit() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        store.validatePlanReference = { _, _ in throw StudyMutationFailure.invalid }
        let result = await store.submit(.init(intent: .savePlan(plan(), collectionID: nil)))
        XCTAssertEqual(result, .rejected(.invalid)); XCTAssertTrue(store.plans.isEmpty)
    }
}

extension PlanTests {
    func testSuspendedSavePreservesQueuedFolderAndLinkChanges() async throws {
        let repository = SuspendedPlanRepository()
        let store = CollectionsStore(repository: repository); await store.load()
        await repository.holdNextSave()
        let draft = plan()
        let saving = Task { await store.submit(.init(intent: .savePlan(draft, collectionID: nil))) }
        while !(await repository.isWaiting()) { await Task.yield() }
        let folderID = try XCTUnwrap(store.createCollection(name: "During save", detail: "", parentID: nil, accent: .sage))
        let linkID = try XCTUnwrap(store.addLink(title: "During save", url: "https://example.com"))
        await repository.release()
        let result = await saving.value; await store.flush()
        XCTAssertNotNil(result.receipt)
        let disk = await repository.load().snapshot
        XCTAssertEqual(disk.plans.first?.id, draft.id)
        XCTAssertTrue(disk.collections.contains { $0.id == folderID }); XCTAssertTrue(disk.links.contains { $0.id == linkID })
        XCTAssertEqual(store.plans.first?.id, draft.id)
    }
}
private actor SuspendedPlanRepository: CollectionsRepository {
    private var value = CollectionsSnapshot()
    private var hold = false
    private var continuation: CheckedContinuation<Void, Never>?
    func holdNextSave() { hold = true }
    func isWaiting() -> Bool { continuation != nil }
    func release() { continuation?.resume(); continuation = nil }
    func load() -> CollectionsLoad { .init(snapshot: value, recovered: false) }
    func save(_ snapshot: CollectionsSnapshot, expectedRevision: Int) async throws -> CollectionsSnapshot {
        if hold { hold = false; await withCheckedContinuation { continuation = $0 } }
        guard value.revision == expectedRevision else { throw CollectionsError.stale }
        value = snapshot; value.revision += 1; return value
    }
}

extension PlanTests {
    func testInertRecoveryCannotUnderprotectAnExistingDerivedTarget() throws {
        let planID = UUID(), requirement = UUID()
        var note = NoteDocument(kind: .page); note.planOrigin = .init(planID: planID, creationOperationID: UUID())
        let access = StudyAccessRequirements(collectionsCredentialIDs: [requirement])
        let record = PlanRecoveryRecord(operationID: UUID(), planID: planID, targetIDs: [note.id], access: access)
        XCTAssertThrowsError(try StudyBackupService.validateRecoveryRecords([record], notes: [note], links: []))
        note.access = access
        XCTAssertNoThrow(try StudyBackupService.validateRecoveryRecords([record], notes: [note], links: []))
        // A missing target remains a valid inert recovery reference, not a created note.
        XCTAssertNoThrow(try StudyBackupService.validateRecoveryRecords([record], notes: [], links: []))
    }
}
