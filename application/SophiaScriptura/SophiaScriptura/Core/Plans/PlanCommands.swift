import Foundation

enum StudyMutationFailure: String, Error, Codable, LocalizedError, Sendable {
    case invalid, stale, accessDenied, unavailable, capacity, busy, unsupported, persistence
    var errorDescription: String? {
        switch self {
        case .invalid: "The Plan data is invalid. Check its title and assignments."
        case .stale: "This Plan changed. Reopen it before saving these edits."
        case .accessDenied: "Unlock the required study material before continuing."
        case .unavailable: "This study material is no longer available."
        case .capacity: "The study storage limit was reached. Your existing material is unchanged."
        case .busy: "Another study operation is in progress. Try again after it finishes."
        case .unsupported: "This study data requires a newer Sophia. Original files are retained."
        case .persistence: "The save could not be confirmed. Your edits are retained for retry."
        }
    }
}
struct StudyCommandReceipt: Codable, Equatable, Sendable {
    var commandID: UUID
    var intentHash: String
    var storeRevision: Int
    var planID: UUID?
    var planRevision: Int?
    var resultIDs: [UUID]
    var committedAt: Date
}
struct StudyMutationRequest: Sendable {
    var commandID = UUID()
    var expectedPlanRevision: Int?
    var intent: StudyMutationIntent
}
enum StudyMutationIntent: Codable, Sendable {
    case savePlan(StudyPlan, collectionID: UUID?)
    case createPlanMaterialsFolder(planID: UUID, folder: StudyCollection, replaceExisting: Bool)
    case filePlanMaterial(planID: UUID, sectionID: UUID, artifactID: UUID)
    case setPlanTreeTrashed(planID: UUID, trashed: Bool)
    case finishPlanTreeNotes(UUID)
    case purgePlan(UUID)
    case saveLink(SavedLink, collectionID: UUID?)
    case prepareOperation(PlanOperation)
    case finishOperation(UUID)
    case legacyPatch(Data)
    case restoreCollections(Data)
}
enum StudyCommitResult: Equatable, Sendable {
    case committed(StudyCommandReceipt)
    case rejected(StudyMutationFailure)
    case uncertain(commandID: UUID)
    var receipt: StudyCommandReceipt? { if case .committed(let receipt) = self { return receipt }; return nil }
    var message: String? {
        switch self {
        case .committed: nil
        case .rejected(let error): error.localizedDescription
        case .uncertain: StudyMutationFailure.persistence.localizedDescription
        }
    }
}
struct PlanOperation: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable { case attachNote, createLayer, renameLayers, propagateAccess, detachPlan }
    enum Phase: String, Codable, Sendable { case prepared, targetCommitted, attached, needsReview }
    var id = UUID()
    var kind: Kind
    var planID: UUID?
    var affectedPlanIDs: [UUID] = []
    var anchorItemID: UUID?
    var targetIDs: [UUID] = []
    var expectedPlanRevision: Int?
    var access = StudyAccessRequirements()
    var phase: Phase = .prepared
    var createdAt = Date()
    // Typed source/targets; no executable closures or target bodies.
    var sectionID: UUID?
    var source: AnnotationSource?
    var title: String?
}
enum StudyTargetCommitResult: Equatable, Sendable {
    case committed(ids: [UUID], revision: Int)
    case rejected(StudyMutationFailure)
    case uncertain(operationID: UUID)
}
