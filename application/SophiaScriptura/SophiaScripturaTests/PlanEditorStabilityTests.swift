import XCTest
@testable import SophiaScriptura

@MainActor final class PlanEditorStabilityTests: XCTestCase {
    private func payload(_ chapter: Int = 1) -> PlanItemPayload {
        .scripture(referenceSystemID: "org.sophia.web.engwebp", book: "GEN", chapter: chapter)
    }
    private func makePlan() -> StudyPlan {
        .init(title: "Stability", preferredEditionID: ScriptureReferenceIdentity.bundledEditionID,
            referenceSystemID: "org.sophia.web.engwebp", sections: (1...3).map { n in
                .init(items: [.init(payload: payload(n)), .init(payload: .init(kind: .note, targetID: UUID()))])
            })
    }
    func testDeletingOnlySectionLeavesStaleTextBindingSafe() throws {
        var plan = makePlan(); plan.sections = [plan.sections[0]]
        let model = PlanEditorDraft(plan: plan)
        let id = plan.sections[0].id, binding = model.sectionTitleBinding(plan.sections[0].id)
        binding.wrappedValue = "Remove me"
        model.removeSection(id)
        XCTAssertTrue(model.draft.sections.isEmpty)
        XCTAssertEqual(binding.wrappedValue, "")
        binding.wrappedValue = "Delayed keyboard event"
        XCTAssertTrue(model.draft.sections.isEmpty)
        model.addSection(); XCTAssertNotEqual(model.draft.sections[0].id, id)
        XCTAssertNoThrow(try model.draft.validate())
    }
    func testFirstMiddleLastAndRepeatedSectionDeletionPreserveSurvivors() throws {
        for order in [[0, 1, 2], [2, 1, 0], [1, 0, 2]] {
            let plan = makePlan()
            let model = PlanEditorDraft(plan: plan)
            for index in order {
                let removedID = plan.sections[index].id
                model.removeSection(removedID)
                let current = model.draft, command = model.commandID
                model.removeSection(removedID)
                XCTAssertEqual(model.draft, current); XCTAssertEqual(model.commandID, command)
                for section in model.draft.sections {
                    XCTAssertEqual(section, plan.sections.first { $0.id == section.id })
                }
                XCTAssertNoThrow(try model.draft.validate())
            }
            XCTAssertTrue(model.draft.sections.isEmpty)
        }
    }
    func testRemovedItemCallbacksCannotAffectNextItem() {
        let model = PlanEditorDraft(plan: makePlan()), section = makePlan().sections[0]
        let s = model.draft.sections[0], removedID = s.items[0].id, nextID = s.items[1].id
        model.removeItems([removedID], from: s.id)
        model.toggleCompletion(sectionID: s.id, itemID: removedID)
        model.moveItem(removedID, from: s.id, to: model.draft.sections[1].id)
        XCTAssertEqual(model.draft.sections[0].items.map(\.id), [nextID])
        XCTAssertNil(model.draft.sections[0].items[0].completedAt)
        model.removeItems([section.id], from: UUID()) // stale unrelated callback
        XCTAssertEqual(model.draft.sections[0].items.count, 1)
    }
    func testMovesRejectStaleSnapshotsAndInvalidOffsets() {
        let model = PlanEditorDraft(plan: makePlan()), original = makePlan()
        let before = model.draft, ids = before.sections.map(\.id), s = before.sections[0]
        model.moveSections(from: [99], to: 0, renderedIDs: ids)
        model.moveSections(from: [0], to: -1, renderedIDs: ids)
        model.moveSections(from: [0], to: 99, renderedIDs: ids)
        model.moveSections(from: [0], to: 2, renderedIDs: original.sections.map(\.id))
        model.moveItems(in: s.id, from: [20], to: 0, renderedIDs: s.items.map(\.id))
        model.moveItems(in: s.id, from: [0], to: 99, renderedIDs: s.items.map(\.id))
        model.removeSection(UUID())
        XCTAssertEqual(model.draft, before)
        model.removeItems([s.items[0].id], from: s.id)
        let changed = model.draft
        model.moveItems(in: s.id, from: [0], to: 1, renderedIDs: s.items.map(\.id))
        XCTAssertEqual(model.draft, changed)
    }
    func testRepeatedDragCallbackUsesRenderedIdentitiesAfterReorder() {
        let model = PlanEditorDraft(plan: makePlan())
        let ids = model.draft.sections.map(\.id)
        model.moveSections(from: [0], to: 3, renderedIDs: ids)
        model.moveSections(from: [1], to: 0, renderedIDs: ids)
        XCTAssertEqual(model.draft.sections.map(\.id), [ids[1], ids[0], ids[2]])
    }
    func testReorderAndCrossSectionMoveRetainIDsAndCompletion() throws {
        let model = PlanEditorDraft(plan: makePlan()), before = makePlan()
        let firstID = model.draft.sections[0].id, targetID = model.draft.sections[1].id
        let item = model.draft.sections[0].items[0]
        model.toggleCompletion(sectionID: firstID, itemID: item.id)
        let checkedAt = model.draft.sections[0].items[0].completedAt
        model.draft.cursor = .init(kind: .item, sectionID: firstID, itemID: item.id, editionID: model.draft.preferredEditionID)
        let ids = model.draft.sections.map(\.id)
        model.moveSections(from: [0], to: 3, renderedIDs: ids)
        XCTAssertEqual(model.draft.sections.last?.id, firstID); XCTAssertNotNil(model.draft.cursor)
        let source = try XCTUnwrap(model.draft.sections.first { $0.id == firstID })
        model.moveItems(in: firstID, from: [0], to: 2, renderedIDs: source.items.map(\.id))
        model.moveItem(item.id, from: firstID, to: targetID)
        XCTAssertEqual(model.draft.sections.first { $0.id == targetID }?.items.last?.id, item.id)
        XCTAssertEqual(model.draft.sections.first { $0.id == targetID }?.items.last?.completedAt, checkedAt)
        XCTAssertNil(model.draft.cursor)
        XCTAssertEqual(model.draft.items.count, before.items.count)
        XCTAssertNoThrow(try model.draft.validate())
    }
    func testDeletingCurrentTargetClearsCursorButUnrelatedDeletionDoesNot() throws {
        let model = PlanEditorDraft(plan: makePlan()), section = makePlan().sections[0]
        let selected = model.draft.sections[0]
        model.draft.cursor = .init(kind: .item, sectionID: selected.id, itemID: selected.items[0].id, editionID: model.draft.preferredEditionID)
        model.removeSection(model.draft.sections[2].id)
        XCTAssertNotNil(model.draft.cursor)
        model.removeItems([selected.items[0].id], from: selected.id)
        XCTAssertNil(model.draft.cursor)
        model.beginAssignment(sectionID: selected.id, replacing: selected.items[1].id)
        model.resetSection = selected.id; model.confirmReset = true
        model.removeSection(selected.id)
        XCTAssertNil(model.addingTo); XCTAssertNil(model.replacingItemID); XCTAssertFalse(model.confirmReset)
        model.resetProgress(sectionID: section.id)
        XCTAssertNoThrow(try model.draft.validate())
    }
    func testCancelReplacementThenAddDoesNotReplaceExistingAssignment() {
        let model = PlanEditorDraft(plan: makePlan()), section = makePlan().sections[0]
        let s = model.draft.sections[0]
        model.beginAssignment(sectionID: s.id, replacing: s.items[0].id)
        model.closeAssignmentPicker()
        model.beginAssignment(sectionID: s.id)
        XCTAssertNil(model.replacingItemID)
        model.applyAssignments([payload(10)], sectionID: s.id, replacing: model.replacingItemID)
        XCTAssertEqual(model.draft.sections[0].items.count, 3)
        XCTAssertEqual(model.draft.sections[0].items[0], s.items[0])
        model.beginAssignment(sectionID: section.id)
        XCTAssertEqual(model.addingTo, s.id) // stale target does not replace the valid route
    }
    func testBatchReplacementKeepsAllChaptersAndStaleTargetCannotAppend() throws {
        let model = PlanEditorDraft(plan: makePlan()), s = makePlan().sections[0]
        let current = model.draft.sections[0], replacement = [payload(10), payload(11), payload(12)]
        model.toggleCompletion(sectionID: current.id, itemID: current.items[0].id)
        model.applyAssignments(replacement, sectionID: current.id, replacing: current.items[0].id)
        XCTAssertEqual(model.draft.sections[0].items.prefix(3).map(\.payload), replacement)
        XCTAssertEqual(model.draft.sections[0].items[0].id, current.items[0].id)
        XCTAssertNil(model.draft.sections[0].items[0].completedAt)
        let before = model.draft
        model.applyAssignments([payload(13)], sectionID: current.id, replacing: UUID())
        model.applyAssignments([payload(13)], sectionID: s.id, replacing: nil)
        XCTAssertEqual(model.draft, before)
        XCTAssertNoThrow(try model.draft.validate())
    }
    func testDuplicateResetAndSummaryInvalidationPreserveReferences() throws {
        let model = PlanEditorDraft(plan: makePlan()), s = makePlan().sections[0]
        let source = model.draft.sections[0]
        model.toggleCompletion(sectionID: source.id, itemID: source.items[0].id)
        model.toggleCompletion(sectionID: model.draft.sections[1].id, itemID: model.draft.sections[1].items[0].id)
        model.draft.cursor = .init(kind: .planSummary)
        model.duplicateSection(source.id)
        let copy = try XCTUnwrap(model.draft.sections.last)
        XCTAssertNotEqual(copy.id, source.id); XCTAssertEqual(copy.items.map(\.payload), source.items.map(\.payload))
        XCTAssertTrue(Set(copy.items.map(\.id)).isDisjoint(with: Set(source.items.map(\.id))))
        XCTAssertTrue(copy.items.allSatisfy { $0.completedAt == nil && $0.operationID == nil })
        XCTAssertNil(model.draft.cursor)
        model.resetProgress(sectionID: source.id)
        XCTAssertEqual(model.draft.completedCount, 1)
        model.resetProgress(sectionID: s.id); XCTAssertEqual(model.draft.completedCount, 1)
        model.resetProgress(sectionID: nil); XCTAssertEqual(model.draft.completedCount, 0)
        XCTAssertNoThrow(try model.draft.validate())
    }
    func testSavingFreezesDraftAndCapacityDoesNotPublishInvalidEdits() {
        let model = PlanEditorDraft(plan: makePlan()), initial = makePlan()
        let before = model.draft, s = before.sections[0]
        model.saving = true
        model.removeSection(s.id); model.addSection(); model.duplicateSection(s.id)
        model.removeItems([s.items[0].id], from: s.id); model.toggleCompletion(sectionID: s.id, itemID: s.items[0].id)
        model.sectionTitleBinding(s.id).wrappedValue = "Late edit"
        model.applyAssignments([payload(8)], sectionID: s.id, replacing: nil); model.resetProgress(sectionID: nil)
        XCTAssertEqual(model.draft, before)
        model.saving = false
        model.draft.sections = (0..<200).map { _ in .init() }
        model.addSection(); model.duplicateSection(model.draft.sections[0].id)
        XCTAssertEqual(model.draft.sections.count, 200); XCTAssertNotNil(model.message)
        model.draft = initial
        model.draft.sections[0].items = (0..<1996).map { _ in .init(payload: payload()) }
        model.applyAssignments([payload()], sectionID: model.draft.sections[0].id, replacing: nil)
        XCTAssertEqual(model.draft.items.count, 2000); XCTAssertNotNil(model.message)
    }
    func testMixedStructuralEditsRemainValidAndRoundTripAfterSave() async throws {
        let model = PlanEditorDraft(plan: makePlan())
        for n in 0..<400 {
            if model.draft.sections.isEmpty { model.addSection() }
            let id = model.draft.sections[0].id
            switch n % 7 {
            case 0: model.applyAssignments([payload(n % 30 + 1)], sectionID: id, replacing: nil)
            case 1: model.duplicateSection(id)
            case 2: model.moveSections(from: [0], to: model.draft.sections.count, renderedIDs: model.draft.sections.map(\.id))
            case 3: model.sectionTitleBinding(id).wrappedValue = "Part \(n)"
            case 4: model.resetProgress(sectionID: id)
            case 5: model.removeSection(id)
            default:
                if let item = model.draft.sections[0].items.first { model.removeItems([item.id], from: id) }
            }
            XCTAssertNoThrow(try model.draft.validate(), "Mutation \(n)")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CollectionsFileRepository(directory: directory)
        let store = CollectionsStore(repository: repository); await store.load()
        let result = await store.submit(.init(intent: .savePlan(model.draft, collectionID: nil)))
        XCTAssertNotNil(result.receipt)
        let reopened = CollectionsStore(repository: repository); await reopened.load()
        XCTAssertEqual(reopened.plans.first?.sections.map(\.items), model.draft.sections.map(\.items))
    }
    func testChapterBoundsSurviveShorterBookAndTransientInvalidValues() {
        let shorter = PlanChapterBounds(chapter: 150, lastChapter: 150, chapterCount: 1)
        XCTAssertEqual(shorter.chapter, 1); XCTAssertEqual(shorter.lastChapter, 1)
        XCTAssertEqual(shorter.throughRange, 1...1)
        for count in [0, 1, 2, 21, 150] {
            for chapter in [-20, 0, 1, 2, 100, 150, 200] {
                for end in [-10, 1, 200] {
                    let value = PlanChapterBounds(chapter: chapter, lastChapter: end, chapterCount: count)
                    XCTAssertTrue((1...max(1, count)).contains(value.chapter))
                    XCTAssertTrue(value.throughRange.contains(value.lastChapter))
                }
            }
        }
    }
}
