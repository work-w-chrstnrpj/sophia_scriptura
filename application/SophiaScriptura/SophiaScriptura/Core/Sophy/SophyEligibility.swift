import Foundation

struct SophyEligibleRecord: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable { case note, collection }
    var id: UUID
    var kind: Kind
    var title: String
    var body: String
    var tags: [String]
    var protectionID: UUID?
    var parentID: UUID?
    var membershipIDs: [UUID]
    var isArchived: Bool
    var isTrashed: Bool
    var isVirtualUnfiled: Bool
    var modifiedAt: Date
}

enum SophyEligibility {
    static func excludedIDs(_ records: [SophyEligibleRecord]) -> Set<UUID> {
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        var protectedCollections = Set<UUID>()
        func collectionExcluded(_ id: UUID, trail: Set<UUID>) -> Bool {
            guard let record = byID[id], record.kind == .collection else { return true }
            if record.isVirtualUnfiled { return false }
            if record.isArchived || record.isTrashed || record.protectionID != nil || trail.contains(id) { return true }
            if let parent = record.parentID {
                if byID[parent] == nil || collectionExcluded(parent, trail: trail.union([id])) { return true }
            }
            return false
        }
        for record in records where record.kind == .collection && !record.isVirtualUnfiled {
            if collectionExcluded(record.id, trail: []) { protectedCollections.insert(record.id) }
        }
        var excluded = protectedCollections
        for record in records where record.kind == .note {
            if record.isArchived || record.isTrashed || record.protectionID != nil {
                excluded.insert(record.id)
                continue
            }
            if record.membershipIDs.contains(where: { membership in
                byID[membership] == nil || protectedCollections.contains(membership)
            }) {
                excluded.insert(record.id)
            }
        }
        return excluded
    }

    static func search(_ records: [SophyEligibleRecord], query: String, limit: Int = 8) -> [SophyEligibleRecord] {
        let excluded = excludedIDs(records)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        let eligible = records.filter { !excluded.contains($0.id) && !$0.isVirtualUnfiled }
        return eligible
            .filter { record in
                record.title.localizedCaseInsensitiveContains(needle)
                    || record.body.localizedCaseInsensitiveContains(needle)
                    || record.tags.contains { $0.localizedCaseInsensitiveContains(needle) }
            }
            .sorted { lhs, rhs in
                func rank(_ record: SophyEligibleRecord) -> Int {
                    if record.title.compare(needle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame { return 0 }
                    if record.title.localizedCaseInsensitiveContains(needle) { return 1 }
                    return 2
                }
                let left = rank(lhs)
                let right = rank(rhs)
                if left != right { return left < right }
                if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt > rhs.modifiedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .prefix(limit)
            .map { $0 }
    }
}
