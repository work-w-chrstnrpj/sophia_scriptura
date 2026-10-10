import SwiftUI
import PencilKit
import ImageIO

/// Owns one library and serializes autosave; surfaces never write files.
@MainActor @Observable final class NotesSession {
    var protection = ItemProtectionSession.shared
    private var flushingForLock = false
    weak var collections: CollectionsStore?
    private(set) var openingCollectionID: UUID?
    func canAccessEditor(_ id: UUID) -> Bool {
        guard let document = snapshot.notes.first(where: { $0.id == id }), !isLocked(document) else { return false }
        return flushingForLock || collections?.allowsNoteOpening(id, from: openingCollectionID) != false
    }
    func concealInaccessibleNote() {
        guard let id = selectedNoteID, !canAccessEditor(id) else { return }
        flushingForLock = true; flushSurface?(); flushingForLock = false
        selectedNoteID = nil; selection = []; strokeSelection = []; undoStack = []; redoStack = []
        rejectedInk = nil; toolsVisible = false; surfaceGeneration = UUID(); inkRecoveryGeneration = UUID()
        Task { await save() }
    }
    func isLocked(_ note: NoteDocument) -> Bool { !flushingForLock && protection.isLocked(note.protectionID, in: .notes) }
    func setProtected(_ id: UUID, enabled: Bool) async {
        guard let original = snapshot.notes.first(where: { $0.id == id }), original.protectionID != nil || enabled else { return }
        do {
            if !enabled {
                try await protection.confirmRemoval(binding: original.protectionID, in: .notes)
            } else if original.protectionID == nil {
                try await protection.authenticate([.notes], setupIfNeeded: true)
            } else {
                try await protection.request(binding: original.protectionID, in: .notes)
            }
            try protection.require([original.protectionID ?? protection.credential?.id], in: .notes)
            guard let i = snapshot.notes.firstIndex(where: { $0.id == id }), snapshot.notes[i].protectionID == original.protectionID else { return }
            snapshot.notes[i].protectionID = enabled ? protection.credential?.id : nil
            snapshot.notes[i].updatedAt = Date(); changed(); await save()
        } catch { if case ItemLockError.cancelled = error {} else { report(error) } }
    }
    func concealProtectedNote() {
        if clipboardProtectionID != nil { canvasClipboard = []; clipboardProtectionID = nil }
        flushingForLock = true; flushSurface?(); flushingForLock = false
        if let selected = snapshot.notes.first(where: { $0.id == selectedNoteID }), selected.protectionID != nil {
            selectedNoteID = nil; selection = []; strokeSelection = []; undoStack = []; redoStack = []; rejectedInk = nil; canvasClipboard = []
            toolsVisible = false; surfaceGeneration = UUID(); inkRecoveryGeneration = UUID()
        }
        Task { await save() }
    }
    enum Mode: String, CaseIterable { case select = "Select", text = "Text", draw = "Draw", pan = "Pan" }
    private(set) var snapshot = NotesSnapshot()
    private(set) var loaded = false
    private(set) var dirty = false
    private(set) var saving = false
    private(set) var restoring = false
    var notice: String?
    var selectedNoteID: UUID? {
        didSet { if selectedNoteID != oldValue || selectedNoteID == nil { openingCollectionID = nil } }
    }
    var selection = Set<UUID>() { didSet { if !selection.isEmpty { strokeSelection = [] } } }
    var strokeSelection = Set<NoteStrokeReference>()
    var editsStrokes = false { didSet { if editsStrokes != oldValue { selection = []; strokeSelection = [] } } }
    var startsNewInkRegion = false
    func newInkRegion() {
        flushSurface?(); editsStrokes = false; selection = []; strokeSelection = []; startsNewInkRegion = true
        mode = .draw; toolsVisible = true; toolsRequest = UUID()
    }
    var mode = Mode.select
    var active = false
    var surfaceGeneration = UUID()
    var focusRequest = UUID()
    var insertionPoint = CGPoint(x: 600, y: 400)
    var selectingMultiple = false
    var setZoom: ((CGFloat?) -> Void)?
    var zoom: CGFloat = 1
    var bodySelection = NSRange(location: 0, length: 0)
    var sophyCanvasSelection: (id: UUID, range: NSRange)?
    var onSophyEnhance: ((SophyNoteSelection) -> Void)?
    var editingObjectID: UUID?
    var toolsRequest = UUID()
    var toolsVisible = true
    var endTyping: (() -> Void)?
    var flushSurface: (() -> Void)?
    var shareCanvas: (() -> Void)?
    private(set) var canvasClipboard: [NoteObject] = []
    private var clipboardProtectionID: UUID?
    private(set) var rejectedInk: Data?
    private var inkRecoveryTask: Task<Void, Never>?
    private var inkRecoveryGeneration = UUID()
    func retainRejectedInk(_ data: Data) {
        guard let id = selectedNoteID else { return }
        inkRecoveryGeneration = UUID(); rejectedInk = data
        let previous = inkRecoveryTask
        inkRecoveryTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            do { try await repository.retainRejectedInk(data, noteID: id) }
            catch { notice = "Unsaved ink remains in memory, but its recovery file could not be written: \(error.localizedDescription)" }
        }
    }
    func loadRejectedInk() async {
        guard let id = selectedNoteID else { return }
        let generation = inkRecoveryGeneration
        await inkRecoveryTask?.value
        do {
            let data = try await repository.rejectedInk(noteID: id)
            guard selectedNoteID == id, inkRecoveryGeneration == generation else { return }
            rejectedInk = data
            if data != nil { notice = "Unsaved ink was retained. Use Note options → Recover unsaved drawing." }
        } catch { if selectedNoteID == id, inkRecoveryGeneration == generation { report(error) } }
    }
    func recoverRejectedInk() async {
        await inkRecoveryTask?.value
        guard let originalID = selectedNoteID, let original = note, let data = rejectedInk else { return }
        do {
            let drawing = try PKDrawing(data: data)
            let recovered = try NoteCanvasInk(objects: []).objects(after: drawing, replacing: [])
            guard let id = create(kind: .canvas, title: "Recovered drawing") else { return }
            edit { $0.objects = recovered; $0.protectionID = original.protectionID }
            guard note?.id == id, note?.objects == recovered else { return }
            await save()
            if !dirty {
                try await repository.clearRejectedInk(noteID: originalID)
                rejectedInk = nil; notice = "Recovered the unsaved drawing in a new Canvas note."
            }
        } catch { report(error) }
    }
    private let repository: any NotesRepository
    private var change = 0
    private var saveTask: Task<Void, Never>?
    private var imageTasks: [UUID: Task<Void, Never>] = [:]
    // Only changed objects are retained, rather than whole document snapshots.
    private struct Edit {
        var noteID: UUID
        var before: [NoteObject]
        var after: [NoteObject]
        var beforeOrder: [UUID]
        var afterOrder: [UUID]
        var beforePage: NotePage?
        var afterPage: NotePage?
        var bytes: Int {
            let beforePageBytes = Self.pageBytes(beforePage)
            let afterPageBytes = Self.pageBytes(afterPage)
            let objectBytes = (before + after).reduce(0) { total, object in
                total + object.payload.count + object.text.utf8.count + (object.strokeIDs?.count ?? 0) * 16
            }
            return beforePageBytes + afterPageBytes + objectBytes
        }

        private static func pageBytes(_ page: NotePage?) -> Int {
            guard let page else { return 0 }
            let attachmentBytes = page.attachments.reduce(0) { total, attachment in
                total + attachment.object.payload.count
            }
            return page.ink.count + attachmentBytes + page.body.utf8.count
        }
    }
    private var undoStack: [Edit] = []
    private var redoStack: [Edit] = []
    var renderRevision: Int { change }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var note: NoteDocument? { snapshot.notes.first { $0.id == selectedNoteID && canAccessEditor($0.id) } }
    var status: String { saving ? "Saving…" : dirty ? "Not saved — Retry" : "Saved" }
    init(repository: any NotesRepository = NotesFileRepository(directory: NotesFileRepository.defaultDirectory())) { self.repository = repository }
    func load() async {
        guard !loaded else { return }
        do {
            let result = try await repository.load()
            var loadedSnapshot = result.snapshot
            migrateLegacyNoteFields(on: &loadedSnapshot)
            loadedSnapshot.sanitize()
            try loadedSnapshot.validate()
            snapshot = loadedSnapshot
            purgeExpiredTrash()
            loaded = true
            notice = nil
            if result.recovered { notice = "Recovered the previous Notes revision. Damaged files are preserved." }
            if loadedSnapshot != result.snapshot {
                changed()
                await save()
            }
        } catch {
            loaded = false
            report(error)
        }
    }
    func report(_ error: Error) { notice = error.localizedDescription }

    /// Deletes the on-device Notes store and starts with an empty library.
    func resetLibrary() async {
        protection.lock([.notes])
        do {
            try await repository.resetStorage()
            snapshot = NotesSnapshot()
            selectedNoteID = nil
            selection = []
            undoStack = []
            redoStack = []
            dirty = false
            loaded = true
            notice = "Notes library was reset on this iPad."
            surfaceGeneration = UUID()
        } catch {
            loaded = false
            report(error)
        }
    }
    func open(_ id: UUID, from collectionID: UUID? = nil) {
        guard collections?.allowsNoteOpening(id, from: collectionID) != false else { report(ItemLockError.locked); return }
        guard let target = snapshot.notes.first(where: { $0.id == id }) else { return }
        if isLocked(target) {
            Task {
                do { try await protection.request(binding: target.protectionID, in: .notes)
                    guard snapshot.notes.contains(where: { $0.id == id && $0.protectionID == target.protectionID }) else { return }; open(id, from: collectionID)
                } catch { if case ItemLockError.cancelled = error {} else { report(error) } }
            }; return
        }
        protection.activity(in: .notes)
        flushSurface?(); selectedNoteID = id; openingCollectionID = collectionID; strokeSelection = []; startsNewInkRegion = false; editsStrokes = false; selection = []; selectingMultiple = false; mode = .select
        undoStack = []; redoStack = []; surfaceGeneration = UUID(); bodySelection = NSRange(location: 0, length: 0)
        inkRecoveryGeneration = UUID(); rejectedInk = nil
        Task { [weak self] in await self?.loadRejectedInk() }
    }
    @discardableResult func create(
        kind: NoteKind = .page,
        quote: NoteQuote? = nil,
        color: CollectionAccent = .preset,
        title: String = ""
    ) -> UUID? {
        guard !restoring, loaded, snapshot.notes.count < 200 else { notice = "Notes is unavailable or its 200-note safety limit has been reached."; return nil }
        var note = NoteDocument(kind: kind)
        note.color = color
        if kind == .prayer { note.title = "Untitled Prayer" }
        if kind == .journal { note.title = "Untitled Journal" }
        let trimmedTitle = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        if !trimmedTitle.isEmpty, quote == nil { note.title = trimmedTitle }
        if let quote {
            do { try quote.validate() } catch { report(error); return nil }
            note.title = quote.reference
            if kind.usesPageBody { note.page?.insert(quote, at: 0) }
            else { note.objects.append(NoteObject(kind: .quote, quote: quote)) }
            if NotePageTypography.height(of: note.page?.body ?? "") > NoteDocument.extent - 400 { notice = "That passage is too long for one note."; return nil }
        }
        snapshot.notes.append(note); changed(); open(note.id); return note.id
    }

    @discardableResult func create(kind: NoteKind, saveContent: StudyNoteSaveContent) -> UUID? {
        switch saveContent {
        case .scriptureQuote(let quote):
            return create(kind: kind, quote: quote)
        case .companionResponse(let text, let anchor):
            return createCompanionNote(kind: kind, text: text, anchor: anchor)
        }
    }

    func append(saveContent: StudyNoteSaveContent) {
        switch saveContent {
        case .scriptureQuote(let quote):
            appendQuote(quote)
        case .companionResponse(let text, let anchor):
            appendCompanionResponse(text: text, anchor: anchor)
        }
    }
    func metadata(title: String, tags: String, paper: NoteDocument.Paper) {
        guard let id = selectedNoteID,
              let existing = snapshot.notes.first(where: { $0.id == id }) else { return }
        updateNote(id: id, title: title, tags: tags, paper: paper, color: existing.color)
    }

    func updateNote(id: UUID, title: String, tags: String, paper: NoteDocument.Paper, color: CollectionAccent) {
        guard !restoring, let i = snapshot.notes.firstIndex(where: { $0.id == id }) else { return }
        guard !isLocked(snapshot.notes[i]) else { notice = ItemLockError.locked.localizedDescription; return }
        protection.activity(in: .notes)
        let trimmed = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        snapshot.notes[i].title = trimmed.isEmpty ? defaultTitle(for: snapshot.notes[i].kind) : trimmed
        snapshot.notes[i].tags = Array(Set(tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces).prefix(60)) }.filter { !$0.isEmpty })).sorted().prefix(30).map { $0 }
        snapshot.notes[i].paper = paper
        snapshot.notes[i].color = color
        snapshot.notes[i].updatedAt = Date()
        changed()
    }

    private func defaultTitle(for kind: NoteKind) -> String {
        switch kind {
        case .prayer: "Untitled Prayer"
        case .journal: "Untitled Journal"
        default: "Untitled Note"
        }
    }
    func setColor(_ color: CollectionAccent) {
        guard let id = selectedNoteID else { return }
        setColor(color, for: id)
    }

    func setColor(_ color: CollectionAccent, for id: UUID) {
        guard !restoring, let i = snapshot.notes.firstIndex(where: { $0.id == id }) else { return }
        guard !isLocked(snapshot.notes[i]) else { notice = ItemLockError.locked.localizedDescription; return }
        protection.activity(in: .notes)
        snapshot.notes[i].color = color
        snapshot.notes[i].updatedAt = Date()
        changed()
    }
    /// Hides the note in the library; unarchive from Settings or Notes archive.
    func archive(_ id: UUID) {
        protection.cancel(affecting: [.notes])
        guard !restoring, let i = snapshot.notes.firstIndex(where: { $0.id == id }) else { return }
        snapshot.notes[i].archivedAt = Date()
        snapshot.notes[i].trashedAt = nil
        snapshot.notes[i].deletedAt = snapshot.notes[i].archivedAt
        snapshot.notes[i].updatedAt = Date()
        changed()
        if id == selectedNoteID { selectedNoteID = nil; surfaceGeneration = UUID() }
    }

    func unarchive(_ id: UUID) {
        guard !restoring, let i = snapshot.notes.firstIndex(where: { $0.id == id }) else { return }
        snapshot.notes[i].archivedAt = nil
        snapshot.notes[i].deletedAt = nil
        snapshot.notes[i].updatedAt = Date()
        changed()
    }

    func restoreFromArchive(_ id: UUID) { unarchive(id) }

    func moveToTrash(_ id: UUID) {
        protection.cancel(affecting: [.notes])
        guard !restoring, let i = snapshot.notes.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        snapshot.notes[i].trashedAt = now
        snapshot.notes[i].archivedAt = nil
        snapshot.notes[i].deletedAt = now
        snapshot.notes[i].updatedAt = now
        changed()
        if id == selectedNoteID { selectedNoteID = nil; surfaceGeneration = UUID() }
    }

    func restoreFromTrash(_ id: UUID) {
        guard !restoring, let i = snapshot.notes.firstIndex(where: { $0.id == id }) else { return }
        snapshot.notes[i].trashedAt = nil
        snapshot.notes[i].deletedAt = nil
        snapshot.notes[i].updatedAt = Date()
        changed()
    }

    func purgeExpiredTrash(now: Date = Date()) {
        let expired = snapshot.notes.filter { note in
            guard let trashedAt = note.trashedAt else { return false }
            return TrashRetention.isExpired(trashedAt, now: now)
        }.map(\.id)
        guard !expired.isEmpty else { return }
        for id in expired { permanentlyDelete(id) }
    }

    private func migrateLegacyNoteFields(on snapshot: inout NotesSnapshot) {
        for index in snapshot.notes.indices {
            if snapshot.notes[index].archivedAt == nil,
               snapshot.notes[index].trashedAt == nil,
               let legacy = snapshot.notes[index].deletedAt {
                snapshot.notes[index].archivedAt = legacy
            }
            snapshot.notes[index].deletedAt = snapshot.notes[index].trashedAt ?? snapshot.notes[index].archivedAt
        }
    }

    /// Permanently removes every note, including archived notes, and closes the editor.
    func removeAllNotes() {
        guard !restoring, loaded else { return }
        protection.lock([.notes])
        snapshot.notes.removeAll()
        selectedNoteID = nil
        surfaceGeneration = UUID()
        flushSurface = nil
        selection = []
        undoStack = []
        redoStack = []
        changed()
    }

    /// Removes the note from the library entirely. Prefer archiving for reversible removal.
    func permanentlyDelete(_ id: UUID) {
        protection.cancel(affecting: [.notes])
        guard !restoring, let i = snapshot.notes.firstIndex(where: { $0.id == id }) else { return }
        snapshot.notes.remove(at: i)
        changed()
        if id == selectedNoteID { selectedNoteID = nil; surfaceGeneration = UUID() }
    }

    @available(*, deprecated, message: "Use archive(_:) or restoreFromArchive(_:)")
    func delete(_ id: UUID, restore: Bool = false) {
        if restore { restoreFromArchive(id) } else { archive(id) }
    }
    private var index: Int? { snapshot.notes.firstIndex { $0.id == selectedNoteID && canAccessEditor($0.id) } }
    func edit(_ operation: (inout NoteDocument) -> Void, record: Bool = true) {
        guard !restoring, let i = index else { return }
        if record { protection.activity(in: .notes) }
        let before = snapshot.notes[i]
        var next = before; operation(&next)
        guard before != next else { return }
        do {
            try next.validate()
            let oldObjects = Dictionary(uniqueKeysWithValues: before.allObjects.map { ($0.id, $0) })
            for object in next.allObjects where object.kind == .ink && oldObjects[object.id] != object {
                let drawing = try PKDrawing(data: object.payload)
                guard drawing.strokes.count <= 10_000 else { throw NotesError.limit }
                if let ids = object.strokeIDs, ids.count != drawing.strokes.count { throw NotesError.invalid }
            }
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
        guard let note, note.allObjects.count < NoteDocument.objectLimit else { notice = "This note has reached its object limit."; return }
        if note.kind.usesPageBody {
            switch kind {
            case .link:
                guard let link = URL(string: url), ["http", "https"].contains(link.scheme?.lowercased() ?? ""), link.host != nil else { report(NotesError.invalid); return }
                replaceBody(bodySelection, with: url + " "); return
            case .bullets: replaceBody(bodySelection, with: "• "); return
            case .numbered: replaceBody(bodySelection, with: "1. "); return
            case .image, .table, .audio: break
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
        case .audio: object.frame.size = CGSize(width: NotePage.columnWidth, height: 72); if object.text.isEmpty { object.text = "Audio" }
        default: break
        }
        object.shape = shape; object.tint = tint
        if kind == .link { object.frame.size = CGSize(width: 320, height: 260) }
        if note.kind == .canvas {
            object.frame.origin = CGPoint(x: max(0, min(NoteDocument.extent - object.frame.width, insertionPoint.x - object.frame.width / 2)), y: max(0, min(NoteDocument.extent - object.frame.height, insertionPoint.y - object.frame.height / 2)))
        }
        edit {
            if $0.kind.usesPageBody { $0.page?.insertAttachment(object, at: bodySelection.location) }
            else { $0.objects.append(object) }
        }; selection = [object.id]
        mode = kind == .ink ? .draw : [.text, .bullets, .numbered].contains(kind) ? .text : .select
        focusRequest = UUID()
        if kind == .link { refreshLink(object.id) }
    }
    func formatBody(_ change: NoteTextFormatting.Change) {
        guard let page = note?.page else { return }
        let range = bodySelection.length > 0 ? bodySelection : NoteTextFormatting.lineRange(in: page.body, utf16: bodySelection.location)
        guard range.length > 0 else { notice = "Add some text before formatting it."; return }
        edit { note in
            guard var page = note.page else { return }
            page.formatting = NoteTextFormatting.changing(page.formatting, range: range, change: change)
            note.page = page
        }
    }

    func insertCheckbox() {
        guard let body = note?.page?.body else { return }
        let edit = NoteTextFormatting.checkboxEdit(in: body, caret: bodySelection.location)
        replaceBody(edit.0, with: edit.1)
    }

    func formatBodyList(_ kind: NoteTextFormatting.ListKind) {
        applyBodyLineEdits(collectingLineEdits { NoteTextFormatting.listEdit(in: $0, line: $1, kind: kind) })
    }

    func formatBodyIndent(outdent: Bool) {
        applyBodyLineEdits(collectingLineEdits { NoteTextFormatting.indentEdit(in: $0, line: $1, outdent: outdent) })
    }

    func formatBodyColor(_ index: Int?) {
        formatBodyInkColor(index.map { .preset($0) } ?? .default)
    }

    func formatBodyInkColor(_ spec: NoteTextFormatting.ColorSpec) {
        formatBody(.inkColor(spec))
    }

    var bodyFormatState: NoteTextFormatting.ActiveState {
        guard let page = note?.page else { return .empty }
        return NoteTextFormatting.activeState(formatting: page.formatting, body: page.body, selection: bodySelection)
    }

    /// Uniform style level for the current selection or caret (0 body … 4 monospaced).
    var bodyStyleLevel: Int {
        let level = bodyFormatState.level
        return level >= 0 ? level : 0
    }

    func formatBodyBlockQuote() {
        guard let body = note?.page?.body else { return }
        let lines = NoteTextFormatting.lineRanges(in: body, covering: bodyLineSelectionRange(in: body))
        let ranges = lines.map { NoteTextFormatting.quoteTargetRange(in: body, line: $0) }.filter { $0.length > 0 }
        guard !ranges.isEmpty else { notice = "Add some text before formatting it."; return }
        edit { note in
            guard var page = note.page else { return }
            for range in ranges {
                page.formatting = NoteTextFormatting.changing(page.formatting, range: range, change: .blockQuote)
            }
            note.page = page
        }
    }

    private func bodyLineSelectionRange(in body: String) -> NSRange {
        bodySelection.length > 0 ? bodySelection : NoteTextFormatting.lineRange(in: body, utf16: bodySelection.location)
    }

    private func collectingLineEdits(_ edit: (String, NSRange) -> (NSRange, String)?) -> [(NSRange, String)] {
        guard let body = note?.page?.body else { return [] }
        let lines = NoteTextFormatting.lineRanges(in: body, covering: bodyLineSelectionRange(in: body))
        return lines.compactMap { edit(body, $0) }
    }

    private func applyBodyLineEdits(_ edits: [(NSRange, String)]) {
        guard !edits.isEmpty else { return }
        edit { note in
            guard var page = note.page else { return }
            var body = page.body
            var spans = page.formatting
            for (range, text) in edits.sorted(by: { $0.0.location > $1.0.location }) {
                let delta = (text as NSString).length - range.length
                body = (body as NSString).replacingCharacters(in: range, with: text)
                spans = NoteTextFormatting.adjusting(spans, replacing: range, delta: delta)
            }
            page.body = body
            page.formatting = spans
            note.page = page
        }
    }

    func insertScannedText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { notice = "No text was found in that scan."; return }
        replaceBody(bodySelection, with: String(trimmed.prefix(20_000)) + "\n")
    }

    func insertAudio(_ data: Data, name: String = "Audio") {
        guard !data.isEmpty, data.count <= 16 * 1024 * 1024 else { notice = "That audio could not be added or exceeds 16 MiB."; return }
        guard let note, note.kind.usesPageBody, note.allObjects.count < NoteDocument.objectLimit else { notice = "This note has reached its object limit."; return }
        var object = NoteObject(kind: .audio, payload: data)
        object.text = String(name.prefix(60))
        object.frame.size = CGSize(width: NotePage.columnWidth, height: 72)
        edit { $0.page?.insertAttachment(object, at: bodySelection.location) }
        selection = [object.id]
        focusRequest = UUID()
    }

    func insertImage(_ data: Data) {
        guard let target = selectedNoteID else { return }
        guard imageTasks.count < 4 else { notice = "Please wait for the current images to finish importing."; return }
        let generation = surfaceGeneration
        let request = UUID()
        imageTasks[request] = Task { [weak self] in
            let prepared = await NoteImagePreparation.prepare(data)
            guard let self else { return }
            defer { self.imageTasks[request] = nil }
            guard !Task.isCancelled, self.selectedNoteID == target,
                  self.surfaceGeneration == generation, self.note?.isActiveInLibrary == true else { return }
            guard let prepared else { self.notice = "That image could not be opened or exceeds 32 MiB."; return }
            let existing = Set(self.note?.allObjects.map(\.id) ?? [])
            self.insert(.image, payload: prepared.data)
            if let id = self.selection.first, !existing.contains(id) {
                self.update(id) { $0.frame.size = CGSize(width: 320, height: max(40, 320 * prepared.size.height / prepared.size.width)) }
            }
        }
    }
    func copySelection() {
        guard let note else { return }
        if !strokeSelection.isEmpty, let scene = try? NoteCanvasInk(objects: note.objects) {
            canvasClipboard = scene.copying(strokeSelection); clipboardProtectionID = note.protectionID; return
        }
        let ids = note.members(selection)
        canvasClipboard = note.objects.filter { ids.contains($0.id) }; clipboardProtectionID = note.protectionID
    }

    func pasteCanvasClipboard() {
        guard let note, note.kind == .canvas, !canvasClipboard.isEmpty, !protection.isLocked(clipboardProtectionID, in: .notes) else { return }
        var copies = canvasClipboard
        let groups = Dictionary(uniqueKeysWithValues: Set(copies.compactMap(\.group)).map { ($0, UUID()) })
        for index in copies.indices {
            copies[index].id = UUID()
            copies[index].group = copies[index].group.flatMap { groups[$0] }
            copies[index].positionLocked = false
            if let ids = copies[index].strokeIDs { copies[index].strokeIDs = ids.map { _ in UUID() } }
            copies[index].frame.origin.x = min(NoteDocument.extent - copies[index].frame.width, copies[index].frame.minX + 32)
            copies[index].frame.origin.y = min(NoteDocument.extent - copies[index].frame.height, copies[index].frame.minY + 32)
        }
        edit { $0.objects += copies }
        let ids = Set(copies.map(\.id))
        if ids.isSubset(of: Set(self.note?.objects.map(\.id) ?? [])) { selection = ids; strokeSelection = []; focusRequest = UUID() }
    }

    func cutSelection() {
        copySelection()
        remove()
    }

    func togglePositionLock() {
        edit { note in
            for index in note.objects.indices where selection.contains(note.objects[index].id) {
                note.objects[index].positionLocked.toggle()
            }
        }
    }

    func reorderSelection(front: Bool) {
        edit { note in
            let ids = note.members(selection)
            let moving = note.objects.filter { ids.contains($0.id) }
            guard !moving.isEmpty else { return }
            note.objects.removeAll { ids.contains($0.id) }
            if front { note.objects.append(contentsOf: moving) } else { note.objects.insert(contentsOf: moving, at: 0) }
        }
    }

    func duplicateSelection() {
        guard let note else { return }
        if !strokeSelection.isEmpty {
            guard let scene = try? NoteCanvasInk(objects: note.objects) else { return }
            var copies = scene.copying(strokeSelection)
            for index in copies.indices {
                copies[index].frame.origin.x = min(NoteDocument.extent - copies[index].frame.width, copies[index].frame.minX + 32)
                copies[index].frame.origin.y = min(NoteDocument.extent - copies[index].frame.height, copies[index].frame.minY + 32)
            }
            edit { $0.objects += copies }
            if Set(copies.map(\.id)).isSubset(of: Set(self.note?.objects.map(\.id) ?? [])) {
                selection = Set(copies.map(\.id)); strokeSelection = []
            }
            return
        }
        let ids = note.members(selection)
        var copies = note.objects.filter { ids.contains($0.id) }
        let groupMap = Dictionary(uniqueKeysWithValues: Set(copies.compactMap(\.group)).map { ($0, UUID()) })
        for i in copies.indices {
            copies[i].id = UUID()
            if let ids = copies[i].strokeIDs { copies[i].strokeIDs = ids.map { _ in UUID() } }
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
    func move(_ delta: CGSize) {
        if !strokeSelection.isEmpty { editSelectedStrokes(.move(delta)) }
        else { edit { $0.move(selection, by: delta) } }
    }
    func colorSelectedStrokes(_ color: UIColor) { editSelectedStrokes(.color(color)) }
    private func editSelectedStrokes(_ operation: NoteCanvasInk.StrokeEdit) {
        guard let note, !strokeSelection.isEmpty else { return }
        do {
            let scene = try NoteCanvasInk(objects: note.objects)
            var change = operation
            if case .move(let delta) = operation {
                let bounds = scene.strokeIndex.bounds(of: strokeSelection)
                guard !bounds.isNull else { return }
                change = .move(CGSize(width: max(-bounds.minX, min(NoteDocument.extent - bounds.maxX, delta.width)),
                                      height: max(-bounds.minY, min(NoteDocument.extent - bounds.maxY, delta.height))))
            }
            let edited = scene.editing(strokeSelection, in: note.objects, operation: change)
            edit { $0.objects = edited }
            if case .delete = operation { strokeSelection = [] }
        } catch { report(error) }
    }
    func group() { edit { $0.group(selection) } }
    func ungroup() { edit { $0.ungroup(selection) } }
    func remove() {
        if !strokeSelection.isEmpty { editSelectedStrokes(.delete); return }
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
        selection = []; strokeSelection = []; surfaceGeneration = UUID()
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
    @discardableResult private func createCompanionNote(kind: NoteKind, text: String, anchor: CompanionPassageAnchor?) -> UUID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let anchor, let quote = companionQuote(text: trimmed, anchor: anchor) {
            return create(kind: kind, quote: quote)
        }
        guard let id = create(kind: kind) else { return nil }
        appendCompanionPlainText(trimmed, kind: kind)
        return id
    }

    func appendCompanionResponse(text: String, anchor: CompanionPassageAnchor?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let anchor, let quote = companionQuote(text: trimmed, anchor: anchor) {
            appendQuote(quote)
            return
        }
        appendCompanionPlainText(trimmed, kind: note?.kind ?? .page)
    }

    private func companionQuote(text: String, anchor: CompanionPassageAnchor) -> NoteQuote? {
        var end = VerseID(book: anchor.bookID, chapter: anchor.chapter, verse: anchor.endVerse)
        let start = VerseID(book: anchor.bookID, chapter: anchor.chapter, verse: anchor.startVerse)
        if anchor.endVerse < anchor.startVerse { end = start }
        let quote = NoteQuote(
            verse: start,
            editionID: anchor.editionID,
            contentRevision: "companion",
            attribution: "Companion",
            source: String(text.prefix(20_000)),
            endVerse: end == start ? nil : end
        )
        do { try quote.validate() } catch { return nil }
        return quote
    }

    private func appendCompanionPlainText(_ text: String, kind: NoteKind) {
        flushSurface?()
        edit { note in
            if kind.usesPageBody {
                guard var page = note.page else { return }
                let prefix = page.body.isEmpty ? "" : "\n\n"
                page.replace(NSRange(location: page.body.utf16.count, length: 0), with: prefix + text + "\n")
                note.page = page
            } else {
                var object = NoteObject(kind: .text)
                object.text = text
                object.frame = CGRect(x: 60, y: min(NoteDocument.extent - 600, (note.objects.last?.frame.maxY ?? 60) + 40), width: 480, height: 280)
                note.objects.append(object)
            }
        }
        focusRequest = UUID()
    }

    func appendQuote(_ quote: NoteQuote) {
        guard selectedNoteID != nil else { _ = create(quote: quote); return }
        flushSurface?()
        edit { note in
            if note.kind.usesPageBody {
                // Scripture saves are append-only. A reopened Page has no active body caret,
                // so retaining its previous selection would otherwise insert at the beginning.
                guard var page = note.page else { return }
                page.insert(quote, at: page.body.utf16.count)
                note.page = page
            }
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
        try await protection.authorize([.notes: snapshot.notes.map(\.protectionID)])
        try protection.require(snapshot.notes.map(\.protectionID), in: .notes)
        flushSurface?(); await save()
        guard !dirty, !saving else { throw NotesError.stale }
        let data = try await repository.exportArchive()
        try protection.require(snapshot.notes.map(\.protectionID), in: .notes)
        return data
    }
    func preRestore() async throws -> Data {
        try await protection.authorize([.notes: snapshot.notes.map(\.protectionID)])
        try protection.require(snapshot.notes.map(\.protectionID), in: .notes)
        let data = try await repository.preRestoreArchive()
        let backup = try NotesFileRepository.inspectArchive(data)
        try await protection.authorize([.notes: backup.notes.map(\.protectionID)])
        try protection.require(backup.notes.map(\.protectionID), in: .notes)
        return data
    }
    func restore(_ data: Data) async {
        guard !restoring else { return }
        do { try await protection.authorize([.notes: snapshot.notes.map(\.protectionID)]) } catch { report(error); return }
        flushSurface?(); await save()
        guard !saving, !dirty else { notice = "Save current edits before restoring."; return }
        restoring = true
        defer { restoring = false }
        do {
            try protection.require(snapshot.notes.map(\.protectionID), in: .notes)
            let next = try await repository.restore(data, expectedRevision: snapshot.revision)
            protection.lock([.notes])
            surfaceGeneration = UUID(); flushSurface = nil; snapshot = next; loaded = true
            selectedNoteID = nil; selection = []; undoStack = []; redoStack = []; notice = "Notes backup restored. The pre-restore copy is available in Backups."
        } catch { report(error) }
    }

    static func prayerDayKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    @discardableResult
    func recordPrayerTap() -> Bool {
        guard !restoring else { return false }
        var recorded = false
        edit { note in
            guard case .prayer(var content) = note.content else { return }
            let today = Self.prayerDayKey()
            guard content.lastPrayedDay != today else { return }
            content.lastPrayedDay = today
            content.prayerCount += 1
            note.content = .prayer(content)
            recorded = true
        }
        return recorded
    }

    func canRecordPrayerTapToday() -> Bool {
        guard let content = note?.prayerContent else { return false }
        return content.lastPrayedDay != Self.prayerDayKey()
    }

    func setPrayerStatus(_ status: PrayerStatus) {
        edit { note in
            guard case .prayer(var content) = note.content else { return }
            content.status = status
            note.content = .prayer(content)
        }
    }

    func setJournalScriptureVisible(_ visible: Bool) {
        edit({ note in
            guard case .journal(var content) = note.content else { return }
            content.scriptureVisible = visible
            note.content = .journal(content)
        }, record: false)
    }

    func setJournalEmotionalState(_ state: JournalEmotionalState?) {
        protection.activity(in: .notes)
        edit({ note in
            guard case .journal(var content) = note.content else { return }
            content.emotionalState = state
            note.content = .journal(content)
        }, record: false)
    }

    func setJournalMentalState(_ state: JournalMentalState?) {
        protection.activity(in: .notes)
        edit({ note in
            guard case .journal(var content) = note.content else { return }
            content.mentalState = state
            note.content = .journal(content)
        }, record: false)
    }

    func addPrayerUpdate(_ body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard (note?.prayerContent?.updates.count ?? 0) < 200 else { notice = "This prayer has reached its update limit."; return }
        edit { note in
            guard case .prayer(var content) = note.content else { return }
            content.updates.insert(PrayerUpdate(body: String(trimmed.prefix(20_000))), at: 0)
            note.content = .prayer(content)
        }
    }

    func updatePrayerUpdate(id: UUID, body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        edit { note in
            guard case .prayer(var content) = note.content else { return }
            guard let index = content.updates.firstIndex(where: { $0.id == id }) else { return }
            content.updates[index].body = String(trimmed.prefix(20_000))
            content.updates[index].updatedAt = Date()
            note.content = .prayer(content)
        }
    }

    func deletePrayerUpdate(id: UUID) {
        edit { note in
            guard case .prayer(var content) = note.content else { return }
            content.updates.removeAll { $0.id == id }
            note.content = .prayer(content)
        }
    }

    func clearPrayerContent() {
        edit { note in
            guard case .prayer(var content) = note.content else { return }
            content.page = NotePage()
            note.content = .prayer(content)
        }
    }

    func archiveCurrentNote() {
        guard let id = note?.id else { return }
        archive(id)
    }

    func moveCurrentNoteToTrash() {
        guard let id = note?.id else { return }
        moveToTrash(id)
    }

    func permanentlyDeleteCurrentNote() {
        guard let id = note?.id else { return }
        permanentlyDelete(id)
    }

    @discardableResult
    func applySophyReplacement(noteID: UUID, range: NSRange, digest: String, replacement: String, canvasObjectID: UUID?) -> Bool {
        guard selectedNoteID == noteID, canAccessEditor(noteID), let current = note else { return false }
        let before = current
        if let canvasObjectID {
            guard let object = current.objects.first(where: { $0.id == canvasObjectID && [.text, .bullets, .numbered].contains($0.kind) }),
                  let slice = Self.utf16Slice(object.text, range),
                  SophyContextBuilder.digest(slice) == digest else { return false }
            edit { note in
                guard let index = note.objects.firstIndex(where: { $0.id == canvasObjectID }) else { return }
                note.objects[index].text = (object.text as NSString).replacingCharacters(in: range, with: replacement)
            }
            return note != before
        }
        guard let page = current.page,
              let slice = Self.utf16Slice(page.body, range),
              SophyContextBuilder.digest(slice) == digest else { return false }
        replaceBody(range, with: replacement)
        return note != before
    }

    static func utf16Slice(_ body: String, _ range: NSRange) -> String? {
        let units = Array(body.utf16)
        guard range.location != NSNotFound, range.location >= 0, range.length >= 0,
              range.location <= units.count, range.length <= units.count - range.location else { return nil }
        let end = range.location + range.length
        // Swift String slicing can widen a UTF-16 index inside a grapheme. Never let a
        // selection start/end inside a surrogate pair and use the exact native range.
        for boundary in [range.location, end] where boundary < units.count {
            if (0xDC00...0xDFFF).contains(units[boundary]) { return nil }
        }
        return (body as NSString).substring(with: range)
    }

    func sophySelection(range: NSRange, objectID: UUID? = nil) -> SophyNoteSelection? {
        flushSurface?()
        guard let current = note, canAccessEditor(current.id), range.length > 0 else { return nil }
        let body = objectID.flatMap { id in current.objects.first { $0.id == id && [.text, .bullets, .numbered].contains($0.kind) }?.text } ?? (objectID == nil ? current.page?.body : nil)
        guard let body, let text = Self.utf16Slice(body, range), !text.isEmpty else { return nil }
        let protectedFolder = collections?.collectionIDs(containing: current.id).contains {
            collections?.sophyFolderIsProtected($0) != false
        } ?? false
        return SophyNoteSelection(noteID: current.id, objectID: objectID, range: range, text: text,
            digest: SophyContextBuilder.digest(text), revision: current.updatedAt,
            editorRoute: openingCollectionID, requiresConsent: current.protectionID != nil || protectedFolder)
    }

    func sophySelectionIsCurrent(_ selection: SophyNoteSelection) -> Bool {
        guard selectedNoteID == selection.noteID, openingCollectionID == selection.editorRoute,
              canAccessEditor(selection.noteID), note?.updatedAt == selection.revision,
              let fresh = sophySelection(range: selection.range, objectID: selection.objectID) else { return false }
        return fresh == selection
    }
}
