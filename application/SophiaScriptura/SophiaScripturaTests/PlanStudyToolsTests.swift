import XCTest
import UIKit
@testable import SophiaScriptura

@MainActor final class PlanStudyToolsTests: XCTestCase {
    private func makePlan() -> StudyPlan {
        StudyPlan(title: "Daily reading", preferredEditionID: ScriptureReferenceIdentity.bundledEditionID,
            referenceSystemID: "org.sophia.web.engwebp", sections: [.init(items: [
                .init(payload: .scripture(referenceSystemID: "org.sophia.web.engwebp", book: "GEN", chapter: 1, start: 7, end: 14))])])
    }
    func testFullBookNamePresentationKeepsCanonicalReference() {
        let payload = makePlan().items[0].payload
        XCTAssertEqual(payload.referenceLabel(bookTitle: "Genesis"), "Genesis 1:7–14")
        XCTAssertEqual(payload.book, "GEN")
    }
    func testFocusDimsOtherVersesAndKeepsSelectedContinuationsReadable() throws {
        let blocks = [
            ScriptureBlock(id: "a", kind: "body", text: "First verse", label: "1", verses: [1], style: "p"),
            ScriptureBlock(id: "b", kind: "body", text: "Second verse", label: "2", verses: [2], style: "q1"),
            ScriptureBlock(id: "c", kind: "body", text: "Second continuation", label: "2", verses: [2], style: "q2")]
        let map = ChapterTextMap(document: ChapterDocument(schemaVersion: 1, editionID: "web.engwebp", contentRevision: "test", book: "GEN", chapter: 1, blocks: blocks))
        let text = NSMutableAttributedString(string: map.text, attributes: [.foregroundColor: UIColor.black])
        PlanVerseFocus.apply(to: text, map: map, verses: [2], ink: .black)
        let first = try XCTUnwrap(text.attribute(.foregroundColor, at: map.runs[0].range.location, effectiveRange: nil) as? UIColor)
        XCTAssertLessThan(first.cgColor.alpha, 0.4)
        for run in map.runs.dropFirst() {
            XCTAssertEqual(text.attribute(.foregroundColor, at: run.range.location, effectiveRange: nil) as? UIColor, UIColor.black)
        }
    }
    func testCreatedLinkIsCheckedImmediatelyAfterAnchorAndRetryDoesNotDuplicate() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        _ = await store.submit(.init(intent: .savePlan(makePlan(), collectionID: nil)))
        let plan = try XCTUnwrap(store.plans.first)
        let draft = PlanReflectionDraft(kind: .link, plan: plan, sectionID: plan.sections[0].id, anchorID: plan.items[0].id)
        let created = await draft.createLink(title: "Study source", url: "https://example.com/study", store: store, collectionID: StudyCollection.unfiledID)
        XCTAssertTrue(created)
        let retry = await draft.createLink(title: "Study source", url: "https://example.com/study", store: store, collectionID: StudyCollection.unfiledID)
        XCTAssertTrue(retry)
        let saved = try XCTUnwrap(store.plans.first)
        XCTAssertEqual(saved.items.count, 2); XCTAssertEqual(saved.items[1].payload.targetID, draft.targetID)
        XCTAssertEqual(saved.items[1].origin, .reflection); XCTAssertNotNil(saved.items[1].completedAt)
        XCTAssertNil(saved.items[0].completedAt); XCTAssertEqual(store.links.count, 1)
    }
    func testMultipleReflectionsKeepCreationOrderAfterCurrentAssignment() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        _ = await store.submit(.init(intent: .savePlan(makePlan(), collectionID: nil)))
        let firstPlan = try XCTUnwrap(store.plans.first)
        let first = PlanReflectionDraft(kind: .link, plan: firstPlan, sectionID: firstPlan.sections[0].id, anchorID: firstPlan.items[0].id)
        let firstResult = await first.createLink(title: "First", url: "https://example.com/first", store: store, collectionID: StudyCollection.unfiledID)
        XCTAssertTrue(firstResult)
        let updated = try XCTUnwrap(store.plans.first)
        let second = PlanReflectionDraft(kind: .link, plan: updated, sectionID: updated.sections[0].id, anchorID: updated.items[0].id)
        let secondResult = await second.createLink(title: "Second", url: "https://example.com/second", store: store, collectionID: StudyCollection.unfiledID)
        XCTAssertTrue(secondResult)
        XCTAssertEqual(store.plans.first?.items.dropFirst().map { $0.payload.targetID }, [first.targetID, second.targetID])
    }
    func testStaleAttachmentRetainsSavedLinkWithoutCheckingPhantomItem() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        _ = await store.submit(.init(intent: .savePlan(makePlan(), collectionID: nil)))
        let plan = try XCTUnwrap(store.plans.first)
        let draft = PlanReflectionDraft(kind: .link, plan: plan, sectionID: plan.sections[0].id, anchorID: plan.items[0].id)
        var changed = plan; changed.title = "Changed elsewhere"
        _ = await store.submit(.init(expectedPlanRevision: plan.revision, intent: .savePlan(changed, collectionID: nil)))
        let attached = await draft.createLink(title: "Retained", url: "https://example.com", store: store, collectionID: StudyCollection.unfiledID)
        XCTAssertFalse(attached); XCTAssertEqual(store.links.count, 1); XCTAssertEqual(store.plans.first?.items.count, 1)
        XCTAssertNil(store.plans.first?.items.first?.completedAt)
    }
    func testNoteCreationUsesChosenTypeColorAndClearsCompletedOperation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let notes = NotesSession(repository: NotesFileRepository(directory: directory)); await notes.load()
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        _ = await store.submit(.init(intent: .savePlan(makePlan(), collectionID: nil)))
        let folderA = try XCTUnwrap(store.createCollection(name: "A", detail: "", parentID: nil, accent: .sage))
        let folderB = try XCTUnwrap(store.createCollection(name: "B", detail: "", parentID: nil, accent: .gold))
        let idToFile = try XCTUnwrap(store.plans.first?.id)
        store.addMembership(artifactID: idToFile, collectionID: folderA)
        store.addMembership(artifactID: idToFile, collectionID: folderB)
        await store.flush()
        let plan = try XCTUnwrap(store.plans.first)
        let draft = PlanReflectionDraft(kind: .note, plan: plan, sectionID: plan.sections[0].id, anchorID: plan.items[0].id)
        let id = await draft.createNote(kind: .page, color: .sage, title: "Reflection", notes: notes, store: store, collectionID: StudyCollection.unfiledID)
        XCTAssertEqual(id, draft.targetID)
        let note = try XCTUnwrap(notes.snapshot.notes.first)
        XCTAssertEqual(note.color, .sage); XCTAssertEqual(note.planOrigin?.planID, plan.id)
        XCTAssertNotNil(store.plans.first?.items.last?.completedAt)
        XCTAssertTrue(try store.exportBackupSnapshot().planOperations.isEmpty)
        XCTAssertEqual(Set(store.collectionIDs(containing: draft.targetID)), Set([folderA, folderB]))
    }
}
