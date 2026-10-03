import CryptoKit
import Foundation

struct MusicCatalog: Sendable {
    let seed: MusicCatalogSeedFile

    init(seed: MusicCatalogSeedFile) { self.seed = seed }

    static func bundled() throws -> MusicCatalog {
        guard let url = Bundle.main.url(forResource: "music-catalog", withExtension: "seed.json", subdirectory: "Music")
            ?? Bundle.main.url(forResource: "music-catalog", withExtension: "seed.json") else {
            throw MusicCatalogError.missingResource
        }
        let decoded = try JSONDecoder().decode(MusicCatalogSeedFile.self, from: Data(contentsOf: url))
        guard decoded.schemaVersion == 1 else { throw MusicCatalogError.invalidManifest }
        let catalog = MusicCatalog(seed: decoded)
        if !catalog.tracks.isEmpty {
            try catalog.validateBundledFiles()
        }
        return catalog
    }

    var tracks: [MusicTrackDefinition] {
        seed.tracks.filter(\.ownerApproved).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func track(id: String) -> MusicTrackDefinition? { seed.tracks.first { $0.id == id } }

    func fileURL(for track: MusicTrackDefinition) -> URL? {
        Bundle.main.url(forResource: track.resourceName, withExtension: track.fileExtension, subdirectory: "Music/tracks")
            ?? Bundle.main.url(forResource: track.resourceName, withExtension: track.fileExtension, subdirectory: "tracks")
            ?? Bundle.main.url(forResource: track.resourceName, withExtension: track.fileExtension)
    }

    func nextTrackID(after currentID: String, loopAll: Bool) -> String? {
        MusicTrackDefinition.nextTrackID(in: tracks, after: currentID, loopAll: loopAll)
    }

    private func validateBundledFiles() throws {
        guard !tracks.isEmpty else { throw MusicCatalogError.noApprovedTracks }
        for track in tracks {
            guard let url = fileURL(for: track) else { throw MusicCatalogError.missingTrackFile(trackID: track.id) }
            let data = try Data(contentsOf: url)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == track.fileDigest else { throw MusicCatalogError.digestMismatch(trackID: track.id) }
        }
    }
}
