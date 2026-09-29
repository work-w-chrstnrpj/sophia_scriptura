import Foundation

struct APIEdition: Codable, Sendable {
    let id: String
    let name: String
    let abbreviation: String
    let copyright: String
    let updatedAt: String?
}
struct APIBook: Codable, Sendable {
    let id: String
    let name: String
    let chapters: [APIChapterSummary]
}
struct APIChapterSummary: Codable, Sendable {
    let id: String
    let number: String
    let bookId: String
}
struct APIChapter: Decodable, Sendable {
    let id: String
    let bibleId: String
    let bookId: String
    let number: String
    let content: [APINode]
    let verseCount: Int
}
struct APINode: Decodable, Sendable {
    let type: String
    let name: String?
    let text: String?
    let attrs: Attributes?
    let items: [APINode]?
    struct Attributes: Decodable, Sendable {
        let style: String?
        let number: String?
        let verseId: String?
        let sid: String?
    }
}
private struct APIEnvelope<T: Decodable>: Decodable { let data: T }

protocol BibleAPI: Sendable {
    func editions(key: String) async throws -> (editions:[APIEdition], date:Date)
    func books(id: String, key: String) async throws -> [APIBook]
    func chapter(id: String, chapter: String, key: String) async throws -> APIChapter
}

struct APIBibleClient: BibleAPI {
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil; config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpCookieStorage = nil; config.timeoutIntervalForRequest = 30
        config.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration:config,delegate:NoBibleRedirect(),delegateQueue:nil)
    }
    func editions(key: String) async throws -> (editions:[APIEdition], date:Date) {
        try await get("bibles?include-full-details=true",key:key,type:[APIEdition].self)
    }
    func books(id: String, key: String) async throws -> [APIBook] {
        try await get("bibles/\(id)/books?include-chapters=true",key:key,type:[APIBook].self).0
    }
    func chapter(id: String, chapter: String, key: String) async throws -> APIChapter {
        try await get("bibles/\(id)/chapters/\(chapter)?content-type=json&include-notes=true&include-titles=true&include-verse-numbers=true",key:key,type:APIChapter.self).0
    }
    private func get<T: Decodable>(_ path: String, key: String, type: T.Type) async throws -> (T,Date) {
        guard !key.isEmpty, !key.contains("\n"), !key.contains("\r") else { throw LicensedContentError.credential }
        var request = URLRequest(url:URL(string:"https://rest.api.bible/v1/" + path)!)
        request.setValue(key,forHTTPHeaderField:"api-key")
        let bytes: Data; let response: URLResponse
        do { (bytes,response) = try await session.data(for:request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw LicensedContentError.transport }
        guard let http = response as? HTTPURLResponse else { throw LicensedContentError.transport }
        switch http.statusCode {
        case 200: break
        case 401,403: throw LicensedContentError.accessDenied
        case 429: throw LicensedContentError.quota
        default: throw LicensedContentError.transport
        }
        guard bytes.count < 4_000_000 else { throw LicensedContentError.invalidContent }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier:"en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT:0); formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        guard let header = http.value(forHTTPHeaderField:"Date"), let date = formatter.date(from:header) else { throw LicensedContentError.transport }
        do { return (try JSONDecoder().decode(APIEnvelope<T>.self,from:bytes).data,date) }
        catch { throw LicensedContentError.invalidContent }
    }
}
private final class NoBibleRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
