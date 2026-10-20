import SwiftUI

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CollectionsStore
    let notes: NotesSession
    var reader: ReaderSession?
    let collectionID: UUID
    @Bindable var model: PlanEditorDraft

    private var permitted: Bool {
        if let plan = store.plans.first(where: { $0.id == model.draft.id }) { return store.planAccessAllowed(plan) }
        return !store.isLocked(collectionID)
    }
    var body: some View {
        let resetTarget = model.resetSection
        return NavigationStack {
            Group {
                if permitted { editor }
                else { ContentUnavailableView("Plan locked", systemImage: "lock", description: Text("Close and unlock Collections to continue.")) }
            }
            .navigationTitle(model.expectedRevision == nil ? "New Plan" : model.draft.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(model.saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(model.saving || !permitted)
                        .accessibilityIdentifier("plans.save")
                }
                ToolbarItem(placement: .secondaryAction) { EditButton().disabled(model.saving) }
            }
            .sheet(item: Binding(get: { model.addingTo.map(PlanSectionTarget.init) }, set: { if $0 == nil { model.closeAssignmentPicker() } else { model.addingTo = $0?.id } })) { target in
                PlanAssignmentPicker(store: store, notes: notes, reader: reader, referenceSystemID: model.draft.referenceSystemID, planID: model.draft.id, access: store.accessForPlan(model.draft.id), collectionID: collectionID) { payloads in
                    model.applyAssignments(payloads, sectionID: target.id, replacing: model.replacingItemID)
                }
            }
            .confirmationDialog(model.resetSection == nil ? "Reset the whole Plan?" : "Reset this section?", isPresented: $model.confirmReset, titleVisibility: .visible) {
                Button("Reset progress", role: .destructive) { model.resetProgress(sectionID: resetTarget) }
            } message: { Text("Notes, links and Pencil drawings are kept.") }
            .onChange(of: permitted) { _, allowed in if !allowed { model.closeAssignmentPicker(); model.confirmReset = false } }
        }
        .interactiveDismissDisabled(model.saving)
    }
    private var editor: some View {
        let sections = model.draft.sections
        return List {
            Section("Plan") {
                TextField("Plan title", text: $model.draft.title).accessibilityIdentifier("plans.title")
                TextField("Description", text: $model.draft.detail, axis: .vertical)
                TextField("Section label, such as Day", text: $model.draft.sectionPrefix)
                Text("Translation: \(reader?.edition?.id == model.draft.preferredEditionID ? reader?.edition?.abbreviation ?? model.draft.preferredEditionID : model.draft.preferredEditionID)").font(.caption)
                if let reader, let edition = reader.edition, edition.id != model.draft.preferredEditionID {
                    Button("Use current translation (\(edition.abbreviation))") { model.draft.preferredEditionID = edition.id; model.commandID = UUID() }
                }
                if let message = model.message { Text(message).foregroundStyle(.red).accessibilityIdentifier("plans.error") }
            }
            ForEach(sections) { section in
                Section {
                    TextField(model.sectionTitle(section.id), text: model.sectionTitleBinding(section.id))
                        .accessibilityIdentifier("plans.sectionTitle.\(section.id)")
                    ForEach(section.items) { item in
                        HStack {
                            Button { model.toggleCompletion(sectionID: section.id, itemID: item.id) } label: {
                                Image(systemName: item.completedAt == nil ? "circle" : "checkmark.circle.fill")
                            }.buttonStyle(.borderless).accessibilityLabel(item.completedAt == nil ? "Mark complete" : "Mark unfinished")
                            Text(itemTitle(item)).lineLimit(2)
                            Spacer()
                            Menu {
                                Button("Replace assignment") {
                                    Task { if await persistDraft() { model.beginAssignment(sectionID: section.id, replacing: item.id) } }
                                }
                                ForEach(model.draft.sections.filter { $0.id != section.id }) { destination in
                                    Button("Move to \(model.sectionTitle(destination.id))") {
                                        model.moveItem(item.id, from: section.id, to: destination.id)
                                    }
                                }
                                Button(role: .destructive) { model.removeItems([item.id], from: section.id) } label: {
                                    Label("Remove assignment", systemImage: "trash").foregroundStyle(.red)
                                }
                            } label: { Image(systemName: "ellipsis") }.buttonStyle(.borderless)
                                .accessibilityLabel("Manage assignment \(itemTitle(item))")
                                .accessibilityIdentifier("plans.manageItem.\(item.id)")
                        }
                    }
                    .onMove { source, target in model.moveItems(in: section.id, from: source, to: target, renderedIDs: section.items.map(\.id)) }
                    .onDelete { offsets in model.removeItems(offsets.compactMap { section.items.indices.contains($0) ? section.items[$0].id : nil }, from: section.id) }
                    Button("Add assignment", systemImage: "plus") {
                        Task { if await persistDraft() { model.beginAssignment(sectionID: section.id) } }
                    }.accessibilityIdentifier("plans.addAssignment")
                    Menu {
                        Button("Reset section") { model.resetSection = section.id; model.confirmReset = true }
                        Button("Duplicate section") { model.duplicateSection(section.id) }
                        Button("Remove section", role: .destructive) { model.removeSection(section.id) }
                    } label: {
                        HStack { Text("Manage section"); Spacer(); Image(systemName: "ellipsis") }.contentShape(Rectangle())
                    }.buttonStyle(.borderless).accessibilityLabel("Manage section")
                    .accessibilityIdentifier("plans.manageSection.\(section.id)")
                } header: { Text(model.sectionTitle(section.id)) }
            }
            .onMove { source, target in model.moveSections(from: source, to: target, renderedIDs: sections.map(\.id)) }
            Section {
                Button("Add section", systemImage: "plus.rectangle.on.rectangle") { model.addSection() }
                    .accessibilityIdentifier("plans.addSection")
                Button("Reset whole Plan", systemImage: "arrow.counterclockwise") { model.resetSection = nil; model.confirmReset = true }
                if model.expectedRevision != nil {
                    Button("Duplicate Plan", systemImage: "doc.on.doc") { Task { await duplicate() } }.disabled(model.saving)
                    Button(model.draft.archivedAt == nil ? "Archive Plan" : "Unarchive Plan", systemImage: model.draft.archivedAt == nil ? "archivebox" : "tray.and.arrow.up") { model.draft.archivedAt = model.draft.archivedAt == nil ? Date() : nil; model.commandID = UUID() }
                    Button(role: .destructive) { model.draft.trashedAt = Date(); Task { await save() } } label: {
                        Label("Move Plan to Trash", systemImage: "trash").foregroundStyle(.red)
                    }.tint(.red)
                }
            } footer: { Text("Assignments may share existing notes and links. Removing an assignment keeps its original material.") }
        }
        .appSurface()
        .disabled(model.saving)
        .task { await reader?.start() }
    }
    private func itemTitle(_ item: PlanItem) -> String {
        switch item.payload.kind {
        case .scripture: return item.payload.referenceLabel(bookTitle: reader?.books.first(where: { $0.id == item.payload.book })?.title ?? item.payload.book ?? "Scripture")
        case .note:
            guard let note = notes.snapshot.notes.first(where: { $0.id == item.payload.targetID }), note.isActiveInLibrary else { return "Note unavailable" }
            return notes.isLocked(note) || store.concealsNote(note.id) ? "Locked note" : "\(note.title) (\(note.kind.displayName))"
        case .link:
            guard let link = store.links.first(where: { $0.id == item.payload.targetID }), store.accessAllowed(link.access) else { return "Link unavailable" }
            return link.title
        }
    }
    private func persistDraft() async -> Bool {
        guard permitted, !model.saving else { return false }; model.saving = true; defer { model.saving = false }
        model.draft.title = model.draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = await store.submit(.init(commandID: model.commandID, expectedPlanRevision: model.expectedRevision, intent: .savePlan(model.draft, collectionID: collectionID)))
        guard result.receipt != nil, let saved = store.plans.first(where: { $0.id == model.draft.id }) else { model.message = result.message; return false }
        model.draft = saved; model.expectedRevision = saved.revision; model.commandID = UUID(); model.message = nil
        return true
    }
    private func save() async { if await persistDraft() { dismiss() } }
    private func duplicate() async {
        guard permitted else { return }; model.saving = true; defer { model.saving = false }
        let result = await store.submit(.init(intent: .savePlan(model.draft.duplicated(), collectionID: collectionID)))
        if result.receipt != nil { dismiss() } else { model.message = result.message }
    }
}
private struct PlanSectionTarget: Identifiable { let id: UUID }
