import SwiftUI
import UniformTypeIdentifiers

struct NotesView: View {
    @Environment(\.appTheme) private var theme
    @Bindable var session: NotesSession
    var reader: ReaderSession
    @State private var search = ""
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
            VStack {
                HStack {
                    Picker("Sort", selection: $sort) { ForEach(["Modified", "Created", "Title"], id: \.self) { Text($0) } }.pickerStyle(.menu)
                    Picker("Tag", selection: $tag) {
                        Text("All tags").tag("")
                        ForEach(Array(Set(session.snapshot.notes.flatMap(\.tags))).sorted(), id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                    Spacer()
                    Toggle("Cards", isOn: $cards).fixedSize()
                }.padding(.horizontal)
                if !session.loaded { ContentUnavailableView("Notes unavailable", systemImage: "exclamationmark.triangle", description: Text("Retry or restore a Notes backup.")); Button("Retry") { Task { await session.load() } } }
                else if notes.isEmpty { ContentUnavailableView(search.isEmpty && tag.isEmpty ? (deleted ? "No deleted notes" : "Your study starts here") : "No matching notes", systemImage: "note.text", description: Text("Create a blank note for text, handwriting, images and Scripture.")) }
                else {
                    ScrollView {
                        LazyVGrid(columns: cards ? [GridItem(.adaptive(minimum: 260), alignment: .top)] : [GridItem(.flexible())], spacing: 16) {
                            ForEach(notes) { note in
                                Button { if !deleted { session.open(note.id) } } label: { noteCard(note) }.buttonStyle(.plain)
                                    .contextMenu {
                                        if deleted { Button("Restore note") { session.delete(note.id, restore: true) } }
                                        else { Button("Delete note", role: .destructive) { deleting = note.id } }
                                    }
                            }
                        }.padding()
                    }
                }
            }
            .accessibilityIdentifier("notes.content")
            .appSurface()
            .navigationTitle(deleted ? "Recently Deleted" : "Notes")
            .searchable(text: $search, prompt: "Title, tags, passage or text")
            .toolbar {
                Menu("New Note", systemImage: "square.and.pencil") {
                    Button("Page", systemImage: "doc.text") { session.create(kind: .page) }.accessibilityIdentifier("notes.new.page")
                    Button("Canvas", systemImage: "square.on.square") { session.create(kind: .canvas) }.accessibilityIdentifier("notes.new.canvas")
                }.disabled(!session.loaded).accessibilityIdentifier("notes.new")
                Menu("Backups", systemImage: "ellipsis.circle") {
                    Toggle("Recently Deleted", isOn: $deleted)
                    Button("Export Notes backup") { Task { do { archive = NotesArchiveDocument(data: try await session.export()); exporting = true } catch { session.report(error) } } }
                    Button("Restore Notes backup…") { importing = true }
                    Button("Recover before last restore…") { Task { do { pendingRestore = try await session.preRestore(); confirmRestore = true } catch { session.report(error) } } }
                    #if DEBUG
                    NavigationLink("SP-006 canvas experiment") { CanvasExperimentView() }.accessibilityIdentifier("notes.openCanvasExperiment")
                    #endif
                }.accessibilityIdentifier("notes.backups")
            }
            .navigationDestination(isPresented: Binding(get: { session.selectedNoteID != nil }, set: { if !$0 { session.flushSurface?(); session.selectedNoteID = nil } })) { NoteEditorView(session: session, reader: reader) }
        }
        .disabled(session.restoring)
        .task { await session.load() }
        .onChange(of: scenePhase) { _, value in if value != .active { session.flushSurface?(); Task { await session.save() } } }
        .alert("Notes", isPresented: Binding(get: { session.notice != nil }, set: { if !$0 { session.notice = nil } })) { Button("OK") { session.notice = nil } } message: { Text(session.notice ?? "") }
        .alert("Delete this note?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) { if let id = deleting { session.delete(id) }; deleting = nil }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: { Text("You can restore it from Recently Deleted. Scripture and annotation layers are unchanged.") }
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
    private func noteCard(_ note: NoteDocument) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.title).font(.headline)
            Label(note.kind.rawValue.capitalized, systemImage: note.kind == .page ? "doc.text" : "square.on.square").font(.caption).foregroundStyle(.secondary)
            Text(note.tags.map { "#" + $0 }.joined(separator: " ")).font(.caption).foregroundStyle(.secondary)
            if cards { Text((note.page?.body.isEmpty == false ? note.page?.body : nil) ?? note.objects.first.map { $0.quote?.source ?? ($0.text.isEmpty ? $0.kind.rawValue.capitalized : $0.text) } ?? "Blank note").lineLimit(4).frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading) }
            Text(note.updatedAt, style: .date).font(.caption).foregroundStyle(.secondary)
            if deleted { Button("Restore note") { session.delete(note.id, restore: true) } }
        }
        .frame(maxWidth: .infinity, minHeight: cards ? 220 : nil, maxHeight: cards ? 220 : nil, alignment: .leading)
        .padding()
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: cards ? 16 : 6))
        .overlay(RoundedRectangle(cornerRadius: cards ? 16 : 6).stroke(.secondary.opacity(0.25)))
    }
}

struct NotesArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
