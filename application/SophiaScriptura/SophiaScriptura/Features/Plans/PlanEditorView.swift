import SwiftUI

struct PlanEditorView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmDeletePlan = false
    @State private var editMode: EditMode = .inactive
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CollectionsStore
    let notes: NotesSession
    var reader: ReaderSession?
    let collectionID: UUID
    @Bindable var model: PlanEditorDraft
    /// Existing Plans embed this editor in their main workspace. New Plans retain
    /// their creation route while sharing every field, command and autosave boundary.
    var embedded = false
    var onFinish: (() -> Void)? = nil

    private var permitted: Bool {
        if let plan = store.plans.first(where: { $0.id == model.draft.id }) { return store.planAccessAllowed(plan) }
        return !store.isLocked(collectionID)
    }
    var body: some View {
        Group {
            if embedded { editorContent }
            else {
                NavigationStack {
                    editorContent
                        .navigationTitle(model.expectedRevision == nil ? "New Plan" : model.draft.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    if !permitted { finish() }
                                    else if model.expectedRevision == nil && model.draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.draft.items.isEmpty { finish() }
                                    else { Task { await save() } }
                                }.disabled(model.saving)
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") { Task { await save() } }.disabled(model.saving || !permitted)
                                    .accessibilityIdentifier("plans.save")
                            }
                            ToolbarItem(placement: .secondaryAction) { EditButton().disabled(model.saving) }
                        }
                }
            }
        }
        .interactiveDismissDisabled(model.saving || model.autosaving || model.saveStatus != "Saved")
        .environment(\.editMode, $editMode)
        .onAppear { if embedded { editMode = .active } }
        .onChange(of: model.draft) { _, _ in model.scheduleAutosave(store: store, collectionID: collectionID) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { _ = await model.persist(store: store, collectionID: collectionID) } }
        }
        .onDisappear { Task { _ = await model.persist(store: store, collectionID: collectionID) } }
    }
    private var editorContent: some View {
        let resetTarget = model.resetSection
        return Group {
            if permitted { editor }
            else { ContentUnavailableView("Plan locked", systemImage: "lock", description: Text("Close and unlock Collections to continue.")) }
        }
            .sheet(item: Binding(get: { model.addingTo.map(PlanSectionTarget.init) }, set: { if $0 == nil { model.closeAssignmentPicker() } else { model.addingTo = $0?.id } })) { target in
                PlanAssignmentPicker(store: store, notes: notes, reader: reader, referenceSystemID: model.draft.referenceSystemID, planID: model.draft.id, sectionID: target.id, collectionID: collectionID,
                    initialScripture: model.draft.items.first(where: { $0.id == model.replacingItemID && $0.payload.kind == .scripture })?.payload) { payloads in
                    if let saved = store.plans.first(where: { $0.id == model.draft.id }) { model.adoptSavedPlan(saved) }
                    model.applyAssignments(payloads, sectionID: target.id, replacing: model.replacingItemID)
                }
            }
            .overlay {
                if confirmDeletePlan {
                    StudyCenteredConfirmationOverlay(title: "Delete this Plan?", message: store.planDeleteMessage,
                        confirmLabel: "Delete Plan", confirmAccessibilityIdentifier: "plans.delete.confirm",
                        onConfirm: { confirmDeletePlan = false; Task { await deletePlan() } },
                        onCancel: { confirmDeletePlan = false })
                }
            }
            .confirmationDialog(model.resetSection == nil ? "Reset the whole Plan?" : "Reset this section?", isPresented: $model.confirmReset, titleVisibility: .visible) {
                Button("Reset progress", role: .destructive) { model.resetProgress(sectionID: resetTarget) }
            } message: { Text("Notes, links and Pencil drawings are kept.") }
            .onChange(of: permitted) { _, allowed in if !allowed { model.closeAssignmentPicker(); model.confirmReset = false; confirmDeletePlan = false } }
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
                Text(model.saveStatus).font(.caption).accessibilityIdentifier("plans.saveStatus")
                if let message = model.message { Text(message).foregroundStyle(.red).accessibilityIdentifier("plans.error") }
            }
            Section {
                HStack {
                    Label("Linked Folder", systemImage: "folder")
                    Spacer()
                    Text(linkedFolderName).foregroundStyle(.secondary)
                }.accessibilityIdentifier("plans.linkedFolder")
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
                            if editMode.isEditing {
                                Button("Move assignment up", systemImage: "arrow.up") {
                                    let ids = model.draft.sections.first(where: { $0.id == section.id })?.items.map(\.id) ?? []
                                    if let i = ids.firstIndex(of: item.id), i > 0 { model.moveItems(in: section.id, from: [i], to: i - 1, renderedIDs: ids) }
                                }.labelStyle(.iconOnly).buttonStyle(.borderless)
                                Button("Move assignment down", systemImage: "arrow.down") {
                                    let ids = model.draft.sections.first(where: { $0.id == section.id })?.items.map(\.id) ?? []
                                    if let i = ids.firstIndex(of: item.id), i + 1 < ids.count { model.moveItems(in: section.id, from: [i], to: i + 2, renderedIDs: ids) }
                                }.labelStyle(.iconOnly).buttonStyle(.borderless)
                            }
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
                    Button(role: .destructive) { confirmDeletePlan = true } label: {
                        Label("Delete Plan", systemImage: "trash").foregroundStyle(.red)
                    }.tint(.red).accessibilityIdentifier("plans.delete.begin")
                }
            } footer: { Text("Assignments may share existing notes and links. Removing an assignment keeps its original material.") }
        }
        .appSurface()
        .disabled(model.saving)
        .task { await reader?.start() }
    }
    private var linkedFolderName: String {
        guard let id = model.draft.materialsFolderID else { return "Created automatically" }
        guard let folder = store.collection(id: id), folder.isActiveInLibrary else { return "Unavailable" }
        return store.isLocked(id) ? "Locked folder" : folder.name
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
        guard permitted else { return false }
        return await model.persist(store: store, collectionID: collectionID)
    }
    private func finish() {
        if let onFinish { onFinish() } else { dismiss() }
    }
    private func save() async { if await persistDraft() { finish() } }
    private func deletePlan() async {
        guard await persistDraft() else { return }
        model.saving = true; defer { model.saving = false }
        let result = await store.setPlanTreeTrashed(model.draft.id, trashed: true)
        if result.receipt != nil { finish() } else { model.message = result.message }
    }
    private func duplicate() async {
        guard permitted else { return }; model.saving = true; defer { model.saving = false }
        let result = await store.submit(.init(intent: .savePlan(model.draft.duplicated(), collectionID: collectionID)))
        if result.receipt != nil { finish() } else { model.message = result.message }
    }
}
private struct PlanSectionTarget: Identifiable { let id: UUID }
