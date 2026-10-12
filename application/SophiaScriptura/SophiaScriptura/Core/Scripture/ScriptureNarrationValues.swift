import Foundation

/// Stable identity for a chapter narration asset. URLs are resolved at playback time, not persisted as identity.
struct ScriptureAudioAssetIdentity: Codable, Equatable, Sendable {
    let sourceID: TranslationSourceID
    let editionID: String
    let referenceSystemID: String
    let contentRevision: String
    let aoTranslationID: String
    let bookID: String
    let chapter: Int
    let narratorID: String
    let recordingRevision: String
    let rightsPolicyID: String

    var chapterLabel: String { "\(bookID) \(chapter)" }
}

enum ScriptureNarrationPlaybackPhase: Equatable, Sendable {
    case idle
    case loading
    case playing
    case paused
    case buffering
    case ended
    case failed(String)
}

struct ScriptureNarrationOperationEpoch: Equatable, Sendable {
    let id: UUID
    static func fresh() -> ScriptureNarrationOperationEpoch { ScriptureNarrationOperationEpoch(id: UUID()) }
}

struct ScriptureNarrationPlaybackSnapshot: Equatable, Sendable {
    var phase: ScriptureNarrationPlaybackPhase = .idle
    var asset: ScriptureAudioAssetIdentity?
    var elapsed: TimeInterval = 0
    var duration: TimeInterval = 0
    var highlightingAvailable = false
    var highlightingStatusMessage: String?
    var editionDisplayName: String = ""
    var narratorDisplayName: String = ""
    /// True when `AVPlayer` is reading a file under Application Support narration storage.
    var usesLocalAudio = false
}

enum ScriptureNarrationDeliveryMode: String, Codable, CaseIterable, Sendable {
    /// Play from Hello AO HTTPS URLs when no chapter is saved on device.
    case streaming
    /// Download each chapter to this iPad before playback (or use an existing saved file).
    case saveForOffline

    var settingsLabel: String {
        switch self {
        case .streaming: "Stream when online"
        case .saveForOffline: "Save for offline"
        }
    }
}

struct ScriptureNarrationPreferences: Codable, Equatable, Sendable {
    var continuousChapters: Bool
    var followAudio: Bool
    var preferredNarratorID: String
    var deliveryMode: ScriptureNarrationDeliveryMode

    static let initial = ScriptureNarrationPreferences(
        continuousChapters: false,
        followAudio: false,
        preferredNarratorID: ScriptureNarrationNarrator.defaultID,
        deliveryMode: .saveForOffline
    )
}

enum ScriptureNarrationNarrator: String, CaseIterable, Sendable {
    case hays
    case david
    case souer
    case gilbert

    static let defaultID = ScriptureNarrationNarrator.hays.rawValue

    var displayName: String {
        switch self {
        case .hays: "Hays McEachern"
        case .david: "David Cochran"
        case .souer: "Souer"
        case .gilbert: "Gilbert"
        }
    }
}

enum ScriptureNarrationCatalog {
    static let bsbEditionID = "helloao.BSB"
    static let bsbAOTranslationID = "BSB"
    static let bsbDisplayName = "Berean Standard Bible"
    static let streamingRightsPolicyID = "helloao.bsb.narration.streaming"
    static let offlineRightsPolicyID = "helloao.bsb.narration.offline"

    static var rightsPolicyID: String { offlineRightsPolicyID }

    static func aoTranslationID(forEditionID editionID: String) -> String? {
        guard editionID == bsbEditionID else { return nil }
        return bsbAOTranslationID
    }

    static func supportsNarration(editionID: String) -> Bool {
        aoTranslationID(forEditionID: editionID) != nil
    }
}

enum ScriptureNarrationMediaHostPolicy {
    private static let allowedHosts: Set<String> = [
        "audio.bible.helloao.org",
        "openbible.com",
        "bible.helloao.org"
    ]

    static func isAllowedMediaURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return allowedHosts.contains(host)
    }
}
