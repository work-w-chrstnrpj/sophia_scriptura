import Foundation

actor HelloAOStore {
    static let stagingBudgetBytes = 256 * 1024 * 1024
    /// Reserve before starting a download; full guide target is 512 MiB — use a practical floor for personal devices.
    static let minimumFreeDiskBytes: Int64 = 128 * 1024 * 1024

    private let client: HelloAOClient
    private let root: URL
    private var catalogCache: HelloAOCatalogCache?
    private var activeDownload: String?
    private var downloadTask: Task<Void, Never>?
    private var operationEpoch = UUID()
    private var stagingBytes = 0

    init(client: HelloAOClient = HelloAOClient(), root: URL? = nil) {
        self.client = client
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScriptureSources/HelloAO", isDirectory: true)
    }

    func localStatuses() -> [HelloAOEditionStatus] {
        let catalog = loadCatalogCache()
        return HelloAOEligibility.manifest.editions.map { eligible in
            let installed = loadInstalledManifest(providerID: eligible.providerEditionID)
            let journal = loadJournal(providerID: eligible.providerEditionID)
            let entry = catalog?.entries.first { $0.id == eligible.providerEditionID }
            let state: HelloAOInstallState
            let completed: Int
            let total: Int
            let errorMessage: String?
            if activeDownload == eligible.providerEditionID {
                state = .downloading
                completed = journal?.completed.count ?? 0
                total = journal?.chapters.count ?? installed?.chapters.count ?? 0
                errorMessage = nil
            } else if let installed {
                state = .installed
                completed = installed.chapters.count
                total = installed.chapters.count
                errorMessage = nil
            } else if let journal, !journal.completed.isEmpty {
                state = .paused
                completed = journal.completed.count
                total = journal.chapters.count
                errorMessage = nil
            } else {
                state = .notInstalled
                completed = 0
                total = entry?.numberOfBooks ?? eligible.expectedBookCount
                errorMessage = nil
            }
            return HelloAOEditionStatus(
                eligible: eligible,
                state: state,
                progressCompleted: completed,
                progressTotal: max(total, 1),
                contentRevision: installed?.contentRevision,
                catalogName: entry?.name ?? eligible.name,
                catalogLanguage: entry?.languageName ?? entry?.language ?? eligible.language,
                lastCatalogRefresh: catalog?.refreshedAt,
                errorMessage: errorMessage
            )
        }
    }

    func refreshCatalog() async throws {
        let wire = try await client.availableTranslations()
        let allowed = Set(HelloAOEligibility.manifest.editions.map(\.providerEditionID))
        let entries = wire.translations.compactMap { row -> HelloAOCatalogEntry? in
            guard allowed.contains(row.id) else { return nil }
            return HelloAOCatalogEntry(
                id: row.id,
                name: row.name ?? row.id,
                shortName: row.shortName,
                language: row.language ?? "eng",
                languageName: row.languageName,
                numberOfBooks: row.numberOfBooks ?? 0,
                licenseUrl: row.licenseUrl,
                website: row.website,
                sha256: row.sha256
            )
        }
        let cache = HelloAOCatalogCache(refreshedAt: Date(), entries: entries)
        try ensureRoot()
        catalogCache = cache
        try writeJSON(cache, to: root.appendingPathComponent("catalog-cache.json"))
    }

    func download(
        providerEditionID: String,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws {
        guard let eligible = HelloAOEligibility.edition(providerID: providerEditionID) else {
            throw HelloAOError.ineligibleEdition
        }
        guard activeDownload == nil else { throw HelloAOError.busy }
        guard hasDiskSpace() else { throw HelloAOError.insufficientStorage }

        let epoch = UUID()
        operationEpoch = epoch
        activeDownload = providerEditionID
        stagingBytes = 0

        defer {
            if operationEpoch == epoch {
                activeDownload = nil
            }
        }

        try ensureRoot()
        let booksWire = try await client.books(translationID: providerEditionID)
        let books = try HelloAOChapterParser.books(from: booksWire, eligible: eligible)
        let chapters = HelloAOChapterParser.chapterInventory(from: books)
        let revision = booksWire.translation?.sha256 ?? "provider-unversioned"
        let referenceSystemID = ScriptureReferenceIdentity.referenceSystemID(forEditionID: eligible.appEditionID) ?? ""
        let edition = ScriptureEdition(
            id: eligible.appEditionID,
            referenceSystemID: referenceSystemID,
            contentRevision: revision,
            name: eligible.name,
            abbreviation: eligible.abbreviation,
            attribution: eligible.attribution
        )

        var journal = loadJournal(providerID: providerEditionID)
        if journal?.contentRevision != revision || journal?.chapters != chapters {
            journal = HelloAOStagingJournal(
                generation: UUID().uuidString,
                providerEditionID: providerEditionID,
                edition: edition,
                books: books,
                chapters: chapters,
                completed: [],
                contentRevision: revision
            )
        }
        guard var stage = journal else { throw HelloAOError.invalidResponse }
        let editionRoot = editionRootURL(providerID: providerEditionID, generation: stage.generation)
        stage.completed = reconcileCompletedChapters(
            stage.completed,
            inventory: chapters,
            editionRoot: editionRoot,
            editionID: edition.id
        )
        try writeJSON(stage, to: journalURL(providerID: providerEditionID))

        progress(stage.completed.count, chapters.count)
        let pending = chapters.filter { !stage.completed.contains($0) }
        stagingBytes = stagedPayloadBytes(in: editionRoot)

        let network = client
        for start in stride(from: 0, to: pending.count, by: 2) {
            try Task.checkCancellation()
            guard operationEpoch == epoch else { throw HelloAOError.cancelled }
            let batch = Array(pending[start..<min(start + 2, pending.count)])
            try await withThrowingTaskGroup(of: (String, ChapterDocument).self) { group in
                for chapterID in batch {
                    group.addTask {
                        let parts = chapterID.split(separator: ".", maxSplits: 1)
                        guard parts.count == 2, let chapterNumber = Int(parts[1]) else { throw HelloAOError.invalidResponse }
                        let wire = try await network.chapter(
                            translationID: providerEditionID,
                            book: String(parts[0]),
                            number: chapterNumber
                        )
                        let document = try HelloAOChapterParser.parse(wire, eligible: eligible)
                        return (chapterID, document)
                    }
                }
                for try await (chapterID, document) in group {
                    guard operationEpoch == epoch else { throw HelloAOError.cancelled }
                    let bytes = try JSONEncoder().encode(document)
                    guard hasDiskSpace(additionalBytes: bytes.count) else { throw HelloAOError.insufficientStorage }
                    guard stagingBytes + bytes.count <= Self.stagingBudgetBytes else { throw HelloAOError.insufficientStorage }
                    try ensureDirectory(editionRoot.appendingPathComponent("chapters", isDirectory: true))
                    let destination = editionRoot.appendingPathComponent("chapters/\(chapterID).json")
                    try writeData(bytes, to: destination)
                    stage.completed.insert(chapterID)
                    stagingBytes = stagedPayloadBytes(in: editionRoot)
                    try writeJSON(stage, to: journalURL(providerID: providerEditionID))
                    progress(stage.completed.count, chapters.count)
                }
            }
        }

        guard stage.completed.count == chapters.count else { throw HelloAOError.invalidResponse }
        for chapterID in chapters {
            let url = editionRoot.appendingPathComponent("chapters/\(chapterID).json")
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let document = try? JSONDecoder().decode(ChapterDocument.self, from: data),
                  document.editionID == edition.id else { throw HelloAOError.invalidResponse }
        }

        let manifest = HelloAOInstalledManifest(
            generation: stage.generation,
            providerEditionID: providerEditionID,
            edition: edition,
            books: books,
            chapters: chapters,
            fetchedAt: Date(),
            contentRevision: revision
        )
        try writeJSON(manifest, to: editionRoot.appendingPathComponent("manifest.json"))
        try writeJSON(manifest, to: installedManifestURL(providerID: providerEditionID))
        try? FileManager.default.removeItem(at: journalURL(providerID: providerEditionID))
        stagingBytes = 0
    }

    func cancelDownload() {
        operationEpoch = UUID()
        activeDownload = nil
        downloadTask?.cancel()
        downloadTask = nil
    }

    func deleteDownload(providerEditionID: String) throws {
        guard activeDownload != providerEditionID else { throw HelloAOError.busy }
        let manifest = loadInstalledManifest(providerID: providerEditionID)
        try? FileManager.default.removeItem(at: editionDirectory(providerID: providerEditionID))
        try? FileManager.default.removeItem(at: installedManifestURL(providerID: providerEditionID))
        try? FileManager.default.removeItem(at: journalURL(providerID: providerEditionID))
        if manifest == nil { throw HelloAOError.notInstalled }
    }

    func installedManifest(providerEditionID: String) -> HelloAOInstalledManifest? {
        loadInstalledManifest(providerID: providerEditionID)
    }

    func chapter(providerEditionID: String, book: String, number: Int) throws -> ChapterDocument {
        guard let manifest = loadInstalledManifest(providerID: providerEditionID) else { throw HelloAOError.notInstalled }
        let chapterID = "\(book).\(number)"
        guard manifest.chapters.contains(chapterID) else { throw ScriptureError.chapterUnavailable }
        let url = editionRootURL(providerID: providerEditionID, generation: manifest.generation)
            .appendingPathComponent("chapters/\(chapterID).json")
        guard let data = try? Data(contentsOf: url) else { throw HelloAOError.invalidResponse }
        let document = try JSONDecoder().decode(ChapterDocument.self, from: data)
        guard document.editionID == manifest.edition.id,
              document.book == book,
              document.chapter == number else { throw HelloAOError.invalidResponse }
        return document
    }

    // MARK: - Paths

    private func ensureRoot() throws {
        try ensureDirectory(root)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = root
        try url.setResourceValues(values)
    }

    private func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func editionDirectory(providerID: String) -> URL {
        root.appendingPathComponent(providerID, isDirectory: true)
    }

    private func editionRootURL(providerID: String, generation: String) -> URL {
        editionDirectory(providerID: providerID).appendingPathComponent(generation, isDirectory: true)
    }

    private func installedManifestURL(providerID: String) -> URL {
        editionDirectory(providerID: providerID).appendingPathComponent("installed-manifest.json")
    }

    private func journalURL(providerID: String) -> URL {
        editionDirectory(providerID: providerID).appendingPathComponent("staging-journal.json")
    }

    private func loadInstalledManifest(providerID: String) -> HelloAOInstalledManifest? {
        let url = installedManifestURL(providerID: providerID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HelloAOInstalledManifest.self, from: data)
    }

    private func loadJournal(providerID: String) -> HelloAOStagingJournal? {
        let url = journalURL(providerID: providerID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HelloAOStagingJournal.self, from: data)
    }

    private func loadCatalogCache() -> HelloAOCatalogCache? {
        if let catalogCache { return catalogCache }
        let url = root.appendingPathComponent("catalog-cache.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(HelloAOCatalogCache.self, from: data) else { return nil }
        catalogCache = decoded
        return decoded
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        try ensureDirectory(url.deletingLastPathComponent())
        let data = try JSONEncoder().encode(value)
        try writeData(data, to: url)
    }

    private func writeData(_ data: Data, to url: URL) throws {
        let temporary = url.appendingPathExtension("tmp")
        try data.write(to: temporary, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: temporary, to: url)
    }

    private func hasDiskSpace(additionalBytes: Int = 0) -> Bool {
        try? ensureRoot()
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: root.path),
              let free = attrs[.systemFreeSize] as? Int64 else { return true }
        return free >= Self.minimumFreeDiskBytes + Int64(additionalBytes)
    }

    /// Drop journal entries whose staged files are missing or no longer decode as the expected edition.
    private func reconcileCompletedChapters(
        _ completed: Set<String>,
        inventory: [String],
        editionRoot: URL,
        editionID: String
    ) -> Set<String> {
        let allowed = Set(inventory)
        var verified: Set<String> = []
        for chapterID in completed where allowed.contains(chapterID) {
            let url = editionRoot.appendingPathComponent("chapters/\(chapterID).json")
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let document = try? JSONDecoder().decode(ChapterDocument.self, from: data),
                  document.editionID == editionID else { continue }
            verified.insert(chapterID)
        }
        return verified
    }

    private func stagedPayloadBytes(in editionRoot: URL) -> Int {
        let chaptersDir = editionRoot.appendingPathComponent("chapters", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: chaptersDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + size
        }
    }
}
