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
