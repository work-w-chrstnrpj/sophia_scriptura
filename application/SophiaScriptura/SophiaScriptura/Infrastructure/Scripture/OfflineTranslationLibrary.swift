import Foundation
import CryptoKit

actor OfflineTranslationLibrary: TranslationLibrary {
    private struct Manifest: Codable {
        let generation: String
        let edition: ScriptureEdition
        let books: [ScriptureBook]
        let chapters: [String]
        let lease: OfflineLease
    }
    private struct Staging: Codable {
        let manifest: Manifest
        var completed: Set<String>
    }
    private let api: any BibleAPI
    private let keychain: any ScriptureSecureStore
    private let url: URL
    private let canonical: any ScriptureContentRepository
    private let policy: OfflineContentPolicy
    private var store: EncryptedBibleStore?
    private var syncing = false
    private var timeAnchor: (date: Date, uptime: TimeInterval)?
    private var rollbackDetected = false

    init(api: any BibleAPI = APIBibleClient(), canonical: any ScriptureContentRepository = BundledScriptureRepository(),
         url: URL? = nil, keychain: any ScriptureSecureStore = ScriptureKeychain(),
         policy: OfflineContentPolicy = .current) {
        self.api = api; self.canonical = canonical; self.keychain = keychain
        self.policy = policy
        self.url = url ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("LicensedBibles",isDirectory:true).appendingPathComponent("encrypted-v1.sqlite")
    }
    private func storage() throws -> EncryptedBibleStore {
        if let store { return store }
        let key = try keychain.encryptionKey(create:!FileManager.default.fileExists(atPath:url.path))
        let result = try EncryptedBibleStore(url:url,key:key); store = result; return result
    }
    private func effectiveNow() throws -> Date {
        let wall = Date(), uptime = ProcessInfo.processInfo.systemUptime
        let prior = try keychain.read("lastSeen").flatMap { try? JSONDecoder().decode(Date.self,from:$0) } ?? wall
        if wall < prior.addingTimeInterval(-300) { rollbackDetected = true }
        var now = max(wall,prior)
        if let anchor = timeAnchor {
            let monotonic = anchor.date.addingTimeInterval(max(0,uptime - anchor.uptime))
            if wall < monotonic.addingTimeInterval(-300) { rollbackDetected = true }
            now = max(now,monotonic)
        }
        timeAnchor = (now,uptime)
        if now.timeIntervalSince(prior) >= 60 || prior == wall { try keychain.write(try JSONEncoder().encode(now),name:"lastSeen") }
        return now
    }
    private func authorized(_ id: String) throws -> Manifest {
        guard LicensedTranslation.approved.contains(where: { $0.id == id }) else { throw ScriptureError.editionUnavailable }
        // A failed sync is not a withdrawal of the separately supplied development
        // authorization. Preserve the legacy flag for the standard policy.
        if policy == .standard, try keychain.read("revoked") != nil {
            throw LicensedContentError.expired
        }
        guard let manifest: Manifest = try storage().get("manifest/" + id) else { throw LicensedContentError.expired }
        let now = try effectiveNow()
        guard !rollbackDetected, manifest.lease.permits(now:now,lastSeen:now,policy:policy) else { throw LicensedContentError.expired }
        return manifest
    }
    func statuses() throws -> [TranslationStatus] {
        let store = try storage()
        let statuses = try LicensedTranslation.approved.map { translation in
            let manifest: Manifest? = try store.get("manifest/" + translation.id)
            let available = (try? authorized(translation.id)) != nil
            return TranslationStatus(translation:translation,expiresAt:manifest?.lease.expiresAt,isAvailable:available)
        }
        #if DEBUG
        // Access evidence only: no Scripture, credentials, keys or reading state.
        let evidence = statuses.map { ["edition":$0.id,"available":$0.isAvailable,"cached":$0.expiresAt != nil] as [String:Any] }
        let destination = FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("SP010-access.json")
        if let bytes = try? JSONSerialization.data(withJSONObject:evidence) { try? bytes.write(to:destination,options:.atomic) }
        #endif
        return statuses
    }
    func setCredential(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count < 512, !trimmed.contains("\n"), !trimmed.contains("\r") else { throw LicensedContentError.credential }
        try keychain.write(Data(trimmed.utf8),name:"apiKey")
    }
    func repository(editionID: String) throws -> any ScriptureContentRepository {
        guard let item = LicensedTranslation.approved.first(where:{ $0.editionID == editionID }) else { throw ScriptureError.editionUnavailable }
        _ = try authorized(item.id)
        return LicensedEditionRepository(library:self,id:item.id)
    }
    fileprivate func edition(_ id: String) throws -> ScriptureEdition {
        let stored = try authorized(id).edition
        guard let translation = LicensedTranslation.approved.first(where: { $0.id == id }) else {
            throw ScriptureError.editionUnavailable
        }
        return ScriptureEdition(id: stored.id, referenceSystemID: stored.referenceSystemID,
                                contentRevision: stored.contentRevision, name: translation.name,
                                abbreviation: translation.abbreviation, attribution: stored.attribution)
    }
    fileprivate func books(_ id: String) throws -> [ScriptureBook] { try authorized(id).books }
    fileprivate func chapter(_ id: String, book: String, number: Int) throws -> ChapterDocument {
        let manifest = try authorized(id)
        let chapterID = "\(book).\(number)"
        guard manifest.chapters.contains(chapterID),
              let doc: ChapterDocument = try storage().get("payload/\(id)/\(manifest.generation)/\(chapterID)"),
              doc.editionID == manifest.edition.id, doc.contentRevision == manifest.edition.contentRevision,
              doc.book == book, doc.chapter == number else { throw LicensedContentError.invalidContent }
        return doc
    }
    func sync(_ id: String, progress: @escaping @Sendable (Int, Int) -> Void) async throws {
        guard !syncing else { throw LicensedContentError.busy }
        guard let translation = LicensedTranslation.approved.first(where:{ $0.id == id }),
              let keyData = try keychain.read("apiKey"), let key = String(data:keyData,encoding:.utf8) else { throw LicensedContentError.credential }
        syncing = true; defer { syncing = false }
        do {
            let catalog = try await api.editions(key:key)
            guard let metadata = catalog.editions.first(where:{ $0.id == id }), !metadata.copyright.isEmpty else { throw LicensedContentError.accessDenied }
            let reference = try await canonical.books()
            let apiBooks = try await api.books(id:id,key:key)
            guard Set(apiBooks.map(\.id)) == Set(reference.map(\.id)), apiBooks.count == reference.count else { throw LicensedContentError.invalidContent }
            var chapters: [String] = []
            var books: [ScriptureBook] = []
            for book in reference {
                guard let source = apiBooks.first(where:{ $0.id == book.id }) else { throw LicensedContentError.invalidContent }
                let numbered = source.chapters.filter { Int($0.number) != nil }
                guard numbered.count == book.chapterCount, Set(numbered.compactMap { Int($0.number) }) == Set(1...book.chapterCount),
                      numbered.allSatisfy({ $0.bookId == book.id && $0.id == "\(book.id).\($0.number)" }) else { throw LicensedContentError.invalidContent }
                chapters += numbered.sorted { Int($0.number)! < Int($1.number)! }.map(\.id)
                books.append(ScriptureBook(id:book.id,title:source.name,testament:book.testament,order:book.order,chapterCount:book.chapterCount))
            }
            let db = try storage()
            let revision = metadata.updatedAt ?? "provider-unversioned"
            let edition = ScriptureEdition(id:"api.bible." + id,referenceSystemID:"org.sophia.api.bible." + id,
                                           contentRevision:revision,name:translation.name,
                                           abbreviation:translation.abbreviation,attribution:metadata.copyright)
            let previous: Manifest? = try db.get("manifest/" + id)
            var stage: Staging
            if let saved: Staging = try db.get("staging/" + id), saved.manifest.edition.contentRevision == revision,
               saved.manifest.chapters == chapters, catalog.date < saved.manifest.lease.expiresAt {
                stage = saved
            } else {
                stage = Staging(manifest:Manifest(generation:UUID().uuidString,edition:edition,books:books,chapters:chapters,
                                                lease:OfflineLease(synchronizedAt:catalog.date)),completed:[])
                try db.put(stage,at:"staging/" + id)
            }
            progress(stage.completed.count,chapters.count)
            Self.diagnostic(id:id,completed:stage.completed.count,total:chapters.count,state:"downloading")
            let pending = chapters.filter { !stage.completed.contains($0) }
            for start in stride(from:0,to:pending.count,by:4) {
                try Task.checkCancellation()
                let batch = Array(pending[start..<min(start + 4,pending.count)])
                let api = self.api
                let docs = try await withThrowingTaskGroup(of:ChapterDocument.self) { group in
                    for chapterID in batch {
                        group.addTask {
                            let source = try await api.chapter(id:id,chapter:chapterID,key:key)
                            guard source.id == chapterID else { throw LicensedContentError.invalidContent }
                            return try APIChapterParser.parse(source,edition:edition)
                        }
                    }
                    var documents: [ChapterDocument] = []
                    for try await document in group { documents.append(document) }
                    return documents
                }
                for document in docs {
                    let chapterID = "\(document.book).\(document.chapter)"
                    try db.put(document,at:"payload/\(id)/\(stage.manifest.generation)/\(chapterID)")
                    stage.completed.insert(chapterID)
                }
                try db.put(stage,at:"staging/" + id)
                progress(stage.completed.count,chapters.count)
                Self.diagnostic(id:id,completed:stage.completed.count,total:chapters.count,state:"downloading")
            }
            for chapterID in chapters {
                guard let stored: ChapterDocument = try db.get("payload/\(id)/\(stage.manifest.generation)/\(chapterID)"),
                      stored.editionID == edition.id, stored.contentRevision == edition.contentRevision,
                      "\(stored.book).\(stored.chapter)" == chapterID, !stored.verseNumbers.isEmpty else { throw LicensedContentError.invalidContent }
            }
            // Validate token/entitlement again before publishing a complete generation.
            let finalCatalog = try await api.editions(key:key)
            guard finalCatalog.editions.contains(where: { $0.id == id && $0.updatedAt == metadata.updatedAt }),
                  finalCatalog.date < stage.manifest.lease.expiresAt,
                  stage.completed == Set(chapters) else { throw LicensedContentError.invalidContent }
            try db.put(stage.manifest,at:"manifest/" + id)
            // A successful online validation establishes time again; never renew a partial sync.
            try keychain.write(try JSONEncoder().encode(finalCatalog.date),name:"lastSeen")
            try keychain.remove("revoked")
            timeAnchor = (finalCatalog.date,ProcessInfo.processInfo.systemUptime); rollbackDetected = false
            Self.diagnostic(id:id,completed:chapters.count,total:chapters.count,state:"complete")
            try? db.remove(prefix:"staging/" + id)
            if let previous, previous.generation != stage.manifest.generation {
                try? db.remove(prefix:"payload/\(id)/\(previous.generation)/")
            }
        } catch LicensedContentError.accessDenied {
            try keychain.write(Data([1]),name:"revoked")
            Self.diagnostic(id:id,completed:0,total:0,state:"accessDenied")
            throw LicensedContentError.accessDenied
        } catch {
            Self.diagnostic(id:id,completed:0,total:0,state:error.localizedDescription)
            throw error
        }
    }
    private static func diagnostic(id: String, completed: Int, total: Int, state: String) {
        #if DEBUG
        // Deliberately contains counts/status only: never credentials or provider payloads.
        let url = FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("SP010-\(id).json")
        let value: [String:Any] = ["edition":id,"completed":completed,"total":total,"state":state]
        if let data = try? JSONSerialization.data(withJSONObject:value) { try? data.write(to:url,options:.atomic) }
        #endif
    }
    func authorizeQuote(editionID: String, verses: Int, characters: Int) throws {
        guard let item = LicensedTranslation.approved.first(where: { $0.editionID == editionID }) else { throw ScriptureError.editionUnavailable }
        _ = try authorized(item.id)
    }
}

private struct LicensedEditionRepository: ScriptureContentRepository {
    let library: OfflineTranslationLibrary
    let id: String
    func edition() async throws -> ScriptureEdition { try await library.edition(id) }
    func books() async throws -> [ScriptureBook] { try await library.books(id) }
    func chapter(book: String, number: Int) async throws -> ChapterDocument { try await library.chapter(id,book:book,number:number) }
    func resolve(_ range: PassageRange) async throws -> [ScriptureBlock] {
        let edition = try await edition()
        guard range.start.referenceSystemID == edition.referenceSystemID,
              range.end.referenceSystemID == edition.referenceSystemID else { throw ScriptureError.passageUnmapped }
        let books = try await books()
        guard let startBook = books.first(where: { $0.id == range.start.book }),
              let endBook = books.first(where: { $0.id == range.end.book }),
              (startBook.order, range.start.chapter, range.start.verse) <= (endBook.order, range.end.chapter, range.end.verse),
              range.start.chapter > 0, range.end.chapter > 0,
              range.start.verse > 0, range.end.verse > 0 else { throw ScriptureError.passageUnmapped }
        var result: [ScriptureBlock] = []
        for book in books where book.order >= startBook.order && book.order <= endBook.order {
            let firstChapter = book.id == startBook.id ? range.start.chapter : 1
            let lastChapter = book.id == endBook.id ? range.end.chapter : book.chapterCount
            guard firstChapter...lastChapter ~= firstChapter, lastChapter <= book.chapterCount else { throw ScriptureError.passageUnmapped }
            for chapterNumber in firstChapter...lastChapter {
                let document = try await chapter(book: book.id, number: chapterNumber)
                let lower = book.id == startBook.id && chapterNumber == range.start.chapter ? range.start.verse : 1
                let upper = book.id == endBook.id && chapterNumber == range.end.chapter ? range.end.verse : Int.max
                result += document.blocks.filter { $0.kind == "body" && $0.verses.contains { lower...upper ~= $0 } }
            }
        }
        return result
    }
}
