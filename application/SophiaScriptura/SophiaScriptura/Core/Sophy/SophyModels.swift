import Foundation

enum SophySafeError: Equatable, Sendable, Error {
    case malformedPlan
    case unknownAction
    case invalidArguments
    case forgedHandle
    case cancelled
    case unconfigured
    case offline
    case invalidCredential
    case rateLimited
    case providerUnavailable
    case stalePlan
    case busy
    case writeFailed
    case uncertain
    case accessDenied
    case unsupportedRecurrence
    case inputTooLong
    case notApplied

    var code: String {
        switch self {
        case .malformedPlan: return "malformed_plan"
        case .unknownAction: return "unknown_action"
        case .invalidArguments: return "invalid_arguments"
        case .forgedHandle: return "forged_handle"
        case .cancelled: return "cancelled"
        case .unconfigured: return "unconfigured"
        case .offline: return "offline"
        case .invalidCredential: return "invalid_credential"
        case .rateLimited: return "rate_limited"
        case .providerUnavailable: return "provider_unavailable"
        case .stalePlan: return "stale_plan"
        case .busy: return "busy"
        case .writeFailed: return "write_failed"
        case .uncertain: return "uncertain"
        case .accessDenied: return "access_denied"
        case .unsupportedRecurrence: return "unsupported_recurrence"
        case .inputTooLong: return "input_too_long"
        case .notApplied: return "not_applied"
        }
    }

    var message: String {
        switch self {
        case .malformedPlan: return "Sophy could not read a valid response. You can try again."
        case .unknownAction: return "Sophy proposed an action this app does not allow."
        case .invalidArguments: return "Sophy’s proposal was missing or had invalid details."
        case .forgedHandle: return "Sophy referred to something outside this request."
        case .cancelled: return "That request was cancelled."
        case .unconfigured: return "Choose a provider and model in Settings before asking Sophy."
        case .offline: return "Sophy needs a network connection to reach the provider."
        case .invalidCredential: return "The provider rejected the API key."
        case .rateLimited: return "The provider rate-limited this request. Try again shortly."
        case .providerUnavailable: return "That model is unavailable for this provider."
        case .stalePlan: return "The target changed. Review a fresh preview before saving."
        case .busy: return "Sophia is saving another change. Try again when it finishes."
        case .writeFailed: return "The change could not be saved."
        case .uncertain: return "Sophia could not confirm whether that change was saved. Check the result before trying again."
        case .accessDenied: return "That item is not available to Sophy."
        case .unsupportedRecurrence: return "That repeat rule is not supported. Choose once, daily, weekdays, weekends, or weekly."
        case .inputTooLong: return "That message is longer than 8,000 characters. Shorten it before sending."
        case .notApplied: return "That change was not saved. Ask again if you still want it."
        }
    }
}

enum SophyCommitOutcome: Equatable, Sendable {
    case committed(resultIDs: [UUID])
    case alreadyCommitted(resultIDs: [UUID])
    case partial(resultIDs: [UUID], error: SophySafeError)
    case rejected(SophySafeError)
    case uncertain(resultIDs: [UUID])
}

struct SophyFolderCommit: Equatable, Sendable {
    var id: UUID
    var name: String
    var detail: String
    var parentID: UUID?
    var allowDuplicateName = false
}

enum SophyResponseKind: String, Equatable, Sendable {
    case reply, clarification, plan, enhancement
}

struct SophyQuestion: Equatable, Sendable {
    var field: String
    var prompt: String
    var choices: [String]
}

struct SophyFolderNodeDraft: Equatable, Sendable {
    // UI-only resolutions; never decoded from provider arguments.
    var existingID: UUID? = nil
    var allowDuplicateName = false
    var key: String
    var parentKey: String?
    var name: String
    var description: String
}

enum SophyActionDraft: Equatable, Sendable {
    case createFolders(destinationHandle: String?, nodes: [SophyFolderNodeDraft])
    case createReminder(title: String, description: String, modeHandle: String, localDate: String, localTime: String, repeatRule: String, deleteAfterFiring: Bool)
    case createActivity(title: String, description: String, modeHandle: String, localDate: String, localStartTime: String?, localEndDate: String?, localEndTime: String?, durationMinutes: Int?)
    case music(operation: String, trackHandle: String?)
    case openQuiz(types: [String]?, difficulty: String?, timed: Bool?)
    case openContemplation(title: String?, passage: SophyPassageDraft?)
    case openChat(presetHandle: String, prompt: String)
    case openScripture(book: String, chapter: Int, verse: Int, editionAbbreviation: String?)
    case lookup(query: String, scope: String)
    case insights(period: String, anchorDate: String?, modeHandle: String?)
    case enhance(operation: String, tone: String?, ratingTarget: String?)

    var typeName: String {
        switch self {
        case .createFolders: return "createFolders"
        case .createReminder: return "createReminder"
        case .createActivity: return "createActivity"
        case .music: return "music"
        case .openQuiz: return "openQuiz"
        case .openContemplation: return "openContemplation"
        case .openChat: return "openChat"
        case .openScripture: return "openScripture"
        case .lookup: return "lookup"
        case .insights: return "insights"
        case .enhance: return "enhance"
        }
    }

    var mutatesSavedData: Bool {
        switch self {
        case .createFolders, .createReminder, .createActivity: return true
        default: return false
        }
    }
}

struct SophyPassageDraft: Equatable, Sendable {
    var book: String
    var chapter: Int
    var startVerse: Int
    var endVerse: Int
}

struct SophyValidatedResponse: Equatable, Sendable {
    var kind: SophyResponseKind
    var message: String
    var questions: [SophyQuestion]
    var actions: [SophyActionDraft]
    var sourceHandles: [String]
}

struct SophyEnhancementScore: Equatable, Sendable {
    var grammar: Double?
    var idea: Double?
}

struct SophyEnhancementResult: Equatable, Sendable {
    var replacementText: String
    var feedback: String
    var scores: SophyEnhancementScore?
}

enum SophyJournalState: String, Codable, Equatable, Sendable {
    case prepared, applying, committed, rejected, uncertain
}

struct SophyJournalEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var planID: UUID
    var actionType: String
    var resultIDs: [UUID]
    var state: SophyJournalState
    var createdAt: Date
    var updatedAt: Date
    var safeErrorCode: String?
}

struct SophyHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var createdAt: Date
    var actionType: String
    var status: String
    var resultIDs: [UUID]
    var resultCount: Int
}

struct SophyStoreFile: Codable, Equatable, Sendable {
    var schemaVersion: Int = 1
    var history: [SophyHistoryEntry] = []
    var journal: [SophyJournalEntry] = []
}

enum SophyReconcileDisposition: Equatable, Sendable {
    case committed
    case notApplied
    case integrityError
    case uncertain
    case terminal
}

enum SophyReconciler {
    static func disposition(
        entry: SophyJournalEntry,
        presentResultIDs: Set<UUID>,
        featureRecoveredOlderGeneration: Bool
    ) -> SophyReconcileDisposition {
        if entry.state == .committed || entry.state == .rejected { return .terminal }
        if featureRecoveredOlderGeneration { return .uncertain }
        let expected = Set(entry.resultIDs)
        if expected.isEmpty { return entry.state == .uncertain ? .uncertain : .notApplied }
        if expected.isSubset(of: presentResultIDs) { return .committed }
        if expected.isDisjoint(with: presentResultIDs) { return .notApplied }
        return .integrityError
    }
}

enum SophyBibleTree {
    /// Natural-language requests for Bible → Testaments → 66 book folders (not a single “Bible” folder).
    static func requestsHierarchy(_ text: String) -> Bool {
        let normalized = text.lowercased()
            .replacingOccurrences(of: "&", with: "and")
        guard normalized.contains("bible") else { return false }
        let oldTestament = normalized.contains("old testament")
        let newTestament = normalized.contains("new testament")
        let bothTestaments = (oldTestament && newTestament)
            || normalized.contains("old and new")
            || normalized.contains("new and old")
        guard bothTestaments else { return false }
        if normalized.contains("66") { return true }
        if normalized.contains("books of the bible") { return true }
        return normalized.contains("book")
            && (normalized.contains("subfolder") || normalized.contains("populate") || normalized.contains("each"))
    }

    static func folderDrafts(books: [ScriptureBook]) -> [SophyFolderNodeDraft] {
        let ordered = books.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id < rhs.id
        }
        var nodes = [
            SophyFolderNodeDraft(key: "bible", parentKey: nil, name: "Bible", description: "Bible study notes."),
            SophyFolderNodeDraft(key: "ot", parentKey: "bible", name: "Old Testament", description: "Old Testament study notes."),
            SophyFolderNodeDraft(key: "nt", parentKey: "bible", name: "New Testament", description: "New Testament study notes.")
        ]
        for book in ordered {
            let parent = book.testament == "NT" ? "nt" : "ot"
            nodes.append(SophyFolderNodeDraft(
                key: book.id,
                parentKey: parent,
                name: book.title,
                description: "This folder is notes about the \(book.title)."
            ))
        }
        return nodes
    }
}

enum SophySlashCommand: Equatable, Sendable {
    case folders, enhance, reminder, activity, music, quiz, contemplate, find, insights, chat, help
    case newSession, history, clearHistory, bibleTree
    case unknown(String)
}

enum SophyCommandParser {
    static func slashCommand(in text: String) -> (command: SophySlashCommand, remainder: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }
        let body = trimmed.dropFirst()
        let parts = body.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let name = parts.first.map(String.init)?.lowercased() ?? ""
        let remainder = parts.count > 1 ? String(parts[1]) : ""
        let command: SophySlashCommand
        switch name {
        case "create-collection-folder", "folders", "create-folders", "folder": command = .folders
        case "create-bible-collection-tree", "bible-tree", "bible": command = .bibleTree
        case "enhance-note", "enhance": command = .enhance
        case "create-reminder", "reminder": command = .reminder
        case "create-activity", "activity": command = .activity
        case "play-music", "music": command = .music
        case "open-quiz", "quiz": command = .quiz
        case "open-contemplation", "contemplate": command = .contemplate
        case "find-notes", "find", "search": command = .find
        case "study-insights", "insights": command = .insights
        case "open-chat", "chat": command = .chat
        case "help": command = .help
        case "new-session", "new": command = .newSession
        case "show-history", "history": command = .history
        case "clear-history": command = .clearHistory
        default: command = .unknown(name)
        }
        return (command, remainder)
    }
}

enum SophySlashCommandCatalog {
    static let composerSuggestions: [String] = [
        "/create-bible-collection-tree",
        "/create-collection-folder",
        "/create-reminder",
        "/create-activity",
        "/open-quiz",
        "/open-contemplation",
        "/find-notes",
        "/study-insights",
        "/open-chat",
        "/play-music",
        "/enhance-note",
        "/help"
    ]

    static let helpMessage = """
    Slash commands (older short names like /folders still work):

    /create-collection-folder [name] — Create one collection folder, or describe a custom tree in chat.
    /create-bible-collection-tree — Bible → Old Testament & New Testament → all 66 book folders.
    /create-reminder — Schedule a local study reminder (title, mode, date, time, repeat).
    /create-activity — Log or schedule a study activity with mode and duration.
    /open-quiz — Open Quiz Me with optional difficulty and question types.
    /open-contemplation — Start a meditation journey from a passage or title.
    /find-notes [query] — Search notes and collections on this iPad.
    /study-insights [day|week|month|year] — Summarize recent study activity.
    /open-chat [preset] — Start a Companion conversation from a prompt preset.
    /play-music play|pause — Control background study music.
    /enhance-note — Improve selected note text (grammar, tone, organize, and more).
    /new-session — Clear the current Sophy chat thread.
    /show-history — Open durable Sophy action history.
    /clear-history — Remove Sophy history entries (not the folders or records they created).

    You can also ask in plain language—for example, open James 1 in Scripture, or describe folders to review before saving.
    """
}
