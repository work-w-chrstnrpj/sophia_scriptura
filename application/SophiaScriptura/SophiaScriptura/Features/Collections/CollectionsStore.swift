import Foundation
import Combine
import CryptoKit

@MainActor
final class CollectionsStore: ObservableObject {
    @Published private(set) var collections: [StudyCollection]
    @Published private(set) var artifacts: [CollectionArtifact]
    @Published private(set) var memberships: Set<CollectionMembership>
    @Published private(set) var pointsToPonder: [PointToPonder] = []
    @Published private(set) var passages: [SavedPassage]
    @Published private(set) var savedAnnotations: [SavedAnnotation]
    @Published private(set) var links: [SavedLink]
    @Published private(set) var conversations: [StudyConversation]
    @Published private(set) var notice: String?
    private let repository: (any CollectionsRepository)?
    var protection = ItemProtectionSession.shared
    private(set) var recoveredOlderGeneration = false
    private var revision = 0
    private var unfiledAccent: CollectionAccent = .noFolder
    @Published var sophyOpenCollectionID: UUID?
    private var sophyCommitInFlight = false
    private var linkedNoteIDs = Set<UUID>()
    private var linkedNoteBindings: [UUID: UUID] = [:]
    private var linkedNoteAccess: [UUID: StudyAccessRequirements] = [:]
    private var writeChain: Task<StudyCommitResult, Never>?
    @Published private(set) var plans: [StudyPlan] = []
    @Published private(set) var persistenceUncertain = false
    private var planLifecycleActivated = false
    private var planTreeTrash: [PlanTreeTrash] = []
    private var planFormatActivated = false
    private var planOperations: [PlanOperation] = []
    private var commandReceipts: [StudyCommandReceipt] = []
    private var retainedPlanAccess: [RetainedPlanAccess] = []
    private var committedState: CollectionsSnapshot?
    private var legacyBaseline: CollectionsSnapshot?
    private var pendingLegacy: [(UUID, CollectionsLegacyPatch)] = []
    weak var planNotes: NotesSession?
    weak var planCompanion: CompanionSession?
    var validatePlanReference: ((PlanItemPayload, String) async throws -> Void)?
    @Published var studyMutationBlocked = false

    init(
        collections: [StudyCollection],
        artifacts: [CollectionArtifact],
        memberships: Set<CollectionMembership>,
        passages: [SavedPassage] = [],
        savedAnnotations: [SavedAnnotation] = [],
        links: [SavedLink] = [],
        conversations: [StudyConversation] = [],
        repository: (any CollectionsRepository)? = nil
    ) {
        self.artifacts = artifacts
        self.passages = passages
        self.savedAnnotations = savedAnnotations
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
        committedState = exportSnapshot(); legacyBaseline = exportSnapshot()
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
        if let requirements = linkedNoteAccess[noteID], !accessAllowed(requirements) { return true }
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
        if folder.isUnfiled { return !concealsNote(noteID) && !hasFiledMembership(noteID) }
        return artifactIDs(for: collectionID, includingDescendants: true).contains(noteID)
    }

    func canRevealNoteMetadata(_ note: NoteDocument) -> Bool {
        !protection.isLocked(note.protectionID, in: .notes) && accessAllowed(note.access) && !concealsNote(note.id)
    }

    func searchableNoteText(_ note: NoteDocument) -> String {
        guard accessAllowed(note.access) else { return "" }
        return canRevealNoteMetadata(note) ? note.searchableText : note.title
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

    private func arrangedForDisplay(_ folders: [StudyCollection], parentName: String) -> [StudyCollection] {
        let names = folders.map(\.name)
        if BibleCollectionOrder.prefersScriptureOrder(parentName: parentName, childNames: names) {
            return BibleCollectionOrder.sorted(folders, name: \.name)
        }
        if BibleCollectionOrder.prefersNumberOrder(names) {
            return BibleCollectionOrder.sorted(folders, name: \.name, scripture: false)
        }
        return folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func membershipCount(for collectionID: UUID, includingDescendants: Bool = false, notes: [NoteDocument]? = nil, annotationSnapshot: AnnotationSnapshot? = nil) -> Int {
        let ids = artifactIDs(for: collectionID, includingDescendants: includingDescendants)
        guard let notes else { return ids.count }
        return ids.intersection(Set(presentedArtifacts(notes: notes, annotationSnapshot: annotationSnapshot).map(\.id))).count
    }

    /// Up to `limit` artifact kinds by membership count, for folder preview dots.
    func membershipKindHints(
        for collectionID: UUID,
        notes: [NoteDocument],
        includingDescendants: Bool = true,
        limit: Int = 3,
        annotationSnapshot: AnnotationSnapshot? = nil
    ) -> [CollectionArtifactKind] {
        let ids = artifactIDs(for: collectionID, includingDescendants: includingDescendants)
        guard !ids.isEmpty else { return [] }
        var counts: [CollectionArtifactKind: Int] = [:]
        for artifact in presentedArtifacts(notes: notes, annotationSnapshot: annotationSnapshot) where ids.contains(artifact.id) {
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

    /// Copies folder identities and optionally membership edges, never the linked artifacts.
    func duplicateCollection(_ id: UUID, includeContents: Bool) async -> UUID? {
        guard !rejectWhileSophyCommits() else { return nil }
        sophyCommitInFlight = true
        defer { sophyCommitInFlight = false }
        await flush()
        guard let root = collection(id: id), !root.isUnfiled, root.isActiveInLibrary else { return nil }
        var originals = [root], visited: Set<UUID> = [id], pending = [id]
        while let parent = pending.popLast() {
            for child in children(of: parent) where visited.insert(child.id).inserted {
                originals.append(child); pending.append(child.id)
            }
        }
        guard allowChanges(visited.union(Set([root.parentID].compactMap { $0 }))) else { return nil }
        let mapping = Dictionary(uniqueKeysWithValues: originals.map { ($0.id, UUID()) })
        var value = exportSnapshot()
        let now = Date()
        for original in originals {
            value.collections.append(StudyCollection(
                protectionID: original.protectionID,
                id: mapping[original.id]!,
                name: original.id == id ? String(original.name.prefix(113)) + " (Copy)" : original.name,
                detail: original.detail,
                parentID: original.id == id ? original.parentID : original.parentID.flatMap { mapping[$0] },
                accent: original.accent, icon: original.icon, modifiedAt: now
            ))
        }
        if includeContents {
            let edges = memberships.filter { visited.contains($0.collectionID) }
            guard edges.allSatisfy({ noteAccessAllows($0.artifactID) }) else { return nil }
            value.memberships.append(contentsOf: edges.map { CollectionMembership(collectionID: mapping[$0.collectionID]!, artifactID: $0.artifactID) })
        }
        do {
            let result = await commitLegacySnapshot(value)
            guard result.receipt != nil else { notice = result.message; return nil }
            return mapping[id]
        } catch { notice = error.localizedDescription; return nil }
    }

    /// Reparent the folder as a unit; memberships and descendants keep their identities.
    func canMoveCollection(_ id: UUID, to parentID: UUID?) -> Bool {
        guard let folder = collection(id: id), folder.isActiveInLibrary,
              !isLocked(id), folder.parentID != parentID else { return false }
        if let parentID {
            guard let target = collection(id: parentID), target.isActiveInLibrary,
                  !isLocked(parentID) else { return false }
            var current: UUID? = parentID
            var seen = Set<UUID>()
            while let next = current {
                guard next != id, seen.insert(next).inserted,
                      let ancestor = collection(id: next), ancestor.isActiveInLibrary else { return false }
                current = ancestor.parentID
            }
        }
        return true
    }

    @discardableResult
    func moveCollection(id: UUID, to parentID: UUID?) -> Bool {
        guard !rejectWhileSophyCommits() else { return false }
        guard canMoveCollection(id, to: parentID) else {
            notice = "Choose a different unlocked folder outside this folder’s own subfolders."
            return false
        }
        guard allowChanges(Set([id, parentID].compactMap { $0 })),
              let index = collections.firstIndex(where: { $0.id == id }) else { return false }
        let oldParent = collections[index].parentID
        collections[index].parentID = parentID
        collections[index].modifiedAt = Date()
        if let oldParent { touch(oldParent) }
        if let parentID { touch(parentID) }
        notice = nil
        enqueueWrite()
        return true
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
    func updateUnfiledAccent(_ accent: CollectionAccent) -> Bool {
        guard !rejectWhileSophyCommits() else { return false }
        guard let index = collections.firstIndex(where: \.isUnfiled) else { return false }
        unfiledAccent = accent
        collections[index].accent = accent
        collections[index].modifiedAt = Date()
        enqueueWrite()
        return true
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
            let level = collections.filter { $0.parentID == parent && $0.isActiveInLibrary }
            let ordered = arrangedForDisplay(level, parentName: parent.flatMap { collection(id: $0)?.name } ?? "")
            for folder in ordered {
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
            let children = arrangedForDisplay(
                collections.filter { $0.parentID == folder.id && !$0.isUnfiled && $0.isActiveInLibrary },
                parentName: folder.name
            )
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
        if let plan = planOwningFolder(id) { Task { _ = await setPlanTreeTrashed(plan.id, trashed: true) }; return }
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
        if let record = planTreeTrash.first(where: { $0.folderIDs.contains(id) }), let planID = record.planIDs.first {
            Task { _ = await setPlanTreeTrashed(planID, trashed: false) }; return
        }
        guard !rejectWhileSophyCommits() else { return }

        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].trashedAt = nil
        touch(id)
        enqueueWrite()
    }

    func permanentlyDeleteCollection(id: UUID) {
        if let record = planTreeTrash.first(where: { $0.folderIDs.contains(id) }), let planID = record.planIDs.first {
            Task { _ = await submit(.init(expectedPlanRevision: plans.first(where: { $0.id == planID })?.revision, intent: .purgePlan(planID))) }; return
        }
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
        for plan in plans where plan.trashedAt.map({ TrashRetention.isExpired($0, now: now) }) == true && planAccessAllowed(plan) {
            Task { _ = await submit(.init(expectedPlanRevision: plan.revision, intent: .purgePlan(plan.id))) }
        }
        for point in pointsToPonder where point.trashedAt.map({ TrashRetention.isExpired($0, now: now) }) == true { permanentlyDeletePoint(point.id) }
        guard !expired.isEmpty else { return }
        for id in expired { permanentlyDeleteCollection(id: id) }
    }

    func removeArtifact(_ artifactID: UUID, from collectionID: UUID) {
        guard !rejectWhileSophyCommits() else { return }

        guard noteAccessAllows(artifactID) else { return }
        guard allowChanges([collectionID]) else { return }
        guard collection(id: collectionID)?.isUnfiled != true else { return }
        if plans.contains(where: { $0.id == artifactID && $0.materialsFolderID == collectionID }) { notice = "The Plan must remain in its Plan folder."; return }
        memberships.remove(CollectionMembership(collectionID: collectionID, artifactID: artifactID))
        touch(collectionID)
        enqueueWrite()
    }

    @discardableResult
    func registerAnnotation(
        layerID: UUID,
        groupID: UUID,
        source: AnnotationSource,
        bookTitle: String,
        layerName: String
    ) -> UUID {
        guard !rejectWhileSophyCommits() else { return layerID }

        let trimmedTitle = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = String(layerName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        if let index = savedAnnotations.firstIndex(where: { $0.id == layerID }) {
            savedAnnotations[index].groupID = groupID
            savedAnnotations[index].source = source
            savedAnnotations[index].bookTitle = trimmedTitle.isEmpty ? savedAnnotations[index].bookTitle : trimmedTitle
            savedAnnotations[index].layerName = trimmedName.isEmpty ? savedAnnotations[index].layerName : trimmedName
        } else {
            savedAnnotations.append(
                SavedAnnotation(
                    id: layerID,
                    groupID: groupID,
                    source: source,
                    bookTitle: trimmedTitle.isEmpty ? source.book : trimmedTitle,
                    layerName: trimmedName.isEmpty ? "Layer" : trimmedName,
                    savedAt: Date()
                )
            )
        }
        enqueueWrite()
        return layerID
    }

    func deleteAnnotationReference(_ id: UUID) {
        guard !rejectWhileSophyCommits(), savedAnnotations.contains(where: { $0.id == id }),
              allowChanges(Set(memberships.filter { $0.artifactID == id }.map(\.collectionID))) else { return }
        savedAnnotations.removeAll { $0.id == id }
        artifacts.removeAll { $0.id == id }
        memberships = memberships.filter { $0.artifactID != id }
        enqueueWrite()
    }

    func savedAnnotation(id: UUID) -> SavedAnnotation? {
        savedAnnotations.first { $0.id == id }
    }

    func collectionNames(containing artifactID: UUID) -> [String] {
        collectionIDs(containing: artifactID)
            .compactMap { collection(id: $0)?.name }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    @discardableResult
    func addPointToPonder(question: String, collectionID: UUID) -> UUID? {
        guard !rejectWhileSophyCommits(), allowChanges([collectionID]),
              let folder = collection(id: collectionID), folder.isUnfiled || folder.isActiveInLibrary else { return nil }
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, question.count <= 200 else { notice = "Enter a question of up to 200 characters."; return nil }
        let point = PointToPonder(id: UUID(), question: question, createdAt: Date())
        pointsToPonder.append(point)
        if !folder.isUnfiled { memberships.insert(CollectionMembership(collectionID: collectionID, artifactID: point.id)) }
        touch(collectionID)
        enqueueWrite()
        return point.id
    }

    func trashPoint(_ id: UUID) {
        guard !rejectWhileSophyCommits(), let index = pointsToPonder.firstIndex(where: { $0.id == id }) else { return }
        pointsToPonder[index].trashedAt = Date()
        enqueueWrite()
    }

    func restorePoint(_ id: UUID) {
        guard !rejectWhileSophyCommits(), let index = pointsToPonder.firstIndex(where: { $0.id == id }) else { return }
        pointsToPonder[index].trashedAt = nil
        enqueueWrite()
    }

    func permanentlyDeletePoint(_ id: UUID) {
        guard !rejectWhileSophyCommits(), pointsToPonder.contains(where: { $0.id == id && $0.trashedAt != nil }) else { return }
        pointsToPonder.removeAll { $0.id == id }
        memberships = memberships.filter { $0.artifactID != id }
        enqueueWrite()
    }

    @discardableResult func turnBookmarkToGleaning(_ id: UUID) -> Bool {
        guard !rejectWhileSophyCommits(), let index = passages.firstIndex(where: { $0.id == id && $0.kind == .bookmark }) else { return false }
        passages[index].kind = .gleaning
        enqueueWrite()
        return true
    }

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
        linkedNoteAccess = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0.access) })
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
            persistenceUncertain = true
            notice = error.localizedDescription
        }
    }

    func flush() async {
        _ = await writeChain?.value
    }

    func presentedArtifacts(notes: [NoteDocument], annotationSnapshot: AnnotationSnapshot? = nil) -> [CollectionArtifact] {
        let pointItems = pointsToPonder.filter { $0.trashedAt == nil }.map {
            CollectionArtifact(id: $0.id, title: $0.question, subtitle: "Point to Ponder", kind: .pointToPonder, modifiedAt: $0.createdAt)
        }
        let noteItems = notes.filter { $0.isActiveInLibrary && accessAllowed($0.access) }.map { note in
            CollectionArtifact(
                id: note.id,
                title: note.title,
                subtitle: "Note · \(note.kind.displayName)",
                kind: .note,
                modifiedAt: note.updatedAt
            )
        }
        let linkItems = links.filter { accessAllowed($0.access) && !collectionIDs(containing: $0.id).contains(where: isLocked) }.map { link in
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
        let annotationItems = savedAnnotations.compactMap { saved -> CollectionArtifact? in
            if let annotationSnapshot, let layer = AnnotationCollectionCatalog.resolveLayer(layerID: saved.id, in: annotationSnapshot), layer.deleted { return nil }
            return AnnotationCollectionCatalog.artifact(for: saved, snapshot: annotationSnapshot)
        }
        let planItems = plans.filter { $0.isActive && planAccessAllowed($0) }.map {
            CollectionArtifact(id: $0.id, title: $0.title, subtitle: "Plan · \($0.completedSectionCount)/\($0.sections.count) sections complete", kind: .plan, modifiedAt: $0.modifiedAt, isPlanComplete: $0.isComplete)
        }
        let readingItems: [CollectionArtifact] = plans.filter { $0.isActive && planAccessAllowed($0) }.flatMap { plan in
            plan.items.filter { $0.payload.kind == .scripture }.map { item in
                CollectionArtifact(id: item.id, title: item.payload.referenceLabel,
                    subtitle: "Scripture · \(plan.title)", kind: .scripture, modifiedAt: plan.modifiedAt)
            }
        }
        let covered = Set(noteItems.map(\.id))
            .union(pointsToPonder.map(\.id))
            .union(passageItems.map(\.id))
            .union(linkItems.map(\.id))
            .union(conversationItems.map(\.id))
            .union(savedAnnotations.map(\.id))
        return artifacts.filter { !covered.contains($0.id) && $0.kind != .note && $0.kind != .conversation } + noteItems + passageItems + linkItems + conversationItems + annotationItems + pointItems + planItems + readingItems
    }

    func pickableArtifacts(
        notes: [NoteDocument],
        annotationSnapshot: AnnotationSnapshot,
        bookTitleForCode: (String) -> String
    ) -> [CollectionArtifact] {
        let material = presentedArtifacts(notes: notes, annotationSnapshot: annotationSnapshot)
        let layers = AnnotationCollectionCatalog.pickableLayerArtifacts(snapshot: annotationSnapshot, bookTitleForCode: bookTitleForCode)
        let covered = Set(material.map(\.id))
        return material + layers.filter { !covered.contains($0.id) }
    }

    func presentedArtifacts(for collectionID: UUID, includingDescendants: Bool, notes: [NoteDocument], annotationSnapshot: AnnotationSnapshot? = nil) -> [CollectionArtifact] {
        guard !isLocked(collectionID) else { return [] }
        let material = presentedArtifacts(notes: notes, annotationSnapshot: annotationSnapshot)
        if collection(id: collectionID)?.isUnfiled == true {
            let ids = unfiledIDs(in: material)
            return material.filter { ids.contains($0.id) }
        }
        let ids = artifactIDs(for: collectionID, includingDescendants: includingDescendants)
        return material.filter { ids.contains($0.id) }
    }

    func unfiledCount(notes: [NoteDocument], annotationSnapshot: AnnotationSnapshot? = nil) -> Int {
        unfiledIDs(in: presentedArtifacts(notes: notes, annotationSnapshot: annotationSnapshot)).count
    }

    func passage(id: UUID) -> SavedPassage? {
        passages.first { $0.id == id }
    }

    func link(id: UUID) -> SavedLink? {
        links.first { $0.id == id && accessAllowed($0.access) }
    }

    func conversation(id: UUID) -> StudyConversation? {
        conversations.first { $0.id == id }
    }

    func upsertCompanionConversation(_ conversation: StudyConversation) {
        if sophyCommitInFlight || studyMutationBlocked {
            Task { @MainActor in
                while self.sophyCommitInFlight || self.studyMutationBlocked { try? await Task.sleep(for: .milliseconds(20)) }
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
        if sophyCommitInFlight || studyMutationBlocked {
            Task { @MainActor in
                while self.sophyCommitInFlight || self.studyMutationBlocked { try? await Task.sleep(for: .milliseconds(20)) }
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

    @discardableResult
    func updateLink(id: UUID, title: String, url: String, from collectionID: UUID? = nil) -> Bool {
        guard !rejectWhileSophyCommits() else { return false }
        if let collectionID {
            guard let folder = collection(id: collectionID), folder.isUnfiled || folder.isActiveInLibrary,
                  allowChanges([collectionID]) else { return false }
        }
        guard let index = links.firstIndex(where: { $0.id == id }), accessAllowed(links[index].access),
              !collectionIDs(containing: id).contains(where: isLocked) else { return false }
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed),
              let scheme = parsed.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = parsed.host, !host.isEmpty else {
            notice = "Use a full http or https address."; return false
        }
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        links[index].title = title.isEmpty ? host : String(title.prefix(120))
        links[index].url = trimmed
        notice = nil
        for folderID in collectionIDs(containing: id) { touch(folderID) }
        enqueueWrite()
        return true
    }

    /// A drop changes only the explicit source edge, after revalidating the live route.
    @discardableResult
    func moveStudyMaterial(_ id: UUID, from source: UUID, to destination: UUID) -> Bool {
        let activeIDs = Set(outline().map { $0.collection.id })
        guard let sourceFolder = collection(id: source), sourceFolder.isUnfiled || activeIDs.contains(source),
              activeIDs.contains(destination),
              knownItem(id), allowChanges([source, destination]) else { return false }
        if sourceFolder.isUnfiled {
            guard !hasFiledMembership(id) else { notice = "This item has already been filed."; return false }
        } else {
            guard contains(id, in: source) else { notice = "The item is no longer in the source collection."; return false }
        }
        return move(artifactID: id, from: source, to: destination)
    }

    func deleteLink(_ id: UUID) {
        guard !rejectWhileSophyCommits() else { return }

        guard links.contains(where: { $0.id == id && accessAllowed($0.access) }),
              !collectionIDs(containing: id).contains(where: isLocked) else { return }
        links.removeAll { $0.id == id }
        for edge in memberships.filter({ $0.artifactID == id }) {
            memberships.remove(edge)
            touch(edge.collectionID)
        }
        enqueueWrite()
    }

    private func hasFiledMembership(_ artifactID: UUID) -> Bool {
        memberships.contains { membership in
            membership.artifactID == artifactID && collection(id: membership.collectionID)?.isTrashed != true
        }
    }

    private func unfiledIDs(in material: [CollectionArtifact]) -> Set<UUID> {
        Set(material.filter { !hasFiledMembership($0.id) }.map(\.id))
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
        return plans.contains { plan in
            plan.isActive && planAccessAllowed(plan) && (plan.id == id || plan.items.contains { $0.id == id && $0.payload.kind == .scripture })
        }
            || artifacts.contains { $0.id == id && $0.kind != .note && $0.kind != .conversation }
            || pointsToPonder.contains { $0.id == id && $0.trashedAt == nil }
            || passages.contains { $0.id == id }
            || savedAnnotations.contains { $0.id == id }
            || links.contains { $0.id == id }
            || conversations.contains { $0.id == id }
            || linkedNoteIDs.contains(id)
    }

    private func touch(_ collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        collections[index].modifiedAt = Date()
    }

    private func apply(_ snapshot: CollectionsSnapshot) {
        committedState = snapshot
        var projection = snapshot
        for (_, patch) in pendingLegacy { projection = patch.applying(to: projection) }
        applyProjection(projection)
        legacyBaseline = exportSnapshot()
    }
    private func applyProjection(_ snapshot: CollectionsSnapshot) {
        plans = snapshot.plans; planOperations = snapshot.planOperations
        commandReceipts = snapshot.commandReceipts; retainedPlanAccess = snapshot.retainedPlanAccess
        planFormatActivated = snapshot.planFormatActivated
        planLifecycleActivated = snapshot.planLifecycleActivated; planTreeTrash = snapshot.planTreeTrash
        revision = snapshot.revision
        pointsToPonder = snapshot.pointsToPonder
        passages = snapshot.passages
        savedAnnotations = snapshot.savedAnnotations
        links = snapshot.links
        conversations = snapshot.conversations
        if !conversations.contains(where: { $0.id == StudyConversation.placeholderID }) {
            conversations.insert(.placeholder(), at: 0)
        }
        memberships = Set(snapshot.memberships.filter { $0.collectionID != StudyCollection.unfiledID })
        var folders = snapshot.collections.filter { !$0.isUnfiled && $0.id != StudyCollection.unfiledID }
        unfiledAccent = snapshot.unfiledAccent
        folders.insert(.unfiled(accent: unfiledAccent), at: 0)
        collections = folders
    }

    func exportBackupSnapshot() throws -> CollectionsSnapshot {
        try protection.require(collections.map(\.protectionID), in: .collections)
        guard plans.allSatisfy(planAccessAllowed), links.allSatisfy({ accessAllowed($0.access) }),
              retainedPlanAccess.allSatisfy({ accessAllowed($0.access) }),
              planTreeTrash.allSatisfy({ $0.links.allSatisfy { accessAllowed($0.access) } }) else { throw ItemLockError.locked }
        return exportSnapshot()
    }

    @discardableResult func restoreBackupSnapshot(_ snapshot: CollectionsSnapshot) async -> Bool {
        guard !sophyCommitInFlight, !persistenceUncertain else { return false }

        do {
            try protection.require(collections.map(\.protectionID), in: .collections)
            guard (1...5).contains(snapshot.schemaVersion) else { throw CollectionsError.unsupported }
            await flush()
            try protection.require(collections.map(\.protectionID), in: .collections)
            var restored = snapshot
            for i in restored.collections.indices where restored.collections[i].protectionID == nil {
                restored.collections[i].protectionID = collection(id: restored.collections[i].id)?.protectionID
            }
            restored.revision = revision
            restored.schemaVersion = restored.requiredSchemaVersion
            protection.lock([.collections])
            let bytes = try JSONEncoder().encode(restored)
            let result = await submit(.init(intent: .restoreCollections(bytes)))
            guard result.receipt != nil else { notice = result.message; return false }
            notice = "Collections restored from backup."; return true
        } catch { notice = error.localizedDescription; return false }
    }

    private func exportSnapshot() -> CollectionsSnapshot {
        var result = CollectionsSnapshot(
            schemaVersion: !pointsToPonder.isEmpty ? 3 : collections.contains(where: { $0.protectionID != nil }) ? 2 : 1,
            revision: revision,
            collections: collections.filter { !$0.isUnfiled },
            pointsToPonder: pointsToPonder,
            passages: passages,
            savedAnnotations: savedAnnotations,
            links: links,
            conversations: conversations,
            memberships: Array(memberships),
            unfiledAccent: unfiledAccent
        )
        result.planFormatActivated = planFormatActivated; result.plans = plans
        result.planLifecycleActivated = planLifecycleActivated; result.planTreeTrash = planTreeTrash
        result.planOperations = planOperations; result.commandReceipts = commandReceipts
        result.retainedPlanAccess = retainedPlanAccess; result.schemaVersion = result.requiredSchemaVersion
        return result
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
        let result = await commitLegacySnapshot(snapshot)
        switch result {
        case .committed: return .committed(resultIDs: nodes.map(\.id))
        case .rejected(.stale): return .rejected(.stalePlan)
        case .rejected: return .rejected(.accessDenied)
        case .uncertain: return .uncertain(resultIDs: nodes.map(\.id))
        }
    }

    private func rejectWhileSophyCommits() -> Bool {
        guard sophyCommitInFlight || studyMutationBlocked || persistenceUncertain else { return false }
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
        guard !studyMutationBlocked, !persistenceUncertain else { notice = StudyMutationFailure.busy.localizedDescription; return }
        let after = exportSnapshot(), before = legacyBaseline ?? committedState ?? after
        let patch = CollectionsLegacyPatch(before: before, after: after)
        legacyBaseline = after
        let id = UUID()
        pendingLegacy.append((id, patch))
        do { _ = schedule(.init(commandID: id, intent: .legacyPatch(try JSONEncoder().encode(patch)))) }
        catch { notice = error.localizedDescription }
    }
}

extension CollectionsStore {
    var hasCollectionsAccessRequirements: Bool {
        collections.contains { !$0.isUnfiled && $0.protectionID != nil }
            || plans.contains { !$0.access.collectionsCredentialIDs.isEmpty }
            || links.contains { !$0.access.collectionsCredentialIDs.isEmpty }
            || planTreeTrash.contains { $0.links.contains { !$0.access.collectionsCredentialIDs.isEmpty } }
            || linkedNoteAccess.values.contains { !$0.collectionsCredentialIDs.isEmpty }
            || retainedPlanAccess.contains { !$0.access.collectionsCredentialIDs.isEmpty }
    }
    func accessAllowed(_ value: StudyAccessRequirements) -> Bool {
        !value.notesCredentialIDs.contains { protection.isLocked($0, in: .notes) }
            && !value.collectionsCredentialIDs.contains { protection.isLocked($0, in: .collections) }
    }
    func planAccessAllowed(_ plan: StudyPlan) -> Bool {
        accessAllowed(plan.access) && !collectionIDs(containing: plan.id).contains(where: isLocked)
    }
    func accessForPlan(_ id: UUID) -> StudyAccessRequirements {
        var access = plans.first(where: { $0.id == id })?.access ?? .init()
        for folder in collectionIDs(containing: id) {
            var current: UUID? = folder; var seen = Set<UUID>()
            while let next = current, seen.insert(next).inserted, let value = collection(id: next) {
                if let binding = value.protectionID { access.collectionsCredentialIDs.insert(binding) }
                current = value.parentID
            }
        }
        return access
    }
    func submit(_ request: StudyMutationRequest) async -> StudyCommitResult { await schedule(request).value }
    private func schedule(_ request: StudyMutationRequest) -> Task<StudyCommitResult, Never> {
        let previous = writeChain
        let task = Task { @MainActor in
            _ = await previous?.value
            return await self.perform(request)
        }
        writeChain = task
        return task
    }
    func receipt(for commandID: UUID) async -> StudyCommitResult {
        if let value = committedState?.commandReceipts.first(where: { $0.commandID == commandID }) { return .committed(value) }
        guard let repository else { return .rejected(.unavailable) }
        do {
            let current = try await repository.load().snapshot
            guard let receipt = current.commandReceipts.first(where: { $0.commandID == commandID }) else { return .rejected(.persistence) }
            persistenceUncertain = false; apply(current); return .committed(receipt)
        } catch { return .uncertain(commandID: commandID) }
    }
    private func commitLegacySnapshot(_ after: CollectionsSnapshot) async -> StudyCommitResult {
        do {
            let patch = CollectionsLegacyPatch(before: exportSnapshot(), after: after)
            return await submit(.init(intent: .legacyPatch(try JSONEncoder().encode(patch))))
        } catch { return .rejected(.invalid) }
    }
    private func planFolderAccessAllowed(_ id: UUID, snapshot: CollectionsSnapshot) -> Bool {
        var current: UUID? = id; var seen = Set<UUID>()
        while let next = current {
            guard seen.insert(next).inserted, let folder = snapshot.collections.first(where: { $0.id == next }),
                  folder.isActiveInLibrary, !protection.isLocked(folder.protectionID, in: .collections) else { return false }
            current = folder.parentID
        }
        return true
    }
    private func filePlanMaterials(_ plan: inout StudyPlan, folderID: UUID, snapshot: inout CollectionsSnapshot) throws {
        guard planFolderAccessAllowed(folderID, snapshot: snapshot) else { throw StudyMutationFailure.accessDenied }
        let prior = snapshot.plans.first { $0.id == plan.id }
        let allTargets = Set(plan.items.map { $0.payload.targetID ?? $0.id })
        var expected: [UUID: Set<UUID>] = [:]
        for index in plan.sections.indices {
            let section = plan.sections[index]
            let previousID = prior?.sections.first(where: { $0.id == section.id })?.materialsFolderID
            let title = plan.sectionTitle(index)
            let sectionFolderID: UUID
            if let previousID, let f = snapshot.collections.firstIndex(where: { $0.id == previousID && $0.parentID == folderID }) {
                guard planFolderAccessAllowed(previousID, snapshot: snapshot) else { throw StudyMutationFailure.accessDenied }
                sectionFolderID = previousID
                let detail = "Study materials for \(title) of the Plan ‘\(plan.title)’."
                if snapshot.collections[f].name != title || snapshot.collections[f].detail != detail {
                    snapshot.collections[f].name = title; snapshot.collections[f].detail = detail
                    snapshot.collections[f].modifiedAt = Date()
                }
            } else {
                sectionFolderID = UUID()
                let accent = snapshot.collections.first(where: { $0.id == folderID })?.accent ?? .preset
                snapshot.collections.append(StudyCollection(id: sectionFolderID, name: title,
                    detail: "Study materials for \(title) of the Plan ‘\(plan.title)’.",
                    parentID: folderID, accent: accent, modifiedAt: Date()))
            }
            plan.sections[index].materialsFolderID = sectionFolderID
            expected[sectionFolderID] = Set(section.items.map { $0.payload.targetID ?? $0.id })
        }
        // Reorganize known assignments only. Removed assignments, unrelated material,
        // old unlinked trees and their source objects remain available.
        let oldFolders = Set(prior?.sections.compactMap(\.materialsFolderID) ?? [])
        for oldFolder in oldFolders where snapshot.collections.contains(where: { $0.id == oldFolder && $0.parentID == folderID }) {
            let desired = expected[oldFolder] ?? []
            let removed = snapshot.memberships.filter { $0.collectionID == oldFolder && allTargets.contains($0.artifactID) && !desired.contains($0.artifactID) }
            if !removed.isEmpty {
                guard planFolderAccessAllowed(oldFolder, snapshot: snapshot) else { throw StudyMutationFailure.accessDenied }
                snapshot.memberships.removeAll { removed.contains($0) }
            }
        }
        // Upgrade the previous flat filing at this linked root without deleting items.
        let flatTargets = snapshot.memberships.filter { $0.collectionID == folderID && allTargets.contains($0.artifactID) && $0.artifactID != plan.id }
        for edge in flatTargets {
            guard noteAccessAllows(edge.artifactID), accessAllowed(linkedNoteAccess[edge.artifactID] ?? .init()) else { throw StudyMutationFailure.accessDenied }
            if let link = snapshot.links.first(where: { $0.id == edge.artifactID }), !accessAllowed(link.access) { throw StudyMutationFailure.accessDenied }
        }
        snapshot.memberships.removeAll { flatTargets.contains($0) }
        expected[folderID] = [plan.id]
        for (destination, targets) in expected {
            for target in targets {
                let edge = CollectionMembership(collectionID: destination, artifactID: target)
                guard !snapshot.memberships.contains(edge) else { continue }
                guard noteAccessAllows(target), accessAllowed(linkedNoteAccess[target] ?? .init()) else { throw StudyMutationFailure.accessDenied }
                if let link = snapshot.links.first(where: { $0.id == target }), !accessAllowed(link.access) { throw StudyMutationFailure.accessDenied }
                snapshot.memberships.append(edge)
            }
        }
    }
    private func perform(_ request: StudyMutationRequest) async -> StudyCommitResult {
        defer {
            pendingLegacy.removeAll { $0.0 == request.commandID }
            if let committedState { apply(committedState) }
        }
        if studyMutationBlocked {
            guard case .restoreCollections = request.intent else { return .rejected(.busy) }
        }
        guard !persistenceUncertain else { return .rejected(.busy) }
        var value = committedState ?? exportSnapshot()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let hash: String
        do { hash = SHA256.hash(data: try encoder.encode(request.intent)).map { String(format: "%02x", $0) }.joined() }
        catch { return .rejected(.invalid) }
        if let receipt = value.commandReceipts.first(where: { $0.commandID == request.commandID }) {
            return receipt.intentHash == hash ? .committed(receipt) : .rejected(.invalid)
        }
        var planID: UUID?
        do {
            switch request.intent {
            case .legacyPatch(let bytes):
                let patch = try JSONDecoder().decode(CollectionsLegacyPatch.self, from: bytes)
                let changedEdges = Set(patch.before.memberships).symmetricDifference(patch.after.memberships)
                let affected = Set(patch.before.collections.filter { old in patch.after.collections.first(where: { $0.id == old.id }) != old }.map(\.id)).union(changedEdges.map(\.collectionID))
                guard !affected.filter({ collection(id: $0) != nil }).contains(where: isLocked) else { return .rejected(.accessDenied) }
                value = patch.applying(to: value)
            case .restoreCollections(let bytes):
                var restored = try JSONDecoder().decode(CollectionsSnapshot.self, from: bytes)
                restored.preservePlanAccess(from: value)
                restored.revision = value.revision; value = restored
            case .savePlan(var plan, let destination):
                guard accessAllowed(plan.access) else { return .rejected(.accessDenied) }
                planID = plan.id
                let existingPlan = value.plans.first { $0.id == plan.id }
                if let existing = value.plans.first(where: { $0.id == plan.id }) {
                    guard planAccessAllowed(existing) else { return .rejected(.accessDenied) }
                    guard request.expectedPlanRevision == existing.revision else { return .rejected(.stale) }
                    if existing.folderOwnershipConfirmed == true, let owned = existing.materialsFolderID, plan.materialsFolderID != owned { return .rejected(.invalid) }
                    if existing.trashedAt != plan.trashedAt { return .rejected(.invalid) }
                    // Replacing targets reopens only those assignments, regardless of a stale editor checkbox.
                    let prior = Dictionary(uniqueKeysWithValues: existing.items.map { ($0.id, $0) })
                    for s in plan.sections.indices { for i in plan.sections[s].items.indices {
                        let item = plan.sections[s].items[i]
                        if let old = prior[item.id], old.payload != item.payload { plan.sections[s].items[i].completedAt = nil }
                    } }
                    plan.access = plan.access.union(existing.access); plan.revision = existing.revision + 1
                    plan.createdAt = existing.createdAt
                    if let cursor = plan.cursor, cursor.kind != .planSummary, !plan.sections.contains(where: { $0.id == cursor.sectionID }) { plan.cursor = nil }
                } else {
                    guard request.expectedPlanRevision == nil, value.plans.count < 100 else { return .rejected(.capacity) }
                    plan.revision = 0
                }
                if let destination, destination != StudyCollection.unfiledID {
                    guard let folder = collection(id: destination), folder.isActiveInLibrary, !isLocked(destination) else { return .rejected(.accessDenied) }
                    let edge = CollectionMembership(collectionID: destination, artifactID: plan.id)
                    if !value.memberships.contains(edge) { value.memberships.append(edge) }
                }
                // New Plans own a dedicated root. Legacy Plans retain a unique valid
                // link or acquire a root on their next save. The identity is immutable.
                if existingPlan == nil || plan.materialsFolderID == nil || (existingPlan?.folderOwnershipConfirmed != true && !value.collections.contains(where: { $0.id == plan.materialsFolderID && $0.trashedAt == nil })) || value.plans.contains(where: { $0.id != plan.id && $0.materialsFolderID == plan.materialsFolderID }) {
                    let parent = destination == StudyCollection.unfiledID ? nil : destination
                    let folder = StudyCollection(id: UUID(), name: plan.title,
                        detail: "This folder contains the study materials for the Plan ‘\(plan.title)’.",
                        parentID: parent, accent: parent.flatMap { collection(id: $0)?.accent } ?? .preset, modifiedAt: Date())
                    value.collections.append(folder); plan.materialsFolderID = folder.id
                }
                if plan.isActive, let folderID = plan.materialsFolderID {
                    try filePlanMaterials(&plan, folderID: folderID, snapshot: &value)
                }
                plan.folderOwnershipConfirmed = true
                value.planLifecycleActivated = true
                plan.modifiedAt = Date(); try plan.validate()
                let oldItems = Dictionary(uniqueKeysWithValues: value.plans.first(where: { $0.id == plan.id })?.items.map { ($0.id, $0.payload) } ?? [])
                if let validatePlanReference {
                    for item in plan.items where item.payload.kind == .scripture && (oldItems[item.id] != item.payload || value.plans.first(where: { $0.id == plan.id })?.preferredEditionID != plan.preferredEditionID) {
                        try await validatePlanReference(item.payload, plan.preferredEditionID)
                    }
                }
                guard accessAllowed(plan.access), !collectionIDs(containing: plan.id).contains(where: isLocked) else { return .rejected(.accessDenied) }
                if let folderID = plan.materialsFolderID, !planFolderAccessAllowed(folderID, snapshot: value) { return .rejected(.accessDenied) }
                if let index = value.plans.firstIndex(where: { $0.id == plan.id }) { value.plans[index] = plan }
                else { value.plans.append(plan) }
                value.planFormatActivated = true
            case .createPlanMaterialsFolder(let id, let folder, let replaceExisting):
                guard let index = value.plans.firstIndex(where: { $0.id == id }), value.plans[index].isActive,
                      planAccessAllowed(value.plans[index]) else { return .rejected(.accessDenied) }
                if let expected = request.expectedPlanRevision, expected != value.plans[index].revision { return .rejected(.stale) }
                planID = id
                let priorPlanRevision = value.plans[index].revision
                if replaceExisting, value.plans[index].materialsFolderID != nil { return .rejected(.invalid) }
                if value.plans[index].materialsFolderID == nil {
                    guard folder.id != StudyCollection.unfiledID, !value.collections.contains(where: { $0.id == folder.id }),
                          folder.isActiveInLibrary, folder.protectionID == nil,
                          !folder.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          folder.name == folder.name.trimmingCharacters(in: .whitespacesAndNewlines),
                          folder.name.localizedCaseInsensitiveCompare("No Folder") != .orderedSame else { return .rejected(.invalid) }
                    if let parent = folder.parentID {
                        guard value.collections.contains(where: { $0.id == parent && $0.isActiveInLibrary }), !isLocked(parent) else { return .rejected(.accessDenied) }
                    }
                    value.collections.append(folder)
                    value.plans[index].materialsFolderID = folder.id
                    value.plans[index].revision += 1; value.plans[index].modifiedAt = Date()
                }
                if let folderID = value.plans[index].materialsFolderID {
                    var organized = value.plans[index]
                    let oldSections = organized.sections
                    try filePlanMaterials(&organized, folderID: folderID, snapshot: &value)
                    if oldSections != organized.sections && priorPlanRevision == organized.revision { organized.revision += 1 }
                    value.plans[index] = organized
                }
            case .filePlanMaterial(let id, let sectionID, let artifactID):
                guard let plan = value.plans.first(where: { $0.id == id }), plan.isActive, planAccessAllowed(plan),
                      let rootID = plan.materialsFolderID,
                      let section = plan.sections.first(where: { $0.id == sectionID }),
                      let folderID = section.materialsFolderID, knownItem(artifactID),
                      noteAccessAllows(artifactID), accessAllowed(linkedNoteAccess[artifactID] ?? .init()) else { return .rejected(.accessDenied) }
                guard value.collections.contains(where: { $0.id == folderID && $0.parentID == rootID && $0.isActiveInLibrary }), !isLocked(folderID) else { return .rejected(.accessDenied) }
                if let link = value.links.first(where: { $0.id == artifactID }), !accessAllowed(link.access) { return .rejected(.accessDenied) }
                let edge = CollectionMembership(collectionID: folderID, artifactID: artifactID)
                if !value.memberships.contains(edge) { value.memberships.append(edge) }
                planID = id
            case .saveLink(let link, let destination):
                guard accessAllowed(link.access), let url = URL(string: link.url),
                      ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host?.isEmpty == false,
                      !value.links.contains(where: { $0.id == link.id }) else { return .rejected(.invalid) }
                if let destination, destination != StudyCollection.unfiledID {
                    guard !isLocked(destination) else { return .rejected(.accessDenied) }
                    value.memberships.append(.init(collectionID: destination, artifactID: link.id))
                }
                value.links.append(link)
                if link.planOrigin != nil || !link.access.isEmpty { value.planFormatActivated = true }
            case .setPlanTreeTrashed(let id, let trashed):
                planID = id
                try preparePlanTreeTrash(planID: id, trashed: trashed, snapshot: &value)
                value.planLifecycleActivated = true
            case .finishPlanTreeNotes(let id):
                guard let index = value.planTreeTrash.firstIndex(where: { $0.id == id }) else { return .rejected(.unavailable) }
                if value.planTreeTrash[index].restoring { value.planTreeTrash.remove(at: index) }
                else { value.planTreeTrash[index].pendingNotesAction = nil }
            case .purgePlan(let id):
                if let record = value.planTreeTrash.first(where: { $0.planIDs.contains(id) }) {
                    guard record.pendingNotesAction == nil else { return .rejected(.busy) }
                    let pids = Set(record.planIDs), fids = Set(record.folderIDs)
                    guard value.plans.filter({ pids.contains($0.id) }).allSatisfy(planAccessAllowed) else { return .rejected(.accessDenied) }
                    for plan in value.plans where pids.contains(plan.id) {
                        if !value.retainedPlanAccess.contains(where: { $0.planID == plan.id }) {
                            value.retainedPlanAccess.append(.init(planID: plan.id, lastTitle: plan.title, access: plan.access, detachedAt: Date()))
                        }
                    }
                    value.plans.removeAll { pids.contains($0.id) }; value.collections.removeAll { fids.contains($0.id) }
                    value.memberships.removeAll { fids.contains($0.collectionID) || pids.contains($0.artifactID) }
                    value.planTreeTrash.removeAll { $0.id == record.id }; planID = id
                    break
                }
                guard let plan = value.plans.first(where: { $0.id == id }), plan.trashedAt != nil,
                      planAccessAllowed(plan), request.expectedPlanRevision == plan.revision else { return .rejected(.accessDenied) }
                guard !value.planOperations.contains(where: { $0.planID == id }) else { return .rejected(.busy) }
                value.retainedPlanAccess.append(.init(planID: id, lastTitle: plan.title, access: plan.access, detachedAt: Date()))
                value.plans.removeAll { $0.id == id }; value.memberships.removeAll { $0.artifactID == id }
                planID = id
            case .prepareOperation(let operation):
                guard value.planOperations.count < 128, accessAllowed(operation.access),
                      !value.planOperations.contains(where: { $0.id == operation.id }),
                      operation.planID.map({ id in value.plans.contains { $0.id == id && planAccessAllowed($0) } }) ?? true else { return .rejected(.busy) }
                value.planFormatActivated = true; value.planOperations.append(operation)
            case .finishOperation(let id):
                guard let operation = value.planOperations.first(where: { $0.id == id }), accessAllowed(operation.access) else { return .rejected(.accessDenied) }
                value.planOperations.removeAll { $0.id == id }
            }
            if value.planLifecycleActivated {
                for plan in value.plans where plan.trashedAt == nil {
                    guard let root = plan.materialsFolderID else { continue } // legacy record awaits next edit
                    guard value.collections.contains(where: { $0.id == root && $0.trashedAt == nil }) else { return .rejected(.invalid) }
                    let edge = CollectionMembership(collectionID: root, artifactID: plan.id)
                    if !value.memberships.contains(edge) { value.memberships.append(edge) }
                }
            }
            // Sticky union on all filing/protection paths, not just the Plan editor.
            for i in value.plans.indices {
                var access = value.plans[i].access
                for edge in value.memberships where edge.artifactID == value.plans[i].id {
                    var next: UUID? = edge.collectionID; var seen = Set<UUID>()
                    while let id = next, seen.insert(id).inserted, let folder = value.collections.first(where: { $0.id == id }) {
                        if let binding = folder.protectionID { access.collectionsCredentialIDs.insert(binding) }; next = folder.parentID
                    }
                }
                value.plans[i].access = access
                let oldAccess = committedState?.plans.first(where: { $0.id == value.plans[i].id })?.access ?? .init()
                if access != oldAccess, let planNotes {
                    let result = await planNotes.applyPlanAccess(planID: value.plans[i].id, operationID: request.commandID, access: access)
                    guard case .committed = result else { return .uncertain(commandID: request.commandID) }
                }
            }
            let receipt = StudyCommandReceipt(commandID: request.commandID, intentHash: hash,
                storeRevision: value.revision + 1, planID: planID,
                planRevision: value.plans.first(where: { $0.id == planID })?.revision,
                resultIDs: planID.map { [$0] } ?? [], committedAt: Date())
            // Legacy-only stores keep their existing wire schema until the first Plan.
            if value.planFormatActivated {
                value.commandReceipts.append(receipt)
                let pinned = Set(value.planOperations.map(\.id))
                while value.commandReceipts.count > 256 {
                    guard let index = value.commandReceipts.firstIndex(where: { !pinned.contains($0.commandID) }) else { throw StudyMutationFailure.capacity }
                    value.commandReceipts.remove(at: index)
                }
            }
            value.schemaVersion = value.requiredSchemaVersion; try value.validatePlans()
            if let repository { value = try await repository.save(value, expectedRevision: value.revision) }
            else { value.revision += 1 }
            apply(value)
            notice = nil
            return .committed(receipt)
        } catch let failure as StudyMutationFailure { notice = failure.localizedDescription; return .rejected(failure) }
        catch CollectionsError.stale { notice = StudyMutationFailure.stale.localizedDescription; return .rejected(.stale) }
        catch CollectionsError.unsupported { persistenceUncertain = true; notice = StudyMutationFailure.unsupported.localizedDescription; return .rejected(.unsupported) }
        catch {
            if let repository {
                do {
                    let observed = try await repository.load().snapshot
                    if let receipt = observed.commandReceipts.first(where: { $0.commandID == request.commandID }) {
                        apply(observed); return .committed(receipt)
                    }
                    if observed.revision != (committedState?.revision ?? 0) { persistenceUncertain = true; return .uncertain(commandID: request.commandID) }
                } catch { persistenceUncertain = true; return .uncertain(commandID: request.commandID) }
            }
            notice = StudyMutationFailure.persistence.localizedDescription
            return .rejected(.persistence)
        }
    }
}

extension CollectionsStore {
    func adoptMandatoryPlanFolders() async {
        for plan in plans where plan.trashedAt == nil && planAccessAllowed(plan) {
            guard plan.materialsFolderID == nil || plan.folderOwnershipConfirmed != true else { continue }
            let parent = memberships.first(where: { $0.artifactID == plan.id && $0.collectionID != plan.materialsFolderID })?.collectionID
            _ = await submit(.init(expectedPlanRevision: plan.revision, intent: .savePlan(plan, collectionID: parent)))
        }
    }
    func planOwningFolder(_ id: UUID) -> StudyPlan? { plans.first { $0.materialsFolderID == id } }
    func planFolderDeleteTitle(_ id: UUID) -> String {
        planOwningFolder(id) == nil ? "Delete \(collection(id: id)?.name ?? "Collection")?" : "Delete this Plan folder?"
    }
    func planFolderDeleteMessage(_ id: UUID) -> String {
        planOwningFolder(id) == nil
            ? "Subfolders move up one level. Anything that is not in another collection moves to No Folder. Nothing is deleted."
            : "This will also delete the Plan, its subfolders, and items that aren’t shared elsewhere. Shared items will be kept. You can restore the Plan and folder together from Trash."
    }
    var planDeleteMessage: String {
        "This will also delete its Plan folder, subfolders, and items that aren’t shared elsewhere. Shared items will be kept. You can restore the Plan and folder together from Trash."
    }
    func setPlanTreeTrashed(_ planID: UUID, trashed: Bool) async -> StudyCommitResult {
        // Finish a prior interrupted Notes phase before accepting an opposite action.
        await reconcilePlanTreeTrash()
        guard !planTreeTrash.contains(where: { $0.planIDs.contains(planID) && $0.pendingNotesAction != nil }) else { return .rejected(.busy) }
        let result = await submit(.init(intent: .setPlanTreeTrashed(planID: planID, trashed: trashed)))
        guard result.receipt != nil else { notice = result.message; return result }
        await reconcilePlanTreeTrash()
        if planTreeTrash.contains(where: { $0.planIDs.contains(planID) && $0.pendingNotesAction != nil }) {
            notice = "The Plan folder is in Trash, but its study items still need to finish saving. Retry after unlocking Notes."
            return .uncertain(commandID: result.receipt!.commandID)
        }
        return result
    }
    func reconcilePlanTreeTrash() async {
        for record in planTreeTrash {
            guard let action = record.pendingNotesAction else { continue }
            if !record.noteIDs.isEmpty {
                guard let planNotes else { notice = "Open Notes before finishing the Plan deletion."; continue }
                let result = await planNotes.setPlanTreeNotesTrashed(record.noteIDs, trashed: action, timestamp: record.timestamp)
                guard case .committed = result else { notice = "The Plan's Notes changes are pending. Unlock Notes and retry."; continue }
            }
            if !record.conversations.isEmpty, planCompanion == nil { notice = "Open Companion to finish the Plan deletion."; continue }
            if !record.conversations.isEmpty, let planCompanion {
                for conversation in record.conversations where !conversation.isPlaceholder {
                    if action { planCompanion.moveConversationToTrash(conversation.id) }
                    else { planCompanion.restoreConversationFromTrash(conversation.id) }
                }
                await planCompanion.flush()
            }
            _ = await submit(.init(intent: .finishPlanTreeNotes(record.id)))
        }
    }
    private func preparePlanTreeTrash(planID: UUID, trashed: Bool, snapshot: inout CollectionsSnapshot) throws {
        guard let selected = snapshot.plans.first(where: { $0.id == planID }), planAccessAllowed(selected) else { throw StudyMutationFailure.accessDenied }
        if !trashed {
            if selected.trashedAt == nil { return }
            guard let index = snapshot.planTreeTrash.firstIndex(where: { $0.planIDs.contains(planID) }) else {
                // Pre-cascade Trash records have no archived bundle to recover.
                if let i = snapshot.plans.firstIndex(where: { $0.id == planID }) { snapshot.plans[i].trashedAt = nil; snapshot.plans[i].revision += 1 }
                return
            }
            let record = snapshot.planTreeTrash[index]
            guard record.links.allSatisfy({ accessAllowed($0.access) }) else { throw StudyMutationFailure.accessDenied }
            if let planNotes { try planNotes.requireNoteAccess(planNotes.snapshot.notes.filter { record.noteIDs.contains($0.id) }) }
            guard record.pendingNotesAction == nil else { throw StudyMutationFailure.busy }
            let ids = Set(record.folderIDs)
            guard snapshot.collections.filter({ ids.contains($0.id) }).allSatisfy({ !isLocked($0.id) }) else { throw StudyMutationFailure.accessDenied }
            for i in snapshot.collections.indices where ids.contains(snapshot.collections[i].id) { snapshot.collections[i].trashedAt = nil }
            for i in snapshot.plans.indices where record.planIDs.contains(snapshot.plans[i].id) {
                snapshot.plans[i].trashedAt = nil; snapshot.plans[i].revision += 1
            }
            for item in record.links where !snapshot.links.contains(where: { $0.id == item.id }) { snapshot.links.append(item) }
            for item in record.passages where !snapshot.passages.contains(where: { $0.id == item.id }) { snapshot.passages.append(item) }
            for item in record.annotations where !snapshot.savedAnnotations.contains(where: { $0.id == item.id }) { snapshot.savedAnnotations.append(item) }
            for item in record.conversations where !snapshot.conversations.contains(where: { $0.id == item.id }) { snapshot.conversations.append(item) }
            for item in record.points where !snapshot.pointsToPonder.contains(where: { $0.id == item.id }) { snapshot.pointsToPonder.append(item) }
            snapshot.planTreeTrash[index].restoring = true; snapshot.planTreeTrash[index].pendingNotesAction = false
            return
        }
        if selected.trashedAt != nil { return }
        guard let root = selected.materialsFolderID else { throw StudyMutationFailure.unavailable }
        var folders: Set<UUID> = [root]
        var changed = true
        while changed {
            changed = false
            for folder in snapshot.collections where folder.parentID.map(folders.contains) == true {
                if folders.insert(folder.id).inserted { changed = true }
            }
        }
        guard folders.allSatisfy({ !isLocked($0) }) else { throw StudyMutationFailure.accessDenied }
        let planIDs = Set(snapshot.plans.filter { $0.materialsFolderID.map(folders.contains) == true }.map(\.id))
        guard snapshot.plans.filter({ planIDs.contains($0.id) }).allSatisfy(planAccessAllowed) else { throw StudyMutationFailure.accessDenied }
        let candidates = Set(snapshot.memberships.filter { folders.contains($0.collectionID) }.map(\.artifactID))
        let sharedEdges = Set(snapshot.memberships.filter { edge in
            !folders.contains(edge.collectionID) && snapshot.collections.contains { $0.id == edge.collectionID }
        }.map(\.artifactID))
        let sharedAssignments = Set(snapshot.plans.filter { !planIDs.contains($0.id) }.flatMap { $0.items.compactMap(\.payload.targetID) })
        let exclusive = candidates.subtracting(sharedEdges).subtracting(sharedAssignments).subtracting(planIDs)
        let notes = planNotes?.snapshot.notes.filter { exclusive.contains($0.id) && $0.trashedAt == nil } ?? []
        if let planNotes { try planNotes.requireNoteAccess(notes) }
        guard !exclusive.contains(where: { !noteAccessAllows($0) || !accessAllowed(linkedNoteAccess[$0] ?? .init()) }),
              snapshot.links.filter({ exclusive.contains($0.id) }).allSatisfy({ accessAllowed($0.access) }) else { throw StudyMutationFailure.accessDenied }
        let now = Date()
        let record = PlanTreeTrash(planIDs: Array(planIDs), folderIDs: Array(folders), noteIDs: notes.map(\.id),
            links: snapshot.links.filter { exclusive.contains($0.id) }, passages: snapshot.passages.filter { exclusive.contains($0.id) },
            annotations: snapshot.savedAnnotations.filter { exclusive.contains($0.id) },
            conversations: snapshot.conversations.filter { exclusive.contains($0.id) && !$0.isPlaceholder },
            points: snapshot.pointsToPonder.filter { exclusive.contains($0.id) }, timestamp: now, pendingNotesAction: true)
        snapshot.planTreeTrash.append(record)
        snapshot.links.removeAll { exclusive.contains($0.id) }; snapshot.passages.removeAll { exclusive.contains($0.id) }
        snapshot.savedAnnotations.removeAll { exclusive.contains($0.id) }; snapshot.conversations.removeAll { exclusive.contains($0.id) && !$0.isPlaceholder }
        snapshot.pointsToPonder.removeAll { exclusive.contains($0.id) }
        for i in snapshot.collections.indices where folders.contains(snapshot.collections[i].id) { snapshot.collections[i].trashedAt = now }
        for i in snapshot.plans.indices where planIDs.contains(snapshot.plans[i].id) { snapshot.plans[i].trashedAt = now; snapshot.plans[i].revision += 1 }
    }
}
