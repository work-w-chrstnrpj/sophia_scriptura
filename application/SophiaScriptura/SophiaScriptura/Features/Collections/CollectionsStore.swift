import Foundation
import Combine

@MainActor
final class CollectionsStore: ObservableObject {
    @Published private(set) var collections: [StudyCollection]
    @Published private(set) var artifacts: [CollectionArtifact]
    @Published private(set) var memberships: Set<CollectionMembership>
    @Published private(set) var passages: [SavedPassage]
    @Published private(set) var links: [SavedLink]
    @Published private(set) var conversations: [StudyConversation]
    @Published private(set) var notice: String?
    private let repository: (any CollectionsRepository)?
    private var revision = 0
    private var linkedNoteIDs = Set<UUID>()
    private var writeChain: Task<Void, Never>?

    init(
        collections: [StudyCollection],
        artifacts: [CollectionArtifact],
        memberships: Set<CollectionMembership>,
        passages: [SavedPassage] = [],
        links: [SavedLink] = [],
        conversations: [StudyConversation] = [],
        repository: (any CollectionsRepository)? = nil
    ) {
        self.artifacts = artifacts
        self.passages = passages
        self.links = links
        self.conversations = conversations
        self.memberships = Set(memberships.filter { $0.collectionID != StudyCollection.unfiledID })
        self.repository = repository
        if let existing = collections.first(where: \.isUnfiled) {
            var folders = collections.filter { !$0.isUnfiled && $0.id != StudyCollection.unfiledID }
            folders.insert(.unfiled(accent: .noFolder, modifiedAt: existing.modifiedAt), at: 0)
            self.collections = folders
        } else {
            var folders = collections.filter { $0.id != StudyCollection.unfiledID }
            folders.insert(.unfiled(accent: .noFolder), at: 0)
            self.collections = folders
        }
    }

    convenience init(repository: any CollectionsRepository) {
        self.init(collections: [], artifacts: [], memberships: [], repository: repository)
    }

    static func demo() -> CollectionsStore {
        let now = Date()
        let assurance = UUID()
        let romans = UUID()
        let prayer = UUID()

        let artifacts = [
            CollectionArtifact(
                id: UUID(),
                title: "Romans 8:1",
                subtitle: "Saved verse · WEB",
                kind: .scripture,
                modifiedAt: now.addingTimeInterval(-1_800)
            ),
            CollectionArtifact(
                id: UUID(),
                title: "Romans 8 study",
                subtitle: "Note · modified today",
                kind: .note,
                modifiedAt: now.addingTimeInterval(-7_200)
            ),
            CollectionArtifact(
                id: UUID(),
                title: "Why no condemnation?",
                subtitle: "Conversation · 3 messages",
                kind: .conversation,
                modifiedAt: now.addingTimeInterval(-86_400)
            ),
            CollectionArtifact(
                id: UUID(),
                title: "Historical context article",
                subtitle: "Link · example.org",
                kind: .link,
                modifiedAt: now.addingTimeInterval(-172_800)
            )
        ]

        let collections = [
            StudyCollection(
                id: assurance,
                name: "Assurance",
                detail: "Grace, confidence and the security of salvation",
                parentID: nil,
                accent: .oxblood,
                modifiedAt: now.addingTimeInterval(-900)
            ),
            StudyCollection(
                id: romans,
                name: "Romans",
                detail: "Study notes and passages from Romans",
                parentID: assurance,
                accent: .sage,
                modifiedAt: now.addingTimeInterval(-3_600)
            ),
            StudyCollection(
                id: prayer,
                name: "Prayer",
                detail: "Passages and reflections for prayer",
                parentID: nil,
                accent: .gold,
                modifiedAt: now.addingTimeInterval(-259_200)
            )
        ]

        let memberships: Set<CollectionMembership> = [
            CollectionMembership(collectionID: assurance, artifactID: artifacts[0].id),
            CollectionMembership(collectionID: assurance, artifactID: artifacts[1].id),
            CollectionMembership(collectionID: assurance, artifactID: artifacts[2].id),
            CollectionMembership(collectionID: assurance, artifactID: artifacts[3].id),
            CollectionMembership(collectionID: romans, artifactID: artifacts[0].id),
            CollectionMembership(collectionID: romans, artifactID: artifacts[1].id)
        ]

        return CollectionsStore(collections: collections, artifacts: artifacts, memberships: memberships)
    }

    func collection(id: UUID) -> StudyCollection? {
        collections.first { $0.id == id }
    }

    func children(of collectionID: UUID?) -> [StudyCollection] {
        collections.filter { $0.parentID == collectionID && $0.isActiveInLibrary }
    }

    func membershipCount(for collectionID: UUID, includingDescendants: Bool = false, notes: [NoteDocument]? = nil) -> Int {
        let ids = artifactIDs(for: collectionID, includingDescendants: includingDescendants)
        guard let notes else { return ids.count }
        return ids.intersection(Set(presentedArtifacts(notes: notes).map(\.id))).count
    }

    /// Up to `limit` artifact kinds by membership count, for folder preview dots.
    func membershipKindHints(
        for collectionID: UUID,
        notes: [NoteDocument],
        includingDescendants: Bool = true,
        limit: Int = 3
    ) -> [CollectionArtifactKind] {
        let ids = artifactIDs(for: collectionID, includingDescendants: includingDescendants)
        guard !ids.isEmpty else { return [] }
        var counts: [CollectionArtifactKind: Int] = [:]
        for artifact in presentedArtifacts(notes: notes) where ids.contains(artifact.id) {
            counts[artifact.kind, default: 0] += 1
        }
        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key.rawValue < rhs.key.rawValue
            }
            .prefix(limit)
            .map(\.key)
    }

    func artifactIDs(for collectionID: UUID, includingDescendants: Bool) -> Set<UUID> {
        var collectionIDs: Set<UUID> = [collectionID]
        if includingDescendants {
            var pending = [collectionID]
            while let current = pending.popLast() {
                let childIDs = collections.filter { $0.parentID == current }.map(\.id)
                for childID in childIDs where collectionIDs.insert(childID).inserted {
                    pending.append(childID)
                }
            }
        }

        return memberships
            .filter { collectionIDs.contains($0.collectionID) }
            .map(\.artifactID)
            .reduce(into: Set<UUID>()) { $0.insert($1) }
    }

    func artifacts(for collectionID: UUID, includingDescendants: Bool) -> [CollectionArtifact] {
        let ids = artifactIDs(for: collectionID, includingDescendants: includingDescendants)
        return artifacts.filter { ids.contains($0.id) }
    }

    func contains(_ artifactID: UUID, in collectionID: UUID) -> Bool {
        memberships.contains(CollectionMembership(collectionID: collectionID, artifactID: artifactID))
    }

    func toggleMembership(artifactID: UUID, collectionID: UUID) {
        guard let folder = collection(id: collectionID), !folder.isUnfiled else { return }
        guard knownItem(artifactID) else { return }
        let membership = CollectionMembership(collectionID: collectionID, artifactID: artifactID)
        if memberships.contains(membership) {
            memberships.remove(membership)
        } else {
            memberships.insert(membership)
        }
        touch(collectionID)
        enqueueWrite()
    }

    @discardableResult
    func createCollection(name: String, detail: String, parentID: UUID?, accent: CollectionAccent, icon: CollectionIcon = .folder) -> UUID? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        guard trimmedName.localizedCaseInsensitiveCompare("No Folder") != .orderedSame else { return nil }
        if let parentID {
            guard let parent = collection(id: parentID), !parent.isUnfiled else { return nil }
        }
        let id = UUID()
        collections.append(
            StudyCollection(
                id: id,
                name: trimmedName,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                parentID: parentID,
                accent: accent,
                icon: icon,
                modifiedAt: Date()
            )
        )
        if let parentID { touch(parentID) }
        enqueueWrite()
        return id
    }

    func updateAccent(id: UUID, accent: CollectionAccent) {
        guard let index = collections.firstIndex(where: { $0.id == id }), !collections[index].isUnfiled else { return }
        collections[index].accent = accent
        collections[index].modifiedAt = Date()
        enqueueWrite()
    }

    @discardableResult
    func updateCollection(id: UUID, name: String, detail: String, accent: CollectionAccent, icon: CollectionIcon? = nil) -> Bool {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return false }
        if collections[index].isUnfiled { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.localizedCaseInsensitiveCompare("No Folder") != .orderedSame else { return false }
        collections[index].name = trimmed
        collections[index].detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        collections[index].accent = accent
        if let icon {
            collections[index].icon = icon
        }
        collections[index].modifiedAt = Date()
        enqueueWrite()
        return true
    }

    func addMembership(artifactID: UUID, collectionID: UUID) {
        guard let folder = collection(id: collectionID), !folder.isUnfiled, knownItem(artifactID) else { return }
        guard memberships.insert(CollectionMembership(collectionID: collectionID, artifactID: artifactID)).inserted else { return }
        touch(collectionID)
        enqueueWrite()
    }

    /// Adds the destination before removing the source so the item is never left without a home.
    func move(artifactID: UUID, from source: UUID?, to destination: UUID) {
        guard source != destination, let folder = collection(id: destination), !folder.isUnfiled, knownItem(artifactID) else { return }
        memberships.insert(CollectionMembership(collectionID: destination, artifactID: artifactID))
        if let source, collection(id: source)?.isUnfiled == false {
            memberships.remove(CollectionMembership(collectionID: source, artifactID: artifactID))
            touch(source)
        }
        touch(destination)
        enqueueWrite()
    }

    func setMemberships(artifactID: UUID, collectionIDs: Set<UUID>) {
        guard knownItem(artifactID) else { return }
        let valid = Set(collectionIDs.filter { id in collection(id: id).map { !$0.isUnfiled } ?? false })
        let current = self.collectionIDs(containing: artifactID)
        guard valid != current else { return }
        for id in current.subtracting(valid) {
            memberships.remove(CollectionMembership(collectionID: id, artifactID: artifactID))
            touch(id)
        }
        for id in valid.subtracting(current) {
            memberships.insert(CollectionMembership(collectionID: id, artifactID: artifactID))
            touch(id)
        }
        enqueueWrite()
    }

    func collectionIDs(containing artifactID: UUID) -> Set<UUID> {
        Set(memberships.filter { $0.artifactID == artifactID }.map(\.collectionID))
    }

    /// Topic folders in display order with nesting depth; No Folder is never a destination.
    func outline() -> [CollectionOutlineEntry] {
        var result: [CollectionOutlineEntry] = []
        func visit(_ parent: UUID?, depth: Int) {
            let level = collections
                .filter { $0.parentID == parent && !$0.isUnfiled }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            for folder in level {
                result.append(CollectionOutlineEntry(collection: folder, depth: depth))
                visit(folder.id, depth: depth + 1)
            }
        }
        visit(nil, depth: 0)
        return result
    }

    /// Indented library tree for Collections; search flattens to matching folders at their stored depth.
    func libraryOutline(search: String, sort: CollectionLibrarySort) -> [CollectionOutlineEntry] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return outline().filter { entry in
                entry.collection.isActiveInLibrary &&
                    (entry.collection.name.localizedCaseInsensitiveContains(trimmed) ||
                     entry.collection.detail.localizedCaseInsensitiveContains(trimmed))
            }
        }

        let roots = collections.filter { $0.parentID == nil && !$0.isUnfiled && $0.isActiveInLibrary }
        let orderedRoots: [StudyCollection] = switch sort {
        case .name:
            roots.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .modified:
            roots.sorted { $0.modifiedAt > $1.modifiedAt }
        case .itemCount:
            roots.sorted {
                membershipCount(for: $0.id, includingDescendants: true) >
                    membershipCount(for: $1.id, includingDescendants: true)
            }
        }

        var result: [CollectionOutlineEntry] = []
        func visit(_ folder: StudyCollection, depth: Int) {
            result.append(CollectionOutlineEntry(collection: folder, depth: depth))
            let children = collections
                .filter { $0.parentID == folder.id && !$0.isUnfiled && $0.isActiveInLibrary }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            for child in children { visit(child, depth: depth + 1) }
        }
        for root in orderedRoots { visit(root, depth: 0) }
        return result
    }

    /// The most recently touched folder holding the item decides its tint; unfiled items use No Folder.
    func accent(for artifactID: UUID) -> CollectionAccent {
        let ids = collectionIDs(containing: artifactID)
        let owner = collections
            .filter { ids.contains($0.id) }
            .max { $0.modifiedAt < $1.modifiedAt }
        return owner?.accent ?? .noFolder
    }

    func archiveCollection(id: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == id }), !collections[index].isUnfiled else { return }
        collections[index].archivedAt = Date()
        touch(id)
        enqueueWrite()
    }

    func unarchiveCollection(id: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].archivedAt = nil
        touch(id)
        enqueueWrite()
    }

    var archivedCollections: [StudyCollection] {
        collections
            .filter { $0.isArchived }
            .sorted { ($0.archivedAt ?? $0.modifiedAt) > ($1.archivedAt ?? $1.modifiedAt) }
    }

    var trashedCollections: [StudyCollection] {
        collections
            .filter { !$0.isUnfiled && $0.isTrashed }
            .sorted { ($0.trashedAt ?? $0.modifiedAt) > ($1.trashedAt ?? $1.modifiedAt) }
    }

    func moveCollectionToTrash(id: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == id }), !collections[index].isUnfiled else { return }
        let promotedParent = collections[index].parentID
        for childIndex in collections.indices where collections[childIndex].parentID == id {
            collections[childIndex].parentID = promotedParent
        }
        collections[index].trashedAt = Date()
        collections[index].archivedAt = nil
        touch(id)
        enqueueWrite()
    }

    func restoreCollectionFromTrash(id: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].trashedAt = nil
        touch(id)
        enqueueWrite()
    }

    func permanentlyDeleteCollection(id: UUID) {
        guard let removed = collection(id: id), !removed.isUnfiled else { return }
        let promotedParent = removed.parentID
        for index in collections.indices where collections[index].parentID == id {
            collections[index].parentID = promotedParent
        }
        collections.removeAll { $0.id == id }
        memberships = memberships.filter { $0.collectionID != id }
        if let promotedParent { touch(promotedParent) }
        enqueueWrite()
    }

    func deleteCollection(id: UUID) {
        moveCollectionToTrash(id: id)
    }

    func purgeExpiredTrash(now: Date = Date()) {
        let expired = trashedCollections.filter { collection in
            guard let trashedAt = collection.trashedAt else { return false }
            return TrashRetention.isExpired(trashedAt, now: now)
        }.map(\.id)
        guard !expired.isEmpty else { return }
        for id in expired { permanentlyDeleteCollection(id: id) }
    }

    func removeArtifact(_ artifactID: UUID, from collectionID: UUID) {
        guard collection(id: collectionID)?.isUnfiled != true else { return }
        memberships.remove(CollectionMembership(collectionID: collectionID, artifactID: artifactID))
        touch(collectionID)
        enqueueWrite()
    }

    @discardableResult
    func addPassage(_ passage: SavedPassage) -> UUID {
        if passage.kind == .bookmark,
           let existing = passages.first(where: {
               $0.kind == .bookmark && $0.bookID == passage.bookID && $0.chapter == passage.chapter
                   && $0.startVerse == passage.startVerse && $0.endVerse == passage.endVerse
                   && $0.editionID == passage.editionID && $0.passageText == passage.passageText
           }) {
            return existing.id
        }
        passages.append(passage)
        enqueueWrite()
        return passage.id
    }

    func updateInsight(id: UUID, insight: String) {
        guard let index = passages.firstIndex(where: { $0.id == id && $0.kind == .gleaning }) else { return }
        passages[index].insight = String(insight.prefix(2_000))
        enqueueWrite()
    }

    func deletePassage(_ id: UUID) {
        guard passages.contains(where: { $0.id == id }) else { return }
        passages.removeAll { $0.id == id }
        memberships = memberships.filter { $0.artifactID != id }
        enqueueWrite()
    }

    func removeAllCollections() {
        let folderIDs = collections.filter { !$0.isUnfiled }.map(\.id)
        for id in folderIDs { permanentlyDeleteCollection(id: id) }
        memberships.removeAll()
        enqueueWrite()
    }

    func removeAllPassages(kind: SavedPassageKind) {
        let ids = passages.filter { $0.kind == kind }.map(\.id)
        for id in ids { deletePassage(id) }
    }

    func removeAllLinks() {
        let ids = links.map(\.id)
        for id in ids { deleteLink(id) }
    }

    func link(notes: [NoteDocument]) {
        linkedNoteIDs = Set(notes.filter(\.isActiveInLibrary).map(\.id))
    }

    func load() async {
        guard let repository else { return }
        do {
            let result = try await repository.load()
            apply(result.snapshot)
            purgeExpiredTrash()
            notice = result.recovered ? "Recovered the previous Collections revision." : nil
        } catch {
            notice = error.localizedDescription
        }
    }

    func flush() async {
        await writeChain?.value
    }

    func presentedArtifacts(notes: [NoteDocument]) -> [CollectionArtifact] {
        let noteItems = notes.filter(\.isActiveInLibrary).map { note in
            CollectionArtifact(
                id: note.id,
                title: note.title,
                subtitle: "Note · \(note.kind.displayName)",
                kind: .note,
                modifiedAt: note.updatedAt
            )
        }
        let linkItems = links.map { link in
            CollectionArtifact(
                id: link.id,
                title: link.title,
                subtitle: "Link · \(link.url)",
                kind: .link,
                modifiedAt: link.createdAt
            )
        }
        let conversationItems = conversations.map { conversation in
            CollectionArtifact(
                id: conversation.id,
                title: conversation.title,
                subtitle: conversation.isPlaceholder ? "Placeholder · Companion later" : "Conversation",
                kind: .conversation,
                modifiedAt: conversation.createdAt
            )
        }
        let passageItems = passages.map { passage in
            CollectionArtifact(
                id: passage.id,
                title: passage.referenceLabel,
                subtitle: passage.kind == .bookmark ? "Bookmark" : "Gleaning",
                kind: passage.kind == .bookmark ? .bookmark : .gleaning,
                modifiedAt: passage.createdAt,
                passageText: passage.passageText,
                insight: passage.insight
            )
        }
        let covered = Set(noteItems.map(\.id))
            .union(passageItems.map(\.id))
            .union(linkItems.map(\.id))
            .union(conversationItems.map(\.id))
        return artifacts.filter { !covered.contains($0.id) && $0.kind != .note && $0.kind != .conversation } + noteItems + passageItems + linkItems + conversationItems
    }

    func presentedArtifacts(for collectionID: UUID, includingDescendants: Bool, notes: [NoteDocument]) -> [CollectionArtifact] {
        let material = presentedArtifacts(notes: notes)
        if collection(id: collectionID)?.isUnfiled == true {
            let ids = unfiledIDs(in: material)
            return material.filter { ids.contains($0.id) }
        }
        let ids = artifactIDs(for: collectionID, includingDescendants: includingDescendants)
        return material.filter { ids.contains($0.id) }
    }

    func unfiledCount(notes: [NoteDocument]) -> Int {
        unfiledIDs(in: presentedArtifacts(notes: notes)).count
    }

    func passage(id: UUID) -> SavedPassage? {
        passages.first { $0.id == id }
    }

    func link(id: UUID) -> SavedLink? {
        links.first { $0.id == id }
    }

    func conversation(id: UUID) -> StudyConversation? {
        conversations.first { $0.id == id }
    }

    func upsertCompanionConversation(_ conversation: StudyConversation) {
        conversations.removeAll { $0.id == StudyConversation.placeholderID && !conversation.isPlaceholder }
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.append(conversation)
        }
        enqueueWrite()
    }

    func removeCompanionConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        enqueueWrite()
    }

    /// Stores a web link. A blank title uses the site name. Only http and https addresses are accepted.
    @discardableResult
    func addLink(title: String, url: String, verse: VerseID? = nil, editionID: String? = nil) -> UUID? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = parsed.host,
              !host.isEmpty else { return nil }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? host : String(name.prefix(120))
        let link = SavedLink(id: UUID(), title: label, url: trimmed, createdAt: Date(), verse: verse, editionID: editionID)
        links.append(link)
        enqueueWrite()
        return link.id
    }

    func deleteLink(_ id: UUID) {
        guard links.contains(where: { $0.id == id }) else { return }
        links.removeAll { $0.id == id }
        for edge in memberships.filter({ $0.artifactID == id }) {
            memberships.remove(edge)
            touch(edge.collectionID)
        }
        enqueueWrite()
    }

    private func unfiledIDs(in material: [CollectionArtifact]) -> Set<UUID> {
        let filed = Set(memberships.map(\.artifactID))
        return Set(material.map(\.id)).subtracting(filed)
    }

    private func knownItem(_ id: UUID) -> Bool {
        artifacts.contains { $0.id == id && $0.kind != .note && $0.kind != .conversation } || passages.contains { $0.id == id } || links.contains { $0.id == id } || conversations.contains { $0.id == id } || linkedNoteIDs.contains(id)
    }

    private func touch(_ collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        collections[index].modifiedAt = Date()
    }

    private func apply(_ snapshot: CollectionsSnapshot) {
        revision = snapshot.revision
        passages = snapshot.passages
        links = snapshot.links
        conversations = snapshot.conversations
        if !conversations.contains(where: { $0.id == StudyConversation.placeholderID }) {
            conversations.insert(.placeholder(), at: 0)
        }
        memberships = Set(snapshot.memberships.filter { $0.collectionID != StudyCollection.unfiledID })
        var folders = snapshot.collections.filter { !$0.isUnfiled && $0.id != StudyCollection.unfiledID }
        folders.insert(.unfiled(accent: .noFolder), at: 0)
        collections = folders
    }

    func exportBackupSnapshot() -> CollectionsSnapshot {
        exportSnapshot()
    }

    func restoreBackupSnapshot(_ snapshot: CollectionsSnapshot) async {
        apply(snapshot)
        revision = snapshot.revision
        guard let repository else { return }
        do {
            let saved = try await repository.save(exportSnapshot(), expectedRevision: revision)
            revision = saved.revision
            notice = "Collections restored from backup."
        } catch {
            notice = error.localizedDescription
        }
    }

    private func exportSnapshot() -> CollectionsSnapshot {
        CollectionsSnapshot(
            revision: revision,
            collections: collections.filter { !$0.isUnfiled },
            passages: passages,
            links: links,
            conversations: conversations,
            memberships: Array(memberships),
            unfiledAccent: .noFolder
        )
    }

    private func enqueueWrite() {
        guard repository != nil else { return }
        let previous = writeChain
        writeChain = Task { @MainActor in
            await previous?.value
            guard let repository = self.repository else { return }
            let snapshot = self.exportSnapshot()
            let expected = self.revision
            do {
                let saved = try await repository.save(snapshot, expectedRevision: expected)
                self.revision = saved.revision
            } catch {
                self.notice = error.localizedDescription
            }
        }
    }
}
