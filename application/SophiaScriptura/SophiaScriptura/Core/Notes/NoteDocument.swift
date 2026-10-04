import Foundation
import CoreGraphics

struct NoteObject: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable { case text, ink, image, quote, link, table, shape, bullets, numbered, sticker }
    var id = UUID()
    var kind: Kind
    var frame = CGRect(x: 60, y: 60, width: 320, height: 180)
    var group: UUID?
    var text = ""
    var url = ""
    var cells: [[String]] = []
    var payload = Data()
    var shape: NoteShape? = nil
    var tint: NoteTint? = nil
    var inkSize: CGSize? = nil
    var quote: NoteQuote?
    var fontSize: Double = 22
    var label: String { text.isEmpty ? kind.rawValue.capitalized : String(text.prefix(60)) }
}

struct NoteQuote: Codable, Equatable, Sendable {
    let verse: VerseID
    let editionID: String
    let contentRevision: String
    let attribution: String
    let source: String
    var endVerse: VerseID? = nil
    var reference: String {
        let first = "\(verse.book) \(verse.chapter):\(verse.verse)"
        guard let endVerse, endVerse != verse else { return first }
        return first + (endVerse.chapter == verse.chapter ? "–\(endVerse.verse)" : "–\(endVerse.chapter):\(endVerse.verse)")
    }
    var editionLabel: String { LicensedTranslation.approved.first { $0.editionID == editionID }?.abbreviation ?? (editionID == "web.engwebp" ? "WEB" : editionID) }
    func validate() throws {
        guard !source.isEmpty, source.count <= 20_000, !contentRevision.isEmpty,
              !editionID.isEmpty, editionID.count <= 200, attribution.count <= 20_000,
              !verse.referenceSystemID.isEmpty, verse.book.count == 3,
              (1...150).contains(verse.chapter), (1...200).contains(verse.verse) else { throw NotesError.invalid }
        if let endVerse {
            guard endVerse.referenceSystemID == verse.referenceSystemID, endVerse.book == verse.book,
                  (verse.chapter...150).contains(endVerse.chapter), (1...200).contains(endVerse.verse),
                  endVerse.chapter != verse.chapter || endVerse.verse >= verse.verse else { throw NotesError.invalid }
        }
    }
}

/// UTF-16 citation range follows edits to the body; ink always uses page coordinates.
struct NoteCitation: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var location: Int
    var length: Int
    var quote: NoteQuote
}
struct NoteInlineAttachment: Codable, Equatable, Identifiable, Sendable {
    var id: UUID { object.id }
    var location: Int
    var object: NoteObject
}

struct NotePage: Codable, Equatable, Sendable {
    static let width: CGFloat = 1200
    static let columnWidth: CGFloat = 680
    var body = ""
    var attachments: [NoteInlineAttachment] = []
    var citations: [NoteCitation] = []
    var ink = Data()
    var height: CGFloat = 1600
    // Older objects may occupy a wider page. Preserve their original positions.
    var width: CGFloat = Self.width
    private enum CodingKeys: String, CodingKey { case body, citations, ink, height, width, attachments }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        body = try c.decode(String.self, forKey: .body)
        citations = try c.decode([NoteCitation].self, forKey: .citations)
        ink = try c.decode(Data.self, forKey: .ink)
        height = try c.decode(CGFloat.self, forKey: .height)
        width = try c.decodeIfPresent(CGFloat.self, forKey: .width) ?? Self.width
        attachments = try c.decodeIfPresent([NoteInlineAttachment].self, forKey: .attachments) ?? []
    }
    mutating func insertAttachment(_ object: NoteObject, at offset: Int) {
        let point = min(max(0, offset), body.utf16.count)
        replace(NSRange(location: point, length: 0), with: "\u{FFFC}\n")
        attachments.append(NoteInlineAttachment(location: point, object: object))
    }
    mutating func replace(_ range: NSRange, with text: String) {
        guard range.location >= 0, range.length >= 0, range.location <= body.utf16.count,
              range.length <= body.utf16.count - range.location else { return }
        let delta = text.utf16.count - range.length
        attachments = attachments.compactMap { attachment in
            var item = attachment
            if range.location + range.length <= item.location { item.location += delta; return item }
            if range.location > item.location { return item }
            return nil
        }
        citations = citations.compactMap { citation in
            var item = citation
            if range.location + range.length <= item.location { item.location += delta; return item }
            if range.location >= item.location + item.length { return item }
            return nil // Editing a citation removes the link rather than pointing at unrelated text.
        }
        body = (body as NSString).replacingCharacters(in: range, with: text)
    }
    mutating func insert(_ quote: NoteQuote, at offset: Int) {
        let point = min(max(0, offset), body.utf16.count)
        let prefix = point == 0 ? "" : "\n\n"
        let label = quote.reference + " · " + quote.editionLabel
        let text = prefix + quote.source + "\n" + label + (quote.attribution.isEmpty ? "" : "\n" + quote.attribution) + "\n\n"
        replace(NSRange(location: point, length: 0), with: text)
        citations.append(NoteCitation(location: point + prefix.utf16.count + quote.source.utf16.count + 1, length: label.utf16.count, quote: quote))
    }
}

enum NoteKind: String, Codable, CaseIterable, Sendable { case canvas, page, prayer, journal }

extension NoteKind {
    var displayName: String {
        switch self {
        case .canvas: "Canvas"
        case .page: "Page"
        case .prayer: "Prayer"
        case .journal: "Journal"
        }
    }

    var usesPageBody: Bool { self == .page || self == .journal || self == .prayer }
}

enum PrayerStatus: String, Codable, CaseIterable, Sendable {
    case waiting, answered, redirected

    var label: String {
        switch self {
        case .waiting: "Praying & waiting"
        case .answered: "Prayer answered"
        case .redirected: "Prayer redirected"
        }
    }
}

struct PrayerUpdate: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var body = ""
    var createdAt = Date()
    var updatedAt = Date()
}

struct PrayerContent: Codable, Equatable, Sendable {
    var page = NotePage()
    var status = PrayerStatus.waiting
    var prayerCount = 0
    /// Calendar day (`yyyy-MM-dd`) of the last counted prayer tap.
    var lastPrayedDay: String?
    var updates: [PrayerUpdate] = []
}

struct CanvasContent: Codable, Equatable, Sendable { var objects: [NoteObject] = [] }
struct PageContent: Codable, Equatable, Sendable {
    var page = NotePage()
    // Existing v2 floating items are retained at their exact positions; new items flow inline.
    var legacyObjects: [NoteObject] = []
}
struct JournalContent: Codable, Equatable, Sendable {
    var page = NotePage()
    var legacyObjects: [NoteObject] = []
    var scriptureVisible = true
}
enum NoteContent: Equatable, Sendable, Codable {
    case canvas(CanvasContent)
    case page(PageContent)
    case prayer(PrayerContent)
    case journal(JournalContent)
    private enum CodingKeys: String, CodingKey { case kind, canvas, page, prayer, journal }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let kind = NoteKind(rawValue: try c.decode(String.self, forKey: .kind)) else { throw NotesError.unsupported }
        switch kind {
        case .canvas:
            guard !c.contains(.page), !c.contains(.prayer), !c.contains(.journal) else { throw NotesError.invalid }
            self = .canvas(try c.decode(CanvasContent.self, forKey: .canvas))
        case .page:
            guard !c.contains(.canvas), !c.contains(.prayer), !c.contains(.journal) else { throw NotesError.invalid }
            self = .page(try c.decode(PageContent.self, forKey: .page))
        case .prayer:
            guard !c.contains(.canvas), !c.contains(.page), !c.contains(.journal) else { throw NotesError.invalid }
            self = .prayer(try c.decode(PrayerContent.self, forKey: .prayer))
        case .journal:
            guard !c.contains(.canvas), !c.contains(.page), !c.contains(.prayer) else { throw NotesError.invalid }
            self = .journal(try c.decode(JournalContent.self, forKey: .journal))
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .canvas(let value): try c.encode(NoteKind.canvas, forKey: .kind); try c.encode(value, forKey: .canvas)
        case .page(let value): try c.encode(NoteKind.page, forKey: .kind); try c.encode(value, forKey: .page)
        case .prayer(let value): try c.encode(NoteKind.prayer, forKey: .kind); try c.encode(value, forKey: .prayer)
        case .journal(let value): try c.encode(NoteKind.journal, forKey: .kind); try c.encode(value, forKey: .journal)
        }
    }
}

struct NoteDocument: Codable, Equatable, Identifiable, Sendable {
    enum Paper: String, Codable, CaseIterable, Sendable { case plain, ruled, grid, dotted }
    enum Color: String, Codable, CaseIterable, Sendable {
        case neutral, rose, amber, sage, blue, lavender

        var title: String { rawValue.capitalized }
    }
    static let extent: CGFloat = 12_000
    var id = UUID()
    var title = "Untitled Note"
    var tags: [String] = []
    var createdAt = Date()
    var updatedAt = Date()
    var deletedAt: Date?
    var paper = Paper.plain
    var color = Color.neutral
    var content = NoteContent.canvas(CanvasContent())
    var kind: NoteKind {
        switch content {
        case .page: .page
        case .canvas: .canvas
        case .prayer: .prayer
        case .journal: .journal
        }
    }
    var objects: [NoteObject] {
        get {
            switch content {
            case .canvas(let c): c.objects
            case .page(let p): p.legacyObjects
            case .journal(let j): j.legacyObjects
            case .prayer: []
            }
        }
        set {
            switch content {
            case .canvas: content = .canvas(CanvasContent(objects: newValue))
            case .page(var p): p.legacyObjects = newValue; content = .page(p)
            case .journal(var j): j.legacyObjects = newValue; content = .journal(j)
            case .prayer: break
            }
        }
    }
    var page: NotePage? {
        get {
            switch content {
            case .page(let p): p.page
            case .prayer(let p): p.page
            case .journal(let j): j.page
            case .canvas: nil
            }
        }
        set {
            guard let newValue else { return }
            switch content {
            case .page: content = .page(PageContent(page: newValue, legacyObjects: objects))
            case .prayer(var p): p.page = newValue; content = .prayer(p)
            case .journal(var j): j.page = newValue; content = .journal(j)
            case .canvas: break // Undo within Canvas must never change its type.
            }
        }
    }
    var prayerContent: PrayerContent? { if case .prayer(let value) = content { return value }; return nil }
    var journalScriptureVisible: Bool {
        if case .journal(let value) = content { return value.scriptureVisible }
        return false
    }
    var allObjects: [NoteObject] { objects + (page?.attachments.map(\.object) ?? []) }
    init(kind: NoteKind = .canvas, objects: [NoteObject] = [], page: NotePage? = nil) {
        switch kind {
        case .canvas: content = .canvas(CanvasContent(objects: objects))
        case .page: content = .page(PageContent(page: page ?? NotePage(), legacyObjects: objects))
        case .prayer: content = .prayer(PrayerContent(page: page ?? NotePage()))
        case .journal: content = .journal(JournalContent(page: page ?? NotePage(), legacyObjects: objects))
        }
    }
    private enum CodingKeys: String, CodingKey { case id, title, tags, createdAt, updatedAt, deletedAt, paper, color, content, objects, page }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); title = try c.decode(String.self, forKey: .title)
        tags = try c.decode([String].self, forKey: .tags); createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt); deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        paper = try c.decode(Paper.self, forKey: .paper)
        color = try c.decodeIfPresent(Color.self, forKey: .color) ?? .neutral
        if c.contains(.content) {
            guard !c.contains(.objects), !c.contains(.page) else { throw NotesError.invalid }
            content = try c.decode(NoteContent.self, forKey: .content)
        } else {
            let objects = try c.decode([NoteObject].self, forKey: .objects)
            if let page = try c.decodeIfPresent(NotePage.self, forKey: .page) { content = .page(PageContent(page: page, legacyObjects: objects)) }
            else { content = .canvas(CanvasContent(objects: objects)) }
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(title, forKey: .title); try c.encode(tags, forKey: .tags)
        try c.encode(createdAt, forKey: .createdAt); try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(deletedAt, forKey: .deletedAt); try c.encode(paper, forKey: .paper)
        try c.encode(color, forKey: .color)
        try c.encode(content, forKey: .content)
    }
    var contentSize: CGSize {
        if let page { return CGSize(width: page.width, height: page.height) }
        return CGSize(width: min(Self.extent, max(1200, (objects.map(\.frame.maxX).max() ?? 0) + 240)),
               height: min(Self.extent, max(1400, (objects.map(\.frame.maxY).max() ?? 0) + 240)))
    }
    var searchableText: String {
        let prayerText = prayerContent.map { $0.updates.map(\.body).joined(separator: " ") + " " + $0.status.label } ?? ""
        return ([title, page?.body ?? "", prayerText] + tags + allObjects.flatMap { [$0.text, $0.url, $0.quote?.reference ?? "", $0.quote?.source ?? ""] + $0.cells.flatMap { $0 } }).joined(separator: " ")
    }
    func members(_ selected: Set<UUID>) -> Set<UUID> {
        let groups = Set(objects.filter { (kind == .canvas || $0.kind != .ink) && selected.contains($0.id) }.compactMap(\.group))
        return Set(objects.filter { (kind == .canvas || $0.kind != .ink) && (selected.contains($0.id) || $0.group.map(groups.contains) == true) }.map(\.id))
    }
    mutating func move(_ selection: Set<UUID>, by delta: CGSize) {
        guard delta.width.isFinite, delta.height.isFinite else { return }
        let ids = members(selection), frames = objects.filter { ids.contains($0.id) }.map(\.frame)
        guard let first = frames.first else { return }
        let bounds = frames.dropFirst().reduce(first) { $0.union($1) }
        let dx = min(max(delta.width, -bounds.minX), (page?.width ?? Self.extent) - bounds.maxX)
        let dy = min(max(delta.height, -bounds.minY), Self.extent - bounds.maxY)
        for i in objects.indices where ids.contains(objects[i].id) { objects[i].frame = objects[i].frame.offsetBy(dx: dx, dy: dy) }
    }
    mutating func group(_ selection: Set<UUID>) {
        let ids = members(selection)
        guard ids.count > 1 else { return }
        let group = UUID()
        for i in objects.indices where ids.contains(objects[i].id) { objects[i].group = group }
    }
    mutating func ungroup(_ selection: Set<UUID>) {
        let ids = members(selection)
        for i in objects.indices where ids.contains(objects[i].id) { objects[i].group = nil }
    }
    mutating func remove(_ selection: Set<UUID>) {
        let ids = members(selection)
        objects.removeAll { ids.contains($0.id) }
        for i in objects.indices {
            if let group = objects[i].group, objects.filter({ $0.group == group }).count < 2 { objects[i].group = nil }
        }
    }
    func validate() throws {
        if case .prayer(let prayer) = content {
            try validate(page: prayer.page, allowLegacyInkObjects: false)
            guard prayer.prayerCount >= 0, prayer.updates.count <= 200,
                  Set(prayer.updates.map(\.id)).count == prayer.updates.count else { throw NotesError.invalid }
            for update in prayer.updates {
                guard !update.body.isEmpty, update.body.count <= 20_000 else { throw NotesError.invalid }
            }
        } else if let page {
            try validate(page: page, allowLegacyInkObjects: kind != .prayer)
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 200,
              tags.count <= 30, tags.allSatisfy({ !$0.isEmpty && $0.count <= 60 }),
              allObjects.count <= 200, Set(allObjects.map(\.id)).count == allObjects.count else { throw NotesError.invalid }
        for object in allObjects {
            let f = object.frame
            guard [f.minX, f.minY, f.width, f.height].allSatisfy(\.isFinite),
                  f.minX >= 0, f.minY >= 0, f.width >= 40, f.height >= 40,
                  f.maxX <= Self.extent, f.maxY <= Self.extent,
                  object.text.count <= 20_000, object.url.count <= 4096,
                  object.fontSize.isFinite, (12...72).contains(object.fontSize),
                  object.payload.count <= 16 * 1024 * 1024,
                  object.cells.count <= 20, object.cells.allSatisfy({ $0.count <= 10 && $0.allSatisfy { $0.count <= 2000 } }) else { throw NotesError.invalid }
            if let size = object.inkSize {
                guard object.kind == .ink, size.width.isFinite, size.height.isFinite,
                      size.width >= 40, size.height >= 40, size.width <= Self.extent, size.height <= Self.extent else { throw NotesError.invalid }
            }
            if object.kind == .link {
                guard let url = URL(string: object.url), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw NotesError.invalid }
            }
            if object.kind == .quote {
                guard let quote = object.quote else { throw NotesError.invalid }
                try quote.validate()
            } else if object.quote != nil {
                throw NotesError.invalid
            }
        }
        for group in Set(objects.compactMap(\.group)) {
            guard objects.filter({ $0.group == group }).count >= 2 else { throw NotesError.invalid }
        }
    }

    private func validate(page: NotePage, allowLegacyInkObjects: Bool) throws {
        guard page.width.isFinite, page.height.isFinite, (1200...Self.extent).contains(page.width),
              (800...Self.extent).contains(page.height), page.body.count <= 100_000,
              page.ink.count <= 16 * 1024 * 1024, page.citations.count <= 500,
              Set(page.citations.map(\.id)).count == page.citations.count else { throw NotesError.limit }
        guard allowLegacyInkObjects ? !objects.contains(where: { $0.kind == .ink }) : objects.isEmpty,
              page.attachments.count <= 200,
              Set(page.attachments.map(\.location)).count == page.attachments.count else { throw NotesError.invalid }
        for attachment in page.attachments {
            guard [.image, .table].contains(attachment.object.kind), attachment.object.group == nil,
                  attachment.location >= 0, attachment.location < page.body.utf16.count,
                  (page.body as NSString).substring(with: NSRange(location: attachment.location, length: 1)) == "\u{FFFC}" else { throw NotesError.invalid }
        }
        for citation in page.citations {
            guard citation.location >= 0, citation.length > 0, citation.location <= page.body.utf16.count,
                  citation.length <= page.body.utf16.count - citation.location else { throw NotesError.invalid }
            try citation.quote.validate()
        }
    }
}

struct NotesSnapshot: Codable, Equatable, Sendable {
    var schemaVersion = 3
    var revision = 0
    var notes: [NoteDocument] = []
    func validate() throws {
        guard (1...3).contains(schemaVersion) else { throw NotesError.unsupported }
        guard revision >= 0, notes.count <= 200, Set(notes.map(\.id)).count == notes.count else { throw NotesError.invalid }
        for note in notes { try note.validate() }
    }
}

struct NotesLoad: Sendable { var snapshot: NotesSnapshot; var recovered: Bool }
protocol NotesRepository: Sendable {
    func load() async throws -> NotesLoad
    func save(_ snapshot: NotesSnapshot, expectedRevision: Int) async throws -> NotesSnapshot
    func exportArchive() async throws -> Data
    func restore(_ data: Data, expectedRevision: Int) async throws -> NotesSnapshot
    func preRestoreArchive() async throws -> Data
}

enum NotesError: LocalizedError {
    case invalid, unsupported, damaged, stale, limit
    var errorDescription: String? {
        switch self {
        case .invalid: "The note contains invalid or unsupported content. Existing saved data is unchanged."
        case .unsupported: "This Notes format needs a newer app. Your files have been preserved."
        case .damaged: "Notes could not be recovered. Original files are preserved; restore a Notes backup."
        case .stale: "Notes changed during saving. Reopen before editing further."
        case .limit: "This exceeds the current Notes size limit. Reduce the image or document size."
        }
    }
}
