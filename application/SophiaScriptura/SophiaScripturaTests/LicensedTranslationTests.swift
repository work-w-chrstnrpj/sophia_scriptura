import XCTest
import CryptoKit
@testable import SophiaScriptura

private final class InMemorySecureStore: ScriptureSecureStore, @unchecked Sendable {
    private var values: [String: Data] = [:]
    private var key: SymmetricKey?
    func read(_ name: String) throws -> Data? { values[name] }
    func write(_ data: Data, name: String) throws { values[name] = data }
    func remove(_ name: String) throws { values.removeValue(forKey:name) }
    func encryptionKey(create: Bool) throws -> SymmetricKey {
        if let key { return key }
        guard create else { throw LicensedContentError.storage }
        let value = SymmetricKey(size:.bits256)
        key = value
        return value
    }
}

final class LicensedTranslationTests: XCTestCase {
    private func location() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        return directory.appendingPathComponent("encrypted.sqlite")
    }
    func testLeaseBoundaryAndRollback() {
        let date = Date(timeIntervalSince1970:1_000_000)
        let lease = OfflineLease(synchronizedAt:date)
        XCTAssertTrue(lease.permits(now:lease.expiresAt.addingTimeInterval(-1),lastSeen:date))
        XCTAssertFalse(lease.permits(now:lease.expiresAt,lastSeen:date))
        XCTAssertFalse(lease.permits(now:date,lastSeen:date.addingTimeInterval(301)))
        XCTAssertFalse(lease.permits(now:date.addingTimeInterval(-301),lastSeen:date))
        XCTAssertTrue(lease.permits(now:lease.expiresAt.addingTimeInterval(1),lastSeen:date,policy:.developmentException))
        XCTAssertFalse(lease.permits(now:date.addingTimeInterval(-301),lastSeen:date,policy:.developmentException))
    }
    func testEncryptedCoreDataRoundTripAndWrongKeyFails() throws {
        let url = try location(), key = SymmetricKey(size:.bits256)
        let store = try EncryptedBibleStore(url:url,key:key)
        let secret = "SYNTHETIC_PAYLOAD_NEVER_PLAINTEXT_123456"
        try store.put(secret,at:"chapter")
        XCTAssertEqual(try store.get("chapter",as:String.self),secret)
        let raw = try Data(contentsOf:url)
        XCTAssertNil(raw.range(of:Data(secret.utf8)))
        let wrong = try EncryptedBibleStore(url:url,key:SymmetricKey(size:.bits256))
        XCTAssertThrowsError(try wrong.get("chapter",as:String.self))
        try store.remove(prefix:"chapter")
        XCTAssertNil(try store.get("chapter",as:String.self))
    }
    func testParserPreservesUnicodeNotesAndBridgedVerseIdentity() throws {
        let chapter = try FixtureAPI.document(number:1)
        let edition = FixtureAPI.edition
        let parsed = try APIChapterParser.parse(chapter,edition:edition)
        XCTAssertEqual(parsed.verseNumbers,[1,2,3])
        XCTAssertEqual(parsed.body(for:1),"Synthetic é 👋 body.")
        XCTAssertFalse(parsed.body(for:1).contains("source note"))
        XCTAssertTrue(parsed.blocks.contains { $0.kind == "note" && $0.text == "source note" })
        XCTAssertEqual(parsed.verse(1).referenceSystemID,edition.referenceSystemID)
        XCTAssertEqual(ChapterTextMap(document:parsed).focusRanges(for:2),ChapterTextMap(document:parsed).focusRanges(for:3))
    }
    func testInterruptedSyncCannotPublishAndResumeCompletes() async throws {
        let api = FixtureAPI()
        await api.fail(true)
        let keychain = InMemorySecureStore()
        let library = OfflineTranslationLibrary(api:api,canonical:FixtureCanonical(),url:try location(),keychain:keychain)
        try await library.setCredential("synthetic-key")
        do { try await library.sync(FixtureAPI.id) { _,_ in }; XCTFail("Should fail") } catch {}
        let failed = try await library.statuses()
        XCTAssertFalse(failed.first!.isAvailable)
        await api.fail(false)
        try await library.sync(FixtureAPI.id) { _,_ in }
        let repository = try await library.repository(editionID:FixtureAPI.edition.id)
        let document = try await repository.chapter(book:"GEN",number:2)
        XCTAssertEqual(document.chapter,2)
        let statuses = try await library.statuses()
        XCTAssertTrue(statuses.first!.isAvailable)
    }
    func testRelaunchExpiryAndUnlimitedPersonalQuotePermission() async throws {
        let url = try location(), api = FixtureAPI(), keys = InMemorySecureStore()
        let library = OfflineTranslationLibrary(api:api,canonical:FixtureCanonical(),url:url,keychain:keys)
        try await library.setCredential("synthetic-key")
        try await library.sync(FixtureAPI.id) { _,_ in }
        let reopened = OfflineTranslationLibrary(api:api,canonical:FixtureCanonical(),url:url,keychain:keys)
        let repository = try await reopened.repository(editionID:FixtureAPI.edition.id)
        let document = try await repository.chapter(book:"GEN",number:1)
        XCTAssertEqual(document.editionID,FixtureAPI.edition.id)
        try await reopened.authorizeQuote(editionID:document.editionID,verses:1000,characters:100000)
        // Persisted high-water time ahead of wall clock must fail closed, including after relaunch.
        try keys.write(try JSONEncoder().encode(Date().addingTimeInterval(86400)),name:"lastSeen")
        do { _ = try await reopened.repository(editionID:document.editionID); XCTFail("Clock rollback accepted") } catch {}
    }
    func testRevokedTokenLocksExistingCopy() async throws {
        let api = FixtureAPI(), keys = InMemorySecureStore()
        let library = OfflineTranslationLibrary(api:api,canonical:FixtureCanonical(),url:try location(),keychain:keys,policy:.standard)
        try await library.setCredential("synthetic-key")
        try await library.sync(FixtureAPI.id) { _,_ in }
        await api.revoke()
        do { try await library.sync(FixtureAPI.id) { _,_ in }; XCTFail("Revocation accepted") } catch {}
        do { _ = try await library.repository(editionID:FixtureAPI.edition.id); XCTFail("Revoked copy readable") } catch {}
    }
    func testDevelopmentAuthorizationRestoresCachedCopyAfterDeniedSyncAndRelaunch() async throws {
        let api = FixtureAPI(), keys = InMemorySecureStore(), url = try location()
        let standard = OfflineTranslationLibrary(api:api,canonical:FixtureCanonical(),url:url,keychain:keys,policy:.standard)
        try await standard.setCredential("synthetic-key")
        try await standard.sync(FixtureAPI.id) { _,_ in }
        await api.revoke()
        do { try await standard.sync(FixtureAPI.id) { _,_ in }; XCTFail("Denied sync succeeded") } catch {}
        let development = OfflineTranslationLibrary(api:api,canonical:FixtureCanonical(),url:url,keychain:keys,policy:.developmentException)
        let repository = try await development.repository(editionID:FixtureAPI.edition.id)
        let chapter = try await repository.chapter(book:"GEN",number:1)
        XCTAssertEqual(chapter.editionID,FixtureAPI.edition.id)
        let statuses = try await development.statuses()
        XCTAssertTrue(statuses.first!.isAvailable)
        XCTAssertNotNil(try keys.read("revoked"))
    }
    @MainActor func testReaderEditionSwitchAndRestore() async throws {
        let api = FixtureAPI(), keys = InMemorySecureStore()
        let library = MultiSourceTranslationLibrary(api:api,canonical:FixtureCanonical(),url:try location(),keychain:keys)
        try await library.setCredential("synthetic-key")
        try await library.sync(FixtureAPI.id) { _,_ in }
        let state = try ReaderStateStore(inMemory:true)
        let reader = ReaderSession(content:FixtureCanonical(),state:state,library:library)
        await reader.start()
        await reader.selectEdition(FixtureAPI.edition.id)
        XCTAssertEqual(reader.document?.editionID,FixtureAPI.edition.id)
        XCTAssertEqual(reader.edition?.abbreviation,"NASB")
        XCTAssertEqual(reader.document?.verse(1).referenceSystemID,FixtureAPI.edition.referenceSystemID)
        let restored = ReaderSession(content:FixtureCanonical(),state:state,library: library)
        await restored.start()
        XCTAssertEqual(restored.document?.editionID,FixtureAPI.edition.id)
    }
    @MainActor func testResumeNeverStartsLicensedSync() async {
        let library = ManualSyncLibrary()
        let reader = ReaderSession(content:FixtureCanonical(),state:nil,translationLibrary:library)
        await reader.start()
        await reader.resume()
        let syncCount = await library.syncCount()
        XCTAssertEqual(syncCount,0)
    }
}

private actor ManualSyncLibrary: TranslationLibrary {
    private var count = 0
    func statuses() -> [TranslationStatus] {
        [TranslationStatus(translation:LicensedTranslation.approved[0],
                           expiresAt:Date().addingTimeInterval(86400),isAvailable:true)]
    }
    func repository(editionID: String) throws -> any ScriptureContentRepository {
        throw ScriptureError.editionUnavailable
    }
    func setCredential(_ value: String) {}
    func sync(_ id: String, progress: @escaping @Sendable (Int, Int) -> Void) { count += 1 }
    func authorizeQuote(editionID: String, verses: Int, characters: Int) {}
    func syncCount() -> Int { count }
}

private actor FixtureAPI: BibleAPI {
    static let id = LicensedTranslation.approved[0].id
    static let edition = ScriptureEdition(id:"api.bible." + id,referenceSystemID:"org.sophia.api.bible." + id,contentRevision:"fixture",name:"Synthetic",abbreviation:"NASB",attribution:"Synthetic attribution")
    private var failure = false
    private var revoked = false
    func fail(_ value: Bool) { failure = value }
    func revoke() { revoked = true }
    func editions(key: String) throws -> (editions:[APIEdition],date:Date) {
        if revoked { throw LicensedContentError.accessDenied }
        return ([APIEdition(id:Self.id,name:"Synthetic",abbreviation:"NASB",copyright:"Synthetic attribution",updatedAt:"fixture")],Date())
    }
    func books(id: String, key: String) -> [APIBook] {
        [APIBook(id:"GEN",name:"Genesis",chapters:(1...2).map { APIChapterSummary(id:"GEN.\($0)",number:String($0),bookId:"GEN") })]
    }
    func chapter(id: String, chapter: String, key: String) throws -> APIChapter {
        if failure && chapter == "GEN.2" { throw LicensedContentError.transport }
        return try Self.document(number:Int(chapter.split(separator:".").last!)!)
    }
    static func document(number: Int) throws -> APIChapter {
        let raw = """
        {"id":"GEN.\(number)","bibleId":"\(id)","bookId":"GEN","number":"\(number)","verseCount":3,"content":[
        {"type":"tag","name":"para","attrs":{"style":"s1"},"items":[{"type":"text","text":"Synthetic heading"}]},
        {"type":"tag","name":"para","attrs":{"style":"p"},"items":[
        {"type":"tag","name":"verse","attrs":{"number":"1"},"items":[{"type":"text","text":"1"}]},
        {"type":"text","text":"Synthetic é 👋 body."},
        {"type":"tag","name":"note","attrs":{"style":"f"},"items":[{"type":"text","text":"source note"}]},
        {"type":"tag","name":"verse","attrs":{"number":"2-3"},"items":[]},
        {"type":"text","text":"Synthetic bridge."}]}]}
        """
        return try JSONDecoder().decode(APIChapter.self,from:Data(raw.utf8))
    }
}
private struct FixtureCanonical: ScriptureContentRepository {
    func edition() -> ScriptureEdition { ScriptureEdition(id:"web.engwebp",referenceSystemID:"org.sophia.web.engwebp",contentRevision:"test",name:"WEB",abbreviation:"WEB",attribution:"Public domain fixture") }
    func books() -> [ScriptureBook] { [ScriptureBook(id:"GEN",title:"Genesis",testament:"OT",order:1,chapterCount:2)] }
    func chapter(book: String, number: Int) throws -> ChapterDocument {
        ChapterDocument(schemaVersion:1,editionID:"web.engwebp",contentRevision:"test",book:book,chapter:number,blocks:[ScriptureBlock(id:"1",kind:"body",text:"Synthetic baseline",label:"1",verses:[1],style:"p")])
    }
    func resolve(_ range: PassageRange) -> [ScriptureBlock] { [] }
}
