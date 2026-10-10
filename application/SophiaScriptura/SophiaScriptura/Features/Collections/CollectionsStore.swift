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
    var protection = ItemProtectionSession.shared
    private(set) var recoveredOlderGeneration = false
    private var revision = 0
    @Published var sophyOpenCollectionID: UUID?
    private var sophyCommitInFlight = false
    private var linkedNoteIDs = Set<UUID>()
    private var linkedNoteBindings: [UUID: UUID] = [:]
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

    /// Notes filed in a locked collection, or in any folder nested under one, stay out of the Notes library.
    /// Depth does not matter. Membership in any locked folder is enough. The note's own lock is separate.
    func concealsNote(_ noteID: UUID) -> Bool {
        let hidden = folderIDsHiddenFromNotes()
        return collectionIDs(containing: noteID).contains { hidden.contains($0) || isLocked($0) }
    }

    /// Locked folders plus every nested folder beneath them. The walk has no depth limit.
    func folderIDsHiddenFromNotes() -> Set<UUID> {
        var hidden = Set<UUID>()
        var pending: [UUID] = []
        for folder in collections where !folder.isUnfiled && protection.isLocked(folder.protectionID, in: .collections) {
            if hidden.insert(folder.id).inserted { pending.append(folder.id) }
        }
        while let current = pending.popLast() {
            for child in collections where child.parentID == current && child.id != StudyCollection.unfiledID {
                if hidden.insert(child.id).inserted { pending.append(child.id) }
            }
        }
        return hidden
    }

    /// An editor opened from a collection keeps that route's access, independently of library visibility.
    func allowsNoteOpening(_ noteID: UUID, from collectionID: UUID? = nil) -> Bool {
        guard let collectionID else { return !concealsNote(noteID) }
        guard !isLocked(collectionID), let folder = collection(id: collectionID), (folder.isUnfiled || folder.isActiveInLibrary) else { return false }
        if folder.isUnfiled { return self.collectionIDs(containing: noteID).isEmpty }
        return artifactIDs(for: collectionID, includingDescendants: true).contains(noteID)
    }

    func canRevealNoteMetadata(_ note: NoteDocument) -> Bool {
        !protection.isLocked(note.protectionID, in: .notes) && !concealsNote(note.id)
    }

    func searchableNoteText(_ note: NoteDocument) -> String {
        canRevealNoteMetadata(note) ? note.searchableText : note.title
    }

    func visibleNoteTags(in notes: [NoteDocument]) -> [String] {
        Array(Set(notes.filter(canRevealNoteMetadata).flatMap(\.tags))).sorted()
    }

    /// A child route requires access through every protected ancestor, without protecting member notes.
    func isLocked(_ id: UUID) -> Bool {
        var current: UUID? = id; var seen = Set<UUID>()
        while let next = current {
            guard seen.insert(next).inserted, let folder = collection(id: next) else { return true }
            if protection.isLocked(folder.protectionID, in: .collections) { return true }
            current = folder.parentID
        }
        return false
    }
    func requestAccess(_ id: UUID) async {
        do {
            var current: UUID? = id; var seen = Set<UUID>(); var bindings: [UUID] = []
            while let next = current {
                guard seen.insert(next).inserted, let folder = collection(id: next) else { throw ItemLockError.locked }
                if let binding = folder.protectionID { bindings.append(binding) }; current = folder.parentID
            }
            for binding in bindings { try await protection.request(binding: binding, in: .collections) }
            guard !isLocked(id) else { throw ItemLockError.locked }
            protection.activity(in: .collections)
        } catch { if case ItemLockError.cancelled = error {} else { notice = error.localizedDescription } }
    }
    func setProtected(_ id: UUID, enabled: Bool) async {
        guard !rejectWhileSophyCommits() else { return }

        guard let original = collection(id: id), !original.isUnfiled else { return }
        do {
            if let parent = original.parentID { await requestAccess(parent); guard !isLocked(parent) else { throw ItemLockError.locked } }
            if !enabled {
                try await protection.confirmRemoval(binding: original.protectionID, in: .collections)
            } else if original.protectionID == nil {
                try await protection.authenticate([.collections], setupIfNeeded: true)
            } else {
                try await protection.request(binding: original.protectionID, in: .collections)
            }
            try protection.require([original.protectionID ?? protection.credential?.id], in: .collections)
            guard let i = collections.firstIndex(where: { $0.id == id }), collections[i].protectionID == original.protectionID else { return }
            guard !rejectWhileSophyCommits() else { return }
            collections[i].protectionID = enabled ? protection.credential?.id : nil
            touch(id); enqueueWrite(); await flush()
        } catch { if case ItemLockError.cancelled = error {} else { notice = error.localizedDescription } }
    }
    private func allowChanges(_ ids: Set<UUID>) -> Bool {
        guard !ids.contains(where: isLocked) else { notice = ItemLockError.locked.localizedDescription; return false }
        protection.activity(in: .collections); return true
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
        guard !isLocked(collectionID) else { return [] }
        var collectionIDs: Set<UUID> = [collectionID]
        if includingDescendants {
            var pending = [collectionID]
            while let current = pending.popLast() {
                let childIDs = collections.filter { $0.parentID == current }.map(\.id)
                for childID in childIDs where !isLocked(childID) && collectionIDs.insert(childID).inserted {
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
        guard !rejectWhileSophyCommits() else { return }
        guard allowChanges([collectionID]) else { return }
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
        guard !rejectWhileSophyCommits() else { return nil }
        if let parentID { guard allowChanges([parentID]) else { return nil } }
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
        guard !rejectWhileSophyCommits() else { return }

        guard allowChanges([id]) else { return }
        guard let index = collections.firstIndex(where: { $0.id == id }), !collections[index].isUnfiled else { return }
        collections[index].accent = accent
        collections[index].modifiedAt = Date()
        enqueueWrite()
    }

    @discardableResult
    func updateCollection(id: UUID, name: String, detail: String, accent: CollectionAccent, icon: CollectionIcon? = nil) -> Bool {
        guard !rejectWhileSophyCommits() else { return false }

        guard allowChanges([id]) else { return false }
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
        guard !rejectWhileSophyCommits() else { return }

        guard allowChanges([collectionID]) else { return }
        guard let folder = collection(id: collectionID), !folder.isUnfiled, knownItem(artifactID) else { return }
        guard memberships.insert(CollectionMembership(collectionID: collectionID, artifactID: artifactID)).inserted else { return }
        touch(collectionID)
        enqueueWrite()
    }

    /// Adds the destination before removing the source so the item is never left without a home.
    @discardableResult
    func move(artifactID: UUID, from source: UUID?, to destination: UUID) -> Bool {
        guard !rejectWhileSophyCommits() else { return false }

        guard allowChanges(Set([source, destination].compactMap { $0 })) else { return false }
        guard let folder = collection(id: destination), !folder.isUnfiled, knownItem(artifactID) else {
            notice = "The item or destination is no longer available."; return false
        }
        guard source != destination else { return true }
        memberships.insert(CollectionMembership(collectionID: destination, artifactID: artifactID))
        if let source, collection(id: source)?.isUnfiled == false {
            memberships.remove(CollectionMembership(collectionID: source, artifactID: artifactID))
            touch(source)
        }
        touch(destination)
        enqueueWrite()
        return true
    }

    @discardableResult
    func setMemberships(artifactID: UUID, collectionIDs: Set<UUID>) -> Bool {
        guard !rejectWhileSophyCommits() else { return false }

        let current = self.collectionIDs(containing: artifactID)
        let proposed = collectionIDs.subtracting([StudyCollection.unfiledID])
        let changed = proposed.symmetricDifference(current)
        guard allowChanges(changed) else { return false }
        guard knownItem(artifactID) else { notice = "Unlock the note or check that the item still exists."; return false }
        let valid = Set(proposed.filter { id in collection(id: id).map { !$0.isUnfiled } ?? false })
        guard valid == proposed else { notice = "A selected collection is no longer available."; return false }
        guard valid != current else { return true }
        for id in current.subtracting(valid) {
            memberships.remove(CollectionMembership(collectionID: id, artifactID: artifactID))
            touch(id)
        }
        for id in valid.subtracting(current) {
            memberships.insert(CollectionMembership(collectionID: id, artifactID: artifactID))
            touch(id)
        }
        enqueueWrite()
        return true
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
        guard !rejectWhileSophyCommits() else { return }

        protection.cancel(affecting: [.collections])
        guard let index = collections.firstIndex(where: { $0.id == id }), !collections[index].isUnfiled else { return }
        collections[index].archivedAt = Date()
        touch(id)
        enqueueWrite()
    }

    func unarchiveCollection(id: UUID) {
        guard !rejectWhileSophyCommits() else { return }

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
        guard !rejectWhileSophyCommits() else { return }

        protection.cancel(affecting: [.collections])
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
        guard !rejectWhileSophyCommits() else { return }

        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].trashedAt = nil
        touch(id)
        enqueueWrite()
    }

    func permanentlyDeleteCollection(id: UUID) {
        guard !rejectWhileSophyCommits() else { return }

        protection.cancel(affecting: [.collections])
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
        guard !rejectWhileSophyCommits() else { return }

        let expired = trashedCollections.filter { collection in
            guard let trashedAt = collection.trashedAt else { return false }
            return TrashRetention.isExpired(trashedAt, now: now)
        }.map(\.id)
        guard !expired.isEmpty else { return }
        for id in expired { permanentlyDeleteCollection(id: id) }
    }

    func removeArtifact(_ artifactID: UUID, from collectionID: UUID) {
        guard !rejectWhileSophyCommits() else { return }

        guard noteAccessAllows(artifactID) else { return }
        guard allowChanges([collectionID]) else { return }
        guard collection(id: collectionID)?.isUnfiled != true else { return }
        memberships.remove(CollectionMembership(collectionID: collectionID, artifactID: artifactID))
        touch(collectionID)
        enqueueWrite()
    }

    @discardableResult
    func addPassage(_ passage: SavedPassage) -> UUID {
        guard !rejectWhileSophyCommits() else { return passage.id }

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
        guard !rejectWhileSophyCommits() else { return }

        guard let index = passages.firstIndex(where: { $0.id == id && $0.kind == .gleaning }) else { return }
        passages[index].insight = String(insight.prefix(2_000))
        enqueueWrite()
    }

    func deletePassage(_ id: UUID) {
        guard !rejectWhileSophyCommits() else { return }

        guard passages.contains(where: { $0.id == id }) else { return }
        passages.removeAll { $0.id == id }
        memberships = memberships.filter { $0.artifactID != id }
        enqueueWrite()
    }

    func removeAllCollections() {
        guard !rejectWhileSophyCommits() else { return }

        protection.lock([.collections])
        let folderIDs = collections.filter { !$0.isUnfiled }.map(\.id)
        for id in folderIDs { permanentlyDeleteCollection(id: id) }
        memberships.removeAll()
        enqueueWrite()
    }

    func removeAllPassages(kind: SavedPassageKind) {
        guard !rejectWhileSophyCommits() else { return }

        let ids = passages.filter { $0.kind == kind }.map(\.id)
        for id in ids { deletePassage(id) }
    }

    func removeAllLinks() {
        guard !rejectWhileSophyCommits() else { return }

        let ids = links.map(\.id)
        for id in ids { deleteLink(id) }
    }

    func link(notes: [NoteDocument]) {
        linkedNoteBindings = Dictionary(uniqueKeysWithValues: notes.compactMap { note in note.protectionID.map { (note.id, $0) } })
        linkedNoteIDs = Set(notes.filter(\.isActiveInLibrary).map(\.id))
    }

    func load() async {
        guard let repository else { return }
        do {
            let result = try await repository.load()
            recoveredOlderGeneration = result.recovered
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
        guard !isLocked(collectionID) else { return [] }
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
        if sophyCommitInFlight {
            Task { @MainActor in
                while self.sophyCommitInFlight { await Task.yield() }
                self.upsertCompanionConversation(conversation)
            }
            return
        }

        conversations.removeAll { $0.id == StudyConversation.placeholderID && !conversation.isPlaceholder }
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.append(conversation)
        }
        enqueueWrite()
    }

    func removeCompanionConversation(_ id: UUID) {
        if sophyCommitInFlight {
            Task { @MainActor in
                while self.sophyCommitInFlight { await Task.yield() }
                self.removeCompanionConversation(id)
            }
            return
        }

        conversations.removeAll { $0.id == id }
        enqueueWrite()
    }

    /// Stores a web link. A blank title uses the site name. Only http and https addresses are accepted.
    @discardableResult
    func addLink(title: String, url: String, verse: VerseID? = nil, editionID: String? = nil) -> UUID? {
        guard !rejectWhileSophyCommits() else { return nil }

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
        guard !rejectWhileSophyCommits() else { return }

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

    private func noteAccessAllows(_ id: UUID) -> Bool {
        guard !protection.isLocked(linkedNoteBindings[id], in: .notes) else {
            notice = ItemLockError.locked.localizedDescription
            return false
        }
        return true
    }

    private func knownItem(_ id: UUID) -> Bool {
        guard noteAccessAllows(id) else { return false }
        return artifacts.contains { $0.id == id && $0.kind != .note && $0.kind != .conversation } || passages.contains { $0.id == id } || links.contains { $0.id == id } || conversations.contains { $0.id == id } || linkedNoteIDs.contains(id)
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

    func exportBackupSnapshot() throws -> CollectionsSnapshot {
        try protection.require(collections.map(\.protectionID), in: .collections)
        return exportSnapshot()
    }

    func restoreBackupSnapshot(_ snapshot: CollectionsSnapshot) async {
        guard !rejectWhileSophyCommits() else { return }

        do {
            try protection.require(collections.map(\.protectionID), in: .collections)
            guard (1...2).contains(snapshot.schemaVersion) else { throw CollectionsError.unsupported }
            await flush()
            try protection.require(collections.map(\.protectionID), in: .collections)
            var restored = snapshot
            for i in restored.collections.indices where restored.collections[i].protectionID == nil {
                restored.collections[i].protectionID = collection(id: restored.collections[i].id)?.protectionID
            }
            restored.revision = revision
            restored.schemaVersion = restored.collections.contains(where: { $0.protectionID != nil }) ? 2 : 1
            protection.lock([.collections])
            if let repository {
                let saved = try await repository.save(restored, expectedRevision: revision)
                apply(saved)
            } else { apply(restored) }
            notice = "Collections restored from backup."
        } catch { notice = error.localizedDescription }
    }

    private func exportSnapshot() -> CollectionsSnapshot {
        CollectionsSnapshot(
            schemaVersion: collections.contains(where: { $0.protectionID != nil }) ? 2 : 1,
            revision: revision,
            collections: collections.filter { !$0.isUnfiled },
            passages: passages,
            links: links,
            conversations: conversations,
            memberships: Array(memberships),
            unfiledAccent: .noFolder
        )
    }

    /// Creates every folder in one snapshot and publishes it only after the repository save succeeds.
    func createTreeFromSophy(_ nodes: [SophyFolderCommit], destinationID: UUID?) async -> SophyCommitOutcome {
        guard !sophyCommitInFlight else { return .rejected(.busy) }
        sophyCommitInFlight = true
        defer { sophyCommitInFlight = false }
        await flush()
        guard !nodes.isEmpty, nodes.count <= 100 else { return .rejected(.invalidArguments) }
        guard Set(nodes.map(\.id)).count == nodes.count else { return .rejected(.invalidArguments) }
        if nodes.contains(where: { node in collections.contains { $0.id == node.id } || node.id == StudyCollection.unfiledID }) {
            let present = nodes.map(\.id).filter { id in collections.contains { $0.id == id } }
            return present.count == nodes.count ? .alreadyCommitted(resultIDs: nodes.map(\.id)) : .rejected(.stalePlan)
        }
        if let destinationID {
            guard let destination = collection(id: destinationID), !destination.isUnfiled, destination.isActiveInLibrary else {
                return .rejected(.stalePlan)
            }
            if sophyFolderIsProtected(destinationID) { return .rejected(.accessDenied) }
        }
        var parentByID: [UUID: UUID?] = [:]
        for node in nodes {
            let name = node.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= 120, node.detail.count <= 2_000 else { return .rejected(.invalidArguments) }
            guard name.localizedCaseInsensitiveCompare("No Folder") != .orderedSame else { return .rejected(.invalidArguments) }
            let parent = node.parentID ?? destinationID
            if let parent {
                let parentIsNew = nodes.contains { $0.id == parent }
                if !parentIsNew {
                    guard let existing = collection(id: parent), !existing.isUnfiled, existing.isActiveInLibrary else { return .rejected(.stalePlan) }
                    if sophyFolderIsProtected(parent) { return .rejected(.accessDenied) }
                }
            }
            let siblings = collections.filter { $0.parentID == parent && !$0.isUnfiled && $0.isActiveInLibrary }
            let newSiblings = nodes.filter { ($0.parentID ?? destinationID) == parent && $0.id != node.id }
            let names = siblings.map(\.name) + newSiblings.map(\.name)
            if names.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(name) == .orderedSame }) && !node.allowDuplicateName {
                return .rejected(.invalidArguments)
            }
            parentByID[node.id] = parent
        }
        if treeHasCycle(parentByID) { return .rejected(.invalidArguments) }
        var snapshot = exportSnapshot()
        let now = Date()
        for node in nodes {
            snapshot.collections.append(StudyCollection(
                id: node.id,
                name: node.name.trimmingCharacters(in: .whitespacesAndNewlines),
                detail: node.detail.trimmingCharacters(in: .whitespacesAndNewlines),
                parentID: parentByID[node.id] ?? nil,
                accent: .preset,
                icon: .folder,
                modifiedAt: now
            ))
        }
        if let repository {
            do {
                let saved = try await repository.save(snapshot, expectedRevision: revision)
                apply(saved)
                return .committed(resultIDs: nodes.map(\.id))
            } catch CollectionsError.stale {
                return .rejected(.stalePlan)
            } catch {
                return .uncertain(resultIDs: nodes.map(\.id))
            }
        }
        snapshot.revision = revision
        apply(snapshot)
        return .committed(resultIDs: nodes.map(\.id))
    }

    private func rejectWhileSophyCommits() -> Bool {
        guard sophyCommitInFlight else { return false }
        notice = SophySafeError.busy.message
        return true
    }

    func sophyFolderIsProtected(_ id: UUID) -> Bool {
        var current: UUID? = id
        var seen = Set<UUID>()
        while let next = current {
            guard seen.insert(next).inserted, let folder = collection(id: next) else { return true }
            if folder.protectionID != nil { return true }
            current = folder.parentID
        }
        return false
    }

    private func treeHasCycle(_ parents: [UUID: UUID?]) -> Bool {
        func visit(_ id: UUID, trail: Set<UUID>) -> Bool {
            guard let parent = parents[id] ?? nil else { return false }
            if trail.contains(parent) { return true }
            if parents[parent] != nil { return visit(parent, trail: trail.union([id])) }
            return false
        }
        return parents.keys.contains { visit($0, trail: []) }
    }

    private func enqueueWrite() {
        guard !sophyCommitInFlight else {
            notice = SophySafeError.busy.message
            return
        }
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
