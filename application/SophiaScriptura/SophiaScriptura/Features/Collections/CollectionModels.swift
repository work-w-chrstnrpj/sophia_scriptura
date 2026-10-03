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

enum CollectionIcon: String, Codable, CaseIterable, Hashable, Identifiable {
    case folder, bible, bookmark, lightbulb, heart, cross, leaf, flame, star, person, people, question
    case book, scroll, map, mappin, tag, gift, crown, shield, key, bell, musicNote, pencil, quote
    case sun, moon, drop, mountain, globe, clock, calendar, envelope, link, sparkles, tray, house
    case tree, graduationcap, mic, photo, rosette, hands, buildingColumns, bird, scope, target
    case briefcase, building2, desktopcomputer, laptopcomputer, chartLine, hammer, wrench, storefront
    case brain, mindBody, forkKnife, figureRun, sport, finance, crossCase, stethoscope, provision
    case megaphone, fellowship, partyPopper, family, heartCircle, community, handshake, marriage
    case child, phone, network, paintbrush, theater, sailboat, tent, rest, bookPages, compass
    case path, seedling, bolt, sharedWithYou, travel, labor, witness, hospitality, creativity, integration, professional

    var id: Self { self }
    var title: String {
        switch self {
        case .folder: return "Folder"
        case .bible: return "Bible"
        case .bookmark: return "Bookmark"
        case .lightbulb: return "Insight"
        case .heart: return "Heart"
        case .cross: return "Cross"
        case .leaf: return "Growth"
        case .flame: return "Flame"
        case .star: return "Star"
        case .person: return "Person"
        case .people: return "People"
        case .question: return "Question"
        case .book: return "Book"
        case .scroll: return "Scroll"
        case .map: return "Map"
        case .mappin: return "Place"
        case .tag: return "Tag"
        case .gift: return "Gift"
        case .crown: return "Crown"
        case .shield: return "Shield"
        case .key: return "Key"
        case .bell: return "Bell"
        case .musicNote: return "Music"
        case .pencil: return "Pencil"
        case .quote: return "Quote"
        case .sun: return "Sun"
        case .moon: return "Moon"
        case .drop: return "Water"
        case .mountain: return "Mountain"
        case .globe: return "World"
        case .clock: return "Clock"
        case .calendar: return "Calendar"
        case .envelope: return "Mail"
        case .link: return "Link"
        case .sparkles: return "Sparkles"
        case .tray: return "Tray"
        case .house: return "Home"
        case .tree: return "Tree"
        case .graduationcap: return "Study"
        case .mic: return "Mic"
        case .photo: return "Photo"
        case .rosette: return "Award"
        case .hands: return "Prayer"
        case .buildingColumns: return "Church"
        case .bird: return "Dove"
        case .scope: return "Focus"
        case .target: return "Goal"
        case .briefcase: return "Work"
        case .building2: return "Workplace"
        case .desktopcomputer: return "Desk"
        case .laptopcomputer: return "Remote work"
        case .chartLine: return "Career"
        case .hammer: return "Labor"
        case .wrench: return "Trade"
        case .storefront: return "Business"
        case .brain: return "Mind"
        case .mindBody: return "Wholeness"
        case .forkKnife: return "Meals"
        case .figureRun: return "Fitness"
        case .sport: return "Recreation"
        case .finance: return "Finances"
        case .crossCase: return "Health"
        case .stethoscope: return "Care"
        case .provision: return "Provision"
        case .megaphone: return "Witness"
        case .fellowship: return "Fellowship"
        case .partyPopper: return "Celebration"
        case .family: return "Family"
        case .heartCircle: return "Relationship"
        case .community: return "Community"
        case .handshake: return "Partnership"
        case .marriage: return "Marriage"
        case .child: return "Parenting"
        case .phone: return "Connection"
        case .network: return "Network"
        case .paintbrush: return "Creativity"
        case .theater: return "Arts"
        case .sailboat: return "Journey"
        case .tent: return "Retreat"
        case .rest: return "Rest"
        case .bookPages: return "Reading"
        case .compass: return "Direction"
        case .path: return "Path"
        case .seedling: return "New life"
        case .bolt: return "Energy"
        case .sharedWithYou: return "Shared life"
        case .travel: return "Travel"
        case .labor: return "Service"
        case .witness: return "Evangelism"
        case .hospitality: return "Hospitality"
        case .creativity: return "Making"
        case .integration: return "Daily life"
        case .professional: return "Professional"
        }
    }
    var symbolName: String {
        switch self {
        case .folder: return "folder.fill"
        case .bible: return "book.closed.fill"
        case .bookmark: return "bookmark.fill"
        case .lightbulb: return "lightbulb.fill"
        case .heart: return "heart.fill"
        case .cross: return "cross.fill"
        case .leaf: return "leaf.fill"
        case .flame: return "flame.fill"
        case .star: return "star.fill"
        case .person: return "person.fill"
        case .people: return "person.2.fill"
        case .question: return "questionmark"
        case .book: return "book.fill"
        case .scroll: return "scroll.fill"
        case .map: return "map.fill"
        case .mappin: return "mappin.and.ellipse"
        case .tag: return "tag.fill"
        case .gift: return "gift.fill"
        case .crown: return "crown.fill"
        case .shield: return "shield.fill"
        case .key: return "key.fill"
        case .bell: return "bell.fill"
        case .musicNote: return "music.note"
        case .pencil: return "pencil"
        case .quote: return "quote.opening"
        case .sun: return "sun.max.fill"
        case .moon: return "moon.fill"
        case .drop: return "drop.fill"
        case .mountain: return "mountain.2.fill"
        case .globe: return "globe.americas.fill"
        case .clock: return "clock.fill"
        case .calendar: return "calendar"
        case .envelope: return "envelope.fill"
        case .link: return "link"
        case .sparkles: return "sparkles"
        case .tray: return "tray.full.fill"
        case .house: return "house.fill"
        case .tree: return "tree.fill"
        case .graduationcap: return "graduationcap.fill"
        case .mic: return "mic.fill"
        case .photo: return "photo.fill"
        case .rosette: return "rosette"
        case .hands: return "hands.clap.fill"
        case .buildingColumns: return "building.columns.fill"
        case .bird: return "bird.fill"
        case .scope: return "scope"
        case .target: return "target"
        case .briefcase: return "briefcase.fill"
        case .building2: return "building.2.fill"
        case .desktopcomputer: return "desktopcomputer"
        case .laptopcomputer: return "laptopcomputer"
        case .chartLine: return "chart.line.uptrend.xyaxis"
        case .hammer: return "hammer.fill"
        case .wrench: return "wrench.and.screwdriver.fill"
        case .storefront: return "storefront.fill"
        case .brain: return "brain.head.profile"
        case .mindBody: return "figure.mind.and.body"
        case .forkKnife: return "fork.knife"
        case .figureRun: return "figure.run"
        case .sport: return "sportscourt.fill"
        case .finance: return "dollarsign.circle.fill"
        case .crossCase: return "cross.case.fill"
        case .stethoscope: return "stethoscope"
        case .provision: return "cart.fill"
        case .megaphone: return "megaphone.fill"
        case .fellowship: return "cup.and.saucer.fill"
        case .partyPopper: return "party.popper.fill"
        case .family: return "figure.and.child.holdinghands"
        case .heartCircle: return "heart.circle.fill"
        case .community: return "figure.2.arms.open"
        case .handshake: return "hands.and.sparkles.fill"
        case .marriage: return "figure.2"
        case .child: return "figure.child"
        case .phone: return "phone.fill"
        case .network: return "network"
        case .paintbrush: return "paintbrush.fill"
        case .theater: return "theatermasks.fill"
        case .sailboat: return "sailboat.fill"
        case .tent: return "tent.fill"
        case .rest: return "bed.double.fill"
        case .bookPages: return "book.pages.fill"
        case .compass: return "location.north.circle.fill"
        case .path: return "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .seedling: return "leaf.circle.fill"
        case .bolt: return "bolt.fill"
        case .sharedWithYou: return "shared.with.you"
        case .travel: return "airplane"
        case .labor: return "person.3.fill"
        case .witness: return "person.wave.2.fill"
        case .hospitality: return "house.lodge.fill"
        case .creativity: return "paintpalette.fill"
        case .integration: return "square.grid.3x3.square"
        case .professional: return "person.crop.rectangle.fill"
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
    var icon: CollectionIcon? = nil
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
    var verse: VerseID? = nil
    var editionID: String? = nil
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
