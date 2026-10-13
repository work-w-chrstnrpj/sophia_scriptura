import Foundation
import CoreGraphics

struct NoteObject: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable { case text, ink, image, quote, link, table, shape, bullets, numbered, sticker, audio }
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
    /// IDs parallel PKDrawing.strokes; absent in legacy archives.
    var strokeIDs: [UUID]? = nil
    var inkSize: CGSize? = nil
    var quote: NoteQuote?
    var fontSize: Double = 22
    var monospaced = false
    var positionLocked = false
    var details = ""
    var label: String { text.isEmpty ? kind.rawValue.capitalized : String(text.prefix(60)) }
}

extension NoteObject {
    private enum CodingKeys: String, CodingKey {
        case id, kind, frame, group, text, url, cells, payload, shape, tint, inkSize, quote, fontSize
        case monospaced, positionLocked, details, strokeIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        frame = try container.decode(CGRect.self, forKey: .frame)
        group = try container.decodeIfPresent(UUID.self, forKey: .group)
        text = try container.decode(String.self, forKey: .text)
        url = try container.decode(String.self, forKey: .url)
        cells = try container.decode([[String]].self, forKey: .cells)
        payload = try container.decode(Data.self, forKey: .payload)
        shape = try container.decodeIfPresent(NoteShape.self, forKey: .shape)
        tint = try container.decodeIfPresent(NoteTint.self, forKey: .tint)
        strokeIDs = try container.decodeIfPresent([UUID].self, forKey: .strokeIDs)
        inkSize = try container.decodeIfPresent(CGSize.self, forKey: .inkSize)
        quote = try container.decodeIfPresent(NoteQuote.self, forKey: .quote)
        fontSize = try container.decode(Double.self, forKey: .fontSize)
        monospaced = try container.decodeIfPresent(Bool.self, forKey: .monospaced) ?? false
        positionLocked = try container.decodeIfPresent(Bool.self, forKey: .positionLocked) ?? false
        details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
    }
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
    /// Omitted from archives while empty so existing Page JSON stays unchanged.
    var formatting: [NoteTextSpan] = []
    private enum CodingKeys: String, CodingKey { case body, citations, ink, height, width, attachments, formatting }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        body = try c.decode(String.self, forKey: .body)
        citations = try c.decode([NoteCitation].self, forKey: .citations)
        ink = try c.decode(Data.self, forKey: .ink)
        height = try c.decode(CGFloat.self, forKey: .height)
        width = try c.decodeIfPresent(CGFloat.self, forKey: .width) ?? Self.width
        attachments = try c.decodeIfPresent([NoteInlineAttachment].self, forKey: .attachments) ?? []
        formatting = try c.decodeIfPresent([NoteTextSpan].self, forKey: .formatting) ?? []
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(body, forKey: .body)
        try container.encode(citations, forKey: .citations)
        try container.encode(ink, forKey: .ink)
        try container.encode(height, forKey: .height)
        try container.encode(width, forKey: .width)
        try container.encode(attachments, forKey: .attachments)
        if !formatting.isEmpty { try container.encode(formatting, forKey: .formatting) }
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
        formatting = NoteTextFormatting.adjusting(formatting, replacing: range, delta: delta)
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
enum PageStatus: String, Codable, CaseIterable, Sendable {
    case unset, drafting, revising, editing, publishing, closed

    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

struct PageContent: Codable, Equatable, Sendable {
    var page: NotePage
    // Existing v2 floating items are retained at their exact positions; new items flow inline.
    var legacyObjects: [NoteObject]
    var pageStatus: PageStatus

    init(page: NotePage = NotePage(), legacyObjects: [NoteObject] = [], pageStatus: PageStatus = .unset) {
        self.page = page
        self.legacyObjects = legacyObjects
        self.pageStatus = pageStatus
    }

    private enum CodingKeys: String, CodingKey { case page, legacyObjects, pageStatus }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decode(NotePage.self, forKey: .page)
        legacyObjects = try container.decode([NoteObject].self, forKey: .legacyObjects)
        pageStatus = try container.decodeIfPresent(String.self, forKey: .pageStatus).flatMap(PageStatus.init(rawValue:)) ?? .unset
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(page, forKey: .page)
        try container.encode(legacyObjects, forKey: .legacyObjects)
        if pageStatus != .unset { try container.encode(pageStatus.rawValue, forKey: .pageStatus) }
    }
}
/// Apple Journal momentary feelings (`HKStateOfMind.Label`), plus Neutral.
enum JournalEmotionalState: String, Codable, CaseIterable, Sendable {
    case amazed, amused, angry, anxious, ashamed, brave, calm, content
    case disappointed, discouraged, disgusted, embarrassed, excited, frustrated
    case grateful, guilty, happy, hopeless, irritated, jealous, joyful, lonely
    case passionate, peaceful, proud, relieved, sad, scared, stressed, surprised
    case worried, annoyed, confident, drained, hopeful, indifferent, overwhelmed
    case satisfied, neutral

    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// Optional journal mind-set. Order runs from thriving through Neutral, then Challenged, then toward distress.
enum JournalMentalState: String, Codable, CaseIterable, Sendable {
    case thriving, confident, content, atEase, evenMinded, neutral, challenged
    case uncertain, doubtful, uneasy, concerned, worried, overthinking
    case pressured, tense, stressed, anxious, overstimulated, ruminating
    case overwhelmed, distressed

    var label: String {
        switch self {
        case .thriving: "Thriving"
        case .confident: "Confident"
        case .content: "Content"
        case .atEase: "At ease"
        case .evenMinded: "Even-minded"
        case .neutral: "Neutral"
        case .uncertain: "Uncertain"
        case .doubtful: "Doubtful"
        case .uneasy: "Uneasy"
        case .concerned: "Concerned"
        case .worried: "Worried"
        case .overthinking: "Overthinking"
        case .pressured: "Pressured"
        case .tense: "Tense"
        case .stressed: "Stressed"
        case .anxious: "Anxious"
        case .overstimulated: "Overstimulated"
        case .ruminating: "Ruminating"
        case .overwhelmed: "Overwhelmed"
        case .distressed: "Distressed"
        case .challenged: "Challenged"
        }
    }

    var meaning: String {
        switch self {
        case .thriving: "Feeling energized, positive, and capable."
        case .confident: "Trusting yourself and your ability to handle things."
        case .content: "Feeling satisfied with how things are."
        case .atEase: "Relaxed and comfortable."
        case .evenMinded: "Calm, balanced, and emotionally steady."
        case .neutral: "Feeling neither particularly positive nor negative."
        case .uncertain: "Unsure about something or what to do next."
        case .doubtful: "Questioning yourself, a decision, or an outcome."
        case .uneasy: "Feeling unsettled or uncomfortable."
        case .concerned: "Recognizing a problem and feeling some worry."
        case .worried: "Thinking about what might go wrong."
        case .overthinking: "Analyzing something repeatedly without reaching clarity."
        case .pressured: "Feeling pushed by demands or expectations."
        case .tense: "Feeling wound up and unable to relax easily."
        case .stressed: "Finding demands difficult to manage."
        case .anxious: "Feeling apprehensive, restless, or fearful."
        case .overstimulated: "Feeling overloaded by noise, activity, sensations, or information."
        case .ruminating: "Repeatedly dwelling on upsetting thoughts or past events."
        case .overwhelmed: "Feeling there is more than you can handle."
        case .distressed: "Feeling deeply upset or emotionally troubled."
        case .challenged: "Facing something difficult and working through it."
        }
    }
}

struct JournalContent: Codable, Equatable, Sendable {
    var page = NotePage()
    var legacyObjects: [NoteObject] = []
    var scriptureVisible = true
    var emotionalState: JournalEmotionalState?
    var mentalState: JournalMentalState?

    init(page: NotePage = NotePage(), legacyObjects: [NoteObject] = [], scriptureVisible: Bool = true, emotionalState: JournalEmotionalState? = nil, mentalState: JournalMentalState? = nil) {
        self.page = page
        self.legacyObjects = legacyObjects
        self.scriptureVisible = scriptureVisible
        self.emotionalState = emotionalState
        self.mentalState = mentalState
    }

    private enum CodingKeys: String, CodingKey {
        case page, legacyObjects, scriptureVisible, emotionalState, mentalState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decode(NotePage.self, forKey: .page)
        legacyObjects = try container.decode([NoteObject].self, forKey: .legacyObjects)
        scriptureVisible = try container.decode(Bool.self, forKey: .scriptureVisible)
        emotionalState = try container.decodeIfPresent(String.self, forKey: .emotionalState).flatMap(JournalEmotionalState.init(rawValue:))
        mentalState = try container.decodeIfPresent(String.self, forKey: .mentalState).flatMap(JournalMentalState.init(rawValue:))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(page, forKey: .page)
        try container.encode(legacyObjects, forKey: .legacyObjects)
        try container.encode(scriptureVisible, forKey: .scriptureVisible)
        try container.encodeIfPresent(emotionalState?.rawValue, forKey: .emotionalState)
        try container.encodeIfPresent(mentalState?.rawValue, forKey: .mentalState)
    }
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
    var protectionID: UUID? = nil
    static let objectLimit = 1000
    enum Paper: String, Codable, CaseIterable, Sendable { case plain, ruled, grid, dotted }
    static let extent: CGFloat = 12_000
    var id = UUID()
    var title = "Untitled Note"
    var tags: [String] = []
    var createdAt = Date()
    var updatedAt = Date()
    /// Legacy export mirror of `trashedAt ?? archivedAt` for older builds.
    var deletedAt: Date?
    var archivedAt: Date?
    var trashedAt: Date?
    var paper = Paper.plain
    var color: CollectionAccent = .preset
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
    var pageStatus: PageStatus? {
        guard case .page(let value) = content else { return nil }
        return value.pageStatus
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
            case .page(var p): p.page = newValue; content = .page(p)
            case .prayer(var p): p.page = newValue; content = .prayer(p)
            case .journal(var j): j.page = newValue; content = .journal(j)
            case .canvas: break // Undo within Canvas must never change its type.
            }
        }
    }
    var prayerContent: PrayerContent? { if case .prayer(let value) = content { return value }; return nil }
    var journalContent: JournalContent? { if case .journal(let value) = content { return value }; return nil }
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
    private enum CodingKeys: String, CodingKey {
        case id, title, tags, createdAt, updatedAt, deletedAt, archivedAt, trashedAt, paper, color, content, objects, page, protectionID
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        protectionID = try c.decodeIfPresent(UUID.self, forKey: .protectionID)
        id = try c.decode(UUID.self, forKey: .id); title = try c.decode(String.self, forKey: .title)
        tags = try c.decode([String].self, forKey: .tags); createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        archivedAt = try c.decodeIfPresent(Date.self, forKey: .archivedAt)
        trashedAt = try c.decodeIfPresent(Date.self, forKey: .trashedAt)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        if archivedAt == nil, trashedAt == nil, let deletedAt { archivedAt = deletedAt }
        paper = try c.decode(Paper.self, forKey: .paper)
        if let accent = try c.decodeIfPresent(CollectionAccent.self, forKey: .color) {
            color = accent
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .color) {
            color = CollectionAccent.migrated(fromLegacyNoteColor: legacy)
        } else {
            color = .preset
        }
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
        try c.encodeIfPresent(archivedAt, forKey: .archivedAt)
        try c.encodeIfPresent(trashedAt, forKey: .trashedAt)
        try c.encodeIfPresent(trashedAt ?? archivedAt, forKey: .deletedAt)
        try c.encode(paper, forKey: .paper)
        try c.encode(color, forKey: .color)
        try c.encode(content, forKey: .content)
        try c.encodeIfPresent(protectionID, forKey: .protectionID)
    }
    var contentSize: CGSize {
        if let page { return CGSize(width: page.width, height: page.height) }
        return CGSize(width: min(Self.extent, max(1200, (objects.map(\.frame.maxX).max() ?? 0) + 240)),
               height: min(Self.extent, max(1400, (objects.map(\.frame.maxY).max() ?? 0) + 240)))
    }
    var isArchived: Bool { archivedAt != nil && trashedAt == nil }
    var isTrashed: Bool { trashedAt != nil }
    var isActiveInLibrary: Bool { archivedAt == nil && trashedAt == nil }

    var searchableText: String {
        let prayerText = prayerContent.map { $0.updates.map(\.body).joined(separator: " ") + " " + $0.status.label } ?? ""
        let journalText = journalContent.map { journal in
            [journal.emotionalState?.label, journal.mentalState?.label, journal.mentalState?.meaning]
                .compactMap { $0 }
                .joined(separator: " ")
        } ?? ""
        var parts = [title, page?.body ?? "", prayerText, journalText]
        parts.append(contentsOf: tags)
        for object in allObjects {
            parts.append(contentsOf: [object.text, object.url,
                                      object.quote?.reference ?? "", object.quote?.source ?? ""])
            parts.append(contentsOf: object.cells.flatMap { $0 })
        }
        return parts.joined(separator: " ")
    }
    func members(_ selected: Set<UUID>) -> Set<UUID> {
        let groups = Set(objects.filter { (kind == .canvas || $0.kind != .ink) && selected.contains($0.id) }.compactMap(\.group))
        return Set(objects.filter { (kind == .canvas || $0.kind != .ink) && (selected.contains($0.id) || $0.group.map(groups.contains) == true) }.map(\.id))
    }
    func objectsInside(_ polygon: [CGPoint]) -> Set<UUID> {
        guard polygon.count >= 3, let first = polygon.first else { return [] }
        let path = CGMutablePath()
        path.move(to: first)
        for point in polygon.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        let selected = Set(objects.filter { path.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }.map(\.id))
        return members(selected)
    }
    mutating func move(_ selection: Set<UUID>, by delta: CGSize) {
        guard delta.width.isFinite, delta.height.isFinite else { return }
        let ids = members(selection).filter { id in objects.first(where: { $0.id == id })?.positionLocked != true }
        guard !ids.isEmpty else { return }
        let frames = objects.filter { ids.contains($0.id) }.map(\.frame)
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
              allObjects.count <= Self.objectLimit, Set(allObjects.map(\.id)).count == allObjects.count else { throw NotesError.invalid }
        for object in allObjects {
            let f = object.frame
            guard [f.minX, f.minY, f.width, f.height].allSatisfy(\.isFinite),
                  f.minX >= 0, f.minY >= 0, f.width >= 40, f.height >= 40,
                  f.maxX <= Self.extent, f.maxY <= Self.extent,
                  object.text.count <= 20_000, object.url.count <= 4096,
                  object.fontSize.isFinite, (12...72).contains(object.fontSize),
                  object.details.count <= 500,
                  object.payload.count <= 16 * 1024 * 1024,
                  object.cells.count <= 20, object.cells.allSatisfy({ $0.count <= 10 && $0.allSatisfy { $0.count <= 2000 } }) else { throw NotesError.invalid }
            if let ids = object.strokeIDs {
                guard object.kind == .ink, ids.count <= 10_000, Set(ids).count == ids.count else { throw NotesError.invalid }
            }
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
              page.attachments.count <= Self.objectLimit,
              Set(page.attachments.map(\.location)).count == page.attachments.count else { throw NotesError.invalid }
        for attachment in page.attachments {
            guard [.image, .table, .audio].contains(attachment.object.kind), attachment.object.group == nil,
                  attachment.location >= 0, attachment.location < page.body.utf16.count,
                  (page.body as NSString).substring(with: NSRange(location: attachment.location, length: 1)) == "\u{FFFC}" else { throw NotesError.invalid }
        }
        for citation in page.citations {
            guard citation.location >= 0, citation.length > 0, citation.location <= page.body.utf16.count,
                  citation.length <= page.body.utf16.count - citation.location else { throw NotesError.invalid }
            try citation.quote.validate()
        }
        for span in page.formatting {
            guard span.location >= 0, span.length > 0, span.location <= page.body.utf16.count,
                  span.length <= page.body.utf16.count - span.location, (0...4).contains(span.level),
                  span.colorIndex == nil || (1...9).contains(span.colorIndex!),
                  span.colorHex == nil || (span.colorHex!.count == 6 && span.colorHex!.uppercased().allSatisfy(\.isHexDigit)) else { throw NotesError.invalid }
        }
    }
}

struct NotesSnapshot: Codable, Equatable, Sendable {
    var schemaVersion = 3
    var revision = 0
    var notes: [NoteDocument] = []
    mutating func sanitize() {
        for index in notes.indices { notes[index].sanitize() }
    }
    func validate() throws {
        guard (1...4).contains(schemaVersion) else { throw NotesError.unsupported }
        guard revision >= 0, notes.count <= 200, Set(notes.map(\.id)).count == notes.count else { throw NotesError.invalid }
        for note in notes { try note.validate() }
    }
}

extension NoteDocument {
    mutating func sanitize() {
        var items = objects
        for index in items.indices { NoteDocument.sanitize(&items[index]) }
        objects = items
        if var page {
            page.sanitize()
            self.page = page
        }
        var seenGroups = Set(objects.compactMap(\.group))
        for group in seenGroups where objects.filter({ $0.group == group }).count < 2 {
            for index in objects.indices where objects[index].group == group { objects[index].group = nil }
        }
    }

    fileprivate static func sanitize(_ object: inout NoteObject) {
        if !object.fontSize.isFinite { object.fontSize = 22 }
        object.fontSize = min(72, max(12, object.fontSize))
        if object.details.count > 500 { object.details = String(object.details.prefix(500)) }
    }
}

extension NotePage {
    mutating func sanitize() {
        for index in attachments.indices { NoteDocument.sanitize(&attachments[index].object) }
        let length = body.utf16.count
        formatting = formatting.compactMap { span in
            var item = span
            if let index = item.colorIndex, !(1...9).contains(index) { item.colorIndex = nil }
            if let hex = item.colorHex?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !hex.isEmpty {
                item.colorHex = hex.count == 6 && hex.allSatisfy(\.isHexDigit) ? hex : nil
            } else {
                item.colorHex = nil
            }
            guard item.location >= 0, item.length > 0, item.location <= length,
                  item.length <= length - item.location, (0...4).contains(item.level) else { return nil }
            return item.isPlain ? nil : item
        }
    }
}

struct NotesLoad: Sendable { var snapshot: NotesSnapshot; var recovered: Bool }
protocol NotesRepository: Sendable {
    func load() async throws -> NotesLoad
    func save(_ snapshot: NotesSnapshot, expectedRevision: Int) async throws -> NotesSnapshot
    func exportArchive() async throws -> Data
    func restore(_ data: Data, expectedRevision: Int) async throws -> NotesSnapshot
    func preRestoreArchive() async throws -> Data
    func resetStorage() async throws
    func retainRejectedInk(_ data: Data, noteID: UUID) async throws
    func rejectedInk(noteID: UUID) async throws -> Data?
    func clearRejectedInk(noteID: UUID) async throws
}
extension NotesRepository {
    func retainRejectedInk(_ data: Data, noteID: UUID) async throws { throw NotesError.unsupported }
    func rejectedInk(noteID: UUID) async throws -> Data? { nil }
    func clearRejectedInk(noteID: UUID) async throws { }
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
