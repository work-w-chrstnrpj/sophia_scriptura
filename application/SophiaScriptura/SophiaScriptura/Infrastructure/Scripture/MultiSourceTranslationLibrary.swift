import Foundation

/// Source-neutral translation library boundary. Forwards API.Bible work to `OfflineTranslationLibrary`; Hello AO Lab uses `HelloAOStore`.
actor MultiSourceTranslationLibrary: TranslationLibrary {
    static let bundledDescriptor = TranslationDescriptor.bundledWEBP()

    private let offline: OfflineTranslationLibrary
    private let helloAO: HelloAOStore

    init(
        api: any BibleAPI = APIBibleClient(),
        canonical: any ScriptureContentRepository = BundledScriptureRepository(),
        url: URL? = nil,
        keychain: any ScriptureSecureStore = ScriptureKeychain(),
        policy: OfflineContentPolicy = .current,
        helloAOStore: HelloAOStore = HelloAOStore()
    ) {
        offline = OfflineTranslationLibrary(
            api: api,
            canonical: canonical,
            url: url,
            keychain: keychain,
            policy: policy
        )
        helloAO = helloAOStore
    }

    func statuses() async throws -> [TranslationStatus] {
        try await offline.statuses()
    }

    func helloAOEditionStatuses() async -> [HelloAOEditionStatus] {
        await helloAO.localStatuses()
    }

    func refreshHelloAOCatalog() async throws {
        try await helloAO.refreshCatalog()
    }

    func downloadHelloAO(
        providerEditionID: String,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws {
        try await helloAO.download(providerEditionID: providerEditionID, progress: progress)
    }

    func cancelHelloAODownload() async {
        await helloAO.cancelDownload()
    }

    func deleteHelloAODownload(providerEditionID: String) async throws {
        try await helloAO.deleteDownload(providerEditionID: providerEditionID)
    }

    func installedHelloAOChapterIDs(providerEditionID: String) async -> [String]? {
        await helloAO.installedManifest(providerEditionID: providerEditionID)?.chapters
    }

    func repository(editionID: String) async throws -> any ScriptureContentRepository {
        if editionID.hasPrefix("helloao.") {
            guard let providerID = HelloAOEligibility.providerEditionID(appEditionID: editionID),
                  let manifest = await helloAO.installedManifest(providerEditionID: providerID) else {
                throw ScriptureError.editionUnavailable
            }
            return HelloAOEditionRepository(store: helloAO, providerEditionID: providerID, manifest: manifest)
        }
        return try await offline.repository(editionID: editionID)
    }

    func setCredential(_ value: String) async throws {
        try await offline.setCredential(value)
    }

    func sync(_ id: String, progress: @escaping @Sendable (Int, Int) -> Void) async throws {
        if HelloAOEligibility.edition(providerID: id) != nil {
            try await downloadHelloAO(providerEditionID: id, progress: progress)
            return
        }
        try await offline.sync(id, progress: progress)
    }

    func authorizeQuote(editionID: String, verses: Int, characters: Int) async throws {
        if editionID.hasPrefix("helloao.") {
            guard let providerID = HelloAOEligibility.providerEditionID(appEditionID: editionID),
                  HelloAOEligibility.edition(appEditionID: editionID) != nil,
                  await helloAO.installedManifest(providerEditionID: providerID) != nil else {
                throw ScriptureError.editionUnavailable
            }
            return
        }
        try await offline.authorizeQuote(editionID: editionID, verses: verses, characters: characters)
    }
}
