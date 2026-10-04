import SwiftUI
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: NotesSession
    var reader: ReaderSession
    @AppStorage("notes.scriptureVisible") private var scriptureVisible = true
    @State private var rename = false
    @State private var title = ""
    @State private var gallery: String?
    @State private var showDetails = false
    @State private var importing = false
    @State private var linkPrompt = false
    @State private var link = "https://"
    @State private var confirmDelete = false
    var body: some View {
        Group {
            if session.note?.kind == .prayer {
                NotePrayerEditorView(session: session, reader: reader)
            } else {
                pageOrJournalEditor
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
        .toolbar {
            ToolbarItem(placement: .principal) { titleButton }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if session.note?.kind == .page || session.note?.kind == .journal {
                    Button(showsScripturePane ? "Hide Scripture" : "Show Scripture", systemImage: "sidebar.left") { toggleScripturePane() }
                        .accessibilityIdentifier("notes.scripture.toggle")
                }
                Button("Undo", systemImage: "arrow.uturn.backward") { session.undo() }.disabled(!session.canUndo).accessibilityIdentifier("notes.undo")
                Button("Redo", systemImage: "arrow.uturn.forward") { session.redo() }.disabled(!session.canRedo).accessibilityIdentifier("notes.redo")
                Button("Archive", systemImage: "archivebox") {
                    session.archiveCurrentNote()
                    dismiss()
                }
                    .accessibilityIdentifier("notes.editor.archive")
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    .accessibilityIdentifier("notes.editor.delete")
                optionsMenu
            }
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
                Button("Note details", systemImage: "tag") { showDetails = true }
                Button(session.status, systemImage: session.dirty ? "arrow.clockwise" : "checkmark.circle") { Task { await session.save() } }
            } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("Note options").accessibilityIdentifier("notes.options")
    }
    private func changePaper(_ paper: NoteDocument.Paper) {
        guard let note = session.note else { return }
        session.metadata(title: note.title, tags: note.tags.joined(separator: ","), paper: paper)
    }
    private var surfaceToken: String { "\(session.renderRevision)|\(session.selection)|\(session.surfaceGeneration)|\(session.focusRequest)|\(session.toolsRequest)|\(session.toolsVisible)|\(session.active)|\(session.mode)" }
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
    private var editor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Button(session.toolsVisible ? "Hide Pencil tools" : "Pencil tools", systemImage: session.toolsVisible ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle") { session.toolsVisible.toggle(); session.toolsRequest = UUID() }.accessibilityIdentifier("notes.tools").accessibilityValue(session.toolsVisible ? "Active" : "Hidden")
                if session.note?.kind == .canvas {
                    Button("Text box", systemImage: "textformat") { session.insert(.text) }.accessibilityIdentifier("notes.insert.text")
                    Button("Shapes", systemImage: "square.on.circle") { gallery = "Shapes" }.accessibilityIdentifier("notes.shapes")
                        .popover(isPresented: galleryBinding("Shapes")) { NoteInsertGallery(session: session, kind: "Shapes") { gallery = nil } }
                    Button("Stickers", systemImage: "face.smiling") { gallery = "Stickers" }.accessibilityIdentifier("notes.stickers")
                        .popover(isPresented: galleryBinding("Stickers")) { NoteInsertGallery(session: session, kind: "Stickers") { gallery = nil } }
                }
                Menu("Insert", systemImage: "plus") {
                    if session.note?.kind == .canvas {
                        Button("Text box") { session.insert(.text) }
                        Button("Sticky note") { session.insert(.text, tint: .yellow) }
                        Button("Shape") { gallery = "Shapes" }
                        Button("Sticker") { gallery = "Stickers" }
                    }
                    Button("Image from Files") { importing = true }
                    Button("Link") { linkPrompt = true }
                    Button("Table") { session.insert(.table) }
                    Button("Bullet list") { session.insert(.bullets) }
                    Button("Numbered list") { session.insert(.numbered) }
                }.accessibilityIdentifier("notes.insert")
                Spacer(minLength: 0)
                Menu {
                    Button("Fit content") { session.setZoom?(nil) }
                    ForEach([25, 50, 75, 100, 150, 200], id: \.self) { value in
                        Button("\(value)%") { session.setZoom?(CGFloat(value) / 100) }
                    }
                } label: { Text("\(Int(session.zoom * 100))%").font(.caption.monospacedDigit()).frame(minWidth: 40) }
                .accessibilityLabel("Zoom").accessibilityIdentifier("notes.zoom")
            }
            .labelStyle(.iconOnly).buttonStyle(.plain).font(.system(size: 20))
            .frame(height: 44).padding(.horizontal, 16).background(Color(theme.palette.paper))
            Divider()
            if session.note?.kind == .canvas {
                NoteCanvasSurface(session: session, active: session.active, stateToken: surfaceToken, openCitation: openCitation)
            } else if session.note?.kind.usesPageBody == true {
                NotePageSurface(session: session, active: session.active, stateToken: surfaceToken, openCitation: openCitation)
            }

        }
        .alert("Insert link", isPresented: $linkPrompt) {
            TextField("https://example.com", text: $link).textInputAutocapitalization(.never)
            Button("Insert") { session.insert(.link, url: link) }
            Button("Cancel", role: .cancel) {}
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get(), granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 32 * 1024 * 1024 else { throw NotesError.limit }
                session.insertImage(try Data(contentsOf: url))
            } catch { session.report(error) }
        }
        .onDisappear { session.flushSurface?(); Task { await session.save() } }
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
                if ![.image, .ink, .shape].contains(object.kind) { Stepper("Text size: \(Int(object.fontSize))", value: $object.fontSize, in: 12...72) }
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
