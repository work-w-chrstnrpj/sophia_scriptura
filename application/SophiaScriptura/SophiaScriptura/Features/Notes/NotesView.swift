import SwiftUI
import UniformTypeIdentifiers

struct NotesView: View {
    @Environment(\.appTheme) private var theme
    @Bindable var session: NotesSession
    var reader: ReaderSession
    @ObservedObject var collections: CollectionsStore
    @State private var search = ""
    @State private var searchPresented = false
    @State private var tag = ""
    @State private var sort = "Modified"
    @State private var cards = true
    @State private var deleted = false
    @State private var importing = false
    @State private var exporting = false
    @State private var pendingRestore: Data?
    @State private var confirmRestore = false
    @State private var permanentlyDeleting: UUID?
    @State private var archive = NotesArchiveDocument(data: Data())
    @State private var filingNote: NoteDocument?
    @State private var editingNote: NoteDocument?
    @State private var showingNewNote = false
    @State private var showArchivedNotes = false
    @State private var selectionMode = false
    @State private var selectedNoteIDs: Set<UUID> = []
    @State private var showBulkCollectionPicker = false
    @State private var confirmBulkDelete = false
    @Environment(\.scenePhase) private var scenePhase

    private var notes: [NoteDocument] {
        session.snapshot.notes.filter { note in
            let visibility = deleted ? note.isArchived : note.isActiveInLibrary
            return visibility
                && (search.isEmpty || note.searchableText.localizedCaseInsensitiveContains(search))
                && (tag.isEmpty || note.tags.contains(tag))
        }.sorted {
            if sort == "Title", $0.title != $1.title { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            if sort == "Created", $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            if sort == "Modified", $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        commandBar
                        library
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                    .frame(width: proxy.size.width, alignment: .leading)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !selectedNoteIDs.isEmpty {
                    bulkSelectionBar
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                        .background(Color(theme.palette.paper).opacity(0.98))
                }
            }
            .accessibilityIdentifier("notes.content")
            .appSurface()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: Binding(get: { session.selectedNoteID != nil }, set: { if !$0 { session.flushSurface?(); session.selectedNoteID = nil } })) {
                NoteEditorView(session: session, reader: reader)
                    .toolbar(.visible, for: .navigationBar)
            }
            .navigationDestination(isPresented: $showArchivedNotes) {
                StudyArchivedNotesView(session: session)
                    .toolbar(.visible, for: .navigationBar)
            }
            .sheet(item: $editingNote) { note in
                NoteEditorSheet(noteID: note.id, session: session)
            }
            .sheet(item: $filingNote) { note in
                CollectionDestinationPicker(
                    store: collections,
                    artifact: CollectionArtifact(
                        id: note.id,
                        title: note.title,
                        subtitle: "Note · \(note.kind.displayName)",
                        kind: .note,
                        modifiedAt: note.updatedAt
                    ),
                    mode: .assign,
                    notes: session
                )
            }
            .sheet(isPresented: $showBulkCollectionPicker) {
                NotesBulkCollectionPicker(store: collections, session: session, noteIDs: selectedNoteIDs) {
                    clearSelection()
                }
            }
        }
        .onChange(of: selectionMode) { _, active in
            if !active { selectedNoteIDs.removeAll() }
        }
        .disabled(session.restoring)
        .task { await session.load() }
        .onChange(of: scenePhase) { _, value in if value != .active { session.flushSurface?(); Task { await session.save() } } }
        .alert("Notes", isPresented: Binding(get: { session.notice != nil }, set: { if !$0 { session.notice = nil } })) { Button("OK") { session.notice = nil } } message: { Text(session.notice ?? "") }
        .sheet(isPresented: $showingNewNote) {
            NoteCreatorSheet(notes: session) { id in
                session.open(id)
            }
        }
        .alert("Move this note to Trash?", isPresented: Binding(
            get: { permanentlyDeleting != nil },
            set: { if !$0 { permanentlyDeleting = nil } }
        )) {
            Button("Move to Trash", role: .destructive) {
                if let id = permanentlyDeleting { session.moveToTrash(id) }
                permanentlyDeleting = nil
            }
            Button("Cancel", role: .cancel) { permanentlyDeleting = nil }
        } message: {
            Text("Trash keeps the note for \(TrashRetention.dayCount) days. Restore it from Settings → Trash, or delete it permanently there.")
        }
        .alert("Move \(selectedNoteIDs.count) notes to Trash?", isPresented: $confirmBulkDelete) {
            Button("Move to Trash", role: .destructive) { bulkDeleteSelected() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Trash keeps notes for \(TrashRetention.dayCount) days. Restore or delete permanently from Settings → Trash.")
        }
        .alert("Replace Notes from backup?", isPresented: $confirmRestore) {
            Button("Restore", role: .destructive) { if let data = pendingRestore { Task { await session.restore(data) } }; pendingRestore = nil }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: { Text("All current notes will be replaced. A pre-restore copy will be retained for recovery.") }
        .fileExporter(isPresented: $exporting, document: archive, contentType: .json, defaultFilename: "Sophia-Notes") { if case .failure(let error) = $0 { session.report(error) } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(), granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= NotesFileRepository.archiveLimit else { throw NotesError.limit }
                pendingRestore = try Data(contentsOf: url); confirmRestore = true
            } catch { session.report(error) }
        }
    }

    private var commandBar: some View {
        HStack(spacing: 4) {
            LibraryHeaderTitle(title: "Notes")
                .accessibilityIdentifier("notes.title")

            Spacer(minLength: 12)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectionMode.toggle()
                    if !selectionMode { selectedNoteIDs.removeAll() }
                }
            } label: {
                LibraryHeaderIcon(systemImage: selectionMode ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectionMode ? "Exit note selection" : "Select notes")
            .accessibilityIdentifier("notes.selectMode")

            Button { showArchivedNotes = true } label: {
                LibraryHeaderIcon(systemImage: "archivebox")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Archived notes")
            .accessibilityIdentifier("notes.archive")

            if searchPresented {
                searchField
                    .frame(minWidth: 180, idealWidth: 280, maxWidth: 340)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Button { searchPresented = true } label: {
                    LibraryHeaderIcon(systemImage: "magnifyingglass")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search notes")
                .accessibilityIdentifier("notes.searchButton")
            }

            libraryControls
        }
        .animation(.easeInOut(duration: 0.2), value: searchPresented)
    }

    private var searchField: some View {
        LibrarySearchField(
            text: $search,
            prompt: "Search notes",
            accessibilityIdentifier: "notes.search",
            dismiss: { searchPresented = false }
        )
    }

    private var libraryControls: some View {
        HStack(spacing: 0) {
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(["Modified", "Created", "Title"], id: \.self) { Text($0) }
                }
                Picker("Tag", selection: $tag) {
                    Text("All tags").tag("")
                    ForEach(Array(Set(session.snapshot.notes.flatMap(\.tags))).sorted(), id: \.self) { Text($0).tag($0) }
                }
                Toggle("Cards", isOn: $cards)
            } label: {
                LibraryHeaderIcon(systemImage: "line.3.horizontal.decrease")
            }
            .accessibilityLabel("Notes view options")
            .accessibilityValue(viewLabel)
            .accessibilityIdentifier("notes.viewOptions")

            backupsMenu

            newNoteButton
        }
    }

    private var viewLabel: String {
        if deleted { return "Archived" }
        return tag.isEmpty ? sort : "\(sort) · \(tag)"
    }

    private var backupsMenu: some View {
        Menu {
            Toggle("Show archived in library", isOn: $deleted)
            Button("Export Notes backup") { Task { do { archive = NotesArchiveDocument(data: try await session.export()); exporting = true } catch { session.report(error) } } }
            Button("Restore Notes backup…") { importing = true }
            Button("Recover before last restore…") { Task { do { pendingRestore = try await session.preRestore(); confirmRestore = true } catch { session.report(error) } } }
        } label: {
            LibraryHeaderIcon(systemImage: "ellipsis.circle")
        }
        .accessibilityLabel("Backups")
        .accessibilityIdentifier("notes.backups")
    }

    private var newNoteButton: some View {
        Button {
            showingNewNote = true
        } label: {
            LibraryHeaderIcon(systemImage: "plus")
        }
        .buttonStyle(.plain)
        .disabled(!session.loaded)
        .accessibilityLabel("New Notes")
        .accessibilityIdentifier("notes.newNotes")
    }

    @ViewBuilder
    private var library: some View {
        if !session.loaded {
            ContentUnavailableView("Notes unavailable", systemImage: "exclamationmark.triangle", description: Text("Retry or restore a Notes backup."))
            Button("Retry") { Task { await session.load() } }
                .buttonStyle(CollectionProminentButtonStyle())
                .frame(maxWidth: .infinity)
        } else if notes.isEmpty {
            emptyState
        } else if cards {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16, alignment: .top)],
                spacing: 16
            ) {
                ForEach(notes) { note in
                    noteCard(note)
                        .contextMenu { noteActions(note) }
                }
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(notes) { note in
                    noteRow(note)
                        .contextMenu { noteActions(note) }
                }
            }
        }
    }

    private var bulkSelectionBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(selectedNoteIDs.count) selected")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(theme.palette.ink))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if deleted {
                        Button {
                            bulkRestoreSelected()
                        } label: {
                            Label("Unarchive", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(CollectionSecondaryButtonStyle())
                    } else {
                        Button { bulkArchiveSelected() } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .buttonStyle(CollectionSecondaryButtonStyle())
                        Button { showBulkCollectionPicker = true } label: {
                            Label("Add to Collection", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(CollectionSecondaryButtonStyle())
                    }
                    Button(role: .destructive) { confirmBulkDelete = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(CollectionSecondaryButtonStyle())
                    Button("Cancel") { clearSelection() }
                        .buttonStyle(CollectionSecondaryButtonStyle())
                }
            }
        }
        .accessibilityIdentifier("notes.bulkBar")
    }

    private func toggleNoteSelection(_ id: UUID) {
        if selectedNoteIDs.contains(id) {
            selectedNoteIDs.remove(id)
        } else {
            selectedNoteIDs.insert(id)
        }
    }

    private func clearSelection() {
        selectedNoteIDs.removeAll()
        selectionMode = false
    }

    private func bulkArchiveSelected() {
        for id in selectedNoteIDs { session.archive(id) }
        clearSelection()
    }

    private func bulkRestoreSelected() {
        for id in selectedNoteIDs { session.unarchive(id) }
        clearSelection()
    }

    private func bulkDeleteSelected() {
        for id in selectedNoteIDs { session.moveToTrash(id) }
        clearSelection()
    }

    @ViewBuilder
    private func selectionCheckbox(for noteID: UUID) -> some View {
        if selectionMode {
            Button { toggleNoteSelection(noteID) } label: {
                Image(systemName: selectedNoteIDs.contains(noteID) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selectedNoteIDs.contains(noteID) ? Color(theme.palette.accent) : Color(theme.palette.rule))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectedNoteIDs.contains(noteID) ? "Selected" : "Not selected")
            .accessibilityIdentifier("notes.select.\(noteID.uuidString)")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: search.isEmpty && tag.isEmpty ? (deleted ? "trash" : "square.and.pencil") : "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color(theme.palette.secondary))
            Text(emptyTitle)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Color(theme.palette.ink))
            Text(emptyDetail)
                .font(.subheadline)
                .foregroundStyle(Color(theme.palette.secondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            if search.isEmpty, tag.isEmpty, !deleted {
                Button("New Notes") { showingNewNote = true }
                    .buttonStyle(CollectionProminentButtonStyle())
                    .padding(.top, 4)
                    .disabled(!session.loaded)
                    .accessibilityIdentifier("notes.newNotes.empty")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color(theme.palette.rule), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        )
    }

    private var emptyTitle: String {
        if !search.isEmpty || !tag.isEmpty { return "No matching notes" }
        return deleted ? "No archived notes" : "Your study starts here"
    }

    private var emptyDetail: String {
        if !search.isEmpty || !tag.isEmpty { return "Try a different title, tag, or passage." }
        if deleted { return "Archived notes stay here until you unarchive them." }
        return "Start a Page, Canvas, Prayer, or Journal note for study and reflection."
    }

    private func noteCard(_ note: NoteDocument) -> some View {
        let accent = accent(for: note)
        let tint = accent.resolvedColor(in: theme)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                selectionCheckbox(for: note.id)
                noteGlyph(note, accent: accent, size: 46)
                Spacer(minLength: 8)
            }
            .padding(.bottom, 14)

            Button { activate(note) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(.system(.headline, design: .serif).weight(.semibold))
                        .foregroundStyle(Color(theme.palette.ink))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(caption(note))
                        .font(.footnote)
                        .foregroundStyle(Color(theme.palette.secondary))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(preview(note))
                        .font(.subheadline)
                        .foregroundStyle(Color(theme.palette.ink))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 12)
            HStack(alignment: .bottom) {
                noteDates(note, accent: accent)
                Spacer()
                if deleted {
                    Button("Unarchive") { session.unarchive(note.id) }
                        .buttonStyle(CollectionSecondaryButtonStyle())
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 248, alignment: .topLeading)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(tint)
                .frame(height: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contextMenu { noteActions(note) }
    }

    private func noteRow(_ note: NoteDocument) -> some View {
        let accent = accent(for: note)
        let tint = accent.resolvedColor(in: theme)
        return HStack(alignment: .center, spacing: 14) {
            selectionCheckbox(for: note.id)
            Button { activate(note) } label: {
                HStack(alignment: .center, spacing: 14) {
                    noteGlyph(note, accent: accent, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(note.title)
                            .font(.system(.body, design: .serif).weight(.semibold))
                            .foregroundStyle(Color(theme.palette.ink))
                            .lineLimit(1)
                        Text(caption(note))
                            .font(.caption)
                            .foregroundStyle(Color(theme.palette.secondary))
                            .lineLimit(1)
                        noteDates(note, accent: accent)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if deleted {
                Button("Unarchive") { session.unarchive(note.id) }
                    .buttonStyle(CollectionSecondaryButtonStyle())
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 10)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu { noteActions(note) }
    }

    @ViewBuilder
    private func noteActions(_ note: NoteDocument) -> some View {
        if deleted {
            Button("Unarchive", systemImage: "arrow.uturn.backward") { session.unarchive(note.id) }
            Button("Delete Note", systemImage: "trash", role: .destructive) { permanentlyDeleting = note.id }
        } else {
            Button("Add to Collection…", systemImage: "folder.badge.plus") { filingNote = note }
                .accessibilityIdentifier("notes.addToCollection.\(note.title)")
            Button("Edit Note", systemImage: "pencil") { editingNote = note }
                .accessibilityIdentifier("notes.editNote")
            Button("Archive note", systemImage: "archivebox") { session.archive(note.id) }
            Button("Delete Note", systemImage: "trash", role: .destructive) { permanentlyDeleting = note.id }
        }
    }

    private func activate(_ note: NoteDocument) {
        if selectionMode {
            toggleNoteSelection(note.id)
            return
        }
        open(note)
    }

    private func open(_ note: NoteDocument) {
        if !deleted { session.open(note.id) }
    }

    private func accent(for note: NoteDocument) -> CollectionAccent {
        note.color
    }

    private func noteGlyph(_ note: NoteDocument, accent: CollectionAccent, size: CGFloat) -> some View {
        let tint = accent.resolvedColor(in: theme)
        return Image(systemName: noteKindSymbol(note.kind))
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }

    private func noteKindSymbol(_ kind: NoteKind) -> String {
        switch kind {
        case .page: "doc.text.fill"
        case .canvas: "square.on.square.dashed"
        case .prayer: "hands.and.sparkles.fill"
        case .journal: "book.pages.fill"
        }
    }

    private func caption(_ note: NoteDocument) -> String {
        let kind = note.kind.displayName
        let tags = note.tags.map { "#" + $0 }.joined(separator: " ")
        return tags.isEmpty ? kind : "\(kind) · \(tags)"
    }

    private func noteDates(_ note: NoteDocument, accent: CollectionAccent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Created \(note.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .accessibilityIdentifier("notes.createdDate.\(note.id.uuidString)")
            Text("Last modified \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .accessibilityIdentifier("notes.modifiedDate.\(note.id.uuidString)")
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(accent.resolvedColor(in: theme))
    }

    private func preview(_ note: NoteDocument) -> String {
        (note.page?.body.isEmpty == false ? note.page?.body : nil)
            ?? note.objects.first.map { $0.quote?.source ?? ($0.text.isEmpty ? $0.kind.rawValue.capitalized : $0.text) }
            ?? "Blank note"
    }
}

private struct NotesBulkCollectionPicker: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CollectionsStore
    @Bindable var session: NotesSession
    let noteIDs: Set<UUID>
    var onComplete: () -> Void

    @State private var selection: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(noteIDs.count) notes")
                        .font(.subheadline)
                        .foregroundStyle(Color(theme.palette.secondary))
                }
                .listRowBackground(Color(theme.palette.soft))

                Section {
                    CollectionFolderChooser(store: store, selection: $selection)
                } header: {
                    Text("Collections")
                } footer: {
                    Text("Selected notes are added to every collection you choose. Existing memberships are kept.")
                }
                .listRowBackground(Color(theme.palette.soft))
            }
            .appSurface()
            .navigationTitle("Add to Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commit()
                        onComplete()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selection.isEmpty)
                    .accessibilityIdentifier("notes.bulkCollections.confirm")
                }
            }
        }
        .onAppear {
            store.link(notes: session.snapshot.notes)
        }
    }

    private func commit() {
        store.link(notes: session.snapshot.notes)
        for noteID in noteIDs {
            for collectionID in selection {
                store.addMembership(artifactID: noteID, collectionID: collectionID)
            }
        }
    }
}

struct NotesArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
