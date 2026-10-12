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
        case "folders", "create-folders": command = .folders
        case "enhance": command = .enhance
        case "reminder", "create-reminder": command = .reminder
        case "activity", "create-activity": command = .activity
        case "music": command = .music
        case "quiz": command = .quiz
        case "contemplate": command = .contemplate
        case "find", "search": command = .find
        case "insights": command = .insights
        case "chat": command = .chat
        case "help": command = .help
        case "new-session", "new": command = .newSession
        case "history": command = .history
        case "clear-history": command = .clearHistory
        case "bible-tree", "bible": command = .bibleTree
        default: command = .unknown(name)
        }
        return (command, remainder)
    }
}
