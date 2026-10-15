import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: NotesSession
    var reader: ReaderSession
    @ObservedObject var collections: CollectionsStore
    @AppStorage("notes.scriptureVisible") private var scriptureVisible = true
    @AppStorage("notes.editor.toolsExpanded") private var toolsExpanded = true
    @State private var rename = false
    @State private var title = ""
    @State private var gallery: String?
    @State private var showDetails = false
    @State private var importing = false
    @State private var linkPrompt = false
    @State private var link = "https://"
    @State private var confirmDelete = false
    @StateObject private var recorder = NoteAudioRecorder()
    @State private var choosePhoto = false
    @State private var photoItem: PhotosPickerItem?
    @State private var takePhoto = false
    @State private var scan: NoteScanMode?
    @State private var importAudio = false
    @State private var showFormatPopover = false
    @State private var showCollectionPicker = false
    @State private var journalSheet: JournalFieldSheet?
    var body: some View {
        Group {
            if session.note == nil {
                ContentUnavailableView("Note unavailable or locked", systemImage: "lock.fill")
            } else if session.note?.kind == .prayer {
                NotePrayerEditorView(session: session, reader: reader, addToCollection: { showCollectionPicker = true })
            } else {
                pageOrJournalEditor
            }
        }
        .sheet(isPresented: $showCollectionPicker) {
            if let note = session.note {
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
        }
    }

    private var pageOrJournalEditor: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if showsScripturePane {
                    NoteScripturePane(reader: reader, notes: session)
                        .frame(width: max(240, min(400, geometry.size.width * 0.36)))
                    Divider()
                }
                editor
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .appSurface()
        .navigationTitle(session.note?.title ?? "Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { editorToolbar }
        .sheet(item: $journalSheet) { field in
            JournalFieldPicker(field: field, journal: session.note?.journalContent, session: session)
        }
        .alert("Move note to Trash?", isPresented: $confirmDelete) {
            Button("Move to Trash", role: .destructive) {
                session.moveCurrentNoteToTrash()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Trash keeps the note for \(TrashRetention.dayCount) days. Restore or delete permanently from Settings → Trash.")
        }
        .alert("Rename note", isPresented: $rename) {
            TextField("Title", text: $title).accessibilityIdentifier("notes.rename.field")
            Button("Save") { if let note = session.note { session.metadata(title: title, tags: note.tags.joined(separator: ","), paper: note.paper) } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showDetails) { NoteDetailsView(session: session) }
        .sheet(item: Binding(get: { session.editingObjectID.flatMap { id in session.note?.allObjects.first { $0.id == id } } }, set: { if $0 == nil { session.editingObjectID = nil } })) { object in
            NoteObjectInspector(session: session, object: object)
        }
    }

    private var showsScripturePane: Bool {
        switch session.note?.kind {
        case .journal: session.note?.journalScriptureVisible ?? true
        case .page: scriptureVisible
        default: false
        }
    }

    private func toggleScripturePane() {
        if session.note?.kind == .journal {
            session.setJournalScriptureVisible(!showsScripturePane)
        } else {
            scriptureVisible.toggle()
        }
    }
    private func galleryBinding(_ kind: String) -> Binding<Bool> {
        Binding(get: { gallery == kind }, set: { if !$0 { gallery = nil } })
    }
    private var titleButton: some View {
        Button { title = session.note?.title ?? ""; rename = true } label: {
            HStack(spacing: 5) {
                Text(session.note?.title ?? "Note").font(.headline).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2)
            }
        }.buttonStyle(.plain).accessibilityIdentifier("notes.rename")
    }
    private var optionsMenu: some View {
            Menu {
                Menu("Paper", systemImage: "square.grid.3x3") {
                    ForEach(NoteDocument.Paper.allCases, id: \.self) { paper in
                        Button { changePaper(paper) } label: {
                            Text(paper.rawValue.capitalized)
                        }
                    }
                }
                if session.note?.kind == .canvas {
                    Picker("Selection", selection: $session.editsStrokes) {
                        Text("Objects").tag(false)
                        Text("Strokes").tag(true)
                    }.accessibilityIdentifier("notes.selection.mode")
                    if session.rejectedInk != nil {
                        Button("Recover unsaved drawing", systemImage: "arrow.counterclockwise") { Task { await session.recoverRejectedInk() } }
                            .accessibilityIdentifier("notes.ink.recover")
                    }
                    Button("Paste", systemImage: "doc.on.clipboard") { session.pasteCanvasClipboard() }
                        .disabled(session.canvasClipboard.isEmpty).accessibilityIdentifier("notes.canvas.paste")
                    Button("New drawing region", systemImage: "pencil.tip.crop.circle.badge.plus") { session.newInkRegion() }
                        .accessibilityIdentifier("notes.ink.new.region")
                }
                Button("Note details", systemImage: "tag") { showDetails = true }
                Button("Add to Collection", systemImage: "folder.badge.plus") { showCollectionPicker = true }
                    .accessibilityIdentifier("notes.options.addToCollection")
                Divider()
                Button("Archive", systemImage: "archivebox") {
                    session.archiveCurrentNote()
                    dismiss()
                }
                .accessibilityIdentifier("notes.editor.archive")
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    .tint(.red)
                    .accessibilityIdentifier("notes.editor.delete")
                if let note = session.note {
                    if note.protectionID == nil {
                        Button("Protect Note", systemImage: "lock") { Task { await session.setProtected(note.id, enabled: true) } }
                            .accessibilityIdentifier("notes.options.protect")
                    } else {
                        Button("Lock Note", systemImage: "lock") { session.protection.lock([.notes]) }
                            .accessibilityIdentifier("notes.options.lock")
                        Button("Remove Note Protection", systemImage: "lock.slash") { Task { await session.setProtected(note.id, enabled: false) } }
                            .accessibilityIdentifier("notes.options.removeProtection")
                    }
                }
                Button(session.status, systemImage: session.dirty ? "arrow.clockwise" : "checkmark.circle") { Task { await session.save() } }
            } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Note options").accessibilityIdentifier("notes.options")
    }
    /// Glyph only. A title string in a toolbar button becomes a separate word control and splits the row.
    @ViewBuilder
    private func journalToolbarMark(_ mark: JournalMark, tint: Color?) -> some View {
        switch mark {
        case .symbol(let name):
            Image(systemName: name)
                .font(.body)
                .foregroundStyle(tint ?? Color.primary)
                .frame(width: 24, height: 24)
        case .emoji(let value):
            Text(value)
                .font(.system(size: 20))
                .frame(width: 24, height: 24)
        }
    }

    private func changePaper(_ paper: NoteDocument.Paper) {
        guard let note = session.note else { return }
        session.metadata(title: note.title, tags: note.tags.joined(separator: ","), paper: paper)
    }
    private var surfaceToken: String { "\(session.renderRevision)|\(session.strokeSelection)|\(session.editsStrokes)|\(session.selection)|\(session.surfaceGeneration)|\(session.focusRequest)|\(session.toolsRequest)|\(session.toolsVisible)|\(session.active)|\(session.mode)" }
    private func openCitation(_ quote: NoteQuote) {
        if session.note?.kind == .journal {
            session.setJournalScriptureVisible(true)
        } else {
            scriptureVisible = true
        }
        Task {
            if reader.edition?.id != quote.editionID { await reader.selectEdition(quote.editionID) }
            guard reader.edition?.id == quote.editionID else { session.notice = "That translation is unavailable. Your saved quote remains in the note."; return }
            await reader.navigate(book: quote.verse.book, chapter: quote.verse.chapter, verse: quote.verse.verse)
        }
    }
    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) { titleButton }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if session.note?.kind == .page || session.note?.kind == .journal {
                Button(toolsExpanded ? "Collapse editing tools" : "Expand editing tools", systemImage: toolsExpanded ? "chevron.right" : "chevron.left") { toolsExpanded.toggle() }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("notes.tools.collapse")
                    .accessibilityValue(toolsExpanded ? "Expanded" : "Collapsed")
            }
            if session.note?.kind == .canvas || toolsExpanded {
                Button(session.toolsVisible ? "Hide Pencil tools" : "Pencil tools", systemImage: session.toolsVisible ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle") {
                    session.toolsVisible.toggle()
                    session.toolsRequest = UUID()
                }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("notes.tools")
                .accessibilityValue(session.toolsVisible ? "Active" : "Hidden")
                if session.note?.kind == .canvas {
                    Button("Text box", systemImage: "textformat") { session.insert(.text) }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("notes.insert.text")
                    Button("Shapes", systemImage: "square.on.circle") { gallery = "Shapes" }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("notes.shapes")
                        .popover(isPresented: galleryBinding("Shapes")) { NoteInsertGallery(session: session, kind: "Shapes") { gallery = nil } }
                    Button("Stickers", systemImage: "face.smiling") { gallery = "Stickers" }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("notes.stickers")
                        .popover(isPresented: galleryBinding("Stickers")) { NoteInsertGallery(session: session, kind: "Stickers") { gallery = nil } }
                    Menu("Insert", systemImage: "plus") {
                        Button("Text box") { session.insert(.text) }
                        Button("Sticky note") { session.insert(.text, tint: .yellow) }
                        Button("Shape") { gallery = "Shapes" }
                        Button("Sticker") { gallery = "Stickers" }
                        Button("Image from Files") { importing = true }
                        Button("Link") { linkPrompt = true }
                        Button("Table") { session.insert(.table) }
                        Button("Bullet list") { session.insert(.bullets) }
                        Button("Numbered list") { session.insert(.numbered) }
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("notes.insert")
                } else if session.note?.kind == .page || session.note?.kind == .journal {
                    Button("Text format", systemImage: "textformat") { showFormatPopover = true }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("notes.format")
                        .popover(isPresented: $showFormatPopover, arrowEdge: .top) {
                            NoteFormatPopover(session: session)
                        }
                    Button("Checkbox", systemImage: "checklist") { session.insertCheckbox() }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("notes.insert.checkbox")
                    Button("Table", systemImage: "tablecells") { session.insert(.table) }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("notes.insert.table")
                    Menu("Attach", systemImage: "paperclip") {
                        Button("Link", systemImage: "link") { linkPrompt = true }
                        Button("Take Photo", systemImage: "camera") { beginCamera() }
                        Button("Choose Photo", systemImage: "photo") { choosePhoto = true }
                        Button("Scan Text", systemImage: "text.viewfinder") { beginScan(.text) }
                        Button("Scan Document", systemImage: "doc.viewfinder") { beginScan(.document) }
                        Button(recorder.recording ? "Stop Recording" : "Record Audio", systemImage: recorder.recording ? "stop.circle" : "mic") { toggleRecording() }
                        Button("Attach Audio", systemImage: "waveform") { importAudio = true }
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("notes.attach")
                }
            }
            if session.note?.kind == .canvas {
                Menu {
                    Button("Fit content") { session.setZoom?(nil) }
                    ForEach([25, 50, 75, 100, 150, 200], id: \.self) { value in
                        Button("\(value)%") { session.setZoom?(CGFloat(value) / 100) }
                    }
                } label: { Text("\(Int(session.zoom * 100))%").font(.caption.monospacedDigit()).frame(minWidth: 40) }
                .accessibilityLabel("Zoom")
                .accessibilityIdentifier("notes.zoom")
            } else if recorder.recording {
                Text("Recording")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("notes.recording")
            }
            if session.note?.kind == .page || session.note?.kind == .journal {
                Button(showsScripturePane ? "Hide Scripture" : "Show Scripture", systemImage: "sidebar.left") { toggleScripturePane() }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("notes.scripture.toggle")
            }
            Button("Undo", systemImage: "arrow.uturn.backward") { session.undo() }
                .disabled(!session.canUndo)
                .accessibilityIdentifier("notes.undo")
            Button("Redo", systemImage: "arrow.uturn.forward") { session.redo() }
                .disabled(!session.canRedo)
                .accessibilityIdentifier("notes.redo")
            if session.note?.kind == .canvas {
                Button("Share", systemImage: "square.and.arrow.up") { session.shareCanvas?() }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("notes.editor.share")
            }
            if session.note?.kind == .page {
                pageStatusMenu
            }
            if session.note?.kind == .journal {
                Menu {
                    Picker("Journal Type", selection: Binding(get: { session.note?.journalContent?.journalType ?? .spiritual }, set: { session.setJournalType($0) })) {
                        ForEach(JournalType.allCases, id: \.self) { choice in
                        Label { Text(choice.label) } icon: { JournalTypeImages.image(for: choice) }.tag(choice)
                    }
                    }
                } label: { JournalTypeImages.image(for: session.note?.journalContent?.journalType ?? .unset) }
                .accessibilityLabel("Journal Type")
                .accessibilityValue(session.note?.journalContent?.journalType.label ?? JournalType.spiritual.label)
                .accessibilityIdentifier("notes.journal.type")
                let emotion = session.note?.journalContent?.emotionalState
                let mind = session.note?.journalContent?.mentalState
                Button { journalSheet = .emotional } label: {
                    journalToolbarMark(
                        emotion.map(JournalStateAppearance.emotional)?.mark ?? .symbol("heart"),
                        tint: emotion.map { JournalStateAppearance.emotional($0).tint }
                    )
                }
                .accessibilityLabel("Emotional state")
                .accessibilityIdentifier("notes.journal.emotional")
                .accessibilityValue(emotion?.label ?? "Not set")
                Button { journalSheet = .mental } label: {
                    journalToolbarMark(
                        mind.map(JournalStateAppearance.mental)?.mark ?? .symbol("brain"),
                        tint: mind.map { JournalStateAppearance.mental($0).tint }
                    )
                }
                .accessibilityLabel("Mental state")
                .accessibilityIdentifier("notes.journal.mental")
                .accessibilityValue(mind?.label ?? "Not set")
            }
            optionsMenu
        }
    }

    private var pageStatusMenu: some View {
        let status = session.note?.pageStatus ?? .unset
        return Menu {
            Picker("Page status", selection: Binding(
                get: { session.note?.pageStatus ?? .unset },
                set: { session.setPageStatus($0) }
            )) {
                ForEach(PageStatus.allCases, id: \.self) { choice in
                    Label(choice.label, systemImage: pageStatusSymbol(choice)).tag(choice)
                }
            }
        } label: {
            Image(systemName: pageStatusSymbol(status))
        }
        .accessibilityLabel("Page status")
        .accessibilityValue(status.label)
        .accessibilityIdentifier("notes.page.status")
    }

    private func pageStatusSymbol(_ status: PageStatus) -> String {
        switch status {
        case .unset: "flag"
        case .drafting: "pencil"
        case .revising: "arrow.triangle.2.circlepath"
        case .editing: "pencil.line"
        case .publishing: "paperplane"
        case .closed: "checkmark.seal"
        }
    }

    private var editor: some View {
        Group {
            if session.note?.kind == .canvas {
                NoteCanvasSurface(session: session, active: session.active, stateToken: surfaceToken, openCitation: openCitation)
            } else if session.note?.kind.usesPageBody == true {
                NotePageSurface(session: session, active: session.active, stateToken: surfaceToken, allowsHorizontalPan: showsScripturePane, openCitation: openCitation)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Insert link", isPresented: $linkPrompt) {
            TextField("https://example.com", text: $link).textInputAutocapitalization(.never)
            Button("Insert") { session.insert(.link, url: link) }
            Button("Cancel", role: .cancel) {}
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { result in
            importFile(result, limit: 32 * 1024 * 1024) { session.insertImage($0) }
        }
        .fileImporter(isPresented: $importAudio, allowedContentTypes: [.audio]) { result in
            importFile(result, limit: 16 * 1024 * 1024) { session.insertAudio($0, name: "Audio") }
        }
        .photosPicker(isPresented: $choosePhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { session.insertImage(data) }
                photoItem = nil
            }
        }
        .fullScreenCover(isPresented: $takePhoto) {
            CameraCapture { session.insertImage($0); takePhoto = false }
        }
        .fullScreenCover(item: $scan) { mode in
            DocumentScanner { images in
                scan = nil
                switch mode {
                case .text:
                    Task { session.insertScannedText(await NoteTextScan.recognize(images)) }
                case .document:
                    for image in images {
                        if let data = image.jpegData(compressionQuality: 0.85) { session.insertImage(data) }
                    }
                }
            }
        }
        .onDisappear { recorder.stop(); session.flushSurface?(); Task { await session.save() } }
    }

    private func beginCamera() {
        guard NoteCapture.canTakePhoto else {
            session.notice = "This iPad has no camera available for taking a photo."
            return
        }
        takePhoto = true
    }

    private func beginScan(_ mode: NoteScanMode) {
        guard NoteCapture.canScan else {
            session.notice = "Document scanning is not available on this iPad."
            return
        }
        scan = mode
    }

    private func toggleRecording() {
        if recorder.recording {
            recorder.onFinish = { data in session.insertAudio(data, name: "Recording") }
            recorder.stop()
        } else {
            do { try recorder.start() } catch { session.notice = "Recording is unavailable. Allow the microphone for Sophia Scriptura in Settings." }
        }
    }

    private func importFile(_ result: Result<URL, Error>, limit: Int, insert: (Data) -> Void) {
        do {
            let url = try result.get(), granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= limit else { throw NotesError.limit }
            insert(try Data(contentsOf: url))
        } catch { session.report(error) }
    }
}

private struct NoteDetailsView: View {
    let session: NotesSession
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var tags = ""
    @State private var paper = NoteDocument.Paper.plain
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title).accessibilityIdentifier("notes.title")
                TextField("Tags, separated by commas", text: $tags)
                Picker("Paper", selection: $paper) { ForEach(NoteDocument.Paper.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                if let note = session.note {
                    Section("Dates") {
                        LabeledContent("Created", value: note.createdAt.formatted(date: .long, time: .shortened))
                        LabeledContent("Last modified", value: note.updatedAt.formatted(date: .long, time: .shortened))
                    }
                }
            }.appSurface().navigationTitle("Note details")
                .toolbar {
                    Button("Cancel") { dismiss() }
                    Button("Save") {
                        session.metadata(title: title, tags: tags, paper: paper)
                        dismiss()
                    }
                }
        }.onAppear {
            title = session.note?.title ?? ""
            tags = session.note?.tags.joined(separator: ", ") ?? ""
            paper = session.note?.paper ?? .plain
        }
    }
}

private struct NoteObjectInspector: View {
    let session: NotesSession
    @State var object: NoteObject
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                if object.kind == .quote {
                    Text(object.quote?.source ?? ""); Text(object.quote?.reference ?? "")
                    Text("Commentary"); TextEditor(text: $object.text).frame(minHeight: 120)
                } else if object.kind == .table {
                    ForEach(object.cells.indices, id: \.self) { row in
                        Section("Row \(row + 1)") {
                            ForEach(object.cells[row].indices, id: \.self) { column in cell(row: row, column: column) }
                        }
                    }
                    Button("Add row") { if object.cells.count < 20 { object.cells.append(Array(repeating: "", count: object.cells.first?.count ?? 3)) } }
                    Button("Add column") { if (object.cells.first?.count ?? 0) < 10 { for i in object.cells.indices { object.cells[i].append("") } } }
                } else if object.kind != .ink && object.kind != .image {
                    TextEditor(text: $object.text).frame(minHeight: 120)
                    if object.kind == .link {
                        TextField("URL", text: $object.url).textInputAutocapitalization(.never)
                        if let url = URL(string: object.url), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil {
                            Link("Open link", destination: url)
                        }
                    }
                }
                if (session.note?.kind == .canvas || object.kind != .ink) && object.group == nil {
                    TextField("Width", value: dimension(width: true), format: .number).keyboardType(.decimalPad)
                    if object.kind != .image { TextField("Height", value: dimension(width: false), format: .number).keyboardType(.decimalPad) }
                }
                if ![.image, .ink, .shape].contains(object.kind) {
                    Stepper("Text size: \(Int(object.fontSize))", value: $object.fontSize, in: 12...72)
                    if [.text, .bullets, .numbered].contains(object.kind) {
                        Toggle("Monospaced", isOn: $object.monospaced)
                    }
                }
                TextField("Description", text: $object.details)
                Toggle("Lock position", isOn: $object.positionLocked)
                if object.kind == .ink { Text("Use Pencil to draw or erase. Select the drawing with your finger to move or resize it.") }
            }.appSurface().navigationTitle(object.kind.rawValue.capitalized)
                .toolbar {
                    Button("Cancel") { dismiss() }
                    Button("Save") {
                        let width = object.frame.width, height = object.frame.height
                        let changedURL = object.kind == .link && session.note?.allObjects.first(where: { $0.id == object.id })?.url != object.url
                        session.update(object.id) { original in
                            let frame = original.frame
                            original = object; original.frame = frame
                            if changedURL { original.payload = Data(); original.text = object.url }
                        }
                        session.resize(object.id, width: width, height: height)
                        if changedURL { session.refreshLink(object.id) }
                        dismiss()
                    }
                }
        }
    }
    private func cell(row: Int, column: Int) -> some View {
        let value = Binding<String>(get: { object.cells[row][column] }, set: { object.cells[row][column] = $0 })
        return TextField("Column \(column + 1)", text: value)
    }

    private func dimension(width: Bool) -> Binding<Double> {
        Binding(get: { Double(width ? object.frame.width : object.frame.height) }, set: { value in
            if width { object.frame.size.width = CGFloat(value) } else { object.frame.size.height = CGFloat(value) }
        })
    }

}
