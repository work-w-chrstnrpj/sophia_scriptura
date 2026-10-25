import SwiftUI

/// Both Plan and folder projections edit the same stable assignment/revision.
struct PlanScriptureEditTarget: Identifiable {
    let plan: StudyPlan
    let sectionID: UUID
    let item: PlanItem
    var id: UUID { item.id }
    @MainActor static func resolve(itemID: UUID, store: CollectionsStore) -> Self? {
        for plan in store.plans where plan.isActive && store.planAccessAllowed(plan) {
            for section in plan.sections {
                if let item = section.items.first(where: { $0.id == itemID && $0.payload.kind == .scripture }) {
                    return .init(plan: plan, sectionID: section.id, item: item)
                }
            }
        }
        return nil
    }
}

struct PlanScriptureAssignmentEditor: View {
    @ObservedObject var store: CollectionsStore
    @ObservedObject private var protection = ItemProtectionSession.shared
    @Environment(\.dismiss) private var dismiss
    let notes: NotesSession
    let reader: ReaderSession?
    let target: PlanScriptureEditTarget
    private var permitted: Bool { PlanScriptureEditTarget.resolve(itemID: target.item.id, store: store) != nil }
    var body: some View {
        let _ = protection.unlocked
        Group {
            if permitted { picker }
            else { ContentUnavailableView("Assignment unavailable or locked", systemImage: "lock") }
        }
        .onChange(of: permitted) { _, allowed in if !allowed { dismiss() } }
    }
    private var picker: some View {
        PlanAssignmentPicker(store: store, notes: notes, reader: reader,
            referenceSystemID: target.plan.referenceSystemID, planID: target.plan.id,
            sectionID: target.sectionID, collectionID: target.plan.materialsFolderID ?? StudyCollection.unfiledID,
            initialScripture: target.item.payload, scriptureOnly: true,
            onSaveScripture: { payloads in
                await PlanCommandService(store: store).replaceScripture(planID: target.plan.id,
                    sectionID: target.sectionID, itemID: target.item.id,
                    expectedRevision: target.plan.revision, payloads: payloads)
            }, onAdded: { _ in })
    }
}
