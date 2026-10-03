import Foundation

protocol CompanionRepository: Sendable {
    func load() async throws -> CompanionLoad
    func save(_ snapshot: CompanionSnapshot, expectedRevision: Int) async throws -> CompanionSnapshot
}

struct CompanionLoad: Sendable {
    var snapshot: CompanionSnapshot
    var recovered: Bool
}

enum CompanionPersistenceError: Error, LocalizedError {
    case stale
    case invalid
    case damaged
    case unsupported

    var errorDescription: String? {
        switch self {
        case .stale: return "Companion changed before this save completed."
        case .invalid: return "Companion data is not valid."
        case .damaged: return "Companion data is damaged. The previous revision was kept."
        case .unsupported: return "This Companion file is from a newer Sophia."
        }
    }
}
