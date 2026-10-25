import XCTest
@testable import SophiaScriptura

@MainActor final class PlanScriptureEditingTests: XCTestCase {
    private func payload(_ chapter: Int, start: Int? = nil, end: Int? = nil) -> PlanItemPayload {
        .scripture(referenceSystemID: "org.sophia.web.engwebp", book: "GEN", chapter: chapter, start: start, end: end)
    }
    private func create(_ store: CollectionsStore) async throws -> StudyPlan {
        let plan = StudyPlan(title: "Scripture editing", preferredEditionID: ScriptureReferenceIdentity.bundledEditionID,
            referenceSystemID: "org.sophia.web.engwebp", sections: [.init(items: [
                .init(payload: payload(1), completedAt: Date()), .init(payload: payload(4), completedAt: Date())])])
        let result = await store.submit(.init(intent: .savePlan(plan, collectionID: nil)))
        XCTAssertNotNil(result.receipt)
        return try XCTUnwrap(store.plans.first)
    }
    func testPlanAndFolderEditSameItemAndUpdatedRangeSurvivesReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CollectionsFileRepository(directory: directory)
        let store = CollectionsStore(repository: repository); await store.load()
        let plan = try await create(store), original = plan.items[0]
        let target = try XCTUnwrap(PlanScriptureEditTarget.resolve(itemID: original.id, store: store))
        XCTAssertEqual(target.item.payload, original.payload)
        XCTAssertEqual(target.plan.id, plan.id)
        let result = await PlanCommandService(store: store).replaceScripture(planID: plan.id,
            sectionID: target.sectionID, itemID: target.id, expectedRevision: plan.revision,
            payloads: [payload(2, start: 3, end: 8)])
        XCTAssertNotNil(result.receipt)
        let saved = try XCTUnwrap(store.plans.first)
        XCTAssertEqual(saved.items[0].id, original.id)
        XCTAssertEqual(saved.items[0].payload, payload(2, start: 3, end: 8))
        XCTAssertNil(saved.items[0].completedAt)
        XCTAssertEqual(saved.items[1].completedAt, plan.items[1].completedAt)
        XCTAssertEqual(saved.completedSectionCount, 0)
        XCTAssertEqual(saved.sections[0].materialsFolderID, plan.sections[0].materialsFolderID)
        let folder = try XCTUnwrap(saved.sections[0].materialsFolderID)
        let row = try XCTUnwrap(store.presentedArtifacts(for: folder, includingDescendants: false, notes: []).first { $0.id == original.id })
        XCTAssertEqual(row.title, "GEN 2:3–8")
        XCTAssertTrue(row.passageText.isEmpty)
        let reopened = CollectionsStore(repository: repository); await reopened.load()
        XCTAssertEqual(reopened.plans.first?.items, saved.items)
        XCTAssertEqual(PlanScriptureEditTarget.resolve(itemID: original.id, store: reopened)?.item.payload, saved.items[0].payload)
    }
    func testMultiChapterReplacementKeepsFirstIdentityAndFilesEveryChapter() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        let plan = try await create(store)
        let replacement = [payload(2), payload(3)]
        let result = await PlanCommandService(store: store).replaceScripture(planID: plan.id,
            sectionID: plan.sections[0].id, itemID: plan.items[0].id, expectedRevision: plan.revision, payloads: replacement)
        XCTAssertNotNil(result.receipt)
        let saved = try XCTUnwrap(store.plans.first)
        XCTAssertEqual(Array(saved.items.prefix(2).map(\.payload)), replacement)
        XCTAssertEqual(saved.items.first?.id, plan.items.first?.id)
        XCTAssertEqual(saved.items.last, plan.items.last)
        let folder = try XCTUnwrap(saved.sections[0].materialsFolderID)
        for item in saved.items { XCTAssertTrue(store.collectionIDs(containing: item.id).contains(folder)) }
    }
    func testUnchangedSelectionKeepsCompletionAndStaleEditorCannotOverwrite() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        let plan = try await create(store)
        let result = await PlanCommandService(store: store).replaceScripture(planID: plan.id,
            sectionID: plan.sections[0].id, itemID: plan.items[0].id, expectedRevision: plan.revision,
            payloads: [plan.items[0].payload])
        XCTAssertNotNil(result.receipt)
        XCTAssertEqual(store.plans.first?.items[0].completedAt, plan.items[0].completedAt)
        let stale = await PlanCommandService(store: store).replaceScripture(planID: plan.id,
            sectionID: plan.sections[0].id, itemID: plan.items[0].id, expectedRevision: plan.revision, payloads: [payload(2)])
        XCTAssertEqual(stale, .rejected(.stale))
        XCTAssertEqual(store.plans.first?.items[0].payload, plan.items[0].payload)
    }
    func testInvalidReferenceAndTrashedPlanCannotBeEdited() async throws {
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        let plan = try await create(store)
        store.validatePlanReference = { _, _ in throw StudyMutationFailure.invalid }
        let result = await PlanCommandService(store: store).replaceScripture(planID: plan.id,
            sectionID: plan.sections[0].id, itemID: plan.items[0].id, expectedRevision: plan.revision, payloads: [payload(150)])
        XCTAssertEqual(result, .rejected(.invalid))
        XCTAssertEqual(store.plans.first?.items[0], plan.items[0])
        let deleted = await store.setPlanTreeTrashed(plan.id, trashed: true)
        XCTAssertNotNil(deleted.receipt)
        XCTAssertNil(PlanScriptureEditTarget.resolve(itemID: plan.items[0].id, store: store))
        let denied = await PlanCommandService(store: store).replaceScripture(planID: plan.id,
            sectionID: plan.sections[0].id, itemID: plan.items[0].id, expectedRevision: plan.revision, payloads: [payload(2)])
        XCTAssertEqual(denied, .rejected(.accessDenied))
    }
}
