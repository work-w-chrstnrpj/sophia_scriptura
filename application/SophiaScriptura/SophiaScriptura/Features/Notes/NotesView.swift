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
    @State private var deleting: UUID?
    @State private var archive = NotesArchiveDocument(data: Data())
    @State private var filingNote: NoteDocument?
    @State private var showingNewNote = false
    @Environment(\.scenePhase) private var scenePhase

    private var notes: [NoteDocument] {
        session.snapshot.notes.filter {
            ($0.deletedAt != nil) == deleted && (search.isEmpty || $0.searchableText.localizedCaseInsensitiveContains(search)) && (tag.isEmpty || $0.tags.contains(tag))
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
            .accessibilityIdentifier("notes.content")
            .appSurface()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: Binding(get: { session.selectedNoteID != nil }, set: { if !$0 { session.flushSurface?(); session.selectedNoteID = nil } })) {
                NoteEditorView(session: session, reader: reader)
                    .toolbar(.visible, for: .navigationBar)
            }
            .sheet(item: $filingNote) { note in
                CollectionDestinationPicker(
                    store: collections,
                    artifact: CollectionArtifact(
                        id: note.id,
                        title: note.title,
                        subtitle: note.kind == .page ? "Note · Page" : "Note · Canvas",
                        kind: .note,
                        modifiedAt: note.updatedAt
                    ),
                    mode: .assign,
                    notes: session
                )
            }
        }
        .disabled(session.restoring)
        .task { await session.load() }
        .onChange(of: scenePhase) { _, value in if value != .active { session.flushSurface?(); Task { await session.save() } } }
        .alert("Notes", isPresented: Binding(get: { session.notice != nil }, set: { if !$0 { session.notice = nil } })) { Button("OK") { session.notice = nil } } message: { Text(session.notice ?? "") }
        .overlay {
            if showingNewNote {
                StudyNoteKindPicker(notes: session, onCancel: { showingNewNote = false }) { id in
                    showingNewNote = false
                    session.open(id)
                }
            }
            if deleting != nil {
                StudyCenteredConfirmationOverlay(
                    title: "Delete this note?",
                    message: "You can restore it from Recently Deleted. Scripture and annotation layers are unchanged.",
                    confirmLabel: "Delete Note",
                    onConfirm: {
                        if let id = deleting { session.delete(id) }
                        deleting = nil
                    },
                    onCancel: { deleting = nil }
                )
            }
        }
        .animation(.easeOut(duration: 0.18), value: showingNewNote)
        .animation(.easeOut(duration: 0.18), value: deleting != nil)
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
        if deleted { return "Recently Deleted" }
        return tag.isEmpty ? sort : "\(sort) · \(tag)"
    }

    private var backupsMenu: some View {
        Menu {
            Toggle("Recently Deleted", isOn: $deleted)
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
                columns: [GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 16, alignment: .top)],
                spacing: 16
            ) {
                ForEach(notes) { note in
                    noteCard(note)
                        .contextMenu { noteActions(note) }
                }
            }
        } else {
            List {
                ForEach(notes) { note in
                    noteRow(note)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !deleted {
                                Button(role: .destructive) { deleting = note.id } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if deleted {
                                Button { session.delete(note.id, restore: true) } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(Color(theme.palette.accent))
                            } else {
                                Button { filingNote = note } label: {
                                    Label("Add to Collection", systemImage: "folder.badge.plus")
                                }
                                .tint(Color(theme.palette.accent))
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .frame(height: CGFloat(notes.count) * 88 + 8)
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
        return deleted ? "No deleted notes" : "Your study starts here"
    }

    private var emptyDetail: String {
        if !search.isEmpty || !tag.isEmpty { return "Try a different title, tag, or passage." }
        if deleted { return "Deleted notes stay here until you restore them." }
        return "Start a Page or Canvas note for text, handwriting, images, and Scripture."
    }

    private func noteCard(_ note: NoteDocument) -> some View {
        let accent = accent(for: note)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                noteGlyph(note, accent: accent, size: 46)
                Spacer(minLength: 8)
            }
            .padding(.bottom, 14)

            Button { open(note) } label: {
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
                    Button("Restore note") { session.delete(note.id, restore: true) }
                        .buttonStyle(CollectionSecondaryButtonStyle())
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(accent.color)
                .frame(height: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent.color.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contextMenu { noteActions(note) }
    }

    private func noteRow(_ note: NoteDocument) -> some View {
        let accent = accent(for: note)
        return HStack(alignment: .center, spacing: 14) {
            Button { open(note) } label: {
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
                Button("Restore note") { session.delete(note.id, restore: true) }
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
            Button("Restore note") { session.delete(note.id, restore: true) }
        } else {
            Button("Add to Collection…", systemImage: "folder.badge.plus") { filingNote = note }
                .accessibilityIdentifier("notes.addToCollection.\(note.title)")
            Button("Delete note", role: .destructive) { deleting = note.id }
        }
    }

    private func open(_ note: NoteDocument) {
        if !deleted { session.open(note.id) }
    }

    private func accent(for note: NoteDocument) -> CollectionAccent {
        note.kind == .page ? .sage : .slate
    }

    private func noteGlyph(_ note: NoteDocument, accent: CollectionAccent, size: CGFloat) -> some View {
        Image(systemName: note.kind == .page ? "doc.text.fill" : "square.on.square.dashed")
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(accent.color)
            .frame(width: size, height: size)
            .background(accent.color.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }

    private func caption(_ note: NoteDocument) -> String {
        let kind = note.kind.rawValue.capitalized
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
        .foregroundStyle(accent.color)
    }

    private func preview(_ note: NoteDocument) -> String {
        (note.page?.body.isEmpty == false ? note.page?.body : nil)
            ?? note.objects.first.map { $0.quote?.source ?? ($0.text.isEmpty ? $0.kind.rawValue.capitalized : $0.text) }
            ?? "Blank note"
    }
}

struct NotesArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
