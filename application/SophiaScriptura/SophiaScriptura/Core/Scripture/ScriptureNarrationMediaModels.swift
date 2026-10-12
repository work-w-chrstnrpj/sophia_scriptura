import Foundation

enum ScriptureNarrationBookAudioState: String, Codable, Sendable, Equatable {
    case notStarted
    case downloading
    case paused
    case available
    case partial
}

struct ScriptureNarrationBookAudioStatus: Identifiable, Sendable, Equatable {
    let bookID: String
    let title: String
    let testament: String
    let chapterCount: Int
    let downloadedChapters: Int
    let unavailableChapters: Int
    let state: ScriptureNarrationBookAudioState

    var id: String { bookID }

    var progressLabel: String {
        if unavailableChapters > 0 {
            return "\(downloadedChapters) of \(chapterCount) chapters saved · \(unavailableChapters) without recording"
        }
        return "\(downloadedChapters) of \(chapterCount) chapters saved"
    }
}

struct ScriptureNarrationStoredChapter: Codable, Sendable, Equatable {
    let bookID: String
    let chapter: Int
    let narratorID: String
    let aoTranslationID: String
    let recordingRevision: String?
    let audioFileName: String
    let timingStartTimes: [TimeInterval]?
    let nextChapterPath: String?
    let previousChapterPath: String?
    let downloadedAt: Date
}

struct ScriptureNarrationBookJournal: Codable, Sendable {
    let narratorID: String
    let aoTranslationID: String
    let bookID: String
    let expectedChapters: [Int]
    var completedChapterIDs: Set<String>
    var unavailableChapterIDs: Set<String>
    let contentRevision: String

    var isFinished: Bool {
        completedChapterIDs.count + unavailableChapterIDs.count >= expectedChapters.count
    }
}

enum ScriptureNarrationMediaError: Error, LocalizedError {
    case busy
    case insufficientStorage
    case invalidResponse
    case chapterTooLarge
    case disallowedHost
    case cancelled

    var errorDescription: String? {
        switch self {
        case .busy: "Another audiobook download is already running."
        case .insufficientStorage: "Not enough free space to save this chapter."
        case .invalidResponse: "Downloaded audio could not be verified."
        case .chapterTooLarge: "This chapter audio exceeds the safe download limit."
        case .disallowedHost: "This audio host is not approved for download."
        case .cancelled: "Download cancelled."
        }
    }
}

enum ScriptureNarrationMediaPaths {
    static func chapterID(bookID: String, chapter: Int) -> String { "\(bookID).\(chapter)" }

    static func parseChapterID(_ id: String) -> (bookID: String, chapter: Int)? {
        let parts = id.split(separator: ".", maxSplits: 1)
        guard parts.count == 2, let chapter = Int(parts[1]) else { return nil }
        return (String(parts[0]), chapter)
    }
}
