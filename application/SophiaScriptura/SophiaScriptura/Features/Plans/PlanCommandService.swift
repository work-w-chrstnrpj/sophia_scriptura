import Foundation

/// Builds requests; CollectionsStore owns both revision and persistence queue.
@MainActor struct PlanCommandService {
    let store: CollectionsStore
    func ensureMaterialsFolder(planID: UUID, parentID: UUID, commandID: UUID, folderID: UUID) async -> StudyCommitResult {
        guard let plan = store.plans.first(where: { $0.id == planID }) else { return .rejected(.unavailable) }
        let parent = parentID == StudyCollection.unfiledID ? nil : parentID
        let folder = StudyCollection(id: folderID, name: plan.title,
            detail: "This folder contains the study materials for the Plan ‘\(plan.title)’.",
            parentID: parent, accent: parent.flatMap { store.collection(id: $0)?.accent } ?? .preset, modifiedAt: plan.createdAt)
        return await store.submit(.init(commandID: commandID,
            intent: .createPlanMaterialsFolder(planID: planID, folder: folder, replaceExisting: false)))
    }
    func replaceScripture(planID: UUID, sectionID: UUID, itemID: UUID, expectedRevision: Int,
                          payloads: [PlanItemPayload]) async -> StudyCommitResult {
        guard let plan = store.plans.first(where: { $0.id == planID }), plan.isActive,
              store.planAccessAllowed(plan) else { return .rejected(.accessDenied) }
        guard plan.revision == expectedRevision else { return .rejected(.stale) }
        guard let section = plan.sections.first(where: { $0.id == sectionID }),
              let original = section.items.first(where: { $0.id == itemID }), original.payload.kind == .scripture,
              !payloads.isEmpty, payloads.allSatisfy({ $0.kind == .scripture && $0.referenceSystemID == plan.referenceSystemID }),
              plan.items.count - 1 + payloads.count <= 2000 else { return .rejected(.invalid) }
        let model = PlanEditorDraft(plan: plan, isExisting: true)
        if payloads != [original.payload] { model.applyAssignments(payloads, sectionID: sectionID, replacing: itemID) }
        return await store.submit(.init(expectedPlanRevision: expectedRevision, intent: .savePlan(model.draft, collectionID: nil)))
    }
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
