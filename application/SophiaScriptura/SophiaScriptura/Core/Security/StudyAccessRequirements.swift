import Foundation

/// Credential bindings, never credentials or grants. Both domains are conjunctive.
struct StudyAccessRequirements: Codable, Equatable, Hashable, Sendable {
    var notesCredentialIDs: Set<UUID> = []
    var collectionsCredentialIDs: Set<UUID> = []
    var isEmpty: Bool { notesCredentialIDs.isEmpty && collectionsCredentialIDs.isEmpty }
    func union(_ other: Self) -> Self {
        .init(notesCredentialIDs: notesCredentialIDs.union(other.notesCredentialIDs),
              collectionsCredentialIDs: collectionsCredentialIDs.union(other.collectionsCredentialIDs))
    }
    private enum CodingKeys: String, CodingKey { case notesCredentialIDs, collectionsCredentialIDs }
    init(notesCredentialIDs: Set<UUID> = [], collectionsCredentialIDs: Set<UUID> = []) {
        self.notesCredentialIDs = notesCredentialIDs; self.collectionsCredentialIDs = collectionsCredentialIDs
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let n = try c.decode([UUID].self, forKey: .notesCredentialIDs)
        let f = try c.decode([UUID].self, forKey: .collectionsCredentialIDs)
        guard n.count <= 16, f.count <= 16, Set(n).count == n.count, Set(f).count == f.count else { throw StudyMutationFailure.invalid }
        notesCredentialIDs = Set(n); collectionsCredentialIDs = Set(f)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(notesCredentialIDs.sorted { $0.uuidString < $1.uuidString }, forKey: .notesCredentialIDs)
        try c.encode(collectionsCredentialIDs.sorted { $0.uuidString < $1.uuidString }, forKey: .collectionsCredentialIDs)
    }
}

struct PlanOrigin: Codable, Equatable, Hashable, Sendable {
    var planID: UUID
    var creationOperationID: UUID?
    var managed = true
}
