import SwiftUI
import UniformTypeIdentifiers

struct NotesView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject private var protection = ItemProtectionSession.shared
    @Bindable var session: NotesSession
    var reader: ReaderSession
    @ObservedObject var collections: CollectionsStore
    /// False when another root tab is selected; clears multiselect when the user leaves Notes.
    var isTabActive = true
    @State private var search = ""
    @State private var searchPresented = false
    @State private var tag = ""
    @State private var noteKindFilter: NoteKind?
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
    @State private var pendingBulkDeleteIDs: Set<UUID> = []
    @State private var confirmResetLibrary = false
    @Environment(\.scenePhase) private var scenePhase
    /// Every library card uses this height. Title and note type stay at the top; the dates sit on the bottom.
    private let noteCardHeight: CGFloat = 176

    private var notes: [NoteDocument] {
        let _ = protection.unlocked
        return session.snapshot.notes.filter { note in
            let visibility = deleted ? note.isArchived : note.isActiveInLibrary
            return visibility
                && !collections.concealsNote(note.id)
                && (search.isEmpty || (session.isLocked(note) ? note.title : note.searchableText).localizedCaseInsensitiveContains(search))
                && (tag.isEmpty || (!session.isLocked(note) && note.tags.contains(tag)))
                && (noteKindFilter == nil || note.kind == noteKindFilter)
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
                NoteEditorView(session: session, reader: reader, collections: collections)
                    .toolbar(.visible, for: .navigationBar)
            }
            .navigationDestination(isPresented: $showArchivedNotes) {
                StudyArchivedNotesView(session: session, collections: collections)
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
        .onChange(of: protection.unlocked) { _, _ in
            if let note = editingNote, session.isLocked(note) || collections.concealsNote(note.id) { editingNote = nil }
            concealNotesInLockedCollections()
        }
        .onChange(of: session.selectedNoteID) { _, id in
            guard let id, !session.canAccessEditor(id) else { return }
            Task { @MainActor in
                guard session.selectedNoteID == id else { return }
                session.concealInaccessibleNote()
            }
        }
        .onChange(of: collections.memberships) { _, _ in concealNotesInLockedCollections() }
        .onChange(of: collections.collections) { _, _ in concealNotesInLockedCollections() }
        .onAppear { session.collections = collections; concealNotesInLockedCollections() }
        .onChange(of: selectionMode) { _, active in
            if !active { selectedNoteIDs.removeAll() }
        }
        .onChange(of: isTabActive) { _, active in
            if !active {
                showBulkCollectionPicker = false
                clearSelection()
            }
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
        .alert("Reset Notes library?", isPresented: $confirmResetLibrary) {
            Button("Reset Notes", role: .destructive) { Task { await session.resetLibrary() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every note and the damaged library on this iPad. Export a backup from Settings first if you still have one elsewhere.")
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

            ProtectionControls(domains: [.notes], available: session.snapshot.notes.contains { $0.protectionID != nil }).labelStyle(.iconOnly)

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
                    ForEach(Array(Set(session.snapshot.notes.filter { !session.isLocked($0) && !collections.concealsNote($0.id) }.flatMap(\.tags))).sorted(), id: \.self) { Text($0).tag($0) }
                }
                Picker("Type", selection: $noteKindFilter) {
                    Text("All types").tag(NoteKind?.none)
                    ForEach(NoteKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(Optional(kind))
                    }
                }
                .accessibilityIdentifier("notes.filter.type")
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
        var parts = [sort]
        if let noteKindFilter { parts.append(noteKindFilter.displayName) }
        if !tag.isEmpty { parts.append(tag) }
        return parts.joined(separator: " · ")
    }

    private var hasActiveLibraryFilter: Bool {
        !search.isEmpty || !tag.isEmpty || noteKindFilter != nil
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
            ContentUnavailableView(
                "Notes unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(session.notice ?? "Retry or restore a Notes backup.")
            )
            Button("Retry") { Task { await session.load() } }
                .buttonStyle(CollectionProminentButtonStyle())
                .frame(maxWidth: .infinity)
            Button("Reset Notes library") { confirmResetLibrary = true }
                .buttonStyle(CollectionProminentButtonStyle(destructive: true))
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("notes.resetLibrary")
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
                    Button(role: .destructive) {
                        pendingBulkDeleteIDs = selectedNoteIDs
                        confirmBulkDelete = !pendingBulkDeleteIDs.isEmpty
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(CollectionSecondaryButtonStyle(destructive: true))
                    .accessibilityIdentifier("notes.bulkDelete")
                    .alert("Move \(pendingBulkDeleteIDs.count) notes to Trash?", isPresented: $confirmBulkDelete) {
                        Button("Move to Trash", role: .destructive) { bulkDeleteSelected() }
                        Button("Cancel", role: .cancel) { pendingBulkDeleteIDs.removeAll() }
                    } message: {
                        Text("Trash keeps notes for \(TrashRetention.dayCount) days. Restore or delete permanently from Settings → Trash.")
                    }
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

    private func concealNotesInLockedCollections() {
        session.concealInaccessibleNote()
        if let note = filingNote, collections.concealsNote(note.id) { filingNote = nil }
        let visible = selectedNoteIDs.filter { !collections.concealsNote($0) }
        if visible != selectedNoteIDs { selectedNoteIDs = visible }
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
        for id in pendingBulkDeleteIDs { session.moveToTrash(id) }
        pendingBulkDeleteIDs.removeAll()
        clearSelection()
    }

    @ViewBuilder
    private func selectionCheckbox(for noteID: UUID) -> some View {
        if selectionMode {
            selectionMark(for: noteID, size: .title2)
        }
    }

    private enum SelectionMarkSize { case title2, cardBadge }

    @ViewBuilder
    private func selectionMark(for noteID: UUID, size: SelectionMarkSize) -> some View {
        let selected = selectedNoteIDs.contains(noteID)
        Button { toggleNoteSelection(noteID) } label: {
            switch size {
            case .title2:
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? Color(theme.palette.accent) : Color(theme.palette.rule))
            case .cardBadge:
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        selected ? Color.white : Color(theme.palette.ink),
                        selected ? Color(theme.palette.accent) : Color(theme.palette.paper)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selected ? "Selected" : "Not selected")
        .accessibilityIdentifier("notes.select.\(noteID.uuidString)")
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: !hasActiveLibraryFilter ? (deleted ? "trash" : "square.and.pencil") : "magnifyingglass")
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
            if !hasActiveLibraryFilter, !deleted {
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
        if hasActiveLibraryFilter { return "No matching notes" }
        return deleted ? "No archived notes" : "Your study starts here"
    }

    private var emptyDetail: String {
        if hasActiveLibraryFilter { return "Try a different title, tag, type, or passage." }
        if deleted { return "Archived notes stay here until you unarchive them." }
        return "Start a Page, Canvas, Prayer, or Journal note for study and reflection."
    }

    private func noteCard(_ note: NoteDocument) -> some View {
        let accent = accent(for: note)
        let tint = accent.resolvedColor(in: theme)
        let isSelected = selectedNoteIDs.contains(note.id)
        return VStack(alignment: .leading, spacing: 10) {
            Button { activate(note) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 12) {
                        noteGlyph(note, accent: accent, size: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(note.title)
                                    .font(.system(.headline, design: .serif).weight(.semibold))
                                    .foregroundStyle(Color(theme.palette.ink))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                if note.protectionID != nil {
                                    Image(systemName: session.isLocked(note) ? "lock.fill" : "lock.open.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel(session.isLocked(note) ? "Locked note" : "Protected note, unlocked")
                                }
                            }
                            Text(note.kind.displayName)
                                .font(.footnote)
                                .foregroundStyle(Color(theme.palette.secondary))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 16)
                    noteDates(note, accent: accent)
                }
                .frame(maxWidth: .infinity, minHeight: noteCardHeight - 28, maxHeight: noteCardHeight - 28, alignment: .top)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: noteCardHeight, maxHeight: noteCardHeight, alignment: .top)
        .overlay(alignment: .bottomTrailing) {
            if deleted {
                Button("Unarchive") { session.unarchive(note.id) }
                    .buttonStyle(CollectionSecondaryButtonStyle())
                    .padding(14)
            }
        }
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
        .overlay(alignment: .topLeading) {
            if selectionMode {
                selectionMark(for: note.id, size: .cardBadge)
                    .padding(6)
            }
        }
        .opacity(selectionMode && isSelected ? 0.58 : 1)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
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
                            .truncationMode(.tail)
                        Text(note.kind.displayName)
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
        ItemProtectionContextActions(
            noun: "Note",
            protectionID: note.protectionID,
            locked: session.isLocked(note),
            protect: { Task { await session.setProtected(note.id, enabled: true) } },
            lock: { session.protection.lock([.notes]) },
            unlock: { session.open(note.id) },
            remove: { Task { await session.setProtected(note.id, enabled: false) } }
        )
        if deleted {
            Button("Unarchive", systemImage: "arrow.uturn.backward") { session.unarchive(note.id) }
            Button("Delete Note", systemImage: "trash", role: .destructive) { permanentlyDeleting = note.id }
        } else {
            if !session.isLocked(note) {
                Button("Add to Collection…", systemImage: "folder.badge.plus") { filingNote = note }
                    .accessibilityIdentifier("notes.addToCollection.\(note.title)")
            }
            if !session.isLocked(note) {
                Button("Edit Note", systemImage: "pencil") { editingNote = note }
                    .accessibilityIdentifier("notes.editNote")
            }
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
        session.isLocked(note) ? .stone : note.color
    }

    private func noteGlyph(_ note: NoteDocument, accent: CollectionAccent, size: CGFloat) -> some View {
        let tint = accent.resolvedColor(in: theme)
        return Image(systemName: session.isLocked(note) ? "lock.fill" : noteKindSymbol(note.kind))
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

    private func noteDates(_ note: NoteDocument, accent: CollectionAccent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Created \(note.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .accessibilityIdentifier("notes.createdDate.\(note.id.uuidString)")
            Text("Last modified \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .accessibilityIdentifier("notes.modifiedDate.\(note.id.uuidString)")
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(accent.resolvedColor(in: theme))
        .frame(maxWidth: .infinity, alignment: .leading)
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
