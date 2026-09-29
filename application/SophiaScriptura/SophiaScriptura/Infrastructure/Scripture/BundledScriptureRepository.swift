import Foundation
import CryptoKit
import SQLite3

struct ScriptureManifest: Codable {
    let schemaVersion: Int
    let editionID: String
    let referenceSystemID: String
    let contentRevision: String
    let databaseSHA256: String
    let databaseBytes: Int
    let bookCount: Int
    let chapterCount: Int
}

/// One serialized, read-only connection; at most four immutable decoded chapters cached.
actor BundledScriptureRepository: ScriptureContentRepository {
    private let databaseURL: URL?
    private let manifestURL: URL?
    private var connection: OpaquePointer?
    private var identity: ScriptureEdition?
    private var inventory: [ScriptureBook] = []
    private var cache: [String: ChapterDocument] = [:]
    private var cacheOrder: [String] = []

    init(bundle: Bundle = .main) {
        databaseURL = bundle.url(forResource: "web-engwebp", withExtension: "sqlite")
        manifestURL = bundle.url(forResource: "web-engwebp.manifest", withExtension: "json")
    }
    init(databaseURL: URL?, manifestURL: URL?) {
        self.databaseURL = databaseURL
        self.manifestURL = manifestURL
    }
    deinit { if let connection { sqlite3_close(connection) } }

    private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    private func open() throws {
        if identity != nil { return }
        guard let databaseURL, let manifestURL,
              let bytes = try? Data(contentsOf: databaseURL),
              let metadata = try? Data(contentsOf: manifestURL) else { throw ScriptureError.artifactMissing }
        let manifest: ScriptureManifest
        do { manifest = try JSONDecoder().decode(ScriptureManifest.self, from: metadata) }
        catch { throw ScriptureError.decoding }
        guard manifest.schemaVersion == 1 else { throw ScriptureError.incompatibleSchema }
        guard bytes.count == manifest.databaseBytes, hash(bytes) == manifest.databaseSHA256,
              manifest.editionID == "web.engwebp", manifest.referenceSystemID == "org.sophia.web.engwebp",
              manifest.bookCount == 66 else { throw ScriptureError.integrityMismatch }
        var handle: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            if let handle { sqlite3_close(handle) }
            throw ScriptureError.decoding
        }
        connection = handle
        do {
            guard try scalar("PRAGMA application_id") == "1397770305",
                  try scalar("PRAGMA user_version") == "1" else { throw ScriptureError.incompatibleSchema }
            let editions: [ScriptureEdition] = try decodeRows("SELECT payload FROM edition")
            let books: [ScriptureBook] = try decodeRows("SELECT payload FROM book ORDER BY ordinal")
            guard let edition = editions.first, editions.count == 1,
                  edition.id == manifest.editionID, edition.contentRevision == manifest.contentRevision,
                  edition.referenceSystemID == manifest.referenceSystemID,
                  books.count == 66, Set(books.map(\.id)).count == 66,
                  books.map(\.order) == Array(1...66),
                  books.filter({ $0.testament == "OT" }).count == 39,
                  books.allSatisfy({ $0.chapterCount > 0 }),
                  try scalar("SELECT count(*) FROM chapter") == String(manifest.chapterCount),
                  books.reduce(0, { $0 + $1.chapterCount }) == manifest.chapterCount
            else { throw ScriptureError.integrityMismatch }
            inventory = books
            identity = edition
        } catch {
            sqlite3_close(handle); connection = nil
            throw error
        }
    }

    private func rows(_ sql: String, parameters: [String] = []) throws -> [[Data]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else { throw ScriptureError.decoding }
        defer { sqlite3_finalize(statement) }
        for (index, value) in parameters.enumerated() {
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            guard sqlite3_bind_text(statement, Int32(index + 1), value, -1, transient) == SQLITE_OK else { throw ScriptureError.decoding }
        }
        var result: [[Data]] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw ScriptureError.decoding }
            result.append((0..<sqlite3_column_count(statement)).map { column in
                let count = Int(sqlite3_column_bytes(statement, column))
                guard let pointer = sqlite3_column_blob(statement, column) else { return Data() }
                return Data(bytes: pointer, count: count)
            })
        }
    }
    private func scalar(_ sql: String) throws -> String? {
        try rows(sql).first?.first.flatMap { String(data: $0, encoding: .utf8) }
    }
    private func decodeRows<T: Decodable>(_ sql: String) throws -> [T] {
        do { return try rows(sql).map { try JSONDecoder().decode(T.self, from: $0[0]) } }
        catch { throw ScriptureError.decoding }
    }
    func edition() throws -> ScriptureEdition {
        try open()
        guard let identity else { throw ScriptureError.integrityMismatch }
        return identity
    }
    func books() throws -> [ScriptureBook] { try open(); return inventory }
    func chapter(book: String, number: Int) throws -> ChapterDocument {
        try open()
        let key = "\(book).\(number)"
        if let cached = cache[key] { return cached }
        guard let row = try rows("SELECT payload,digest FROM chapter WHERE book=? AND number=?", parameters: [book, String(number)]).first else { throw ScriptureError.chapterUnavailable }
        guard hash(row[0]) == String(data: row[1], encoding: .utf8) else { throw ScriptureError.integrityMismatch }
        let doc: ChapterDocument
        do { doc = try JSONDecoder().decode(ChapterDocument.self, from: row[0]) }
        catch { throw ScriptureError.decoding }
        guard doc.schemaVersion == 1, doc.book == book, doc.chapter == number,
              doc.editionID == identity?.id, doc.contentRevision == identity?.contentRevision,
              !doc.verseNumbers.isEmpty else { throw ScriptureError.integrityMismatch }
        cache[key] = doc; cacheOrder.append(key)
        if cacheOrder.count > 4 { cache.removeValue(forKey: cacheOrder.removeFirst()) }
        return doc
    }
    func resolve(_ range: PassageRange) throws -> [ScriptureBlock] {
        try open()
        let order = Dictionary(uniqueKeysWithValues: inventory.map { ($0.id, $0.order) })
        guard range.start.referenceSystemID == identity?.referenceSystemID else { throw ScriptureError.passageUnmapped }
        _ = try range.overlaps(range, bookOrder: order)
        guard try chapter(book: range.start.book, number: range.start.chapter).verseNumbers.contains(range.start.verse),
              try chapter(book: range.end.book, number: range.end.chapter).verseNumbers.contains(range.end.verse)
        else { throw ScriptureError.passageUnmapped }
        var result: [ScriptureBlock] = []
        for book in inventory where book.order >= order[range.start.book]! && book.order <= order[range.end.book]! {
            let first = book.id == range.start.book ? range.start.chapter : 1
            let last = book.id == range.end.book ? range.end.chapter : book.chapterCount
            for number in first...last {
                for block in try chapter(book: book.id, number: number).blocks where block.kind == "body" {
                    if try block.verses.contains(where: { verse in
                        let id = VerseID(book: book.id, chapter: number, verse: verse)
                        return try range.overlaps(PassageRange(start: id, end: id), bookOrder: order)
                    }) { result.append(block) }
                }
            }
        }
        return result
    }
}
