import XCTest
@testable import SophiaScriptura

@MainActor
final class SophyExecutionTests: XCTestCase {
    func testFolderTreeCommitsOnceAndLeavesNothingWhenSaveIsRejected() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sophy-collections-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CollectionsFileRepository(directory: directory)
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [], repository: repository)
        await store.load()
        let bible = UUID()
        let old = UUID()
        let genesis = UUID()
        let nodes = [
            SophyFolderCommit(id: bible, name: "Bible", detail: "Bible study notes.", parentID: nil),
            SophyFolderCommit(id: old, name: "Old Testament", detail: "Old Testament study notes.", parentID: bible),
            SophyFolderCommit(id: genesis, name: "Genesis", detail: "This folder is notes about the Genesis.", parentID: old)
        ]
        let first = await store.createTreeFromSophy(nodes, destinationID: nil)
        XCTAssertEqual(first, .committed(resultIDs: [bible, old, genesis]))
        XCTAssertEqual(store.collection(id: genesis)?.parentID, old)
        XCTAssertEqual(store.collection(id: old)?.parentID, bible)
        let second = await store.createTreeFromSophy(nodes, destinationID: nil)
        XCTAssertEqual(second, .alreadyCommitted(resultIDs: [bible, old, genesis]))
        XCTAssertEqual(store.children(of: bible).map(\.name), ["Old Testament"])

        let failing = CollectionsStore(collections: [], artifacts: [], memberships: [], repository: RejectingCollectionsRepository())
        await failing.load()
        let before = failing.children(of: nil).map(\.id)
        let rejected = await failing.createTreeFromSophy([
            SophyFolderCommit(id: UUID(), name: "Bible", detail: "", parentID: nil)
        ], destinationID: nil)
        XCTAssertEqual(rejected, .rejected(.stalePlan))
        XCTAssertEqual(failing.children(of: nil).map(\.id), before)
    }

    func testManualActivityRejectsOverlapAndDoesNotReplaceAnExistingRecord() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sophy-activity-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActivityStore(repository: ActivityFileRepository(directory: directory))
        await store.load()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(1800)
        let id = UUID()
        let mode = ActivityMode(id: ActivityModeID.reading.id, name: ActivityModeID.reading.title, isBuiltIn: true)
        let created = await store.createManualFromSophy(id: id, title: "Read John", mode: mode, startedAt: start, endedAt: end, description: "")
        XCTAssertEqual(created, .committed(resultIDs: [id]))
        let again = await store.createManualFromSophy(id: id, title: "Read John", mode: mode, startedAt: start, endedAt: end, description: "")
        XCTAssertEqual(again, .alreadyCommitted(resultIDs: [id]))
        let overlap = await store.createManualFromSophy(id: UUID(), title: "Other", mode: mode, startedAt: start.addingTimeInterval(60), endedAt: end, description: "")
        XCTAssertEqual(overlap, .rejected(.invalidArguments))
        XCTAssertEqual(store.records.count, 1)
    }
}

final class SophyPrivacyTests: XCTestCase {
    func testProtectedAndMixedMembershipsStayOutOfSearch() {
        let plainFolder = UUID()
        let protectedFolder = UUID()
        let child = UUID()
        let plain = note("Plain", body: "alpha", memberships: [plainFolder])
        let locked = note("Secret", body: "alpha secret", memberships: [], protectionID: UUID())
        let mixed = note("Mixed", body: "alpha mixed", memberships: [plainFolder, protectedFolder])
        let nested = note("Nested", body: "alpha nested", memberships: [child])
        let records = [
            folder(plainFolder, "Notes"),
            folder(protectedFolder, "Private", protectionID: UUID()),
            folder(child, "Child", parentID: protectedFolder),
            plain, locked, mixed, nested
        ]
        let hits = SophyEligibility.search(records, query: "alpha").map(\.title)
        XCTAssertEqual(hits, ["Plain"])
        XCTAssertFalse(hits.joined().contains("secret"))
    }

    func testCyclesAndDanglingParentsFailClosed() {
        let a = UUID()
        let b = UUID()
        let dangling = UUID()
        let records = [
            folder(a, "A", parentID: b),
            folder(b, "B", parentID: a),
            folder(dangling, "Gone", parentID: UUID()),
            note("Cycle note", body: "find me", memberships: [a]),
            note("Dangling note", body: "find me", memberships: [dangling])
        ]
        XCTAssertTrue(SophyEligibility.search(records, query: "find").isEmpty)
    }

    private func note(_ title: String, body: String, memberships: [UUID], protectionID: UUID? = nil) -> SophyEligibleRecord {
        SophyEligibleRecord(id: UUID(), kind: .note, title: title, body: body, tags: [], protectionID: protectionID, parentID: nil, membershipIDs: memberships, isArchived: false, isTrashed: false, isVirtualUnfiled: false, modifiedAt: Date())
    }

    private func folder(_ id: UUID, _ title: String, parentID: UUID? = nil, protectionID: UUID? = nil) -> SophyEligibleRecord {
        SophyEligibleRecord(id: id, kind: .collection, title: title, body: "", tags: [], protectionID: protectionID, parentID: parentID, membershipIDs: [], isArchived: false, isTrashed: false, isVirtualUnfiled: false, modifiedAt: Date())
    }
}

private actor RejectingCollectionsRepository: CollectionsRepository {
    func load() async throws -> CollectionsLoad {
        CollectionsLoad(snapshot: CollectionsSnapshot(), recovered: false)
    }

    func save(_ snapshot: CollectionsSnapshot, expectedRevision: Int) async throws -> CollectionsSnapshot {
        throw CollectionsError.stale
    }
}

@MainActor final class SophyPlanExecutionTests: XCTestCase {
    func testPlanCommitPersistsFilesAssignmentsAndRejectsRepeatedOrStalePreview() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = CollectionsFileRepository(directory: root.appendingPathComponent("collections"))
        let store = CollectionsStore(repository: repository); await store.load()
        let plan = StudyPlan(title: "Plan", preferredEditionID: ScriptureReferenceIdentity.bundledEditionID,
            referenceSystemID: "org.sophia.web.engwebp", sections: [.init()])
        let saved = await PlanCommandService(store: store).save(plan)
        XCTAssertNotNil(saved.receipt)
        let before = try XCTUnwrap(store.plans.first)
        var after = before
        after.sections.append(contentsOf: (0..<130).map { _ in PlanSection() })
        after.sections[1].items = [.init(payload: .scripture(referenceSystemID: plan.referenceSystemID, book: "GEN", chapter: 1, start: 1))]
        let sophyRepository = SophyFileRepository(directory: root.appendingPathComponent("sophy"))
        let activity = ActivityStore(repository: ActivityFileRepository(directory: root.appendingPathComponent("activity")))
        await activity.load()
        let action = SophyActionDraft.updatePlan(before: before, after: after)
        let result = await SophyActionExecutor.commit(actions: [action], handles: [:], collections: store,
            activity: activity, repository: sophyRepository, now: Date(), calendar: .current)
        guard case .committed(let ids) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(ids.count, 131)
        let committed = try XCTUnwrap(store.plans.first)
        XCTAssertEqual(committed.sections.count, 131)
        let section = committed.sections[1], item = try XCTUnwrap(section.items.first)
        XCTAssertTrue(store.collectionIDs(containing: item.id).contains(try XCTUnwrap(section.materialsFolderID)))
        let reopened = CollectionsStore(repository: repository); await reopened.load()
        XCTAssertEqual(reopened.plans.first, committed)
        let history = try await sophyRepository.loadHistory().value
        let journal = try await sophyRepository.loadJournal().value
        XCTAssertEqual(history.last?.actionType, "updatePlan"); XCTAssertEqual(history.last?.resultCount, 131)
        XCTAssertEqual(journal.last?.state, .committed)
        var interrupted = try XCTUnwrap(journal.last); interrupted.state = .applying
        let present = Set(committed.sections.map(\.id) + committed.items.map(\.id))
        XCTAssertEqual(SophyActionExecutor.reconcile(journal: [interrupted], presentIDs: present, featureRecoveredOlderGeneration: false, now: Date()).first?.state, .committed)
        let retry = await SophyActionExecutor.commit(actions: [action], handles: [:], collections: store,
            activity: activity, repository: sophyRepository, now: Date(), calendar: .current)
        XCTAssertEqual(retry, .rejected(.stalePlan))
        XCTAssertEqual(store.plans.first, committed)
    }
}
