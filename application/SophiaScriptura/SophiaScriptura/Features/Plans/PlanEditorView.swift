import SwiftUI

struct PlanEditorView: View {
    @EnvironmentObject private var activity: ActivityStore
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmDeletePlan = false
    @State private var showingOutfitColors = false
    @State private var sectionCount = "1"
    @State private var showingSectionCount = false
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
            .alert("Add Days/Sections", isPresented: $showingSectionCount) {
                TextField("Number of Days/Sections", text: $sectionCount)
                    .keyboardType(.numberPad).accessibilityIdentifier("plans.sectionCount")
                Button("Cancel", role: .cancel) {}
                Button("Add sections") {
                    let count = Int(sectionCount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                    model.addSections(count)
                }
                    .disabled(Int(sectionCount.trimmingCharacters(in: .whitespacesAndNewlines)).map { $0 > 0 && $0 <= 200 - model.draft.sections.count } != true)
            } message: { Text("How many more? You can add up to \(200 - model.draft.sections.count) Days/Sections.") }
            .onChange(of: permitted) { _, allowed in if !allowed { model.closeAssignmentPicker(); model.confirmReset = false; confirmDeletePlan = false; showingSectionCount = false; showingOutfitColors = false } }
    }
    /// Translations available offline for Plan reading, plus the Plan's current one if it is no longer installed.
    private var translationOptions: [(id: String, label: String)] {
        var options: [(id: String, label: String)] = [(ScriptureReferenceIdentity.bundledEditionID, "WEB · World English Bible")]
        if let reader {
            for status in reader.helloAOEditions where status.isAvailable {
                options.append((status.appEditionID, "\(status.eligible.abbreviation) · \(status.catalogName ?? status.eligible.name)"))
            }
            for status in reader.translations where status.isAvailable {
                options.append((status.translation.editionID, "\(status.translation.abbreviation) · \(status.translation.name)"))
            }
        }
        let current = model.draft.preferredEditionID
        if !options.contains(where: { $0.id == current }) {
            let name = reader?.edition?.id == current ? reader?.edition?.abbreviation
                : LicensedTranslation.approved.first(where: { $0.editionID == current })?.abbreviation
            options.append((current, "\(name ?? current) · not downloaded"))
        }
        return options
    }
    private var outfitColorName: String { model.draft.travelerOutfitColor?.title ?? "Character default" }

    private var outfitColorPicker: some View {
        Button {
            showingOutfitColors = true
        } label: {
            HStack {
                Text("Outfit color")
                    .foregroundStyle(Color(theme.palette.ink))
                Spacer()
                Circle()
                    .fill(model.draft.travelerOutfitColor?.color ?? model.draft.resolvedTravelerCharacter.defaultTravelerOutfit)
                    .frame(width: 16, height: 16)
                Text(outfitColorName)
                    .foregroundStyle(Color(theme.palette.secondary))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(Color(theme.palette.secondary))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Outfit color")
        .accessibilityValue(outfitColorName)
        .accessibilityIdentifier("plans.outfitColor")
        .popover(isPresented: $showingOutfitColors) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Outfit color").font(.headline)
                    Button {
                        model.draft.travelerOutfitColor = nil
                        showingOutfitColors = false
                    } label: {
                        HStack {
                            Circle()
                                .fill(model.draft.resolvedTravelerCharacter.defaultTravelerOutfit)
                                .frame(width: 22, height: 22)
                            Text("Character default")
                            Spacer()
                            if model.draft.travelerOutfitColor == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(model.draft.travelerOutfitColor == nil ? .isSelected : [])
                    CollectionColorGrid(selection: Binding(
                        get: { model.draft.travelerOutfitColor ?? .preset },
                        set: { color in
                            model.draft.travelerOutfitColor = color
                            showingOutfitColors = false
                        }
                    ), palette: CollectionAccent.allCases.filter { $0 != .preset })
                }
                .padding(16)
                .foregroundStyle(Color(theme.palette.ink))
            }
            .frame(width: 320, height: 440)
            .background(Color(theme.palette.paper))
            .presentationCompactAdaptation(.popover)
        }
    }

    private var editor: some View {
        let sections = model.draft.sections
        return List {
            Section("Plan") {
                TextField("Plan title", text: $model.draft.title).accessibilityIdentifier("plans.title")
                TextField("Description", text: $model.draft.detail, axis: .vertical)
                TextField("Section label, such as Day", text: $model.draft.sectionPrefix)
                Picker("Translation", selection: Binding(get: { model.draft.preferredEditionID }, set: { model.changeTranslation(to: $0) })) {
                    ForEach(translationOptions, id: \.id) { option in Text(option.label).tag(option.id) }
                }
                .disabled(model.saving)
                .accessibilityIdentifier("plans.translation")
                Text(model.saveStatus).font(.caption).accessibilityIdentifier("plans.saveStatus")
                if let message = model.message { Text(message).foregroundStyle(.red).accessibilityIdentifier("plans.error") }
            }
            Section("Plan card") {
                Picker("Character", selection: Binding(get: { model.draft.resolvedTravelerCharacter }, set: {
                    model.draft.travelerCharacter = $0
                })) {
                    ForEach(StudyCompanionCharacter.allCases) { character in
                        Text(character.displayName).tag(character)
                    }
                }
                .accessibilityValue(model.draft.resolvedTravelerCharacter.displayName)
                .accessibilityIdentifier("plans.travelerCharacter")
                outfitColorPicker
                Picker("Scenery", selection: Binding(get: { model.draft.travelerBackdrop ?? .cloudy }, set: {
                    model.draft.travelerBackdrop = $0
                })) {
                    ForEach(PlanTravelerBackdrop.allCases) { backdrop in
                        Text(backdrop.title).tag(backdrop)
                    }
                }
                .accessibilityValue((model.draft.travelerBackdrop ?? .cloudy).title)
                .accessibilityIdentifier("plans.travelerBackdrop")
                Picker("Equipment", selection: Binding(get: { model.draft.travelerEquipment ?? .candle }, set: {
                    model.draft.travelerEquipment = $0
                })) {
                    ForEach(PlanTravelerEquipment.allCases) { equipment in
                        Text(equipment.title).tag(equipment)
                    }
                }
                .accessibilityValue((model.draft.travelerEquipment ?? .candle).title)
                .accessibilityIdentifier("plans.travelerEquipment")
                if model.draft.travelerEquipment == .armorOfGod {
                    Text("Ephesians 6:14–17 · Belt of truth, breastplate of righteousness, shoes of readiness for the gospel of peace, shield of faith, helmet of salvation, and sword of the Spirit.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Playback and schedule") {
                Picker("Activity type", selection: Binding(get: { model.draft.resolvedActivityModeID }, set: { model.draft.activityModeID = $0 })) {
                    ForEach(activity.modes) { mode in Text(mode.name).tag(mode.id) }
                    if !activity.modes.contains(where: { $0.id == model.draft.resolvedActivityModeID }) {
                        Text(activity.modeIncludingArchived(model.draft.resolvedActivityModeID)?.name ?? "Unavailable type").tag(model.draft.resolvedActivityModeID)
                    }
                }.accessibilityIdentifier("plans.activityType")
                Toggle("Strict plan mode", isOn: Binding(get: { model.draft.strictSchedule != nil }, set: {
                    model.draft.strictSchedule = $0 ? PlanSchedule() : nil
                })).accessibilityIdentifier("plans.strictMode")
                if model.draft.strictSchedule != nil {
                    let calendar = model.draft.strictSchedule?.calendar ?? .current
                    DatePicker("Initial reminder time", selection: Binding(get: {
                        PlanReminderTime.displayDate(model.draft.strictSchedule?.initialReminderMinute ?? 480, calendar: calendar)
                    }, set: {
                        model.draft.strictSchedule?.reminderMinute = PlanReminderTime.minute(of: $0, calendar: calendar)
                    }), displayedComponents: .hourAndMinute)
                    .environment(\.timeZone, calendar.timeZone)
                    .accessibilityIdentifier("plans.reminderTime")
                    Toggle("Choose start date", isOn: Binding(get: { model.draft.strictSchedule?.startDate != nil }, set: {
                        model.draft.strictSchedule?.startDate = $0 ? Date() : nil
                    }))
                    if model.draft.strictSchedule?.startDate != nil {
                        DatePicker("Start date", selection: Binding(get: { model.draft.strictSchedule?.startDate ?? Date() }, set: {
                            model.draft.strictSchedule?.startDate = $0
                        }), displayedComponents: .date)
                    }
                    if model.draft.canCatchUp() {
                        Button("Catch up from today", systemImage: "calendar.badge.clock") { model.catchUp() }
                            .accessibilityIdentifier("plans.catchUp")
                        Text("Move the first unfinished day to today, then schedule the remaining unfinished days in order. Completed days and checked assignments stay unchanged.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let caption = model.draft.scheduleCaption() {
                        Text(caption).font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("plans.edit.dates")
                    }
                    Text("Each day or section is due on the next calendar day. Without a chosen start date, the first Play sets Day 1. Dates are reminders; overdue sections remain available.")
                        .font(.caption).foregroundStyle(.secondary)
                }
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
                    }.accessibilityLabel("Add assignment to \(model.sectionTitle(section.id))")
                        .accessibilityIdentifier("plans.addAssignment")
                    Menu {
                        Button("Reset section") { model.resetSection = section.id; model.confirmReset = true }
                        Button("Duplicate section") { model.duplicateSection(section.id) }
                        Button("Remove section", role: .destructive) { model.removeSection(section.id) }
                    } label: {
                        HStack { Text("Manage section"); Spacer(); Image(systemName: "ellipsis") }.contentShape(Rectangle())
                    }.buttonStyle(.borderless).accessibilityLabel("Manage section")
                    .accessibilityIdentifier("plans.manageSection.\(section.id)")
                } header: { Text(model.sectionTitle(section.id)) } footer: {
                    if let index = model.draft.sections.firstIndex(where: { $0.id == section.id }),
                       let caption = model.draft.scheduleCaption(for: index) {
                        Text(caption).font(.caption).accessibilityIdentifier("plans.edit.sectionDates.\(section.id)")
                    }
                }
            }
            .onMove { source, target in model.moveSections(from: source, to: target, renderedIDs: sections.map(\.id)) }
            Section {
                Button("Add section", systemImage: "plus.rectangle.on.rectangle") { model.addSection() }
                    .accessibilityIdentifier("plans.addSection")
                Button("Add multiple sections…", systemImage: "plus.rectangle.on.rectangle") {
                    sectionCount = "1"; showingSectionCount = true
                }.accessibilityIdentifier("plans.addMultipleSections")
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
        .task { await activity.load(); await reader?.start() }
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
        case .conversation:
            guard let id = item.payload.targetID, let conversation = store.conversation(id: id) else { return "Conversation unavailable" }
            return store.collectionIDs(containing: id).contains(where: store.isLocked) ? "Locked conversation" : "\(conversation.title) (Conversation)"
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
