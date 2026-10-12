import Foundation

struct HelloAOChapterNarrationPackage: Sendable {
    let audioURL: URL
    let timingStartTimes: [TimeInterval]?
    let nextChapterPath: String?
    let previousChapterPath: String?
    let translationSHA256: String?
}

enum HelloAOChapterNarrationError: Error, LocalizedError {
    case invalidResponse
    case missingAudio(narratorID: String)
    case disallowedMediaHost
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Narration metadata was invalid."
        case .missingAudio(let id): "No verified recording for narrator \(id) in this chapter."
        case .disallowedMediaHost: "This narration host is not approved for playback."
        case .network(let error): error.localizedDescription
        }
    }
}

struct HelloAOChapterNarrationClient: Sendable {
    private static let base = URL(string: "https://bible.helloao.org")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchChapterNarration(
        translationID: String,
        bookID: String,
        chapter: Int,
        narratorID: String
    ) async throws -> HelloAOChapterNarrationPackage {
        let chapterURL = Self.base.appendingPathComponent("api/\(translationID)/\(bookID)/\(chapter).json")
        let chapterData = try await data(from: chapterURL)
        guard
            let chapterJSON = try JSONSerialization.jsonObject(with: chapterData) as? [String: Any],
            let audioLinks = chapterJSON["thisChapterAudioLinks"] as? [String: String],
            let audioLink = audioLinks[narratorID],
            let audioURL = URL(string: audioLink)
        else {
            throw HelloAOChapterNarrationError.missingAudio(narratorID: narratorID)
        }
        guard ScriptureNarrationMediaHostPolicy.isAllowedMediaURL(audioURL) else {
            throw HelloAOChapterNarrationError.disallowedMediaHost
        }

        var timings: [TimeInterval]?
        if let timingLinks = chapterJSON["thisChapterAudioTimings"] as? [String: String],
           let timingPath = timingLinks[narratorID] {
            let timingURL = Self.resolve(relative: timingPath)
            let timingData = try await data(from: timingURL)
            if let timingJSON = try JSONSerialization.jsonObject(with: timingData) as? [String: Any],
               let verses = timingJSON["verses"] as? [Double] {
                timings = verses.map(\.self)
            }
        }

        let translationSHA = (chapterJSON["translation"] as? [String: Any])?["sha256"] as? String
        return HelloAOChapterNarrationPackage(
            audioURL: audioURL,
            timingStartTimes: timings,
            nextChapterPath: chapterJSON["nextChapterApiLink"] as? String,
            previousChapterPath: chapterJSON["previousChapterApiLink"] as? String,
            translationSHA256: translationSHA
        )
    }

    private func data(from url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw HelloAOChapterNarrationError.invalidResponse
            }
            return data
        } catch let error as HelloAOChapterNarrationError {
            throw error
        } catch {
            throw HelloAOChapterNarrationError.network(error)
        }
    }

    func fetchVerseNumbers(translationID: String, bookID: String, chapter: Int) async throws -> [Int] {
        let chapterURL = Self.base.appendingPathComponent("api/\(translationID)/\(bookID)/\(chapter).json")
        let chapterData = try await data(from: chapterURL)
        guard let chapterJSON = try JSONSerialization.jsonObject(with: chapterData) as? [String: Any],
              let chapterData = chapterJSON["chapter"] as? [String: Any],
              let content = chapterData["content"] as? [[String: Any]] else {
            throw HelloAOChapterNarrationError.invalidResponse
        }
        return content.compactMap { item in
            guard (item["type"] as? String) == "verse", let number = item["number"] as? Int else { return nil }
            return number
        }
    }

    private static func resolve(relative path: String) -> URL {
        if path.hasPrefix("http"), let url = URL(string: path) { return url }
        if path.hasPrefix("/"), let url = URL(string: "https://bible.helloao.org" + path) { return url }
        return base.appendingPathComponent(path)
    }
}
