import Foundation

/// Persists Hello AO chapter narration (MP3 + timing metadata) for offline playback.
actor ScriptureNarrationMediaStore {
    static let maxChapterBytes = 128 * 1024 * 1024
    static let minimumFreeDiskBytes: Int64 = 256 * 1024 * 1024

    private static let audioFileName = "narration.mp3"
    private static let legacyAudioFileName = "narration.audio"
    private static let manifestFileName = "chapter.json"

    private let root: URL
    private let session: URLSession

    init(root: URL? = nil, session: URLSession = .shared) {
        let base = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScriptureNarration", isDirectory: true)
        self.root = base
        self.session = session
    }

    func storedChapter(
        aoTranslationID: String,
        narratorID: String,
        bookID: String,
        chapter: Int
    ) -> ScriptureNarrationStoredChapter? {
        let manifest = chapterDirectory(aoTranslationID: aoTranslationID, narratorID: narratorID, bookID: bookID, chapter: chapter)
            .appendingPathComponent(Self.manifestFileName)
        guard let data = try? Data(contentsOf: manifest) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ScriptureNarrationStoredChapter.self, from: data)
    }

    func localAudioURL(
        aoTranslationID: String,
        narratorID: String,
        bookID: String,
        chapter: Int
    ) -> URL? {
        guard let stored = storedChapter(
            aoTranslationID: aoTranslationID,
            narratorID: narratorID,
            bookID: bookID,
            chapter: chapter
        ) else { return nil }
        let chapterRoot = chapterDirectory(
            aoTranslationID: aoTranslationID,
            narratorID: narratorID,
            bookID: bookID,
            chapter: chapter
        )
        guard let url = resolvePlayableAudioFile(in: chapterRoot, storedFileName: stored.audioFileName) else {
            if FileManager.default.fileExists(atPath: chapterRoot.path) {
                try? removeChapterDirectory(
                    aoTranslationID: aoTranslationID,
                    narratorID: narratorID,
                    bookID: bookID,
                    chapter: chapter
                )
            }
            return nil
        }
        return url
    }

    /// Resolves a saved chapter audio file, migrating legacy `narration.audio` to `narration.mp3` when needed.
    private func resolvePlayableAudioFile(in chapterRoot: URL, storedFileName: String) -> URL? {
        let candidates = [storedFileName, Self.audioFileName, Self.legacyAudioFileName]
        var seen = Set<String>()
        for name in candidates where seen.insert(name).inserted {
            let url = chapterRoot.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            guard Self.looksLikePlayableAudio(at: url) else { continue }
            if name == Self.legacyAudioFileName || (name != Self.audioFileName && storedFileName != Self.audioFileName) {
                let canonical = chapterRoot.appendingPathComponent(Self.audioFileName)
                if url != canonical {
                    try? FileManager.default.removeItem(at: canonical)
                    try? FileManager.default.moveItem(at: url, to: canonical)
                }
                return canonical
            }
            return url
        }
        return nil
    }

    func discardChapter(
        aoTranslationID: String,
        narratorID: String,
        bookID: String,
        chapter: Int
    ) {
        try? removeChapterDirectory(
            aoTranslationID: aoTranslationID,
            narratorID: narratorID,
            bookID: bookID,
            chapter: chapter
        )
    }

    func package(from stored: ScriptureNarrationStoredChapter, fileURL: URL) -> HelloAOChapterNarrationPackage {
        HelloAOChapterNarrationPackage(
            audioURL: fileURL,
            timingStartTimes: stored.timingStartTimes,
            nextChapterPath: stored.nextChapterPath,
            previousChapterPath: stored.previousChapterPath,
            translationSHA256: stored.recordingRevision
        )
    }

    /// Returns a on-disk file URL, downloading from `remotePackage` when needed.
    func ensureLocalPlaybackURL(
        remotePackage: HelloAOChapterNarrationPackage,
        aoTranslationID: String,
        narratorID: String,
        bookID: String,
        chapter: Int
    ) async throws -> URL {
        let remoteRevision = remotePackage.translationSHA256
        if let existing = localAudioURL(
            aoTranslationID: aoTranslationID,
            narratorID: narratorID,
            bookID: bookID,
            chapter: chapter
        ),
            let stored = storedChapter(
                aoTranslationID: aoTranslationID,
                narratorID: narratorID,
                bookID: bookID,
                chapter: chapter
            ),
            revisionMatches(stored: stored, remoteRevision: remoteRevision) {
            return existing
        }

        let remoteURL = remotePackage.audioURL
        guard remoteURL.isFileURL == false else { return remoteURL }
        guard ScriptureNarrationMediaHostPolicy.isAllowedMediaURL(remoteURL) else {
            throw ScriptureNarrationMediaError.disallowedHost
        }

        try ensureFreeDiskSpace(forAdditionalBytes: Self.maxChapterBytes)

        let (temporaryFile, response) = try await session.download(from: remoteURL)
        defer { try? FileManager.default.removeItem(at: temporaryFile) }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ScriptureNarrationMediaError.invalidResponse
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: temporaryFile.path)
        let byteCount = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard byteCount > 0 else { throw ScriptureNarrationMediaError.invalidResponse }
        guard byteCount <= Self.maxChapterBytes else { throw ScriptureNarrationMediaError.chapterTooLarge }
        guard Self.looksLikePlayableAudio(at: temporaryFile) else {
            throw ScriptureNarrationMediaError.invalidResponse
        }

        let chapterRoot = chapterDirectory(
            aoTranslationID: aoTranslationID,
            narratorID: narratorID,
            bookID: bookID,
            chapter: chapter
        )
        try FileManager.default.createDirectory(at: chapterRoot, withIntermediateDirectories: true)

        let audioDestination = chapterRoot.appendingPathComponent(Self.audioFileName)
        if FileManager.default.fileExists(atPath: audioDestination.path) {
            try FileManager.default.removeItem(at: audioDestination)
        }
        try FileManager.default.moveItem(at: temporaryFile, to: audioDestination)

        let stored = ScriptureNarrationStoredChapter(
            bookID: bookID,
            chapter: chapter,
            narratorID: narratorID,
            aoTranslationID: aoTranslationID,
            recordingRevision: remoteRevision,
            audioFileName: Self.audioFileName,
            timingStartTimes: remotePackage.timingStartTimes,
            nextChapterPath: remotePackage.nextChapterPath,
            previousChapterPath: remotePackage.previousChapterPath,
            downloadedAt: Date()
        )
        try writeJSON(stored, to: chapterRoot.appendingPathComponent(Self.manifestFileName))
        return audioDestination
    }

    /// Offline playback when chapter JSON was saved previously (no metadata fetch).
    func localPlaybackPackage(
        aoTranslationID: String,
        narratorID: String,
        bookID: String,
        chapter: Int
    ) throws -> (HelloAOChapterNarrationPackage, URL) {
        guard
            let stored = storedChapter(
                aoTranslationID: aoTranslationID,
                narratorID: narratorID,
                bookID: bookID,
                chapter: chapter
            ),
            let fileURL = localAudioURL(
                aoTranslationID: aoTranslationID,
                narratorID: narratorID,
                bookID: bookID,
                chapter: chapter
            )
        else {
            throw ScriptureNarrationMediaError.invalidResponse
        }
        return (package(from: stored, fileURL: fileURL), fileURL)
    }

    private func revisionMatches(stored: ScriptureNarrationStoredChapter, remoteRevision: String?) -> Bool {
        guard let remoteRevision, let saved = stored.recordingRevision else { return true }
        return saved == remoteRevision
    }

    private func chapterDirectory(
        aoTranslationID: String,
        narratorID: String,
        bookID: String,
        chapter: Int
    ) -> URL {
        root
            .appendingPathComponent(aoTranslationID, isDirectory: true)
            .appendingPathComponent(narratorID, isDirectory: true)
            .appendingPathComponent(bookID, isDirectory: true)
            .appendingPathComponent(String(chapter), isDirectory: true)
    }

    private func ensureFreeDiskSpace(forAdditionalBytes bytes: Int) throws {
        let home = NSHomeDirectory()
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: home)
        let free = (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        guard free >= Self.minimumFreeDiskBytes + Int64(bytes) else {
            throw ScriptureNarrationMediaError.insufficientStorage
        }
    }

    static func looksLikePlayableAudio(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let prefix = try? handle.read(upToCount: 12), prefix.count >= 3 else { return false }
        if prefix.starts(with: [0x49, 0x44, 0x33]) { return true } // ID3
        if prefix[0] == 0xFF, (prefix[1] & 0xE0) == 0xE0 { return true } // MP3 frame
        if prefix.count >= 8, prefix[4...7] == Data("ftyp".utf8) { return true } // M4A/MP4
        return false
    }

    private func removeChapterDirectory(
        aoTranslationID: String,
        narratorID: String,
        bookID: String,
        chapter: Int
    ) throws {
        let dir = chapterDirectory(
            aoTranslationID: aoTranslationID,
            narratorID: narratorID,
            bookID: bookID,
            chapter: chapter
        )
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: temporary, to: url)
    }
}
