import Foundation

private final class HelloAOHTTPSDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard request.url?.scheme == "https", request.url?.host == "bible.helloao.org" else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

struct HelloAOClient: Sendable {
    static let host = "bible.helloao.org"
    static let catalogLimit = 8 * 1024 * 1024
    static let booksLimit = 2 * 1024 * 1024
    static let chapterLimit = 8 * 1024 * 1024

    private let session: URLSession
    var retryDelays: [Duration] = [.seconds(1), .seconds(3)]

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.httpCookieStorage = nil
            config.httpShouldSetCookies = false
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 120
            config.httpMaximumConnectionsPerHost = 2
            self.session = URLSession(configuration: config, delegate: HelloAOHTTPSDelegate(), delegateQueue: nil)
        }
    }

    func availableTranslations() async throws -> HelloAOTranslationsWire {
        try await fetchJSON(path: "/api/available_translations.json", limit: Self.catalogLimit)
    }

    func books(translationID: String) async throws -> HelloAOBooksWire {
        try await fetchJSON(path: "/api/\(translationID)/books.json", limit: Self.booksLimit)
    }

    func chapter(translationID: String, book: String, number: Int) async throws -> HelloAOChapterWire {
        try await fetchJSON(path: "/api/\(translationID)/\(book)/\(number).json", limit: Self.chapterLimit)
    }

    private func fetchJSON<T: Decodable>(path: String, limit: Int) async throws -> T {
        guard let url = URL(string: "https://\(Self.host)\(path)") else { throw HelloAOError.invalidResponse }
        var attempt = 0
        while true {
            do {
                let data = try await download(url: url, limit: limit)
                return try JSONDecoder().decode(T.self, from: data)
            } catch is CancellationError {
                throw CancellationError()
            } catch HelloAOError.crossOriginRedirect, HelloAOError.responseTooLarge, HelloAOError.invalidResponse {
                throw HelloAOError.invalidResponse
            } catch HelloAOError.transport {
                if attempt >= retryDelays.count { throw HelloAOError.transport }
                let delay = retryDelays[attempt]
                attempt += 1
                try await Task.sleep(for: delay)
            }
        }
    }

    private func download(url: URL, limit: Int) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = false
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw HelloAOError.transport }
        switch http.statusCode {
        case 200: break
        case 408, 429, 500...599: throw HelloAOError.transport
        default: throw HelloAOError.invalidResponse
        }
        let length = http.expectedContentLength
        if length > 0, length > limit { throw HelloAOError.responseTooLarge }
        var data = Data()
        data.reserveCapacity(min(limit, 256 * 1024))
        for try await chunk in bytes {
            data.append(chunk)
            if data.count > limit { throw HelloAOError.responseTooLarge }
        }
        guard !data.isEmpty else { throw HelloAOError.invalidResponse }
        return data
    }
}
