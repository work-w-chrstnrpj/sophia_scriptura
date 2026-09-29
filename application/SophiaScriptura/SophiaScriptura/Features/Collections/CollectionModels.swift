import Foundation

enum CollectionArtifactKind: String, CaseIterable, Hashable, Identifiable {
    case scripture
    case note
    case conversation
    case link

    var id: Self { self }

    var title: String {
        switch self {
        case .scripture: return "Scripture"
        case .note: return "Notes"
        case .conversation: return "Conversations"
        case .link: return "Links"
        }
    }

    var symbolName: String {
        switch self {
        case .scripture: return "book.closed"
        case .note: return "note.text"
        case .conversation: return "bubble.left.and.bubble.right"
        case .link: return "link"
        }
    }
}

enum CollectionAccent: String, CaseIterable, Hashable, Identifiable {
    case oxblood
    case sage
    case slate
    case gold

    var id: Self { self }
}

struct CollectionArtifact: Identifiable, Hashable {
    let id: UUID
    var title: String
    var subtitle: String
    var kind: CollectionArtifactKind
    var modifiedAt: Date
}

struct StudyCollection: Identifiable, Hashable {
    let id: UUID
    var name: String
    var detail: String
    var parentID: UUID?
    var accent: CollectionAccent
    var modifiedAt: Date
}

struct CollectionMembership: Hashable {
    let collectionID: UUID
    let artifactID: UUID
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
    case conversation
    case link

    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "All"
        case .scripture: return "Scripture"
        case .note: return "Notes"
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
