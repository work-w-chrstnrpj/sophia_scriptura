import SwiftUI

/// The presenting route owns the draft. Rows capture value IDs, never array-index bindings.
@MainActor @Observable final class PlanEditorDraft: Identifiable {
    let id: UUID
    var draft: StudyPlan
    var expectedRevision: Int?
    var saving = false
    var message: String?
    var addingTo: UUID?
    var resetSection: UUID?
    var confirmReset = false
    var replacingItemID: UUID?
    var commandID = UUID()
    init(plan: StudyPlan, isExisting: Bool = false) {
        id = plan.id; draft = plan; expectedRevision = isExisting ? plan.revision : nil
    }
    func sectionTitle(_ id: UUID) -> String {
        guard let i = draft.sections.firstIndex(where: { $0.id == id }) else { return draft.sectionPrefix }
        return draft.sectionTitle(i)
    }
    func sectionTitleBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { self.draft.sections.first { $0.id == id }?.title ?? "" }, set: { value in
            guard !self.saving, let i = self.draft.sections.firstIndex(where: { $0.id == id }) else { return }
            self.draft.sections[i].title = value.isEmpty ? nil : value; self.changed()
        })
    }
    func addSection() {
        guard !saving else { return }
        guard draft.sections.count < 200 else { message = StudyMutationFailure.capacity.localizedDescription; return }
        draft.sections.append(.init()); changed()
    }
    func removeSection(_ id: UUID) {
        guard !saving, draft.sections.contains(where: { $0.id == id }) else { return }
        // Capture the UUID before mutation; the removed row may still be rendering.
        draft.sections.removeAll { $0.id == id }
        if addingTo == id { closeAssignmentPicker() }
        if resetSection == id { confirmReset = false; resetSection = nil }
        changed()
    }
    func duplicateSection(_ id: UUID) {
        guard !saving, let section = draft.sections.first(where: { $0.id == id }) else { return }
        guard draft.sections.count < 200, draft.items.count + section.items.count <= 2000 else {
            message = StudyMutationFailure.capacity.localizedDescription; return
        }
        let copy = StudyPlan(title: draft.title, preferredEditionID: draft.preferredEditionID,
            referenceSystemID: draft.referenceSystemID, sections: [section]).duplicated().sections[0]
        draft.sections.append(copy); draft.cursor = nil; changed()
    }
    func toggleCompletion(sectionID: UUID, itemID: UUID) {
        guard !saving, let s = draft.sections.firstIndex(where: { $0.id == sectionID }),
              let i = draft.sections[s].items.firstIndex(where: { $0.id == itemID }) else { return }
        draft.sections[s].items[i].completedAt = draft.sections[s].items[i].completedAt == nil ? Date() : nil
        changed()
    }
    func removeItems(_ ids: [UUID], from sectionID: UUID) {
        guard !saving, let s = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
        let removed = Set(ids)
        guard draft.sections[s].items.contains(where: { removed.contains($0.id) }) else { return }
        draft.sections[s].items.removeAll { removed.contains($0.id) }
        if let replacingItemID, removed.contains(replacingItemID) { closeAssignmentPicker() }
        changed()
    }
    func moveItem(_ id: UUID, from sourceID: UUID, to targetID: UUID) {
        guard !saving, sourceID != targetID,
              let source = draft.sections.firstIndex(where: { $0.id == sourceID }),
              let target = draft.sections.firstIndex(where: { $0.id == targetID }),
              let index = draft.sections[source].items.firstIndex(where: { $0.id == id }) else { return }
        let item = draft.sections[source].items.remove(at: index)
        draft.sections[target].items.append(item); changed()
    }
    func moveSections(from source: IndexSet, to target: Int, renderedIDs: [UUID]) {
        guard !saving, draft.sections.map(\.id) == renderedIDs, validMove(source, target, count: renderedIDs.count) else { return }
        draft.sections.move(fromOffsets: source, toOffset: target); changed()
    }
    func moveItems(in sectionID: UUID, from source: IndexSet, to target: Int, renderedIDs: [UUID]) {
        guard !saving, let s = draft.sections.firstIndex(where: { $0.id == sectionID }),
              draft.sections[s].items.map(\.id) == renderedIDs, validMove(source, target, count: renderedIDs.count) else { return }
        draft.sections[s].items.move(fromOffsets: source, toOffset: target); changed()
    }
    func beginAssignment(sectionID: UUID, replacing itemID: UUID? = nil) {
        guard !saving, let section = draft.sections.first(where: { $0.id == sectionID }),
              itemID.map({ id in section.items.contains { $0.id == id } }) ?? true else { return }
        replacingItemID = itemID; addingTo = sectionID
    }
    func closeAssignmentPicker() { addingTo = nil; replacingItemID = nil }
    func applyAssignments(_ payloads: [PlanItemPayload], sectionID: UUID, replacing itemID: UUID?) {
        guard !saving, !payloads.isEmpty, let s = draft.sections.firstIndex(where: { $0.id == sectionID }) else { return }
        guard draft.items.count + payloads.count - (itemID == nil ? 0 : 1) <= 2000 else {
            message = StudyMutationFailure.capacity.localizedDescription; return
        }
        if let itemID {
            guard let i = draft.sections[s].items.firstIndex(where: { $0.id == itemID }) else { return }
            draft.sections[s].items[i].payload = payloads[0]; draft.sections[s].items[i].completedAt = nil
            draft.sections[s].items.insert(contentsOf: payloads.dropFirst().map { .init(payload: $0) }, at: i + 1)
        } else { draft.sections[s].items.append(contentsOf: payloads.map { .init(payload: $0) }) }
        if draft.cursor?.kind == .planSummary || (draft.cursor?.kind == .sectionSummary && draft.cursor?.sectionID == sectionID) { draft.cursor = nil }
        replacingItemID = nil; changed()
    }
    func resetProgress(sectionID: UUID?) {
        guard !saving, sectionID.map({ id in draft.sections.contains { $0.id == id } }) ?? true else { return }
        draft.reset(sectionID: sectionID); changed()
    }
    private func validMove(_ source: IndexSet, _ target: Int, count: Int) -> Bool {
        !source.isEmpty && source.allSatisfy { (0..<count).contains($0) } && (0...count).contains(target)
    }
    private func changed() {
        if let cursor = draft.cursor, cursor.kind != .planSummary {
            if let section = draft.sections.first(where: { $0.id == cursor.sectionID }) {
                if cursor.kind == .item && !section.items.contains(where: { $0.id == cursor.itemID }) { draft.cursor = nil }
            } else { draft.cursor = nil }
        }
        commandID = UUID(); message = nil
    }
}
