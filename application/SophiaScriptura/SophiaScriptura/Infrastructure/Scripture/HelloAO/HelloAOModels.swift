import Foundation

enum HelloAOError: Error, LocalizedError, Equatable {
    case ineligibleEdition
    case transport
    case responseTooLarge
    case invalidResponse
    case crossOriginRedirect
    case busy
    case notInstalled
    case insufficientStorage
    case cancelled

    var errorDescription: String? {
        switch self {
        case .ineligibleEdition: "This translation is not approved for download yet."
        case .transport: "Could not reach AO Lab. Check your connection and try again."
        case .responseTooLarge: "The response was too large to download safely."
        case .invalidResponse: "The downloaded content could not be verified."
        case .crossOriginRedirect: "An unexpected redirect blocked this download."
        case .busy: "Another AO Lab download is already running."
        case .notInstalled: "This translation is not installed."
        case .insufficientStorage: "Not enough free space to download this translation."
        case .cancelled: "Download cancelled."
        }
    }
}

enum HelloAOInstallState: String, Codable, Sendable {
    case notInstalled
    case downloading
    case paused
    case installed
    case failed
}

struct HelloAOEditionStatus: Identifiable, Sendable {
    let eligible: HelloAOEligibleEdition
    let state: HelloAOInstallState
    let progressCompleted: Int
    let progressTotal: Int
    let contentRevision: String?
    let catalogName: String?
    let catalogLanguage: String?
    let lastCatalogRefresh: Date?
    let errorMessage: String?

    var id: String { eligible.providerEditionID }
    var appEditionID: String { eligible.appEditionID }
    var isAvailable: Bool { state == .installed }
}

struct HelloAOCatalogEntry: Codable, Sendable {
    let id: String
    let name: String
    let shortName: String?
    let language: String
    let languageName: String?
    let numberOfBooks: Int
    let licenseUrl: String?
    let website: String?
    let sha256: String?
}

struct HelloAOCatalogCache: Codable, Sendable {
    var refreshedAt: Date
    var entries: [HelloAOCatalogEntry]
}

struct HelloAOInstalledManifest: Codable, Sendable {
    let generation: String
    let providerEditionID: String
    let edition: ScriptureEdition
    let books: [ScriptureBook]
    let chapters: [String]
    let fetchedAt: Date
    let contentRevision: String
}

struct HelloAOStagingJournal: Codable, Sendable {
    let generation: String
    let providerEditionID: String
    let edition: ScriptureEdition
    let books: [ScriptureBook]
    let chapters: [String]
    var completed: Set<String>
    let contentRevision: String
}

struct HelloAOChapterWire: Decodable, Sendable {
    struct TranslationInfo: Decodable, Sendable {
        let id: String
        let name: String?
        let shortName: String?
        let sha256: String?
        let licenseUrl: String?
    }

    struct BookInfo: Decodable, Sendable {
        let id: String
        let name: String?
        let commonName: String?
        let order: Int?
        let numberOfChapters: Int?
    }

    struct Footnote: Decodable, Sendable {
        let noteId: Int
        let caller: String?
        let text: String
    }

    struct ContentItem: Decodable, Sendable {
        let type: String
        let number: Int?
        let content: [HelloAOContentPiece]?
    }

    struct ChapterInfo: Decodable, Sendable {
        let number: Int
        let content: [ContentItem]
        let footnotes: [Footnote]?
    }

    let translation: TranslationInfo
    let book: BookInfo
    let chapter: ChapterInfo
}

enum HelloAOContentPiece: Decodable, Sendable {
    case text(String)
    case noteId(Int)
    case lineBreak
    case formatted(Formatted)

    struct Formatted: Decodable, Sendable {
        let text: String?
        let wordsOfJesus: Bool?
        let lineBreak: Bool?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .text(string)
            return
        }
        if let note = try? container.decode([String: Int].self), let value = note["noteId"] {
            self = .noteId(value)
            return
        }
        if let breakFlag = try? container.decode([String: Bool].self), breakFlag["lineBreak"] == true {
            self = .lineBreak
            return
        }
        self = .formatted(try container.decode(Formatted.self))
    }
}

struct HelloAOBooksWire: Decodable, Sendable {
    struct BookRow: Decodable, Sendable {
        let id: String
        let name: String?
        let commonName: String?
        let order: Int?
        let numberOfChapters: Int?
    }

    let translation: HelloAOChapterWire.TranslationInfo?
    let books: [BookRow]
}

struct HelloAOTranslationsWire: Decodable, Sendable {
    struct Row: Decodable, Sendable {
        let id: String
        let name: String?
        let shortName: String?
        let language: String?
        let languageName: String?
        let numberOfBooks: Int?
        let licenseUrl: String?
        let website: String?
        let sha256: String?
    }

    let translations: [Row]
}
