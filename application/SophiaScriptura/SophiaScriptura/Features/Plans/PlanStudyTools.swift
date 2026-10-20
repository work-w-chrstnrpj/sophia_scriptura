import SwiftUI

/// One user-initiated reflection attempt retains stable target/operation/receipt IDs.
/// Cross-store failure retains the original material; it never checks a phantom item.
@MainActor @Observable final class PlanReflectionDraft: Identifiable {
    enum Kind { case note, link }
    let id = UUID()
    let targetID = UUID()
    let itemID = UUID()
    let prepareID = UUID()
    let targetCommandID = UUID()
    let attachCommandID = UUID()
    let finishID = UUID()
    let kind: Kind
    let plan: StudyPlan
    let sectionID: UUID
    let anchorID: UUID?
    var message: String?
    var prepared = false
    var targetSaved = false
    var saving = false
    private var attachment: StudyMutationRequest?
    private var savedLink: SavedLink?
    init(kind: Kind, plan: StudyPlan, sectionID: UUID, anchorID: UUID?) {
        self.kind = kind; self.plan = plan; self.sectionID = sectionID; self.anchorID = anchorID
    }
    func createNote(kind: NoteKind, color: CollectionAccent, title: String, notes: NotesSession, store: CollectionsStore, collectionID: UUID) async -> UUID? {
        guard !saving else { return nil }; saving = true; defer { saving = false }
        guard eligible(store), await prepare(store) else { return nil }
        let result = await notes.createPlanNote(planID: plan.id, operationID: id, noteID: targetID,
            title: title, kind: kind, access: store.accessForPlan(plan.id), color: color)
        guard case .committed = result else { message = "The note save was not confirmed. Its draft is retained for retry."; return nil }
        targetSaved = true
        guard await attach(store, collectionID: collectionID) else { return nil }
        store.link(notes: notes.snapshot.notes)
        return targetID
    }
    func createLink(title: String, url: String, store: CollectionsStore, collectionID: UUID) async -> Bool {
        guard !saving else { return false }; saving = true; defer { saving = false }
        guard eligible(store) else { return false }
        // Freeze the target across uncertain retries of the same command.
        if savedLink == nil {
            let address = url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let parsed = URL(string: address), ["https", "http"].contains(parsed.scheme?.lowercased()), parsed.host != nil else {
                message = "Enter a valid http or https link."; return false
            }
            let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
            savedLink = SavedLink(access: store.accessForPlan(plan.id), planOrigin: .init(planID: plan.id), id: targetID,
                title: name.isEmpty ? parsed.host! : name, url: address, createdAt: Date())
        }
        guard let savedLink else { return false }
        let result = await store.submit(.init(commandID: targetCommandID, intent: .saveLink(savedLink, collectionID: collectionID)))
        guard result.receipt != nil else { message = result.message; return false }
        targetSaved = true
        return await attach(store, collectionID: collectionID)
    }
    private func eligible(_ store: CollectionsStore) -> Bool {
        guard let current = store.plans.first(where: { $0.id == plan.id }), current.isActive,
              store.planAccessAllowed(current) else { message = "The Plan is unavailable or locked."; return false }
        return true
    }
    private func prepare(_ store: CollectionsStore) async -> Bool {
        if prepared { return true }
        let operation = PlanOperation(id: id, kind: .attachNote, planID: plan.id, anchorItemID: anchorID,
            targetIDs: [targetID], expectedPlanRevision: plan.revision, access: store.accessForPlan(plan.id), sectionID: sectionID)
        let result = await store.submit(.init(commandID: prepareID, intent: .prepareOperation(operation)))
        message = result.message; prepared = result.receipt != nil
        return prepared
    }
    private func attach(_ store: CollectionsStore, collectionID: UUID) async -> Bool {
        if attachment == nil {
            guard var current = store.plans.first(where: { $0.id == plan.id }), store.planAccessAllowed(current),
                  current.isActive, current.revision == plan.revision,
                  let s = current.sections.firstIndex(where: { $0.id == sectionID }) else {
                message = "The Plan changed. Your new material is saved; reopen the Plan before assigning it."; return false
            }
            let position: Int
            if let anchorID {
                guard let i = current.sections[s].items.firstIndex(where: { $0.id == anchorID }) else { message = "The original assignment was removed. Your material is saved."; return false }
                var insertion = i + 1
                while insertion < current.sections[s].items.count && current.sections[s].items[insertion].origin == .reflection { insertion += 1 }
                position = insertion
            } else { position = current.sections[s].items.count }
            current.sections[s].items.insert(.init(id: itemID, payload: .init(kind: kind == .note ? .note : .link, targetID: targetID),
                completedAt: Date(), origin: .reflection, operationID: id), at: position)
            attachment = .init(commandID: attachCommandID, expectedPlanRevision: current.revision, intent: .savePlan(current, collectionID: collectionID))
        }
        guard let attachment else { return false }
        let result = await store.submit(attachment)
        guard result.receipt != nil else { message = result.message; return false }
        if prepared {
            let finished = await store.submit(.init(commandID: finishID, intent: .finishOperation(id)))
            guard finished.receipt != nil else { message = finished.message; return false }
        }
        message = nil; return true
    }
}

struct PlanNewLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CollectionsStore
    let collectionID: UUID
    @Bindable var draft: PlanReflectionDraft
    @State private var title = ""
    @State private var url = "https://"
    var body: some View {
        NavigationStack {
            Form {
                Section("Link") {
                    TextField("Title", text: $title).accessibilityIdentifier("plans.link.title")
                    TextField("https://", text: $url).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .accessibilityIdentifier("plans.link.url")
                }
                if let message = draft.message { Text(message).foregroundStyle(.red) }
            }.appSurface().navigationTitle("New link").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { if await draft.createLink(title: title, url: url, store: store, collectionID: collectionID) { dismiss() } } }
                        .accessibilityIdentifier("plans.link.save")
                }
            }.disabled(draft.saving)
        }.interactiveDismissDisabled(draft.saving)
    }
}
