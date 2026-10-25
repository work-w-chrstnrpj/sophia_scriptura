import XCTest
@testable import SophiaScriptura

@MainActor final class PlanLifecycleTests: XCTestCase {
    private func plan() -> StudyPlan {
        .init(title: "Strict Plan", preferredEditionID: ScriptureReferenceIdentity.bundledEditionID,
            referenceSystemID: "org.sophia.web.engwebp", sections: [
                .init(items: [.init(payload: .scripture(referenceSystemID: "org.sophia.web.engwebp", book: "GEN", chapter: 1)),
                              .init(payload: .scripture(referenceSystemID: "org.sophia.web.engwebp", book: "GEN", chapter: 2))]),
                .init(items: [.init(payload: .scripture(referenceSystemID: "org.sophia.web.engwebp", book: "GEN", chapter: 3))])])
    }
    func testProgressCountsCompletedSectionsInsteadOfItems() {
        var value = plan()
        value.sections[0].items[0].completedAt = Date()
        XCTAssertEqual(value.completedCount, 1); XCTAssertEqual(value.completedSectionCount, 0)
        value.sections[0].items[1].completedAt = Date()
        XCTAssertEqual(value.completedSectionCount, 1); XCTAssertFalse(value.isComplete)
        value.sections[1].items[0].completedAt = Date()
        XCTAssertEqual(value.completedSectionCount, 2); XCTAssertTrue(value.isComplete)
        value.sections.append(.init())
        XCTAssertEqual(value.completedSectionCount, 2); XCTAssertFalse(value.isComplete)
    }
    func testMandatoryRootRejectsNilReplacementAndPreservesSchemaFiveOnReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CollectionsFileRepository(directory: directory)
        let store = CollectionsStore(repository: repository); await store.load()
        let create = await store.submit(.init(intent: .savePlan(plan(), collectionID: nil)))
        XCTAssertNotNil(create.receipt)
        var saved = try XCTUnwrap(store.plans.first)
        let root = try XCTUnwrap(saved.materialsFolderID)
        XCTAssertEqual(store.collection(id: root)?.name, "Strict Plan")
        saved.materialsFolderID = nil
        let nilResult = await store.submit(.init(expectedPlanRevision: saved.revision, intent: .savePlan(saved, collectionID: nil)))
        XCTAssertEqual(nilResult, .rejected(.invalid))
        saved.materialsFolderID = UUID()
        let replacement = await store.submit(.init(expectedPlanRevision: saved.revision, intent: .savePlan(saved, collectionID: nil)))
        XCTAssertEqual(replacement, .rejected(.invalid))
        let reopened = CollectionsStore(repository: repository); await reopened.load()
        XCTAssertEqual(reopened.plans.first?.materialsFolderID, root)
        XCTAssertEqual(try reopened.exportBackupSnapshot().schemaVersion, 5)
    }
    func testPlanDeleteAndFolderRestorePreserveSharedItemsAndRecoverExclusiveMaterial() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let noteRepo = NotesFileRepository(directory: directory.appendingPathComponent("notes"))
        let notes = NotesSession(repository: noteRepo); await notes.load()
        let repository = CollectionsFileRepository(directory: directory.appendingPathComponent("collections"))
        let store = CollectionsStore(repository: repository); await store.load(); store.planNotes = notes
        let exclusiveNote = try XCTUnwrap(notes.create(kind: .page, title: "Exclusive"))
        let sharedNote = try XCTUnwrap(notes.create(kind: .journal, title: "Shared"))
        await notes.save(); store.link(notes: notes.snapshot.notes)
        let exclusiveLink = try XCTUnwrap(store.addLink(title: "Exclusive link", url: "https://example.com/private"))
        let sharedLink = try XCTUnwrap(store.addLink(title: "Shared link", url: "https://example.com/shared"))
        let outside = try XCTUnwrap(store.createCollection(name: "Outside", detail: "", parentID: nil, accent: .gold))
        store.addMembership(artifactID: sharedNote, collectionID: outside)
        store.addMembership(artifactID: sharedLink, collectionID: outside)
        await store.flush()
        var value = plan()
        for id in [exclusiveNote, sharedNote] { value.sections[0].items.append(.init(payload: .init(kind: .note, targetID: id))) }
        for id in [exclusiveLink, sharedLink] { value.sections[0].items.append(.init(payload: .init(kind: .link, targetID: id))) }
        _ = await store.submit(.init(intent: .savePlan(value, collectionID: outside)))
        let saved = try XCTUnwrap(store.plans.first), root = try XCTUnwrap(store.plans.first?.materialsFolderID)
        let days = saved.sections.compactMap(\.materialsFolderID)
        let deletion = await store.setPlanTreeTrashed(saved.id, trashed: true)
        XCTAssertNotNil(deletion.receipt)
        XCTAssertNotNil(store.plans.first?.trashedAt)
        XCTAssertTrue(([root] + days).allSatisfy { store.collection(id: $0)?.isTrashed == true })
        XCTAssertNotNil(notes.snapshot.notes.first { $0.id == exclusiveNote }?.trashedAt)
        XCTAssertNil(notes.snapshot.notes.first { $0.id == sharedNote }?.trashedAt)
        XCTAssertFalse(store.links.contains { $0.id == exclusiveLink }); XCTAssertTrue(store.links.contains { $0.id == sharedLink })
        XCTAssertTrue(store.contains(sharedLink, in: outside)); XCTAssertTrue(store.contains(sharedNote, in: outside))
        let reopenedNotes = NotesSession(repository: noteRepo); await reopenedNotes.load()
        let reopened = CollectionsStore(repository: repository); await reopened.load(); reopened.planNotes = reopenedNotes
        reopened.link(notes: reopenedNotes.snapshot.notes)
        XCTAssertNotNil(reopened.plans.first?.trashedAt)
        let restored = await reopened.setPlanTreeTrashed(saved.id, trashed: false)
        XCTAssertNotNil(restored.receipt)
        XCTAssertNil(reopened.plans.first?.trashedAt)
        XCTAssertTrue(([root] + days).allSatisfy { reopened.collection(id: $0)?.isTrashed == false })
        XCTAssertNil(reopenedNotes.snapshot.notes.first { $0.id == exclusiveNote }?.trashedAt)
        XCTAssertTrue(reopened.links.contains { $0.id == exclusiveLink })
        XCTAssertTrue(try reopened.exportBackupSnapshot().planTreeTrash.isEmpty)
    }
    func testFolderDeleteRoutesToPlanCascadeAndDoesNotPromoteChildren() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        _ = await store.submit(.init(intent: .savePlan(plan(), collectionID: nil)))
        let value = try XCTUnwrap(store.plans.first), root = try XCTUnwrap(store.plans.first?.materialsFolderID)
        let child = try XCTUnwrap(value.sections.first?.materialsFolderID)
        store.deleteCollection(id: root)
        for _ in 0..<100 {
            if store.plans.first?.trashedAt != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        await store.flush()
        XCTAssertNotNil(store.plans.first?.trashedAt)
        XCTAssertTrue(store.collection(id: root)?.isTrashed == true)
        XCTAssertTrue(store.collection(id: child)?.isTrashed == true)
        XCTAssertEqual(store.collection(id: child)?.parentID, root)
        XCTAssertTrue(store.planFolderDeleteMessage(root).contains("also delete the Plan"))
        XCTAssertTrue(store.planDeleteMessage.contains("also delete its Plan folder"))
    }
    func testPendingNotesPhaseResumesAfterInterruptedDelete() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let notes = NotesSession(repository: NotesFileRepository(directory: directory.appendingPathComponent("notes"))); await notes.load()
        let noteID = try XCTUnwrap(notes.create(kind: .canvas, title: "Recovery")); await notes.save()
        let store = CollectionsStore(repository: CollectionsFileRepository(directory: directory.appendingPathComponent("collections")))
        await store.load(); store.planNotes = notes; store.link(notes: notes.snapshot.notes)
        var value = plan(); value.sections[0].items.append(.init(payload: .init(kind: .note, targetID: noteID)))
        _ = await store.submit(.init(intent: .savePlan(value, collectionID: nil)))
        let prepared = await store.submit(.init(intent: .setPlanTreeTrashed(planID: value.id, trashed: true)))
        XCTAssertNotNil(prepared.receipt)
        XCTAssertNil(notes.snapshot.notes.first { $0.id == noteID }?.trashedAt)
        XCTAssertEqual(try store.exportBackupSnapshot().planTreeTrash.first?.pendingNotesAction, true)
        await store.reconcilePlanTreeTrash()
        XCTAssertNotNil(notes.snapshot.notes.first { $0.id == noteID }?.trashedAt)
        XCTAssertNil(try store.exportBackupSnapshot().planTreeTrash.first?.pendingNotesAction)
        await store.reconcilePlanTreeTrash()
        XCTAssertEqual(try store.exportBackupSnapshot().planTreeTrash.count, 1)
    }
    func testDeleteFailureLeavesPlanFolderAndMaterialsUntouchedBeforeRetry() async throws {
        let repository = PlanTreeFailureRepository()
        let store = CollectionsStore(repository: repository); await store.load()
        let link = try XCTUnwrap(store.addLink(title: "Keep on failure", url: "https://example.com")); await store.flush()
        var value = plan(); value.sections[0].items.append(.init(payload: .init(kind: .link, targetID: link)))
        _ = await store.submit(.init(intent: .savePlan(value, collectionID: nil)))
        let root = try XCTUnwrap(store.plans.first?.materialsFolderID)
        await repository.failNext()
        let failed = await store.setPlanTreeTrashed(value.id, trashed: true)
        XCTAssertNil(failed.receipt)
        XCTAssertNil(store.plans.first?.trashedAt)
        XCTAssertTrue(store.collection(id: root)?.isActiveInLibrary == true)
        XCTAssertTrue(store.links.contains { $0.id == link })
        let retry = await store.setPlanTreeTrashed(value.id, trashed: true)
        XCTAssertNotNil(retry.receipt); XCTAssertNotNil(store.plans.first?.trashedAt)
        XCTAssertFalse(store.links.contains { $0.id == link })
    }
    func testItemsReferencedByAnotherPlanRemainAvailableAcrossBothDeletesAndRestore() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        let link = try XCTUnwrap(store.addLink(title: "Shared between Plans", url: "https://example.com")); await store.flush()
        var first = plan(); first.sections[0].items.append(.init(payload: .init(kind: .link, targetID: link)))
        var second = plan(); second.title = "Second"
        second.sections[0].items.append(.init(payload: .init(kind: .link, targetID: link)))
        _ = await store.submit(.init(intent: .savePlan(first, collectionID: nil)))
        _ = await store.submit(.init(intent: .savePlan(second, collectionID: nil)))
        let deleteFirst = await store.setPlanTreeTrashed(first.id, trashed: true)
        XCTAssertNotNil(deleteFirst.receipt); XCTAssertTrue(store.links.contains { $0.id == link })
        let deleteSecond = await store.setPlanTreeTrashed(second.id, trashed: true)
        XCTAssertNotNil(deleteSecond.receipt); XCTAssertTrue(store.links.contains { $0.id == link })
        let restoreFirst = await store.setPlanTreeTrashed(first.id, trashed: false)
        XCTAssertNotNil(restoreFirst.receipt); XCTAssertTrue(store.links.contains { $0.id == link })
    }
    func testSchemaFourMissingFolderIsAdoptedWithoutReset() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CollectionsFileRepository(directory: directory)
        var legacy = CollectionsSnapshot(); legacy.planFormatActivated = true; legacy.schemaVersion = 4; legacy.plans = [plan()]
        _ = try await repository.save(legacy, expectedRevision: 0)
        let store = CollectionsStore(repository: repository); await store.load()
        var saved = try XCTUnwrap(store.plans.first); XCTAssertNil(saved.materialsFolderID)
        saved.detail = "Upgrade"
        let result = await store.submit(.init(expectedPlanRevision: saved.revision, intent: .savePlan(saved, collectionID: nil)))
        XCTAssertNotNil(result.receipt); XCTAssertNotNil(store.plans.first?.materialsFolderID)
        XCTAssertEqual(try store.exportBackupSnapshot().schemaVersion, 5)
    }
}


private actor PlanTreeFailureRepository: CollectionsRepository {
    private var value = CollectionsSnapshot()
    private var shouldFail = false
    func failNext() { shouldFail = true }
    func load() -> CollectionsLoad { .init(snapshot: value, recovered: false) }
    func save(_ proposed: CollectionsSnapshot, expectedRevision: Int) throws -> CollectionsSnapshot {
        if shouldFail { shouldFail = false; throw CollectionsError.damaged }
        guard value.revision == expectedRevision else { throw CollectionsError.stale }
        value = proposed; value.revision += 1; return value
    }
}
