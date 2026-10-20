import Foundation

/// Builds requests; CollectionsStore owns both revision and persistence queue.
@MainActor struct PlanCommandService {
    let store: CollectionsStore
    func save(_ plan: StudyPlan, collectionID: UUID? = nil, commandID: UUID = UUID()) async -> StudyCommitResult {
        await store.submit(.init(commandID: commandID, expectedPlanRevision: store.plans.contains(where: { $0.id == plan.id }) ? plan.revision : nil,
                                 intent: .savePlan(plan, collectionID: collectionID)))
    }
}

/// A legacy UI command's delta, applied at the same FIFO boundary as Plan commands.
struct CollectionsLegacyPatch: Codable {
    var before: CollectionsSnapshot
    var after: CollectionsSnapshot
    func applying(to current: CollectionsSnapshot) -> CollectionsSnapshot {
        var result = current
        result.collections = merge(before.collections, after.collections, current.collections, id: \.id)
        result.pointsToPonder = merge(before.pointsToPonder, after.pointsToPonder, current.pointsToPonder, id: \.id)
        result.passages = merge(before.passages, after.passages, current.passages, id: \.id)
        result.links = merge(before.links, after.links, current.links, id: \.id)
        result.savedAnnotations = merge(before.savedAnnotations, after.savedAnnotations, current.savedAnnotations, id: \.id)
        result.conversations = merge(before.conversations, after.conversations, current.conversations, id: \.id)
        let removed = Set(before.memberships).subtracting(after.memberships)
        let added = Set(after.memberships).subtracting(before.memberships)
        result.memberships = Array(Set(current.memberships).subtracting(removed).union(added))
        if before.unfiledAccent != after.unfiledAccent { result.unfiledAccent = after.unfiledAccent }
        return result
    }
    private func merge<T: Equatable>(_ before: [T], _ after: [T], _ current: [T], id: KeyPath<T, UUID>) -> [T] {
        let old = Dictionary(uniqueKeysWithValues: before.map { ($0[keyPath: id], $0) })
        let new = Dictionary(uniqueKeysWithValues: after.map { ($0[keyPath: id], $0) })
        let deleted = Set(old.keys).subtracting(new.keys)
        var output = current.filter { !deleted.contains($0[keyPath: id]) }
        for value in after where old[value[keyPath: id]] != value {
            if let index = output.firstIndex(where: { $0[keyPath: id] == value[keyPath: id] }) { output[index] = value }
            else { output.append(value) }
        }
        return output
    }
}
