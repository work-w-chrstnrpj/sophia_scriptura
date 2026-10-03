import CryptoKit
import Foundation

struct UserMusicLibraryEntry: Codable, Equatable, Sendable {
    var id: String
    var title: String
    var storedFileName: String
    var fileDigest: String
    var importedAt: Date
    var originalFileName: String
}

struct UserMusicLibraryManifest: Codable, Sendable {
    var schemaVersion: Int
    var tracks: [UserMusicLibraryEntry]
}

/// Local-only tracks the owner imports; files live under Application Support.
struct UserMusicLibraryStore: Sendable {
    static let licenseID = "user-owned"
    private static let allowedExtensions: Set<String> = ["m4a", "mp3", "wav", "aac", "caf", "aif", "aiff"]

    let directory: URL
    private var manifestURL: URL { directory.appendingPathComponent("user-library.json") }

    init(directory: URL) { self.directory = directory }

    static func `default`() -> UserMusicLibraryStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return UserMusicLibraryStore(directory: base.appendingPathComponent("MusicUserLibrary", isDirectory: true))
    }

    func loadTracks() throws -> [MusicTrackDefinition] {
        try loadManifest().tracks.map(trackDefinition(from:))
    }

    func fileURL(for trackID: String) -> URL? {
        guard let entry = try? loadManifest().tracks.first(where: { $0.id == trackID }) else { return nil }
        let url = directory.appendingPathComponent(entry.storedFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func deleteTrack(id: String) throws {
        var manifest = try loadManifest()
        guard let index = manifest.tracks.firstIndex(where: { $0.id == id }) else { return }
        let entry = manifest.tracks.remove(at: index)
        try saveManifest(manifest)
        let file = directory.appendingPathComponent(entry.storedFileName)
        if FileManager.default.fileExists(atPath: file.path) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    func renameTrack(id: String, title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MusicCatalogError.invalidManifest }
        var manifest = try loadManifest()
        guard let index = manifest.tracks.firstIndex(where: { $0.id == id }) else { return }
        manifest.tracks[index].title = trimmed
        try saveManifest(manifest)
    }

    /// Replaces audio bytes while keeping the track id and display title.
    func replaceTrackFile(id: String, from source: URL) throws {
        let ext = source.pathExtension.lowercased()
        guard Self.allowedExtensions.contains(ext) else { throw MusicCatalogError.unsupportedAudioFormat }
        var manifest = try loadManifest()
        guard let index = manifest.tracks.firstIndex(where: { $0.id == id }) else { return }
        let title = manifest.tracks[index].title
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }

        let storedFileName = "\(id).\(ext)"
        let destination = directory.appendingPathComponent(storedFileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        let data = try Data(contentsOf: destination)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        manifest.tracks[index].storedFileName = storedFileName
        manifest.tracks[index].fileDigest = digest
        manifest.tracks[index].originalFileName = source.lastPathComponent
        manifest.tracks[index].title = title
        try saveManifest(manifest)
    }

    func importFile(from source: URL) throws -> MusicTrackDefinition {
        let ext = source.pathExtension.lowercased()
        guard Self.allowedExtensions.contains(ext) else { throw MusicCatalogError.unsupportedAudioFormat }
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString.lowercased()
        let storedFileName = "\(id).\(ext)"
        let destination = directory.appendingPathComponent(storedFileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)

        let data = try Data(contentsOf: destination)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let title = sanitizedTitle(from: source.deletingPathExtension().lastPathComponent)
        let entry = UserMusicLibraryEntry(
            id: id,
            title: title,
            storedFileName: storedFileName,
            fileDigest: digest,
            importedAt: Date(),
            originalFileName: source.lastPathComponent
        )
        var manifest = try loadManifest()
        manifest.tracks.append(entry)
        try saveManifest(manifest)
        return trackDefinition(from: entry)
    }

    private func loadManifest() throws -> UserMusicLibraryManifest {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return UserMusicLibraryManifest(schemaVersion: 1, tracks: [])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UserMusicLibraryManifest.self, from: Data(contentsOf: manifestURL))
    }

    private func saveManifest(_ manifest: UserMusicLibraryManifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }

    private func trackDefinition(from entry: UserMusicLibraryEntry) -> MusicTrackDefinition {
        let parts = entry.storedFileName.split(separator: ".", maxSplits: 1).map(String.init)
        let resource = parts.first ?? entry.id
        let fileExt = parts.count > 1 ? parts[1] : "m4a"
        let importedDay = ISO8601DateFormatter().string(from: entry.importedAt).prefix(10)
        return MusicTrackDefinition(
            id: entry.id,
            title: entry.title,
            composer: "Your library",
            performer: "Imported on device",
            resourceName: resource,
            fileExtension: fileExt,
            fileDigest: entry.fileDigest,
            licenseID: Self.licenseID,
            licenseURL: "local://user-library",
            sourceURL: "file://\(entry.originalFileName)",
            evidenceCapturedOn: String(importedDay),
            attributionRequired: false,
            attributionText: nil,
            ownerApproved: true,
            reviewStatus: "user-import"
        )
    }

    private func sanitizedTitle(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Imported track" : trimmed
    }
}
