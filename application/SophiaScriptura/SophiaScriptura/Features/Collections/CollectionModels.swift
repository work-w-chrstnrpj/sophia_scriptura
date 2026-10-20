import Foundation

enum CollectionArtifactKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case scripture
    case annotation
    case note
    case conversation
    case link
    case bookmark
    case gleaning
    case pointToPonder
    case plan

    var id: Self { self }

    var title: String {
        switch self {
        case .scripture: return "Scripture"
        case .annotation: return "Annotations"
        case .note: return "Notes"
        case .conversation: return "Conversations"
        case .link: return "Links"
        case .bookmark: return "Bookmarks"
        case .gleaning: return "Gleanings"
        case .pointToPonder: return "Points to Ponder"
        case .plan: return "Plans"
        }
    }

    var symbolName: String {
        switch self {
        case .scripture: return "book.closed"
        case .annotation: return "square.3.layers.3d"
        case .note: return "note.text"
        case .conversation: return "bubble.left.and.bubble.right"
        case .link: return "link"
        case .bookmark: return "bookmark.fill"
        case .gleaning: return "laurel.leading"
        case .pointToPonder: return "questionmark.bubble"
        case .plan: return "list.bullet.rectangle"
        }
    }
}

/// Muted, ink-like folder colors ordered around the color wheel. Raw values are persisted.
enum CollectionAccent: String, Codable, CaseIterable, Hashable, Identifiable {
    /// Tracks the active appearance preset accent from Settings (light/dark aware).
    case preset
    case oxblood
    case brick
    case rose
    case blush
    case terracotta
    case copper
    case gold
    case honey
    case mustard
    case wheat
    case olive
    case moss
    case sage
    case fern
    case teal
    case sea
    case slate
    case navy
    case indigo
    case plum
    case lavender
    case orchid
    case umber
    case sand
    case taupe
    case stone
    case pewter
    case fog

    var id: Self { self }

    /// Fixed gray for the virtual No Folder tray; not user-customizable.
    static let noFolder: CollectionAccent = .stone

    var title: String {
        switch self {
        case .preset: return "Preset accent"
        case .oxblood: return "Oxblood"
        case .brick: return "Brick"
        case .rose: return "Rose"
        case .blush: return "Blush"
        case .terracotta: return "Terracotta"
        case .copper: return "Copper"
        case .gold: return "Ochre"
        case .honey: return "Honey"
        case .mustard: return "Mustard"
        case .wheat: return "Wheat"
        case .olive: return "Olive"
        case .moss: return "Moss"
        case .sage: return "Sage"
        case .fern: return "Fern"
        case .teal: return "Teal"
        case .sea: return "Sea"
        case .slate: return "Slate"
        case .navy: return "Navy"
        case .indigo: return "Indigo"
        case .plum: return "Plum"
        case .lavender: return "Lavender"
        case .orchid: return "Orchid"
        case .umber: return "Umber"
        case .sand: return "Sand"
        case .taupe: return "Taupe"
        case .stone: return "Stone"
        case .pewter: return "Pewter"
        case .fog: return "Fog"
        }
    }

    /// Maps persisted note colors from before accents were shared with collections.
    static func migrated(fromLegacyNoteColor raw: String) -> CollectionAccent {
        switch raw {
        case "neutral": return .stone
        case "rose": return .rose
        case "amber": return .gold
        case "sage": return .sage
        case "blue": return .teal
        case "lavender": return .lavender
        default: return CollectionAccent(rawValue: raw) ?? .preset
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

extension Array where Element == CollectionOutlineEntry {
    /// Keeps a collapsed folder and hides every nested folder beneath it.
    func hidingCollapsedSubfolders(_ collapsed: Set<UUID>) -> [CollectionOutlineEntry] {
        var hiddenBelow: Int?
        return filter { entry in
            if let hiddenBelow, entry.depth > hiddenBelow { return false }
            hiddenBelow = collapsed.contains(entry.id) ? entry.depth : nil
            return true
        }
    }
}

struct CollectionArtifact: Identifiable, Hashable {
    let id: UUID
    var title: String
    var subtitle: String
    var kind: CollectionArtifactKind
    var modifiedAt: Date
    var passageText: String = ""
    var insight: String = ""
    var isPlanComplete = false
}

struct StudyCollection: Codable, Identifiable, Hashable {
    var protectionID: UUID? = nil
    static let unfiledID = UUID(uuidString: "00000000-0000-4000-8000-0000000000F1")!

    let id: UUID
    var name: String
    var detail: String
    var parentID: UUID?
    var accent: CollectionAccent
    var icon: CollectionIcon? = nil
    var modifiedAt: Date
    var isUnfiled: Bool = false
    var archivedAt: Date? = nil
    var trashedAt: Date? = nil

    var isArchived: Bool { archivedAt != nil && trashedAt == nil }
    var isTrashed: Bool { trashedAt != nil }
    var isActiveInLibrary: Bool { archivedAt == nil && trashedAt == nil && !isUnfiled }

    static func unfiled(accent: CollectionAccent, modifiedAt: Date = .distantPast) -> StudyCollection {
        StudyCollection(
            id: unfiledID,
            name: "No Folder",
            detail: "Notes, points to ponder, bookmarks, gleanings, and links that are not in a folder.",
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

struct SavedAnnotation: Codable, Identifiable, Hashable {
    let id: UUID
    var groupID: UUID
    var source: AnnotationSource
    var bookTitle: String
    var layerName: String
    var savedAt: Date
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

    var gleaningNoteTitle: String { "Gleaning from \"\(referenceLabel)\"" }
    var noteContent: String { referenceLabel + "\n\n" + passageText + (insight.isEmpty ? "" : "\n\n" + insight) }

    func matches(bookID: String, chapter: Int, verse: Int, editionID: String) -> Bool {
        self.bookID == bookID && self.chapter == chapter && self.editionID == editionID
            && verse >= startVerse && verse <= endVerse
    }
}

struct SavedLink: Codable, Identifiable, Hashable {
    var access = StudyAccessRequirements()
    var planOrigin: PlanOrigin? = nil
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

struct PointToPonder: Codable, Identifiable, Hashable {
    let id: UUID
    var question: String
    var createdAt: Date
    var trashedAt: Date? = nil
}

struct CollectionsSnapshot: Codable, Equatable {
    var pointsToPonder: [PointToPonder] = []
    var planFormatActivated = false
    var plans: [StudyPlan] = []
    var planOperations: [PlanOperation] = []
    var commandReceipts: [StudyCommandReceipt] = []
    var retainedPlanAccess: [RetainedPlanAccess] = []
    var requiredSchemaVersion: Int { planFormatActivated || !plans.isEmpty || !planOperations.isEmpty || !retainedPlanAccess.isEmpty || links.contains(where: { !$0.access.isEmpty || $0.planOrigin != nil }) ? 4 : !pointsToPonder.isEmpty ? 3 : collections.contains(where: { $0.protectionID != nil }) ? 2 : 1 }
    var schemaVersion = 1
    var revision = 0
    var collections: [StudyCollection] = []
    var passages: [SavedPassage] = []
    var savedAnnotations: [SavedAnnotation] = []
    var links: [SavedLink] = []
    var conversations: [StudyConversation] = []
    var memberships: [CollectionMembership] = []
    var unfiledAccent: CollectionAccent = .stone

    private enum CodingKeys: String, CodingKey {
        case pointsToPonder, schemaVersion, revision, collections, passages, savedAnnotations, links, conversations, memberships, unfiledAccent
        case planFormatActivated, plans, planOperations, commandReceipts, retainedPlanAccess
    }

    private enum RequiredLinkAccess: String, CodingKey { case access }

    init(
        schemaVersion: Int = 1,
        revision: Int = 0,
        collections: [StudyCollection] = [],
        pointsToPonder: [PointToPonder] = [],
        passages: [SavedPassage] = [],
        savedAnnotations: [SavedAnnotation] = [],
        links: [SavedLink] = [],
        conversations: [StudyConversation] = [],
        memberships: [CollectionMembership] = [],
        unfiledAccent: CollectionAccent = .stone
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.collections = collections
        self.pointsToPonder = pointsToPonder
        self.passages = passages
        self.savedAnnotations = savedAnnotations
        self.links = links
        self.conversations = conversations
        self.memberships = memberships
        self.unfiledAccent = unfiledAccent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
        if schemaVersion >= 4 {
            planFormatActivated = try container.decode(Bool.self, forKey: .planFormatActivated)
            plans = try container.decode([StudyPlan].self, forKey: .plans)
            planOperations = try container.decode([PlanOperation].self, forKey: .planOperations)
            commandReceipts = try container.decode([StudyCommandReceipt].self, forKey: .commandReceipts)
            retainedPlanAccess = try container.decode([RetainedPlanAccess].self, forKey: .retainedPlanAccess)
            guard planFormatActivated else { throw CollectionsError.invalid }
        }
        collections = try container.decodeIfPresent([StudyCollection].self, forKey: .collections) ?? []
        pointsToPonder = try container.decodeIfPresent([PointToPonder].self, forKey: .pointsToPonder) ?? []
        passages = try container.decodeIfPresent([SavedPassage].self, forKey: .passages) ?? []
        savedAnnotations = try container.decodeIfPresent([SavedAnnotation].self, forKey: .savedAnnotations) ?? []
        links = try container.decodeIfPresent([SavedLink].self, forKey: .links) ?? []
        if schemaVersion == 4 {
            var records = try container.nestedUnkeyedContainer(forKey: .links)
            while !records.isAtEnd {
                let decoder = try records.superDecoder()
                let fields = try decoder.container(keyedBy: RequiredLinkAccess.self)
                _ = try fields.decode(StudyAccessRequirements.self, forKey: .access)
            }
        }
        conversations = try container.decodeIfPresent([StudyConversation].self, forKey: .conversations) ?? []
        memberships = try container.decodeIfPresent([CollectionMembership].self, forKey: .memberships) ?? []
        unfiledAccent = try container.decodeIfPresent(CollectionAccent.self, forKey: .unfiledAccent) ?? .stone
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
    case annotation
    case note
    case bookmark
    case gleaning
    case pointToPonder
    case plan
    case conversation
    case link

    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "All"
        case .scripture: return "Scripture"
        case .annotation: return "Annotations"
        case .note: return "Notes"
        case .bookmark: return "Bookmarks"
        case .gleaning: return "Gleanings"
        case .pointToPonder: return "Points to Ponder"
        case .plan: return "Plans"
        case .conversation: return "Conversations"
        case .link: return "Links"
        }
    }

    var kind: CollectionArtifactKind? {
        switch self {
        case .all: return nil
        case .scripture: return .scripture
        case .annotation: return .annotation
        case .note: return .note
        case .conversation: return .conversation
        case .link: return .link
        case .bookmark: return .bookmark
        case .gleaning: return .gleaning
        case .pointToPonder: return .pointToPonder
        case .plan: return .plan
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

extension SavedLink {
    private enum CodingKeys: String, CodingKey { case id, title, url, createdAt, verse, editionID, access, planOrigin }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); title = try c.decode(String.self, forKey: .title)
        url = try c.decode(String.self, forKey: .url); createdAt = try c.decode(Date.self, forKey: .createdAt)
        verse = try c.decodeIfPresent(VerseID.self, forKey: .verse)
        editionID = try c.decodeIfPresent(String.self, forKey: .editionID)
        access = try c.decodeIfPresent(StudyAccessRequirements.self, forKey: .access) ?? .init()
        planOrigin = try c.decodeIfPresent(PlanOrigin.self, forKey: .planOrigin)
    }
}

extension CollectionsSnapshot {
    func validatePlans() throws {
        guard (1...4).contains(schemaVersion), revision >= 0 else { throw CollectionsError.unsupported }
        guard plans.count <= 100, planOperations.count <= 128, commandReceipts.count <= 256,
              Set(commandReceipts.map(\.commandID)).count == commandReceipts.count,
              Set(planOperations.map(\.id)).count == planOperations.count else { throw CollectionsError.invalid }
        var ids = Set(collections.map(\.id) + passages.map(\.id) + links.map(\.id) + savedAnnotations.map(\.id) + conversations.map(\.id) + pointsToPonder.map(\.id))
        for plan in plans {
            try plan.validate()
            for id in [plan.id] + plan.sections.map(\.id) + plan.items.map(\.id) {
                guard ids.insert(id).inserted else { throw CollectionsError.invalid }
            }
        }
    }
    mutating func preservePlanAccess(from previous: Self) {
        planFormatActivated = planFormatActivated || previous.planFormatActivated || !plans.isEmpty
        for i in plans.indices {
            if let old = previous.plans.first(where: { $0.id == plans[i].id }) { plans[i].access = plans[i].access.union(old.access) }
        }
        for record in previous.retainedPlanAccess {
            if let index = retainedPlanAccess.firstIndex(where: { $0.planID == record.planID }) {
                retainedPlanAccess[index].access = retainedPlanAccess[index].access.union(record.access)
            } else { retainedPlanAccess.append(record) }
        }
        for i in links.indices {
            if let old = previous.links.first(where: { $0.id == links[i].id }) { links[i].access = links[i].access.union(old.access) }
        }
        schemaVersion = requiredSchemaVersion
    }
}
