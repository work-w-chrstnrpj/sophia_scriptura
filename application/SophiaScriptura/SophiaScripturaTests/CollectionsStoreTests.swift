import XCTest
@testable import SophiaScriptura

@MainActor
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

    func testNoFolderKeepsItemsThatLoseTheirOnlyFolder() throws {
        let store = CollectionsStore.demo()
        let assurance = try XCTUnwrap(store.collections.first { $0.name == "Assurance" })
        let link = try XCTUnwrap(store.artifacts.first { $0.kind == .link })
        let verse = try XCTUnwrap(store.artifacts.first { $0.kind == .scripture })

        store.deleteCollection(id: StudyCollection.unfiledID)
        store.deleteCollection(id: assurance.id)

        let unfiled = store.presentedArtifacts(for: StudyCollection.unfiledID, includingDescendants: false, notes: [])
        XCTAssertNotNil(store.collection(id: StudyCollection.unfiledID))
        XCTAssertTrue(unfiled.contains { $0.id == link.id })
        XCTAssertFalse(unfiled.contains { $0.id == verse.id })
        XCTAssertNil(store.createCollection(name: "No Folder", detail: "", parentID: nil, accent: .sage))
        XCTAssertNil(store.createCollection(name: "Child", detail: "", parentID: StudyCollection.unfiledID, accent: .sage))
    }

    func testBookmarkLabelAndGleaningCardStayDistinct() {
        let store = CollectionsStore.demo()
        let bookmark = samplePassage(kind: .bookmark, insight: "", endVerse: 1)
        let ranged = samplePassage(kind: .bookmark, insight: "", endVerse: 3)
        let gleaning = samplePassage(kind: .gleaning, insight: "No condemnation.", endVerse: 1)

        XCTAssertEqual(bookmark.referenceLabel, "Romans 8:1 (WEB)")
        XCTAssertEqual(ranged.referenceLabel, "Romans 8:1–3 (WEB)")
        let first = store.addPassage(bookmark)
        XCTAssertEqual(store.addPassage(samplePassage(kind: .bookmark, insight: "", endVerse: 1)), first)
        XCTAssertEqual(store.passages.filter { $0.kind == .bookmark && $0.endVerse == 1 }.count, 1)
        store.addPassage(gleaning)
        store.addPassage(samplePassage(kind: .gleaning, insight: "A second insight.", endVerse: 1))
        let cards = store.presentedArtifacts(notes: []).filter { $0.kind == .gleaning }
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards.first { $0.insight == "No condemnation." }?.passageText, "There is therefore now no condemnation.")
        XCTAssertTrue(store.presentedArtifacts(for: StudyCollection.unfiledID, includingDescendants: false, notes: []).contains { $0.id == gleaning.id })
    }

    func testSavedCollectionsReopenWithFolderColorAndMembership() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("collections-" + UUID().uuidString, isDirectory: true)
        let store = CollectionsStore(repository: CollectionsFileRepository(directory: directory))
        await store.load()
        let folder = try XCTUnwrap(store.createCollection(name: "Grace", detail: "Held", parentID: nil, accent: .sage))
        store.updateAccent(id: StudyCollection.unfiledID, accent: .gold)
        let passage = samplePassage(kind: .bookmark, insight: "", endVerse: 1)
        store.addPassage(passage)
        store.toggleMembership(artifactID: passage.id, collectionID: folder)
        await store.flush()

        let reopened = CollectionsStore(repository: CollectionsFileRepository(directory: directory))
        await reopened.load()
        XCTAssertEqual(reopened.collection(id: folder)?.accent, .sage)
        XCTAssertEqual(reopened.collection(id: folder)?.parentID, nil)
        XCTAssertEqual(reopened.collection(id: StudyCollection.unfiledID)?.accent, .gold)
        XCTAssertEqual(reopened.passage(id: passage.id)?.referenceLabel, "Romans 8:1 (WEB)")
        XCTAssertTrue(reopened.contains(passage.id, in: folder))
        XCTAssertFalse(reopened.presentedArtifacts(for: StudyCollection.unfiledID, includingDescendants: false, notes: []).contains { $0.id == passage.id })
    }

    func testMovingAndAssigningPassagesNeverLosesThem() throws {
        let store = CollectionsStore.demo()
        let grace = try XCTUnwrap(store.createCollection(name: "Grace", detail: "", parentID: nil, accent: .plum))
        let hope = try XCTUnwrap(store.createCollection(name: "Hope", detail: "", parentID: nil, accent: .teal))
        let passage = samplePassage(kind: .gleaning, insight: "Kept.", endVerse: 1)
        let id = store.addPassage(passage)

        store.addMembership(artifactID: id, collectionID: grace)
        store.addMembership(artifactID: id, collectionID: StudyCollection.unfiledID)
        XCTAssertEqual(store.collectionIDs(containing: id), [grace])
        XCTAssertEqual(store.accent(for: id), .plum)

        store.move(artifactID: id, from: grace, to: hope)
        XCTAssertEqual(store.collectionIDs(containing: id), [hope])
        XCTAssertEqual(store.accent(for: id), .teal)

        store.setMemberships(artifactID: id, collectionIDs: [grace, hope, StudyCollection.unfiledID])
        XCTAssertEqual(store.collectionIDs(containing: id), [grace, hope])

        store.setMemberships(artifactID: id, collectionIDs: [])
        XCTAssertTrue(store.presentedArtifacts(for: StudyCollection.unfiledID, includingDescendants: false, notes: []).contains { $0.id == id })
        XCTAssertEqual(store.accent(for: id), store.collection(id: StudyCollection.unfiledID)?.accent)
    }

    func testOutlineNestsSubfoldersAndEditKeepsNoFolderNameFixed() throws {
        let store = CollectionsStore.demo()
        let parent = try XCTUnwrap(store.createCollection(name: "Aaa Psalms", detail: "", parentID: nil, accent: .sage))
        let child = try XCTUnwrap(store.createCollection(name: "Laments", detail: "", parentID: parent, accent: .sage))
        let outline = store.outline()
        let parentIndex = try XCTUnwrap(outline.firstIndex { $0.id == parent })
        XCTAssertEqual(outline[parentIndex + 1].id, child)
        XCTAssertEqual(outline[parentIndex + 1].depth, outline[parentIndex].depth + 1)
        XCTAssertFalse(outline.contains { $0.collection.isUnfiled })

        XCTAssertTrue(store.updateCollection(id: parent, name: " Psalms ", detail: " Songs ", accent: .indigo))
        XCTAssertEqual(store.collection(id: parent)?.name, "Psalms")
        XCTAssertEqual(store.collection(id: parent)?.detail, "Songs")
        XCTAssertEqual(store.collection(id: parent)?.accent, .indigo)
        XCTAssertFalse(store.updateCollection(id: parent, name: "No Folder", detail: "", accent: .indigo))
        XCTAssertTrue(store.updateCollection(id: StudyCollection.unfiledID, name: "Renamed", detail: "", accent: .rose))
        XCTAssertEqual(store.collection(id: StudyCollection.unfiledID)?.name, "No Folder")
        XCTAssertEqual(store.collection(id: StudyCollection.unfiledID)?.accent, .rose)
    }

    func testLinkAndPlaceholderConversationStayDistinctFromTheirFolders() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("collections-" + UUID().uuidString, isDirectory: true)
        let store = CollectionsStore(repository: CollectionsFileRepository(directory: directory))
        await store.load()
        let sample = try XCTUnwrap(store.conversation(id: StudyConversation.placeholderID))
        XCTAssertTrue(sample.isPlaceholder)
        XCTAssertNil(store.addLink(title: "Article", url: "not a link"))
        let link = try XCTUnwrap(store.addLink(title: " Context ", url: "https://example.com/study"))
        XCTAssertEqual(store.link(id: link)?.title, "Context")
        let folder = try XCTUnwrap(store.createCollection(name: "Reading", detail: "", parentID: nil, accent: .slate))
        var note = NoteDocument()
        note.title = "Grace"
        store.link(notes: [note])
        store.addMembership(artifactID: note.id, collectionID: folder)
        store.addMembership(artifactID: link, collectionID: folder)
        store.addMembership(artifactID: sample.id, collectionID: folder)
        store.setMemberships(artifactID: note.id, collectionIDs: [])
        store.removeArtifact(link, from: folder)
        XCTAssertFalse(store.contains(note.id, in: folder))
        XCTAssertNotNil(store.link(id: link))
        XCTAssertTrue(store.presentedArtifacts(for: StudyCollection.unfiledID, includingDescendants: false, notes: [note]).contains { $0.id == link })
        XCTAssertTrue(store.contains(sample.id, in: folder))
        store.deleteLink(link)
        XCTAssertNil(store.link(id: link))
        XCTAssertNotNil(store.conversation(id: sample.id))
        await store.flush()

        let reopened = CollectionsStore(repository: CollectionsFileRepository(directory: directory))
        await reopened.load()
        XCTAssertNil(reopened.link(id: link))
        XCTAssertEqual(reopened.conversation(id: sample.id)?.title, "Sample conversation")
        XCTAssertTrue(reopened.contains(sample.id, in: folder))
    }

    private func samplePassage(kind: SavedPassageKind, insight: String, endVerse: Int) -> SavedPassage {
        SavedPassage(
            id: UUID(),
            bookID: "ROM",
            bookTitle: "Romans",
            chapter: 8,
            startVerse: 1,
            endVerse: endVerse,
            editionID: "web.engwebp",
            versionAbbreviation: "WEB",
            passageText: "There is therefore now no condemnation.",
            insight: insight,
            kind: kind,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
