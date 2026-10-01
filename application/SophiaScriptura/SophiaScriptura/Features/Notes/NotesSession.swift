import SwiftUI
import PencilKit
import ImageIO

/// Owns one library and serializes autosave; surfaces never write files.
@MainActor @Observable final class NotesSession {
    enum Mode: String, CaseIterable { case select = "Select", text = "Text", draw = "Draw", pan = "Pan" }
    private(set) var snapshot = NotesSnapshot()
    private(set) var loaded = false
    private(set) var dirty = false
    private(set) var saving = false
    private(set) var restoring = false
    var notice: String?
    var selectedNoteID: UUID?
    var selection = Set<UUID>()
    var mode = Mode.select
    var active = false
    var surfaceGeneration = UUID()
    var focusRequest = UUID()
    var insertionPoint = CGPoint(x: 600, y: 400)
    var selectingMultiple = false
    var setZoom: ((CGFloat?) -> Void)?
    var zoom: CGFloat = 1
    var bodySelection = NSRange(location: 0, length: 0)
    var editingObjectID: UUID?
    var toolsRequest = UUID()
    var toolsVisible = true
    var endTyping: (() -> Void)?
    var flushSurface: (() -> Void)?
    private let repository: any NotesRepository
    private var change = 0
    private var saveTask: Task<Void, Never>?
    // Only changed objects are retained, rather than whole document snapshots.
    private struct Edit {
        var noteID: UUID
        var before: [NoteObject]
        var after: [NoteObject]
        var beforeOrder: [UUID]
        var afterOrder: [UUID]
        var beforePage: NotePage?
        var afterPage: NotePage?
        var bytes: Int { (beforePage?.ink.count ?? 0) + (afterPage?.ink.count ?? 0) + (beforePage?.attachments.reduce(0, { $0 + $1.object.payload.count }) ?? 0) + (afterPage?.attachments.reduce(0, { $0 + $1.object.payload.count }) ?? 0) + (beforePage?.body.utf8.count ?? 0) + (afterPage?.body.utf8.count ?? 0) + (before + after).reduce(0) { $0 + $1.payload.count + $1.text.utf8.count } }
    }
    private var undoStack: [Edit] = []
    private var redoStack: [Edit] = []
    var renderRevision: Int { change }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var note: NoteDocument? { snapshot.notes.first { $0.id == selectedNoteID } }
    var status: String { saving ? "Saving…" : dirty ? "Not saved — Retry" : "Saved" }
    init(repository: any NotesRepository = NotesFileRepository(directory: NotesFileRepository.defaultDirectory())) { self.repository = repository }
    func load() async {
        guard !loaded else { return }
        do {
            let result = try await repository.load(); snapshot = result.snapshot; loaded = true
            if result.recovered { notice = "Recovered the previous Notes revision. Damaged files are preserved." }
        } catch { report(error) }
    }
    func report(_ error: Error) { notice = error.localizedDescription }
    func open(_ id: UUID) {
        flushSurface?(); selectedNoteID = id; selection = []; selectingMultiple = false; mode = .select
        undoStack = []; redoStack = []; surfaceGeneration = UUID(); bodySelection = NSRange(location: 0, length: 0)
    }
    @discardableResult func create(kind: NoteKind = .page, quote: NoteQuote? = nil) -> UUID? {
        guard !restoring, loaded, snapshot.notes.count < 200 else { notice = "Notes is unavailable or its 200-note safety limit has been reached."; return nil }
        var note = NoteDocument(page: kind == .page ? NotePage() : nil)
        if let quote {
            do { try quote.validate() } catch { report(error); return nil }
            note.title = quote.reference
            if kind == .page { note.page?.insert(quote, at: 0) }
            else { note.objects.append(NoteObject(kind: .quote, quote: quote)) }
            if NotePageTypography.height(of: note.page?.body ?? "") > NoteDocument.extent - 400 { notice = "That passage is too long for one note."; return nil }
        }
        snapshot.notes.append(note); changed(); open(note.id); return note.id
    }
    func metadata(title: String, tags: String, paper: NoteDocument.Paper) {
        guard !restoring, let i = index else { return }
        snapshot.notes[i].title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        if snapshot.notes[i].title.isEmpty { snapshot.notes[i].title = "Untitled Note" }
        snapshot.notes[i].tags = Array(Set(tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces).prefix(60)) }.filter { !$0.isEmpty })).sorted().prefix(30).map { $0 }
        snapshot.notes[i].paper = paper; snapshot.notes[i].updatedAt = Date(); changed()
    }
    func delete(_ id: UUID, restore: Bool = false) {
        guard !restoring, let i = snapshot.notes.firstIndex(where: { $0.id == id }) else { return }
        snapshot.notes[i].deletedAt = restore ? nil : Date(); snapshot.notes[i].updatedAt = Date(); changed()
        if id == selectedNoteID { selectedNoteID = nil; surfaceGeneration = UUID() }
    }
    private var index: Int? { snapshot.notes.firstIndex { $0.id == selectedNoteID } }
    func edit(_ operation: (inout NoteDocument) -> Void, record: Bool = true) {
        guard !restoring, let i = index else { return }
        let before = snapshot.notes[i]
        var next = before; operation(&next)
        guard before != next else { return }
        do {
            try next.validate()
            if let page = next.page, NotePageTypography.height(of: page) > NoteDocument.extent - 400 {
                notice = "This page has reached its length limit. Start another note to keep all text reachable."; return
            }
        } catch { report(error); return }
        next.updatedAt = Date(); snapshot.notes[i] = next
        if record {
            let beforeByID = Dictionary(uniqueKeysWithValues: before.objects.map { ($0.id, $0) })
            let afterByID = Dictionary(uniqueKeysWithValues: next.objects.map { ($0.id, $0) })
            let ids = Set(beforeByID.keys).union(afterByID.keys).filter { beforeByID[$0] != afterByID[$0] }
            undoStack.append(Edit(noteID: next.id, before: before.objects.filter { ids.contains($0.id) }, after: next.objects.filter { ids.contains($0.id) }, beforeOrder: before.objects.map(\.id), afterOrder: next.objects.map(\.id), beforePage: before.page, afterPage: next.page))
            redoStack = []
            while undoStack.count > 80 || undoStack.reduce(0, { $0 + $1.bytes }) > 24 * 1024 * 1024 { undoStack.removeFirst() }
        }
        changed()
    }
    func update(_ id: UUID, _ operation: (inout NoteObject) -> Void) {
        edit { note in
            if let i = note.objects.firstIndex(where: { $0.id == id }) { operation(&note.objects[i]) }
            else if let i = note.page?.attachments.firstIndex(where: { $0.id == id }) { operation(&note.page!.attachments[i].object) }
        }
    }
    func insert(_ kind: NoteObject.Kind, payload: Data = Data(), url: String = "", shape: NoteShape? = nil, sticker: String? = nil, tint: NoteTint? = nil) {
        guard kind != .ink else { toolsVisible = true; toolsRequest = UUID(); return }
        guard let note, note.allObjects.count < 200 else { notice = "This note has reached its object limit."; return }
        if note.kind == .page {
            switch kind {
            case .link:
                guard let link = URL(string: url), ["http", "https"].contains(link.scheme?.lowercased() ?? ""), link.host != nil else { report(NotesError.invalid); return }
                replaceBody(bodySelection, with: url + " "); return
            case .bullets: replaceBody(bodySelection, with: "• "); return
            case .numbered: replaceBody(bodySelection, with: "1. "); return
            case .image, .table: break
            default: return
            }
        }
        var object = NoteObject(kind: kind)
        object.frame.origin = CGPoint(x: ((note.page?.width ?? 1200) - NotePage.columnWidth) / 2 + CGFloat(note.objects.count % 5) * 30, y: min(NoteDocument.extent - 700, (note.objects.last?.frame.maxY ?? 60) + 40))
        switch kind {
        case .ink: object.frame.size = CGSize(width: 900, height: 600); object.payload = PKDrawing().dataRepresentation()
        case .image: object.payload = payload
        case .link: object.url = url; object.text = url
        case .shape:
            switch shape ?? .roundedRectangle {
            case .rectangle, .roundedRectangle: break
            case .arrow: object.frame.size = CGSize(width: 240, height: 100)
            default: object.frame.size = CGSize(width: 180, height: 180)
            }
        case .table: object.cells = Array(repeating: Array(repeating: "", count: 3), count: 3); object.frame.size = CGSize(width: 480, height: 240)
        case .sticker: object.text = sticker ?? "🌿"; object.frame.size = CGSize(width: 100, height: 100); object.fontSize = 64
        case .bullets: object.text = "• "
        case .numbered: object.text = "1. "
        default: break
        }
        object.shape = shape; object.tint = tint
        if kind == .link { object.frame.size = CGSize(width: 320, height: 260) }
        if note.kind == .canvas {
            object.frame.origin = CGPoint(x: max(0, min(NoteDocument.extent - object.frame.width, insertionPoint.x - object.frame.width / 2)), y: max(0, min(NoteDocument.extent - object.frame.height, insertionPoint.y - object.frame.height / 2)))
        }
        edit {
            if $0.kind == .page { $0.page?.insertAttachment(object, at: bodySelection.location) }
            else { $0.objects.append(object) }
        }; selection = [object.id]
        mode = kind == .ink ? .draw : [.text, .bullets, .numbered].contains(kind) ? .text : .select
        focusRequest = UUID()
        if kind == .link { refreshLink(object.id) }
    }
    func insertImage(_ data: Data) {
        guard data.count <= 32 * 1024 * 1024, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 2048, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary),
              let bytes = UIImage(cgImage: image).jpegData(compressionQuality: 0.85) else { notice = "That image could not be opened or exceeds 32 MiB."; return }
        insert(.image, payload: bytes)
        if let id = selection.first { update(id) { $0.frame.size = CGSize(width: 320, height: max(40, 320 * CGFloat(image.height) / CGFloat(image.width))) } }
    }
    func duplicateSelection() {
        guard let note else { return }
        let ids = note.members(selection)
        var copies = note.objects.filter { ids.contains($0.id) }
        let groupMap = Dictionary(uniqueKeysWithValues: Set(copies.compactMap(\.group)).map { ($0, UUID()) })
        for i in copies.indices {
            copies[i].id = UUID()
            copies[i].group = copies[i].group.flatMap { groupMap[$0] }
            copies[i].frame.origin.x = min((note.page?.width ?? NoteDocument.extent) - copies[i].frame.width, copies[i].frame.minX + 32)
            copies[i].frame.origin.y = min(NoteDocument.extent - copies[i].frame.height, copies[i].frame.minY + 32)
        }
        edit { $0.objects += copies }
        let copiedIDs = Set(copies.map(\.id))
        if copiedIDs.isSubset(of: Set(self.note?.objects.map(\.id) ?? [])) { selection = copiedIDs; focusRequest = UUID() }
    }
    func refreshLink(_ id: UUID) {
        guard let note, let object = note.objects.first(where: { $0.id == id && $0.kind == .link }), let url = URL(string: object.url) else { return }
        let noteID = note.id
        Task { [weak self] in
            guard let preview = await NoteLinkPreview.load(url) else { return }
            guard let self, self.selectedNoteID == noteID,
                  self.note?.objects.first(where: { $0.id == id })?.url == object.url else { return }
            self.edit({ note in
                guard let i = note.objects.firstIndex(where: { $0.id == id }) else { return }
                if note.objects[i].text == object.text { note.objects[i].text = preview.title }
                note.objects[i].payload = preview.image
            }, record: false)
            // Loading a preview is not an extra user edit. Keep insertion redo cached.
            for entry in self.undoStack.indices {
                for item in self.undoStack[entry].after.indices where self.undoStack[entry].after[item].id == id && self.undoStack[entry].after[item].url == object.url {
                    if self.undoStack[entry].after[item].text == object.text { self.undoStack[entry].after[item].text = preview.title }
                    self.undoStack[entry].after[item].payload = preview.image
                }
            }
            while self.undoStack.reduce(0, { $0 + $1.bytes }) > 24 * 1024 * 1024 { self.undoStack.removeFirst() }
        }
    }
    func move(_ delta: CGSize) { edit { $0.move(selection, by: delta) } }
    func group() { edit { $0.group(selection) } }
    func ungroup() { edit { $0.ungroup(selection) } }
    func remove() {
        edit { note in
            if let attachments = note.page?.attachments.filter({ selection.contains($0.id) }).sorted(by: { $0.location > $1.location }) {
                for item in attachments { note.page?.replace(NSRange(location: item.location, length: 1), with: "") }
            }
            note.remove(selection)
        }; selection = []
    }
    func resize(_ id: UUID, width: CGFloat, height: CGFloat) {
        update(id) { object in
            guard (note?.kind == .canvas || object.kind != .ink), object.group == nil else { return }
            let w = min(max(40, width), (note?.page?.width ?? NoteDocument.extent) - object.frame.minX)
            let h = [.image, .ink].contains(object.kind) ? object.frame.height * w / object.frame.width : height
            guard h <= NoteDocument.extent - object.frame.minY else { return }
            object.frame.size = CGSize(width: w, height: max(40, h))
        }
    }
    func reorder(_ id: UUID, front: Bool) {
        edit { note in
            guard let i = note.objects.firstIndex(where: { $0.id == id }) else { return }
            let value = note.objects.remove(at: i)
            if front { note.objects.append(value) } else { note.objects.insert(value, at: 0) }
        }
    }
    func undo() { flushSurface?(); guard let entry = undoStack.popLast() else { return }; apply(entry, forward: false); redoStack.append(entry) }
    func redo() { flushSurface?(); guard let entry = redoStack.popLast() else { return }; apply(entry, forward: true); undoStack.append(entry) }
    private func apply(_ entry: Edit, forward: Bool) {
        guard entry.noteID == selectedNoteID else { return }
        edit({ note in
            note.page = forward ? entry.afterPage : entry.beforePage
            let ids = Set((entry.before + entry.after).map(\.id))
            note.objects.removeAll { ids.contains($0.id) }
            note.objects += forward ? entry.after : entry.before
            let order = forward ? entry.afterOrder : entry.beforeOrder
            note.objects.sort { (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0) }
        }, record: false)
        selection = []; surfaceGeneration = UUID()
    }
    func replaceBody(_ range: NSRange, with text: String) {
        edit { note in note.page?.replace(range, with: text) }
    }
    func quote(for selection: ChapterTextMap.Selection, reader: ReaderSession) async -> NoteQuote? {
        guard let first = selection.passages.first, !selection.text.isEmpty else { return nil }
        let attribution = reader.edition?.attribution ?? ""
        guard await reader.authorizeQuote(selection) != nil else { return nil }
        return NoteQuote(verse: first.start, editionID: selection.editionID,
            contentRevision: selection.contentRevision, attribution: attribution, source: selection.text,
            endVerse: selection.passages.last?.end)
    }
    func saveSelection(_ selection: ChapterTextMap.Selection, reader: ReaderSession, newNote: Bool) async -> UUID? {
        let selectedID = selectedNoteID
        guard let quote = await quote(for: selection, reader: reader) else { return nil }
        if newNote { return create(quote: quote) }
        guard selectedID == selectedNoteID else { return nil }
        appendQuote(quote); return selectedNoteID
    }
    func appendQuote(_ quote: NoteQuote) {
        guard selectedNoteID != nil else { _ = create(quote: quote); return }
        flushSurface?()
        edit { note in
            if note.kind == .page { note.page?.insert(quote, at: bodySelection.location) }
            else {
                var object = NoteObject(kind: .quote, quote: quote)
                object.frame.origin.y = min(NoteDocument.extent - 600, (note.objects.last?.frame.maxY ?? 60) + 40)
                object.frame.size = CGSize(width: 480, height: 360)
                note.objects.append(object)
            }
        }
        focusRequest = UUID()
    }
    func updatePageInk(_ data: Data) { edit { $0.page?.ink = data } }
    func growPage(to height: CGFloat) {
        guard height.isFinite else { return }
        edit({ note in
            guard var page = note.page else { return }
            page.height = min(NoteDocument.extent, max(page.height, ceil(height / 400) * 400)); note.page = page
        }, record: false)
    }
    private func changed() {
        dirty = true; change += 1
        saveTask?.cancel()
        saveTask = Task { try? await Task.sleep(for: .milliseconds(350)); guard !Task.isCancelled else { return }; await save() }
    }
    func save() async {
        guard loaded, dirty, !saving else { return }
        saving = true
        defer { saving = false }
        while dirty {
            let version = change, value = snapshot
            do {
                let saved = try await repository.save(value, expectedRevision: value.revision)
                snapshot.revision = saved.revision; snapshot.schemaVersion = saved.schemaVersion
                if version == change { dirty = false; notice = nil }
            } catch { report(error); return }
        }
    }
    func export() async throws -> Data {
        flushSurface?(); await save()
        guard !dirty, !saving else { throw NotesError.stale }
        return try await repository.exportArchive()
    }
    func preRestore() async throws -> Data { try await repository.preRestoreArchive() }
    func restore(_ data: Data) async {
        guard !restoring else { return }
        flushSurface?(); await save()
        guard !saving, !dirty else { notice = "Save current edits before restoring."; return }
        restoring = true
        defer { restoring = false }
        do {
            let next = try await repository.restore(data, expectedRevision: snapshot.revision)
            surfaceGeneration = UUID(); flushSurface = nil; snapshot = next; loaded = true
            selectedNoteID = nil; selection = []; undoStack = []; redoStack = []; notice = "Notes backup restored. The pre-restore copy is available in Backups."
        } catch { report(error) }
    }
}
