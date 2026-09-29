import Foundation

struct VerseID: Codable, Hashable, Sendable, Identifiable {
    var referenceSystemID = "org.sophia.web.engwebp"
    let book: String
    let chapter: Int
    let verse: Int
    var id: String { "\(referenceSystemID):\(book).\(chapter).\(verse)" }
}

struct PassageRange: Codable, Equatable, Sendable {
    let start: VerseID
    let end: VerseID

    func overlaps(_ other: PassageRange, bookOrder: [String: Int]) throws -> Bool {
        func key(_ verse: VerseID) throws -> Int {
            guard verse.referenceSystemID == start.referenceSystemID,
                  verse.chapter > 0, verse.chapter < 1000, verse.verse > 0, verse.verse < 1000,
                  let order = bookOrder[verse.book] else { throw ScriptureError.passageUnmapped }
            return order * 1_000_000 + verse.chapter * 1000 + verse.verse
        }
        let a = try key(start), b = try key(end), c = try key(other.start), d = try key(other.end)
        guard a <= b, c <= d else { throw ScriptureError.passageUnmapped }
        return a <= d && c <= b
    }
}

struct ScriptureEdition: Codable, Sendable {
    let id: String
    let referenceSystemID: String
    let contentRevision: String
    let name: String
    let abbreviation: String
    let attribution: String
}

struct ScriptureBook: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let testament: String
    let order: Int
    let chapterCount: Int
}

struct ScriptureBlock: Codable, Identifiable, Sendable {
    let id: String
    let kind: String
    let text: String
    let label: String
    let verses: [Int]
    let style: String
}

struct ChapterDocument: Codable, Sendable {
    let schemaVersion: Int
    let editionID: String
    let contentRevision: String
    let book: String
    let chapter: Int
    let blocks: [ScriptureBlock]
    var verseNumbers: [Int] { Array(Set(blocks.filter { $0.kind == "body" && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.flatMap(\.verses))).sorted() }
    var isLicensed: Bool { editionID.hasPrefix("api.bible.") }
    var referenceSystemID: String { isLicensed ? "org.sophia." + editionID : "org.sophia.web.engwebp" }
    func verse(_ number: Int) -> VerseID { VerseID(referenceSystemID:referenceSystemID,book:book,chapter:chapter,verse:number) }
    func body(for verse: Int) -> String {
        var text = ""
        for block in blocks where block.verses.contains(verse) {
            if block.kind == "body" { text += block.text }
            if block.kind == "break" && !text.isEmpty { text += "\n" }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ReadingLocation: Codable, Equatable, Sendable {
    var editionID: String
    var contentRevision: String
    var verse: VerseID
    var blockID: String?
    var utf16Offset: Int?
}

struct ReaderPreferences: Codable, Equatable, Sendable {
    var preferredEdition = "web.engwebp"
    var typeface = "Georgia"
    var sizeStep = 2
    var theme = "system"
    var controlsExpanded = true
    // Optional for backward-compatible decoding of existing reader snapshots.
    var appearancePreset: String? = nil
    static let typefaces = ["Georgia", "Palatino", "System"]
    var validated: Self {
        var result = self
        if !Self.typefaces.contains(typeface) { result.typeface = "Georgia" }
        if !(0...8).contains(sizeStep) { result.sizeStep = 2 }
        if !["system", "light", "dark"].contains(theme) { result.theme = "system" }
        return result
    }
}

struct ReaderSnapshot: Codable, Sendable {
    var schemaVersion = 1
    var location: ReadingLocation?
    var preferences = ReaderPreferences()
    var updatedAt = Date()
}

enum ScriptureError: Error, LocalizedError, Equatable {
    case artifactMissing, incompatibleSchema, integrityMismatch, editionUnavailable
    case chapterUnavailable, passageUnmapped, decoding, persistence
    var errorDescription: String? {
        switch self {
        case .artifactMissing: "The offline Bible is missing. Retry, or reinstall over the existing app from Xcode."
        case .incompatibleSchema: "This content or saved state needs a compatible app version. Your saved data has been left untouched."
        case .integrityMismatch: "The offline Bible could not be verified. Retry, or reinstall over the existing app from Xcode."
        case .editionUnavailable: "Your saved edition is unavailable. Your reading position has been kept."
        case .chapterUnavailable: "This book or chapter is unavailable. Choose another passage."
        case .passageUnmapped: "This verse has no text in this edition."
        case .decoding: "The offline Bible could not be read. Retry or reinstall over the existing app."
        case .persistence: "Reading position not saved. Reading remains available for this session; existing saved data is unchanged."
        }
    }
}

protocol ScriptureContentRepository: Sendable {
    func edition() async throws -> ScriptureEdition
    func books() async throws -> [ScriptureBook]
    func chapter(book: String, number: Int) async throws -> ChapterDocument
    func resolve(_ range: PassageRange) async throws -> [ScriptureBlock]
}

@MainActor protocol ReaderStateRepository {
    func load() throws -> ReaderSnapshot?
    func save(_ snapshot: ReaderSnapshot) throws
}
