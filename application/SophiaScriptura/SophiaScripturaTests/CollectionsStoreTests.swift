import XCTest
@testable import SophiaScriptura

final class CollectionsStoreTests: XCTestCase {
    func testDemoSupportsSharedArtifactsAndDescendantQueriesWithoutDuplicates() throws {
        let store = CollectionsStore.demo()
        let assurance = try XCTUnwrap(store.collections.first(where: { $0.name == "Assurance" }))
        let direct = store.artifactIDs(for: assurance.id, includingDescendants: false)
        let all = store.artifactIDs(for: assurance.id, includingDescendants: true)

        XCTAssertEqual(direct.count, 4)
        XCTAssertEqual(all.count, 4)
    }

    func testMembershipToggleAddsThenRemovesMembership() throws {
        let store = CollectionsStore.demo()
        let collection = try XCTUnwrap(store.collections.first(where: { $0.name == "Prayer" }))
        let artifact = try XCTUnwrap(store.artifacts.first)

        store.toggleMembership(artifactID: artifact.id, collectionID: collection.id)
        store.toggleMembership(artifactID: artifact.id, collectionID: collection.id)

        XCTAssertFalse(store.contains(artifact.id, in: collection.id))
    }

    func testDeletingFolderPreservesArtifactsAndPromotesChildren() throws {
        let store = CollectionsStore.demo()
        let assurance = try XCTUnwrap(store.collections.first(where: { $0.name == "Assurance" }))
        let romans = try XCTUnwrap(store.collections.first(where: { $0.name == "Romans" }))
        let artifact = try XCTUnwrap(store.artifacts.first)

        store.deleteCollection(id: assurance.id)

        XCTAssertNil(store.collection(id: assurance.id))
        XCTAssertEqual(store.collection(id: romans.id)?.parentID, nil)
        XCTAssertNotNil(store.artifacts.first(where: { $0.id == artifact.id }))
        XCTAssertTrue(store.contains(artifact.id, in: romans.id))
    }

    func testCreateCollectionRejectsBlankNameAndPreservesParent() throws {
        let store = CollectionsStore.demo()
        let parent = try XCTUnwrap(store.collections.first(where: { $0.name == "Assurance" }))

        XCTAssertNil(store.createCollection(name: "  ", detail: "", parentID: parent.id, accent: .sage))
        let childID = try XCTUnwrap(store.createCollection(name: "Promises", detail: "", parentID: parent.id, accent: .sage))

        XCTAssertEqual(store.collection(id: childID)?.parentID, parent.id)
    }

    func testRemovingDirectMembershipPreservesChildAndSourceArtifact() throws {
        let store = CollectionsStore.demo()
        let parent = try XCTUnwrap(store.collections.first { $0.name == "Assurance" })
        let child = try XCTUnwrap(store.collections.first { $0.name == "Romans" })
        let verse = try XCTUnwrap(store.artifacts.first)
        let originalArtifacts = store.artifacts
        store.removeArtifact(verse.id, from: parent.id)
        XCTAssertFalse(store.contains(verse.id, in: parent.id))
        XCTAssertTrue(store.contains(verse.id, in: child.id))
        XCTAssertFalse(store.artifactIDs(for: parent.id, includingDescendants: false).contains(verse.id))
        XCTAssertTrue(store.artifactIDs(for: parent.id, includingDescendants: true).contains(verse.id))
        XCTAssertEqual(store.artifacts, originalArtifacts)
    }

    func testInvalidTargetsCannotCreateDanglingMembershipsOrFolders() throws {
        let store = CollectionsStore.demo()
        let parent = try XCTUnwrap(store.collections.first)
        let verse = try XCTUnwrap(store.artifacts.first)
        let before = store.memberships
        store.toggleMembership(artifactID: UUID(), collectionID: parent.id)
        store.toggleMembership(artifactID: verse.id, collectionID: UUID())
        XCTAssertEqual(store.memberships, before)
        XCTAssertNil(store.createCollection(name: "Orphan", detail: "", parentID: UUID(), accent: .sage))
    }

    func testDeletingNestedFolderPromotesChildrenToGrandparent() throws {
        let store = CollectionsStore.demo()
        let parent = try XCTUnwrap(store.collections.first { $0.name == "Assurance" })
        let child = try XCTUnwrap(store.collections.first { $0.name == "Romans" })
        let grandchild = try XCTUnwrap(store.createCollection(name: "Promises", detail: "", parentID: child.id, accent: .sage))
        let verse = try XCTUnwrap(store.artifacts.first)
        store.toggleMembership(artifactID: verse.id, collectionID: grandchild)
        store.deleteCollection(id: child.id)
        XCTAssertEqual(store.collection(id: grandchild)?.parentID, parent.id)
        XCTAssertTrue(store.contains(verse.id, in: grandchild))
        XCTAssertFalse(store.memberships.contains { $0.collectionID == child.id })
    }
}
