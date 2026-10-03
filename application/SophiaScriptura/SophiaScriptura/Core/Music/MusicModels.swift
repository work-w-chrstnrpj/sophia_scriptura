import Foundation

struct MusicTrackDefinition: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var composer: String
    var performer: String
    var resourceName: String
    var fileExtension: String
    var fileDigest: String
    var licenseID: String
    var licenseURL: String
    var sourceURL: String
    var evidenceCapturedOn: String
    var attributionRequired: Bool
    var attributionText: String?
    var ownerApproved: Bool
    var reviewStatus: String
}

struct MusicCatalogSeedFile: Codable, Sendable {
    var schemaVersion: Int
    var catalogID: String
    var tracks: [MusicTrackDefinition]
}

enum MusicPlaybackPhase: Equatable, Sendable {
    case idle
    case paused
    case playing
    case interrupted
}

struct MusicPlaybackSnapshot: Equatable, Sendable {
    var selectedTrackID: String?
    var loopAll: Bool
    var phase: MusicPlaybackPhase
    var hasStartedPlayback: Bool

    static let initial = MusicPlaybackSnapshot(selectedTrackID: nil, loopAll: true, phase: .idle, hasStartedPlayback: false)
}

enum MusicCommand: Sendable {
    case selectTrack(String)
    case play
    case pause
    case togglePlayPause
    case next
    case setLoopAll(Bool)
    case clear
}

enum MusicCatalogError: Error, Equatable {
    case missingResource
    case invalidManifest
    case digestMismatch(trackID: String)
    case missingTrackFile(trackID: String)
    case noApprovedTracks
    case unsupportedAudioFormat
    case importAccessDenied
}

extension MusicTrackDefinition {
    var isUserLibrary: Bool { licenseID == UserMusicLibraryStore.licenseID }

    static func nextTrackID(in ordered: [MusicTrackDefinition], after currentID: String, loopAll: Bool) -> String? {
        guard let index = ordered.firstIndex(where: { $0.id == currentID }) else { return ordered.first?.id }
        let nextIndex = ordered.index(after: index)
        if nextIndex < ordered.endIndex { return ordered[nextIndex].id }
        return loopAll ? ordered.first?.id : nil
    }
}
