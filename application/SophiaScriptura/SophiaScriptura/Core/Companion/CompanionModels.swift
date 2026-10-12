import Foundation
import CryptoKit

// MARK: - Provider metadata (secrets live in Keychain only)

struct ProviderConfigurationRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var adapterID: String
    var accountLabel: String
    var defaultModelID: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        adapterID: String,
        accountLabel: String,
        defaultModelID: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.adapterID = adapterID
        self.accountLabel = accountLabel
        self.defaultModelID = defaultModelID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ProviderCapabilitySnapshot: Codable, Hashable, Sendable {
    var adapterID: String
    var modelID: String
    var streaming: Bool
    var providerRetrieval: Bool
    var tools: Bool
    var usageReporting: Bool
    var cancellation: Bool

    static func from(adapter: any LLMProviderAdapter, modelID: String) -> ProviderCapabilitySnapshot {
        let caps = adapter.advertisedCapabilities(modelID: modelID)
        return ProviderCapabilitySnapshot(
            adapterID: adapter.id,
            modelID: modelID,
            streaming: caps.contains(.streaming),
            providerRetrieval: caps.contains(.providerRetrieval),
            tools: caps.contains(.tools),
            usageReporting: caps.contains(.usageReporting),
            cancellation: caps.contains(.cancellation)
        )
    }
}

struct PromptPresetSnapshot: Codable, Hashable, Sendable {
    var presetID: String
    var displayName: String
    var resolvedInstruction: String
    var contextVersion: Int
    var contentHash: String
}

enum CompanionConversationState: String, Codable, Sendable {
    case active
    case archived
}

struct CompanionPassageAnchor: Codable, Hashable, Sendable {
    var bookID: String
    var chapter: Int
    var startVerse: Int
    var endVerse: Int
    var editionID: String
    var referenceLabel: String

    func contains(_ verse: VerseID, editionID: String) -> Bool {
        verse.book == bookID && verse.chapter == chapter &&
            verse.verse >= startVerse && verse.verse <= endVerse && self.editionID == editionID
    }
}

/// Reference-only chapter scope, distinct from a verse range.
struct CompanionChapterAnchor: Codable, Hashable, Identifiable, Sendable {
    var bookID: String
    var chapter: Int
    var editionID: String
    var referenceLabel: String

    var id: String { "\(editionID):\(bookID):\(chapter)" }
}

enum CompanionAttachmentDisclosure: String, Codable, Sendable {
    case localOnly
    case referenceOnly
    case textTransmitted
}

struct CompanionAttachment: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var conversationID: UUID
    var messageID: UUID?
    var disclosure: CompanionAttachmentDisclosure
    var referenceLabel: String
    var payload: String?
    var selectedText: String?

    init(
        id: UUID = UUID(),
        conversationID: UUID,
        messageID: UUID? = nil,
        disclosure: CompanionAttachmentDisclosure,
        referenceLabel: String,
        payload: String? = nil,
        selectedText: String? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.messageID = messageID
        self.disclosure = disclosure
        self.referenceLabel = referenceLabel
        self.payload = payload
        self.selectedText = selectedText
    }
}

struct ContextSummary: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var conversationID: UUID
    var text: String
    var sourceMessageIDs: [UUID]
    var createdAt: Date
}

struct CompanionUIState: Codable, Sendable {
    var selectedConversationID: UUID?
    var scripturePanelConversationID: UUID?
    var panelExpandedToTab: Bool = false
    var showFreeModelsOnly: Bool = false
    var sidebarQuizHistoryExpanded: Bool = true
    var sidebarChatHistoryExpanded: Bool = true
    var recentQuizFixtureKeys: [String] = []
    var quizDefaultProviderConfigID: UUID?
    var quizDefaultModelID: String?
    var examModeEnabled: Bool = false

    private enum CodingKeys: String, CodingKey {
        case selectedConversationID, scripturePanelConversationID, panelExpandedToTab, showFreeModelsOnly
        case sidebarQuizHistoryExpanded, sidebarChatHistoryExpanded, recentQuizFixtureKeys
        case quizDefaultProviderConfigID, quizDefaultModelID, examModeEnabled
    }

    init(
        selectedConversationID: UUID? = nil,
        scripturePanelConversationID: UUID? = nil,
        panelExpandedToTab: Bool = false,
        showFreeModelsOnly: Bool = false,
        sidebarQuizHistoryExpanded: Bool = true,
        sidebarChatHistoryExpanded: Bool = true,
        recentQuizFixtureKeys: [String] = [],
        quizDefaultProviderConfigID: UUID? = nil,
        quizDefaultModelID: String? = nil,
        examModeEnabled: Bool = false
    ) {
        self.selectedConversationID = selectedConversationID
        self.scripturePanelConversationID = scripturePanelConversationID
        self.panelExpandedToTab = panelExpandedToTab
        self.showFreeModelsOnly = showFreeModelsOnly
        self.sidebarQuizHistoryExpanded = sidebarQuizHistoryExpanded
        self.sidebarChatHistoryExpanded = sidebarChatHistoryExpanded
        self.recentQuizFixtureKeys = recentQuizFixtureKeys
        self.quizDefaultProviderConfigID = quizDefaultProviderConfigID
        self.quizDefaultModelID = quizDefaultModelID
        self.examModeEnabled = examModeEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedConversationID = try container.decodeIfPresent(UUID.self, forKey: .selectedConversationID)
        scripturePanelConversationID = try container.decodeIfPresent(UUID.self, forKey: .scripturePanelConversationID)
        panelExpandedToTab = try container.decodeIfPresent(Bool.self, forKey: .panelExpandedToTab) ?? false
        showFreeModelsOnly = try container.decodeIfPresent(Bool.self, forKey: .showFreeModelsOnly) ?? false
        sidebarQuizHistoryExpanded = try container.decodeIfPresent(Bool.self, forKey: .sidebarQuizHistoryExpanded) ?? true
        sidebarChatHistoryExpanded = try container.decodeIfPresent(Bool.self, forKey: .sidebarChatHistoryExpanded) ?? true
        recentQuizFixtureKeys = try container.decodeIfPresent([String].self, forKey: .recentQuizFixtureKeys) ?? []
        quizDefaultProviderConfigID = try container.decodeIfPresent(UUID.self, forKey: .quizDefaultProviderConfigID)
        quizDefaultModelID = try container.decodeIfPresent(String.self, forKey: .quizDefaultModelID)
        examModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .examModeEnabled) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(selectedConversationID, forKey: .selectedConversationID)
        try container.encodeIfPresent(scripturePanelConversationID, forKey: .scripturePanelConversationID)
        try container.encode(panelExpandedToTab, forKey: .panelExpandedToTab)
        try container.encode(showFreeModelsOnly, forKey: .showFreeModelsOnly)
        try container.encode(sidebarQuizHistoryExpanded, forKey: .sidebarQuizHistoryExpanded)
        try container.encode(sidebarChatHistoryExpanded, forKey: .sidebarChatHistoryExpanded)
        try container.encode(recentQuizFixtureKeys, forKey: .recentQuizFixtureKeys)
        try container.encodeIfPresent(quizDefaultProviderConfigID, forKey: .quizDefaultProviderConfigID)
        try container.encodeIfPresent(quizDefaultModelID, forKey: .quizDefaultModelID)
        try container.encode(examModeEnabled, forKey: .examModeEnabled)
    }
}

enum QuizType: String, Codable, CaseIterable, Sendable {
    case identifyVerse
    case completeVerse
    case scriptureOrCap
    case whoSaidIt
    case christianHistory
    case bibleQuiz
    case bibleOrFalse
    /// Retained only so previously saved in-progress quizzes remain decodable.
    case identifyReference

    /// Types the owner can start from Quiz Me (legacy sessions may still include completeVerse).
    static var quizMeSelectable: [QuizType] {
        allCases.filter { $0 != .completeVerse && $0 != .identifyReference }
    }
}

extension QuizQuestionRecord {
    var correctAnswerDisplay: String {
        switch type {
        case .scriptureOrCap:
            return answerKey.canonicalText == "scripture" ? "Scripture" : "Cap"
        case .identifyVerse, .identifyReference:
            if let referenceLabel = answerKey.referenceLabel { return referenceLabel }
            return choiceAnswerText ?? "—"
        case .whoSaidIt, .christianHistory, .bibleQuiz:
            return choiceAnswerText ?? "—"
        case .bibleOrFalse:
            return answerKey.canonicalText == "true" ? "True" : "False"
        case .completeVerse:
            if let text = answerKey.canonicalText { return text }
            return answerKey.referenceLabel ?? "—"
        }
    }

    private var choiceAnswerText: String? {
        guard let index = answerKey.choiceIndex, choices.indices.contains(index) else { return nil }
        return choices[index]
    }
}

enum QuizDifficulty: String, Codable, CaseIterable, Sendable {
    case easy, average, difficult

    var questionCount: Int {
        switch self {
        case .easy: return 10
        case .average: return 5
        case .difficult: return 3
        }
    }

    var pointsEach: Int {
        switch self {
        case .easy: return 1
        case .average: return 3
        case .difficult: return 5
        }
    }

    var timerSeconds: Int {
        switch self {
        case .easy: return 60
        case .average: return 45
        case .difficult: return 30
        }
    }
}

enum QuizAnswerResult: String, Codable, Sendable {
    case correct
    case nearlyCorrect
    case incorrect
    case unanswered
}

struct QuizAnswerKey: Codable, Hashable, Sendable {
    var canonicalText: String?
    var referenceLabel: String?
    var choiceIndex: Int?
    var sourceID: UUID?
}

struct QuizQuestionRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var sessionID: UUID
    var index: Int
    var type: QuizType
    var prompt: String
    var choices: [String]
    var answerKey: QuizAnswerKey
    var explanation: String
    var sourceIDs: [UUID]
    /// Stable fixture id for de-duplication across quiz runs.
    var fixtureKey: String?
}

struct QuizQuestionCacheScope: Codable, Hashable, Sendable {
    static let currentPromptContractVersion = 1

    var providerConfigurationID: UUID
    var adapterID: String
    var modelID: String
    var editionID: String
    var promptContractVersion: Int = currentPromptContractVersion
}

struct CachedQuizQuestion: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var scope: QuizQuestionCacheScope
    var difficulty: QuizDifficulty
    var type: QuizType
    var prompt: String
    var choices: [String]
    var answerKey: QuizAnswerKey
    var explanation: String
    var generatedAt: Date
    var promptHash: String
}

struct QuizAttemptRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var questionID: UUID
    var ownerAnswer: String
    var choiceIndex: Int?
    var result: QuizAnswerResult
    var pointsEarned: Int
    var answeredAt: Date
}

struct QuizSession: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var createdAt: Date
    var completedAt: Date?
    var difficulty: QuizDifficulty
    var types: [QuizType]
    var editionID: String
    var timed: Bool
    var recordReviewing: Bool
    var providerConfigID: UUID?
    var providerAdapterID: String
    var modelID: String
    var scoreEarned: Int
    var scoreAvailable: Int
    var completionState: String
    var reviewingLinkID: UUID?
    var activeQuestionSeconds: Int = 0
    var customTitle: String = ""
    var mode: QuizSessionMode = .standard
    var configuredQuestionCount: Int?
    var sessionTimeLimitSeconds: Int?

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, completedAt, difficulty, types, editionID, timed, recordReviewing
        case providerConfigID, providerAdapterID, modelID, scoreEarned, scoreAvailable, completionState, reviewingLinkID, activeQuestionSeconds, customTitle
        case mode, configuredQuestionCount, sessionTimeLimitSeconds
    }

    init(
        id: UUID,
        createdAt: Date,
        completedAt: Date? = nil,
        difficulty: QuizDifficulty,
        types: [QuizType],
        editionID: String,
        timed: Bool,
        recordReviewing: Bool,
        providerConfigID: UUID? = nil,
        providerAdapterID: String,
        modelID: String,
        scoreEarned: Int,
        scoreAvailable: Int,
        completionState: String,
        reviewingLinkID: UUID? = nil,
        activeQuestionSeconds: Int = 0,
        customTitle: String = "",
        mode: QuizSessionMode = .standard,
        configuredQuestionCount: Int? = nil,
        sessionTimeLimitSeconds: Int? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.difficulty = difficulty
        self.types = types
        self.editionID = editionID
        self.timed = timed
        self.recordReviewing = recordReviewing
        self.providerConfigID = providerConfigID
        self.providerAdapterID = providerAdapterID
        self.modelID = modelID
        self.scoreEarned = scoreEarned
        self.scoreAvailable = scoreAvailable
        self.completionState = completionState
        self.reviewingLinkID = reviewingLinkID
        self.activeQuestionSeconds = activeQuestionSeconds
        self.customTitle = customTitle
        self.mode = mode
        self.configuredQuestionCount = configuredQuestionCount
        self.sessionTimeLimitSeconds = sessionTimeLimitSeconds
    }

    var effectiveQuestionCount: Int {
        if mode == .exam, let configuredQuestionCount { return configuredQuestionCount }
        return difficulty.questionCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        difficulty = try container.decode(QuizDifficulty.self, forKey: .difficulty)
        types = try container.decode([QuizType].self, forKey: .types)
        editionID = try container.decode(String.self, forKey: .editionID)
        timed = try container.decode(Bool.self, forKey: .timed)
        recordReviewing = try container.decode(Bool.self, forKey: .recordReviewing)
        providerConfigID = try container.decodeIfPresent(UUID.self, forKey: .providerConfigID)
        providerAdapterID = try container.decode(String.self, forKey: .providerAdapterID)
        modelID = try container.decode(String.self, forKey: .modelID)
        scoreEarned = try container.decode(Int.self, forKey: .scoreEarned)
        scoreAvailable = try container.decode(Int.self, forKey: .scoreAvailable)
        completionState = try container.decode(String.self, forKey: .completionState)
        reviewingLinkID = try container.decodeIfPresent(UUID.self, forKey: .reviewingLinkID)
        activeQuestionSeconds = try container.decodeIfPresent(Int.self, forKey: .activeQuestionSeconds) ?? 0
        customTitle = try container.decodeIfPresent(String.self, forKey: .customTitle) ?? ""
        mode = try container.decodeIfPresent(QuizSessionMode.self, forKey: .mode) ?? .standard
        configuredQuestionCount = try container.decodeIfPresent(Int.self, forKey: .configuredQuestionCount)
        sessionTimeLimitSeconds = try container.decodeIfPresent(Int.self, forKey: .sessionTimeLimitSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(types, forKey: .types)
        try container.encode(editionID, forKey: .editionID)
        try container.encode(timed, forKey: .timed)
        try container.encode(recordReviewing, forKey: .recordReviewing)
        try container.encodeIfPresent(providerConfigID, forKey: .providerConfigID)
        try container.encode(providerAdapterID, forKey: .providerAdapterID)
        try container.encode(modelID, forKey: .modelID)
        try container.encode(scoreEarned, forKey: .scoreEarned)
        try container.encode(scoreAvailable, forKey: .scoreAvailable)
        try container.encode(completionState, forKey: .completionState)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(configuredQuestionCount, forKey: .configuredQuestionCount)
        try container.encodeIfPresent(sessionTimeLimitSeconds, forKey: .sessionTimeLimitSeconds)
        try container.encodeIfPresent(reviewingLinkID, forKey: .reviewingLinkID)
        try container.encode(activeQuestionSeconds, forKey: .activeQuestionSeconds)
        try container.encode(customTitle, forKey: .customTitle)
    }
}

struct ReviewingActivityLink: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var quizSessionID: UUID
    var startedAt: Date
    var endedAt: Date
    var activeSeconds: Int
    var sourceDeleted: Bool
}

struct CompanionConversation: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var providerConfigID: UUID
    var providerAdapterID: String
    var modelID: String
    var presetSnapshot: PromptPresetSnapshot
    var capabilitySnapshot: ProviderCapabilitySnapshot
    var state: CompanionConversationState
    var parentConversationID: UUID?
    var branchPointMessageID: UUID?
    var composerDraft: String
    var passageAnchor: CompanionPassageAnchor?
    var chapterAnchor: CompanionChapterAnchor?
    var trashedAt: Date?

    init(
        id: UUID = UUID(),
        title: String = "New conversation",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        providerConfigID: UUID,
        providerAdapterID: String,
        modelID: String,
        presetSnapshot: PromptPresetSnapshot,
        capabilitySnapshot: ProviderCapabilitySnapshot,
        state: CompanionConversationState = .active,
        parentConversationID: UUID? = nil,
        branchPointMessageID: UUID? = nil,
        composerDraft: String = "",
        passageAnchor: CompanionPassageAnchor? = nil,
        chapterAnchor: CompanionChapterAnchor? = nil,
        trashedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.providerConfigID = providerConfigID
        self.providerAdapterID = providerAdapterID
        self.modelID = modelID
        self.presetSnapshot = presetSnapshot
        self.capabilitySnapshot = capabilitySnapshot
        self.state = state
        self.parentConversationID = parentConversationID
        self.branchPointMessageID = branchPointMessageID
        self.composerDraft = composerDraft
        self.passageAnchor = passageAnchor
        self.chapterAnchor = chapterAnchor
        self.trashedAt = trashedAt
    }

    var isTrashed: Bool { trashedAt != nil }
}

enum CompanionMessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

enum CompanionDeliveryState: String, Codable, Sendable {
    case draft
    case sending
    case streaming
    case complete
    case failed
    case refused
    case interrupted
}

enum ResponseAttemptOutcome: String, Codable, Sendable {
    case complete
    case failed
    case refused
    case cancelled
    case interrupted
}

struct ResponseAttempt: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var content: String
    var startedAt: Date
    var completedAt: Date?
    var outcome: ResponseAttemptOutcome

    init(
        id: UUID = UUID(),
        content: String = "",
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        outcome: ResponseAttemptOutcome = .complete
    ) {
        self.id = id
        self.content = content
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.outcome = outcome
    }
}

struct CompanionMessage: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var conversationID: UUID
    var sequence: Int
    var role: CompanionMessageRole
    var content: String
    /// When set, providers receive this text while `content` remains what the owner sees in the thread.
    var providerContent: String?
    var createdAt: Date
    var deliveryState: CompanionDeliveryState
    var attempts: [ResponseAttempt]
    var sourceIDs: [UUID]
    var retrievalAvailable: Bool?
    var retrievalPerformed: Bool

    init(
        id: UUID = UUID(),
        conversationID: UUID,
        sequence: Int,
        role: CompanionMessageRole,
        content: String,
        providerContent: String? = nil,
        createdAt: Date = Date(),
        deliveryState: CompanionDeliveryState,
        attempts: [ResponseAttempt] = [],
        sourceIDs: [UUID] = [],
        retrievalAvailable: Bool? = nil,
        retrievalPerformed: Bool = false
    ) {
        self.id = id
        self.conversationID = conversationID
        self.sequence = sequence
        self.role = role
        self.content = content
        self.providerContent = providerContent
        self.createdAt = createdAt
        self.deliveryState = deliveryState
        self.attempts = attempts
        self.sourceIDs = sourceIDs
        self.retrievalAvailable = retrievalAvailable
        self.retrievalPerformed = retrievalPerformed
    }
}

struct CompanionSource: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var authorOrPublisher: String?
    var url: String?
    var retrievalProvider: String?
    var claim: String?

    init(
        id: UUID = UUID(),
        title: String,
        authorOrPublisher: String? = nil,
        url: String? = nil,
        retrievalProvider: String? = nil,
        claim: String? = nil
    ) {
        self.id = id
        self.title = title
        self.authorOrPublisher = authorOrPublisher
        self.url = url
        self.retrievalProvider = retrievalProvider
        self.claim = claim
    }
}

struct CompanionSnapshot: Codable, Sendable {
    var schemaVersion: Int = 3
    var revision: Int = 0
    var conversations: [CompanionConversation] = []
    var messages: [CompanionMessage] = []
    var providerConfigurations: [ProviderConfigurationRecord] = []
    var attachments: [CompanionAttachment] = []
    var sources: [CompanionSource] = []
    var summaries: [ContextSummary] = []
    var uiState: CompanionUIState = CompanionUIState()
    var quizSessions: [QuizSession] = []
    var quizQuestions: [QuizQuestionRecord] = []
    var quizAttempts: [QuizAttemptRecord] = []
    var reviewingLinks: [ReviewingActivityLink] = []
    var cachedQuizQuestions: [CachedQuizQuestion] = []
    /// Explicit shared route for new chats and Sophy. Absent values keep the legacy first-saved-key fallback.
    var defaultProviderConfigID: UUID?
    var defaultModelID: String?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, revision, conversations, messages, providerConfigurations
        case attachments, sources, summaries, uiState, quizSessions, quizQuestions, quizAttempts, reviewingLinks
        case cachedQuizQuestions, defaultProviderConfigID, defaultModelID
    }

    init(
        schemaVersion: Int = 3,
        revision: Int = 0,
        conversations: [CompanionConversation] = [],
        messages: [CompanionMessage] = [],
        providerConfigurations: [ProviderConfigurationRecord] = [],
        attachments: [CompanionAttachment] = [],
        sources: [CompanionSource] = [],
        summaries: [ContextSummary] = [],
        uiState: CompanionUIState = CompanionUIState(),
        quizSessions: [QuizSession] = [],
        quizQuestions: [QuizQuestionRecord] = [],
        quizAttempts: [QuizAttemptRecord] = [],
        reviewingLinks: [ReviewingActivityLink] = [],
        cachedQuizQuestions: [CachedQuizQuestion] = [],
        defaultProviderConfigID: UUID? = nil,
        defaultModelID: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.conversations = conversations
        self.messages = messages
        self.providerConfigurations = providerConfigurations
        self.attachments = attachments
        self.sources = sources
        self.summaries = summaries
        self.uiState = uiState
        self.quizSessions = quizSessions
        self.quizQuestions = quizQuestions
        self.quizAttempts = quizAttempts
        self.reviewingLinks = reviewingLinks
        self.cachedQuizQuestions = cachedQuizQuestions
        self.defaultProviderConfigID = defaultProviderConfigID
        self.defaultModelID = defaultModelID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
        conversations = try container.decodeIfPresent([CompanionConversation].self, forKey: .conversations) ?? []
        messages = try container.decodeIfPresent([CompanionMessage].self, forKey: .messages) ?? []
        providerConfigurations = try container.decodeIfPresent([ProviderConfigurationRecord].self, forKey: .providerConfigurations) ?? []
        attachments = try container.decodeIfPresent([CompanionAttachment].self, forKey: .attachments) ?? []
        sources = try container.decodeIfPresent([CompanionSource].self, forKey: .sources) ?? []
        summaries = try container.decodeIfPresent([ContextSummary].self, forKey: .summaries) ?? []
        uiState = try container.decodeIfPresent(CompanionUIState.self, forKey: .uiState) ?? CompanionUIState()
        quizSessions = try container.decodeIfPresent([QuizSession].self, forKey: .quizSessions) ?? []
        quizQuestions = try container.decodeIfPresent([QuizQuestionRecord].self, forKey: .quizQuestions) ?? []
        quizAttempts = try container.decodeIfPresent([QuizAttemptRecord].self, forKey: .quizAttempts) ?? []
        reviewingLinks = try container.decodeIfPresent([ReviewingActivityLink].self, forKey: .reviewingLinks) ?? []
        cachedQuizQuestions = try container.decodeIfPresent([CachedQuizQuestion].self, forKey: .cachedQuizQuestions) ?? []
        defaultProviderConfigID = try container.decodeIfPresent(UUID.self, forKey: .defaultProviderConfigID)
        defaultModelID = try container.decodeIfPresent(String.self, forKey: .defaultModelID)
    }
}

struct SharedProviderRoute: Equatable, Sendable {
    var configurationID: UUID
    var adapterID: String
    var modelID: String
}

enum CompanionContentHash {
    static func digest(_ text: String) -> String {
        let data = Data(text.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
