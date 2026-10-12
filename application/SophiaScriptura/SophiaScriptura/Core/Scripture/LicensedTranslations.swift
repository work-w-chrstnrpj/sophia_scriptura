import Foundation

struct LicensedTranslation: Identifiable, Sendable {
    let id: String
    let abbreviation: String
    let name: String
    static let approved = [
        Self(id:"b8ee27bcd1cae43a-01",abbreviation:"NASB",name:"New American Standard Bible"),
        Self(id:"d6e14a625393b4da-01",abbreviation:"NLT",name:"New Living Translation"),
        Self(id:"63097d2a0a2f7db3-01",abbreviation:"NKJV",name:"New King James Version")]
    var editionID: String { "api.bible." + id }
}

struct TranslationStatus: Identifiable, Sendable {
    let translation: LicensedTranslation
    let expiresAt: Date?
    let isAvailable: Bool
    var id: String { translation.id }
}

/// API.Bible granted Sophia Scriptura a written development-period exception for
/// licensed API editions during development. The exception is compiled into development
/// builds only; Release/Archive builds retain the standard refresh boundary.
enum OfflineContentPolicy: Sendable, Equatable {
    case standard
    case developmentException

    static var current: Self {
        #if DEBUG
        return .developmentException
        #else
        return .standard
        #endif
    }

    var enforcesRefresh: Bool { self == .standard }
}

enum LicensedContentError: Error, LocalizedError {
    case credential, accessDenied, quota, transport, invalidContent, storage, expired, busy
    var errorDescription: String? {
        switch self {
        case .credential: "Enter your API.Bible key in Versions to connect."
        case .accessDenied: "API.Bible denied access. Check your key and selected translations."
        case .quota: "API.Bible's request limit was reached. Try syncing after your allowance resets."
        case .transport: "Could not connect to API.Bible. Existing unexpired downloads remain available."
        case .invalidContent: "The downloaded edition could not be verified. The previous copy is unchanged."
        case .storage: "Encrypted Bible storage could not be opened. Existing data has not been reset."
        case .expired: "This translation is locked. Connect and sync in Versions to renew offline access."
        case .busy: "A translation download is already running."
        }
    }
}

struct OfflineLease: Codable, Sendable {
    static let duration: TimeInterval = 30 * 24 * 60 * 60
    let synchronizedAt: Date
    var expiresAt: Date { synchronizedAt.addingTimeInterval(Self.duration) }
    func permits(now: Date, lastSeen: Date, policy: OfflineContentPolicy = .standard) -> Bool {
        guard now >= synchronizedAt.addingTimeInterval(-300),
              now >= lastSeen.addingTimeInterval(-300) else { return false }
        return !policy.enforcesRefresh || now < expiresAt
    }
}

protocol TranslationLibrary: Sendable {
    func statuses() async throws -> [TranslationStatus]
    func repository(editionID: String) async throws -> any ScriptureContentRepository
    func setCredential(_ value: String) async throws
    func sync(_ id: String, progress: @escaping @Sendable (Int, Int) -> Void) async throws
    func authorizeQuote(editionID: String, verses: Int, characters: Int) async throws
}
