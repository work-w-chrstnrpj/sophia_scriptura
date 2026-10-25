import SwiftUI

struct PlanLifecycleLibrary: View {
    @ObservedObject var store: CollectionsStore
    let notes: NotesSession
    var archived = false
    @State private var message: String?
    @State private var pendingDelete: StudyPlan?
    private var records: [StudyPlan] { store.plans.filter { (archived ? $0.archivedAt != nil && $0.trashedAt == nil : $0.trashedAt != nil) && store.planAccessAllowed($0) } }
    var body: some View {
        List {
            if let message { Text(message).foregroundStyle(.red) }
            ForEach(records) { plan in
                VStack(alignment: .leading) {
                    Text(plan.title)
                    HStack {
                        Button(archived ? "Unarchive" : "Restore") {
                            Task {
                                var restored = plan
                                if archived {
                                    restored.archivedAt = nil
                                    message = await store.submit(.init(expectedPlanRevision: plan.revision, intent: .savePlan(restored, collectionID: nil))).message
                                } else { message = await store.setPlanTreeTrashed(plan.id, trashed: false).message }
                            }
                        }
                        if !archived { Button("Delete permanently", role: .destructive) { pendingDelete = plan } }
                    }.buttonStyle(.borderless)
                }
            }
        }
        .navigationTitle(archived ? "Archived Plans" : "Plans trash")
        .overlay { if records.isEmpty { ContentUnavailableView("No Plans", systemImage: "list.bullet.rectangle") } }
        .confirmationDialog("Permanently delete this Plan?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete Plan", role: .destructive) {
                guard let plan = pendingDelete else { return }; pendingDelete = nil
                Task { message = await store.submit(.init(expectedPlanRevision: plan.revision, intent: .purgePlan(plan.id))).message }
            }
        } message: { Text("The Plan and its deleted folder tree will be permanently removed. Shared items remain in their other locations.") }
    }
}
