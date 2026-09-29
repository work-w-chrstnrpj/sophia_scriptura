import Foundation

/// Serial actor performs file IO away from the UI. The single atomic envelope avoids
/// publishing metadata that points to incompletely written ink/image files.
actor CanvasFixtureStore {
    let url: URL
    private var savedRevision = -1
    init(url: URL) { self.url = url }

    func load() throws -> CanvasFixture? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= CanvasFixture.maximumFileBytes else { throw FixtureError.fileTooLarge }
        return try Self.decode(Data(contentsOf: url))
    }

    func save(_ document: CanvasFixture, revision: Int? = nil) throws {
        // An older autosave task arriving late must never replace a newer revision.
        if let revision, revision < savedRevision { return }
        _ = try document.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(document)
        guard bytes.count <= CanvasFixture.maximumFileBytes else { throw FixtureError.fileTooLarge }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        if let revision { savedRevision = revision }
    }

    /// Validate before replacing the existing fixture. Invalid input cannot destroy it.
    func restore(_ bytes: Data) throws -> CanvasFixture {
        let candidate = try Self.decode(bytes)
        try save(candidate)
        return candidate
    }

    static func decode(_ bytes: Data) throws -> CanvasFixture {
        guard bytes.count <= CanvasFixture.maximumFileBytes else { throw FixtureError.fileTooLarge }
        return try JSONDecoder().decode(CanvasFixture.self, from: bytes).validated()
    }
}
