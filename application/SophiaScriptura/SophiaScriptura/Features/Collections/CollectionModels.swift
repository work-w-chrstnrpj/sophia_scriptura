import Foundation

enum CollectionArtifactKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case scripture
    case note
    case conversation
    case link
    case bookmark
    case gleaning

    var id: Self { self }

    var title: String {
        switch self {
        case .scripture: return "Scripture"
        case .note: return "Notes"
        case .conversation: return "Conversations"
        case .link: return "Links"
        case .bookmark: return "Bookmarks"
        case .gleaning: return "Gleanings"
        }
    }

    var symbolName: String {
        switch self {
        case .scripture: return "book.closed"
        case .note: return "note.text"
        case .conversation: return "bubble.left.and.bubble.right"
        case .link: return "link"
        case .bookmark: return "bookmark.fill"
        case .gleaning: return "laurel.leading"
        }
    }
}

/// Muted, ink-like folder colors ordered around the color wheel. Raw values are persisted.
enum CollectionAccent: String, Codable, CaseIterable, Hashable, Identifiable {
    case oxblood
    case rose
    case terracotta
    case gold
    case mustard
    case olive
    case sage
    case teal
    case slate
    case indigo
    case plum
    case umber

    var id: Self { self }

    var title: String {
        switch self {
        case .oxblood: return "Oxblood"
        case .rose: return "Rose"
        case .terracotta: return "Terracotta"
        case .gold: return "Ochre"
        case .mustard: return "Mustard"
        case .olive: return "Olive"
        case .sage: return "Sage"
        case .teal: return "Teal"
        case .slate: return "Slate"
        case .indigo: return "Indigo"
        case .plum: return "Plum"
        case .umber: return "Umber"
        }
    }
}

struct CollectionOutlineEntry: Identifiable {
    let collection: StudyCollection
    let depth: Int
    var id: UUID { collection.id }
}

struct CollectionArtifact: Identifiable, Hashable {
    let id: UUID
    var title: String
    var subtitle: String
    var kind: CollectionArtifactKind
    var modifiedAt: Date
    var passageText: String = ""
    var insight: String = ""
}

struct StudyCollection: Codable, Identifiable, Hashable {
    static let unfiledID = UUID(uuidString: "00000000-0000-4000-8000-0000000000F1")!

    let id: UUID
    var name: String
    var detail: String
    var parentID: UUID?
    var accent: CollectionAccent
    var modifiedAt: Date
    var isUnfiled: Bool = false

    static func unfiled(accent: CollectionAccent, modifiedAt: Date = .distantPast) -> StudyCollection {
        StudyCollection(
            id: unfiledID,
            name: "No Folder",
            detail: "Notes, bookmarks, gleanings, and links that are not in a folder.",
            parentID: nil,
            accent: accent,
            modifiedAt: modifiedAt,
            isUnfiled: true
        )
    }
}

struct CollectionMembership: Codable, Hashable {
    let collectionID: UUID
    let artifactID: UUID
}

enum SavedPassageKind: String, Codable, Hashable {
    case bookmark
    case gleaning
}

struct PassageSpan: Codable, Hashable {
    var location: Int
    var length: Int
}

struct SavedPassage: Codable, Identifiable, Hashable {
    let id: UUID
    var bookID: String
    var bookTitle: String
    var chapter: Int
    var startVerse: Int
    var endVerse: Int
    var editionID: String
    var versionAbbreviation: String
    var passageText: String
    var insight: String
    var kind: SavedPassageKind
    var createdAt: Date
    var spans: [PassageSpan] = []

    var referenceLabel: String {
        let verses = startVerse == endVerse ? "\(startVerse)" : "\(startVerse)–\(endVerse)"
        return "\(bookTitle) \(chapter):\(verses) (\(versionAbbreviation))"
    }

    func matches(bookID: String, chapter: Int, verse: Int, editionID: String) -> Bool {
        self.bookID == bookID && self.chapter == chapter && self.editionID == editionID
            && verse >= startVerse && verse <= endVerse
    }
}

struct SavedLink: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var url: String
    var createdAt: Date
}

/// A conversation a collection can hold. The sample stays until Companion can create real ones.
struct StudyConversation: Codable, Identifiable, Hashable {
    static let placeholderID = UUID(uuidString: "00000000-0000-4000-8000-0000000000C1")!

    let id: UUID
    var title: String
    var detail: String
    var createdAt: Date
    var isPlaceholder: Bool

    static func placeholder(createdAt: Date = .distantPast) -> StudyConversation {
        StudyConversation(
            id: placeholderID,
            title: "Sample conversation",
            detail: "A placeholder until Companion can keep a real conversation.",
            createdAt: createdAt,
            isPlaceholder: true
        )
    }
}

struct CollectionsSnapshot: Codable, Equatable {
    var schemaVersion = 1
    var revision = 0
    var collections: [StudyCollection] = []
    var passages: [SavedPassage] = []
    var links: [SavedLink] = []
    var conversations: [StudyConversation] = []
    var memberships: [CollectionMembership] = []
    var unfiledAccent: CollectionAccent = .slate

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, revision, collections, passages, links, conversations, memberships, unfiledAccent
    }

    init(schemaVersion: Int = 1, revision: Int = 0, collections: [StudyCollection] = [], passages: [SavedPassage] = [], links: [SavedLink] = [], conversations: [StudyConversation] = [], memberships: [CollectionMembership] = [], unfiledAccent: CollectionAccent = .slate) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.collections = collections
        self.passages = passages
        self.links = links
        self.conversations = conversations
        self.memberships = memberships
        self.unfiledAccent = unfiledAccent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
        collections = try container.decodeIfPresent([StudyCollection].self, forKey: .collections) ?? []
        passages = try container.decodeIfPresent([SavedPassage].self, forKey: .passages) ?? []
        links = try container.decodeIfPresent([SavedLink].self, forKey: .links) ?? []
        conversations = try container.decodeIfPresent([StudyConversation].self, forKey: .conversations) ?? []
        memberships = try container.decodeIfPresent([CollectionMembership].self, forKey: .memberships) ?? []
        unfiledAccent = try container.decodeIfPresent(CollectionAccent.self, forKey: .unfiledAccent) ?? .slate
    }
}

enum CollectionLibrarySort: String, CaseIterable, Identifiable {
    case modified
    case name
    case itemCount

    var id: Self { self }

    var title: String {
        switch self {
        case .modified: return "Recently modified"
        case .name: return "Name"
        case .itemCount: return "Item count"
        }
    }
}

enum CollectionArtifactFilter: String, CaseIterable, Identifiable {
    case all
    case scripture
    case note
    case bookmark
    case gleaning
    case conversation
    case link

    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "All"
        case .scripture: return "Scripture"
        case .note: return "Notes"
        case .bookmark: return "Bookmarks"
        case .gleaning: return "Gleanings"
        case .conversation: return "Conversations"
        case .link: return "Links"
        }
    }

    var kind: CollectionArtifactKind? {
        switch self {
        case .all: return nil
        case .scripture: return .scripture
        case .note: return .note
        case .conversation: return .conversation
        case .link: return .link
        case .bookmark: return .bookmark
        case .gleaning: return .gleaning
        }
    }
}

enum CollectionArtifactSort: String, CaseIterable, Identifiable {
    case modified
    case title

    var id: Self { self }

    var title: String {
        switch self {
        case .modified: return "Recently modified"
        case .title: return "Title"
        }
    }
}
