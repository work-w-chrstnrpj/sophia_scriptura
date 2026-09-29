import Foundation
import Combine

final class CollectionsStore: ObservableObject {
    @Published private(set) var collections: [StudyCollection]
    @Published private(set) var artifacts: [CollectionArtifact]
    @Published private(set) var memberships: Set<CollectionMembership>

    init(
        collections: [StudyCollection],
        artifacts: [CollectionArtifact],
        memberships: Set<CollectionMembership>
    ) {
        self.collections = collections
        self.artifacts = artifacts
        self.memberships = memberships
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
        collections.filter { $0.parentID == collectionID }
    }

    func membershipCount(for collectionID: UUID, includingDescendants: Bool = false) -> Int {
        artifactIDs(for: collectionID, includingDescendants: includingDescendants).count
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
        guard collection(id: collectionID) != nil,
              artifacts.contains(where: { $0.id == artifactID }) else { return }
        let membership = CollectionMembership(collectionID: collectionID, artifactID: artifactID)
        if memberships.contains(membership) {
            memberships.remove(membership)
        } else {
            memberships.insert(membership)
        }
        touch(collectionID)
    }

    @discardableResult
    func createCollection(name: String, detail: String, parentID: UUID?, accent: CollectionAccent) -> UUID? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        if let parentID, collection(id: parentID) == nil { return nil }
        let id = UUID()
        collections.append(
            StudyCollection(
                id: id,
                name: trimmedName,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                parentID: parentID,
                accent: accent,
                modifiedAt: Date()
            )
        )
        if let parentID { touch(parentID) }
        return id
    }

    func deleteCollection(id: UUID) {
        guard let removed = collection(id: id) else { return }
        let promotedParent = removed.parentID
        for index in collections.indices where collections[index].parentID == id {
            collections[index].parentID = promotedParent
        }
        collections.removeAll { $0.id == id }
        memberships = memberships.filter { $0.collectionID != id }
        if let promotedParent { touch(promotedParent) }
    }

    func removeArtifact(_ artifactID: UUID, from collectionID: UUID) {
        memberships.remove(CollectionMembership(collectionID: collectionID, artifactID: artifactID))
        touch(collectionID)
    }

    private func touch(_ collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        collections[index].modifiedAt = Date()
    }
}
