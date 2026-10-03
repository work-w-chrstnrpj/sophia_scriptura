import Foundation
import Combine

@MainActor
final class CompanionSession: ObservableObject {
    @Published private(set) var conversations: [CompanionConversation] = []
    @Published private(set) var messages: [CompanionMessage] = []
    @Published private(set) var providerConfigurations: [ProviderConfigurationRecord] = []
    @Published var selectedConversationID: UUID?
    @Published var notice: String?
    @Published var isSending = false
    @Published var composerText = ""
    @Published var selectedPresetID: String
    @Published var attachments: [CompanionAttachment] = []
    @Published var sources: [CompanionSource] = []
    @Published var summaries: [ContextSummary] = []
    @Published var quizSessions: [QuizSession] = []
    @Published var quizQuestions: [QuizQuestionRecord] = []
    @Published var quizAttempts: [QuizAttemptRecord] = []
    @Published var reviewingLinks: [ReviewingActivityLink] = []
    @Published var cachedQuizQuestions: [CachedQuizQuestion] = []
    @Published var quizCacheRefilling = false
    @Published var scripturePanelConversationID: UUID?
    @Published private(set) var scriptureAutoSend: ScriptureAutoSend?
    @Published var panelExpandedToTab = false
    @Published var activeQuizSessionID: UUID?
    @Published private(set) var modelOptionsByConfigurationID: [UUID: [CompanionModelOption]] = [:]
    @Published private(set) var modelCatalogLoading: Set<UUID> = []
    @Published var showFreeModelsOnly = false
    @Published var sidebarQuizHistoryExpanded = true
    @Published var sidebarChatHistoryExpanded = true
    @Published private(set) var recentQuizFixtureKeys: [String] = []
    @Published private(set) var quizDefaultProviderConfigID: UUID?
    @Published private(set) var quizDefaultModelID: String?

    let presetCatalog: PromptPresetCatalog
    let repository: (any CompanionRepository)?
    let credentials: any CompanionCredentialsStoring
    let registry: ProviderRegistry
    var revision = 0
    var writeChain: Task<Void, Never>?
    var activeStreamTask: Task<Void, Never>?
    var quizCacheWarmTask: Task<Void, Never>?
    var quizCacheRetryTask: Task<Void, Never>?
    var quizCachePriorityTypes: [QuizType] = []
    var quizCachePriorityDifficulty: QuizDifficulty?
    var quizCacheReconcilePending = false
    var quizCacheRetryAttempts = 0
    let quizCacheCoordinator = QuizQuestionCacheCoordinator()
    var onCollectionsSync: ((StudyConversation) -> Void)?
    var onCollectionsRemove: ((UUID) -> Void)?

    init(
        presetCatalog: PromptPresetCatalog,
        repository: (any CompanionRepository)? = nil,
        credentials: any CompanionCredentialsStoring = CompanionKeychainStore(),
        registry: ProviderRegistry = .production()
    ) {
        self.presetCatalog = presetCatalog
        self.repository = repository
        self.credentials = credentials
        self.registry = registry
        self.selectedPresetID = presetCatalog.defaultPresetID()
    }

    convenience init?(repository: any CompanionRepository, registry: ProviderRegistry = .production()) {
        guard let catalog = try? PromptPresetCatalog.bundled() else { return nil }
        self.init(presetCatalog: catalog, repository: repository, registry: registry)
    }

    static func live(registry: ProviderRegistry = .production()) -> CompanionSession {
        guard let catalog = try? PromptPresetCatalog.bundled() else {
            preconditionFailure("prompt-presets.seed.json is missing from the app bundle.")
        }
        return CompanionSession(
            presetCatalog: catalog,
            repository: CompanionFileRepository(directory: CompanionFileRepository.defaultDirectory()),
            registry: registry
        )
    }

    func adapter(id: String) -> (any LLMProviderAdapter)? { registry.adapter(id: id) }

    var supportedAdapters: [any LLMProviderAdapter] { registry.supportedAdapters }

    func clearNotice() { notice = nil }

    func load() async {
        guard let repository else { return }
        do {
            let load = try await repository.load()
            apply(load.snapshot)
            if load.recovered { notice = "Recovered the previous Companion revision." }
            scheduleQuizCacheWarmup()
        } catch {
            notice = error.localizedDescription
        }
    }

    func flush() async {
        _ = await writeChain?.value
    }

    var selectedConversation: CompanionConversation? {
        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    func messages(for conversationID: UUID) -> [CompanionMessage] {
        messages.filter { $0.conversationID == conversationID }.sorted { $0.sequence < $1.sequence }
    }

    func hasCredential(for configurationID: UUID) -> Bool {
        (try? credentials.readKey(for: configurationID))?.isEmpty == false
    }

    func providerRecord(for id: UUID) -> ProviderConfigurationRecord? {
        providerConfigurations.first { $0.id == id }
    }

    func saveProviderKey(_ key: String, adapterID: String, accountLabel: String, defaultModelID: String? = nil) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let seedModel = defaultModelID ?? ProviderModelCatalog.defaultModelID(adapterID: adapterID)
        var record = providerConfigurations.first { $0.adapterID == adapterID && $0.accountLabel == accountLabel }
        if record == nil {
            record = ProviderConfigurationRecord(adapterID: adapterID, accountLabel: accountLabel, defaultModelID: seedModel)
            providerConfigurations.append(record!)
        }
        guard var existing = record else { return }
        existing.updatedAt = Date()
        if existing.defaultModelID.isEmpty { existing.defaultModelID = seedModel }
        try credentials.writeKey(trimmed, for: existing.id)
        if let index = providerConfigurations.firstIndex(where: { $0.id == existing.id }) {
            providerConfigurations[index] = existing
        }
        scheduleSave()
        scheduleQuizCacheWarmup()
    }

    func providerConfigurationsWithCredentials() -> [ProviderConfigurationRecord] {
        providerConfigurations.filter { hasCredential(for: $0.id) }
    }

    func modelOptions(for configurationID: UUID) -> [CompanionModelOption] {
        if let cached = modelOptionsByConfigurationID[configurationID], !cached.isEmpty {
            return cached
        }
        guard let record = providerRecord(for: configurationID) else { return [] }
        return ProviderModelCatalog.curatedModels(adapterID: record.adapterID)
    }

    func filteredModelOptions(for configurationID: UUID) -> [CompanionModelOption] {
        guard let adapterID = providerRecord(for: configurationID)?.adapterID else { return [] }
        return ProviderModelCatalog.filteredModels(
            modelOptions(for: configurationID),
            adapterID: adapterID,
            freeOnly: showFreeModelsOnly
        )
    }

    func setShowFreeModelsOnly(_ enabled: Bool) {
        showFreeModelsOnly = enabled
        scheduleSave()
    }

    func setSidebarQuizHistoryExpanded(_ expanded: Bool) {
        sidebarQuizHistoryExpanded = expanded
        scheduleSave()
    }

    func setSidebarChatHistoryExpanded(_ expanded: Bool) {
        sidebarChatHistoryExpanded = expanded
        scheduleSave()
    }

    func updateQuizDefaults(providerConfigID: UUID, modelID: String) {
        quizDefaultProviderConfigID = providerConfigID
        quizDefaultModelID = modelID
        scheduleSave()
        scheduleQuizCacheWarmup()
    }

    func abandonActiveQuiz() {
        if let id = activeQuizSessionID {
            finishQuiz(sessionID: id, intentional: false)
        }
        activeQuizSessionID = nil
    }

    @discardableResult
    func refreshModelCatalog(for configurationID: UUID) async -> String? {
        guard let record = providerRecord(for: configurationID),
              let adapter = registry.adapter(id: record.adapterID),
              let apiKey = try? credentials.readKey(for: configurationID), !apiKey.isEmpty else {
            return LLMProviderError.missingCredential.errorDescription
        }
        modelCatalogLoading.insert(configurationID)
        defer { modelCatalogLoading.remove(configurationID) }
        do {
            let remote = try await adapter.listModels(apiKey: apiKey)
            let merged = ProviderModelCatalog.mergeRemote(ids: remote, adapterID: record.adapterID)
            modelOptionsByConfigurationID[configurationID] = merged
            let picked = ProviderModelCatalog.pickModel(
                currentID: record.defaultModelID,
                options: merged,
                adapterID: record.adapterID
            )
            if picked != record.defaultModelID, let index = providerConfigurations.firstIndex(where: { $0.id == configurationID }) {
                providerConfigurations[index].defaultModelID = picked
                providerConfigurations[index].updatedAt = Date()
                scheduleSave()
            }
            return nil
        } catch {
            let fallback = ProviderModelCatalog.curatedModels(adapterID: record.adapterID)
            modelOptionsByConfigurationID[configurationID] = fallback
            return error.localizedDescription
        }
    }

    func updateConversationRouting(conversationID: UUID, providerConfigID: UUID, modelID: String) {
        guard var conversation = conversations.first(where: { $0.id == conversationID }),
              let config = providerRecord(for: providerConfigID),
              let adapter = registry.adapter(id: config.adapterID) else { return }
        conversation.providerConfigID = providerConfigID
        conversation.providerAdapterID = config.adapterID
        conversation.modelID = modelID
        conversation.capabilitySnapshot = ProviderCapabilitySnapshot.from(adapter: adapter, modelID: modelID)
        conversation.updatedAt = Date()
        replaceConversation(conversation)
        scheduleSave()
    }

    func updateQuizRouting(quizSessionID: UUID, providerConfigID: UUID, modelID: String) {
        guard let index = quizSessions.firstIndex(where: { $0.id == quizSessionID }),
              let config = providerRecord(for: providerConfigID) else { return }
        quizSessions[index].providerConfigID = providerConfigID
        quizSessions[index].providerAdapterID = config.adapterID
        quizSessions[index].modelID = modelID
        scheduleSave()
    }

    func resolvedProviderConfigID(for quiz: QuizSession) -> UUID? {
        if let id = quiz.providerConfigID, providerRecord(for: id) != nil { return id }
        return providerConfigurations.first { $0.adapterID == quiz.providerAdapterID && hasCredential(for: $0.id) }?.id
    }

    var activeConversations: [CompanionConversation] {
        conversations.filter { $0.state == .active }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var completedQuizSessions: [QuizSession] {
        quizSessions.filter { $0.completionState == "completed" }.sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    func quizQuestions(for sessionID: UUID) -> [QuizQuestionRecord] {
        quizQuestions.filter { $0.sessionID == sessionID }.sorted { $0.index < $1.index }
    }

    func quizAttempts(for sessionID: UUID) -> [QuizAttemptRecord] {
        let questionIDs = Set(quizQuestions(for: sessionID).map(\.id))
        return quizAttempts.filter { questionIDs.contains($0.questionID) }.sorted { $0.answeredAt < $1.answeredAt }
    }

    func renameConversation(_ conversationID: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].title = String(trimmed.prefix(120))
        conversations[index].updatedAt = Date()
        syncCollections(conversations[index])
        scheduleSave()
    }

    func archiveConversation(_ conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].state = .archived
        conversations[index].updatedAt = Date()
        if selectedConversationID == conversationID { selectedConversationID = activeConversations.first?.id }
        scheduleSave()
    }

    func deleteConversation(_ conversationID: UUID) {
        conversations.removeAll { $0.id == conversationID }
        messages.removeAll { $0.conversationID == conversationID }
        attachments.removeAll { $0.conversationID == conversationID }
        if selectedConversationID == conversationID {
            selectedConversationID = activeConversations.first?.id
            composerText = selectedConversationID.flatMap { id in conversations.first { $0.id == id }?.composerDraft } ?? ""
        }
        onCollectionsRemove?(conversationID)
        scheduleSave()
    }

    func updateConversationPreset(_ conversationID: UUID, presetID: String) {
        guard var conversation = conversations.first(where: { $0.id == conversationID }),
              let preset = presetCatalog.snapshot(for: presetID) else { return }
        conversation.presetSnapshot = preset
        conversation.updatedAt = Date()
        selectedPresetID = presetID
        replaceConversation(conversation)
        syncCollections(conversation)
        scheduleSave()
    }

    func archiveQuizSession(_ sessionID: UUID) {
        guard let index = quizSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        quizSessions[index].completionState = "archived"
        scheduleSave()
    }

    func deleteProviderKey(configurationID: UUID) throws {
        try credentials.deleteKey(for: configurationID)
        providerConfigurations.removeAll { $0.id == configurationID }
        cachedQuizQuestions.removeAll { $0.scope.providerConfigurationID == configurationID }
        modelOptionsByConfigurationID.removeValue(forKey: configurationID)
        scheduleSave()
    }

    func testConnection(configurationID: UUID) async -> String? {
        guard let record = providerRecord(for: configurationID),
              let adapter = registry.adapter(id: record.adapterID),
              let key = try? credentials.readKey(for: configurationID) else {
            return LLMProviderError.missingCredential.errorDescription
        }
        do {
            try await adapter.validateConnection(apiKey: key, modelID: record.defaultModelID)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @discardableResult
    func createConversation() -> UUID? {
        guard let config = preferredProviderConfiguration(),
              let adapter = registry.adapter(id: config.adapterID),
              let preset = presetCatalog.snapshot(for: selectedPresetID) else {
            notice = "Configure a provider key in Settings before starting a conversation."
            return nil
        }
        let conversation = CompanionConversation(
            providerConfigID: config.id,
            providerAdapterID: config.adapterID,
            modelID: config.defaultModelID,
            presetSnapshot: preset,
            capabilitySnapshot: ProviderCapabilitySnapshot.from(adapter: adapter, modelID: config.defaultModelID)
        )
        conversations.insert(conversation, at: 0)
        selectedConversationID = conversation.id
        syncCollections(conversation)
        scheduleSave()
        return conversation.id
    }

    func syncCollections(_ conversation: CompanionConversation) {
        let detail: String
        if let anchor = conversation.passageAnchor {
            detail = "Passage · \(anchor.referenceLabel)"
        } else {
            detail = "\(conversation.presetSnapshot.displayName) · \(conversation.modelID)"
        }
        onCollectionsSync?(StudyConversation(
            id: conversation.id,
            title: conversation.title,
            detail: detail,
            createdAt: conversation.createdAt,
            isPlaceholder: false
        ))
    }

    func selectConversation(_ id: UUID?) {
        if let id, let conversation = conversations.first(where: { $0.id == id }) {
            selectedConversationID = id
            composerText = conversation.composerDraft
        } else {
            selectedConversationID = id
        }
    }

    func updateComposerDraft(_ text: String) {
        composerText = text
        guard let selectedConversationID,
              let index = conversations.firstIndex(where: { $0.id == selectedConversationID }) else { return }
        conversations[index].composerDraft = text
    }

    struct ScriptureAutoSend: Equatable {
        let conversationID: UUID
        let displayContent: String
        let providerContent: String
    }

    func scriptureComposerCard(for conversationID: UUID) -> String? {
        guard scriptureAutoSend?.conversationID == conversationID else { return nil }
        return scriptureAutoSend?.displayContent
    }

    func flushScriptureAutoSendIfNeeded(conversationID: UUID) async {
        guard let pending = scriptureAutoSend, pending.conversationID == conversationID else { return }
        scriptureAutoSend = nil
        selectConversation(conversationID)
        await sendMessage(displayContent: pending.displayContent, providerContent: pending.providerContent)
    }

    func sendMessage(displayContent: String? = nil, providerContent: String? = nil) async {
        guard !isSending else { return }
        let providerText = (providerContent ?? composerText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !providerText.isEmpty else { return }
        let visibleText = (displayContent ?? providerText).trimmingCharacters(in: .whitespacesAndNewlines)

        if selectedConversationID == nil {
            guard createConversation() != nil else { return }
        }
        guard let conversationID = selectedConversationID,
              var conversation = conversations.first(where: { $0.id == conversationID }),
              let config = providerRecord(for: conversation.providerConfigID),
              let adapter = registry.adapter(id: config.adapterID),
              let apiKey = try? credentials.readKey(for: config.id), !apiKey.isEmpty else {
            notice = LLMProviderError.missingCredential.errorDescription
            return
        }

        isSending = true
        defer { isSending = false }

        let nextSequence = (messages.filter { $0.conversationID == conversationID }.map(\.sequence).max() ?? -1) + 1
        let userMessage = CompanionMessage(
            conversationID: conversationID,
            sequence: nextSequence,
            role: .user,
            content: visibleText,
            providerContent: providerContent == nil ? nil : providerText,
            deliveryState: .complete
        )
        messages.append(userMessage)

        let assistantSequence = nextSequence + 1
        var assistant = CompanionMessage(
            conversationID: conversationID,
            sequence: assistantSequence,
            role: .assistant,
            content: "",
            deliveryState: .streaming,
            attempts: [ResponseAttempt(outcome: .complete)]
        )
        messages.append(assistant)

        composerText = ""
        conversation.composerDraft = ""
        conversation.updatedAt = Date()
        if conversation.title == "New conversation" {
            conversation.title = String(visibleText.prefix(48))
        }
        replaceConversation(conversation)
        scheduleSave()

        let retrievalAvailable = conversation.capabilitySnapshot.providerRetrieval
        if let index = messages.firstIndex(where: { $0.id == assistant.id }) {
            messages[index].retrievalAvailable = retrievalAvailable
            messages[index].retrievalPerformed = false
        }

        let request = CompanionContextBuilder.completionRequest(
            conversation: conversation,
            messages: messages.filter { $0.id != assistant.id },
            attachments: attachments,
            pendingUserText: ""
        )

        activeStreamTask?.cancel()
        activeStreamTask = Task {
            do {
                for try await event in adapter.streamCompletion(apiKey: apiKey, request: request) {
                    try Task.checkCancellation()
                    await MainActor.run {
                        self.applyStreamEvent(event, assistantID: assistant.id, conversationID: conversationID)
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.markAssistant(assistant.id, state: .interrupted, outcome: .cancelled)
                }
            } catch {
                await MainActor.run {
                    self.markAssistant(assistant.id, state: .failed, outcome: .failed, error: error.localizedDescription)
                }
            }
            await MainActor.run { self.scheduleSave() }
        }
        await activeStreamTask?.value
    }

    func cancelStreaming() {
        activeStreamTask?.cancel()
    }

    func applyStreamEvent(_ event: LLMStreamEvent, assistantID: UUID, conversationID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == assistantID }) else { return }
        switch event {
        case .responseStarted:
            messages[index].deliveryState = .streaming
        case .textDelta(let delta):
            messages[index].content = CompanionResponseFormatting.joinStreamDelta(
                existing: messages[index].content,
                delta: delta
            )
            if var attempt = messages[index].attempts.last {
                attempt.content = messages[index].content
                messages[index].attempts[messages[index].attempts.count - 1] = attempt
            }
        case .sourceEvidence(let source):
            sources.append(source)
            messages[index].sourceIDs.append(source.id)
            messages[index].retrievalPerformed = true
        case .completed:
            let parsed = CompanionResponseFormatting.splitSourcesAppendix(from: messages[index].content)
            messages[index].content = parsed.displayMarkdown
            for source in parsed.appendixSources {
                sources.append(source)
                messages[index].sourceIDs.append(source.id)
            }
            if !parsed.appendixSources.isEmpty {
                messages[index].retrievalPerformed = true
                messages[index].retrievalAvailable = true
            }
            messages[index].deliveryState = .complete
            if var attempt = messages[index].attempts.last {
                attempt.completedAt = Date()
                attempt.outcome = .complete
                attempt.content = messages[index].content
                messages[index].attempts[messages[index].attempts.count - 1] = attempt
            }
            touchConversation(conversationID)
        case .refused(let reason):
            markAssistant(assistantID, state: .refused, outcome: .refused, error: reason)
        case .failed(let error):
            markAssistant(assistantID, state: .failed, outcome: .failed, error: error.errorDescription)
        }
    }

    func markAssistant(_ id: UUID, state: CompanionDeliveryState, outcome: ResponseAttemptOutcome, error: String? = nil) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].deliveryState = state
        if let error, messages[index].content.isEmpty {
            messages[index].content = error
        }
        if var attempt = messages[index].attempts.last {
            attempt.completedAt = Date()
            attempt.outcome = outcome
            attempt.content = messages[index].content
            messages[index].attempts[messages[index].attempts.count - 1] = attempt
        }
    }

    private func touchConversation(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].updatedAt = Date()
    }

    func replaceConversation(_ conversation: CompanionConversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        }
    }

    func preferredProviderConfiguration() -> ProviderConfigurationRecord? {
        providerConfigurations.first { hasCredential(for: $0.id) }
    }

    func resolvedQuizProviderConfiguration() -> ProviderConfigurationRecord? {
        if let id = quizDefaultProviderConfigID, let record = providerRecord(for: id), hasCredential(for: id) {
            return record
        }
        return preferredProviderConfiguration()
    }

    func apply(_ snapshot: CompanionSnapshot) {
        conversations = snapshot.conversations.sorted { $0.updatedAt > $1.updatedAt }
        messages = snapshot.messages
        providerConfigurations = snapshot.providerConfigurations
        attachments = snapshot.attachments
        sources = snapshot.sources
        summaries = snapshot.summaries
        quizSessions = snapshot.quizSessions
        quizQuestions = snapshot.quizQuestions
        quizAttempts = snapshot.quizAttempts
        reviewingLinks = snapshot.reviewingLinks
        cachedQuizQuestions = snapshot.cachedQuizQuestions
        selectedConversationID = snapshot.uiState.selectedConversationID
        scripturePanelConversationID = snapshot.uiState.scripturePanelConversationID
        panelExpandedToTab = snapshot.uiState.panelExpandedToTab
        showFreeModelsOnly = snapshot.uiState.showFreeModelsOnly
        sidebarQuizHistoryExpanded = snapshot.uiState.sidebarQuizHistoryExpanded
        sidebarChatHistoryExpanded = snapshot.uiState.sidebarChatHistoryExpanded
        recentQuizFixtureKeys = snapshot.uiState.recentQuizFixtureKeys
        quizDefaultProviderConfigID = snapshot.uiState.quizDefaultProviderConfigID
        quizDefaultModelID = snapshot.uiState.quizDefaultModelID
        revision = snapshot.revision
        if selectedConversationID == nil, let first = conversations.first {
            selectedConversationID = first.id
            composerText = first.composerDraft
        }
    }

    func scheduleSave() {
        guard repository != nil else { return }
        let previous = writeChain
        writeChain = Task {
            await previous?.value
            await self.persist()
        }
    }

    func backupSnapshot() -> CompanionSnapshot {
        var ui = CompanionUIState()
        ui.selectedConversationID = selectedConversationID
        ui.scripturePanelConversationID = scripturePanelConversationID
        ui.panelExpandedToTab = panelExpandedToTab
        ui.showFreeModelsOnly = showFreeModelsOnly
        ui.sidebarQuizHistoryExpanded = sidebarQuizHistoryExpanded
        ui.sidebarChatHistoryExpanded = sidebarChatHistoryExpanded
        ui.recentQuizFixtureKeys = recentQuizFixtureKeys
        ui.quizDefaultProviderConfigID = quizDefaultProviderConfigID
        ui.quizDefaultModelID = quizDefaultModelID
        return CompanionSnapshot(
            revision: revision,
            conversations: conversations,
            messages: messages,
            providerConfigurations: providerConfigurations,
            attachments: attachments,
            sources: sources,
            summaries: summaries,
            uiState: ui,
            quizSessions: quizSessions,
            quizQuestions: quizQuestions,
            quizAttempts: quizAttempts,
            reviewingLinks: reviewingLinks,
            cachedQuizQuestions: cachedQuizQuestions
        )
    }

    func restoreBackupSnapshot(_ snapshot: CompanionSnapshot) async {
        apply(snapshot)
        await persist()
        notice = "Companion data restored from backup."
    }

    func persist() async {
        guard let repository else { return }
        var ui = CompanionUIState()
        ui.selectedConversationID = selectedConversationID
        ui.scripturePanelConversationID = scripturePanelConversationID
        ui.panelExpandedToTab = panelExpandedToTab
        ui.showFreeModelsOnly = showFreeModelsOnly
        ui.sidebarQuizHistoryExpanded = sidebarQuizHistoryExpanded
        ui.sidebarChatHistoryExpanded = sidebarChatHistoryExpanded
        ui.recentQuizFixtureKeys = recentQuizFixtureKeys
        ui.quizDefaultProviderConfigID = quizDefaultProviderConfigID
        ui.quizDefaultModelID = quizDefaultModelID
        let snapshot = CompanionSnapshot(
            revision: revision,
            conversations: conversations,
            messages: messages,
            providerConfigurations: providerConfigurations,
            attachments: attachments,
            sources: sources,
            summaries: summaries,
            uiState: ui,
            quizSessions: quizSessions,
            quizQuestions: quizQuestions,
            quizAttempts: quizAttempts,
            reviewingLinks: reviewingLinks,
            cachedQuizQuestions: cachedQuizQuestions
        )
        do {
            let saved = try await repository.save(snapshot, expectedRevision: revision)
            revision = saved.revision
        } catch {
            notice = error.localizedDescription
        }
    }

    func anchoredConversations(for verse: VerseID, editionID: String) -> [CompanionConversation] {
        conversations.filter { conversation in
            guard let anchor = conversation.passageAnchor else { return false }
            return anchor.contains(verse, editionID: editionID)
        }
    }

    @discardableResult
    func askFromScripture(
        selection: ChapterTextMap.Selection,
        referenceLabel: String,
        transmittedText: String?,
        bookID: String,
        chapter: Int,
        startVerse: Int,
        endVerse: Int,
        action: ScriptureCompanionAction = .ask
    ) -> UUID? {
        guard let conversationID = createConversation() else { return nil }
        guard var conversation = conversations.first(where: { $0.id == conversationID }) else { return nil }
        conversation.title = referenceLabel
        conversation.passageAnchor = CompanionPassageAnchor(
            bookID: bookID,
            chapter: chapter,
            startVerse: startVerse,
            endVerse: endVerse,
            editionID: selection.editionID,
            referenceLabel: referenceLabel
        )
        replaceConversation(conversation)
        syncCollections(conversation)
        let disclosure: CompanionAttachmentDisclosure = transmittedText == nil ? .referenceOnly : .textTransmitted
        attachments.append(CompanionAttachment(
            conversationID: conversationID,
            disclosure: disclosure,
            referenceLabel: referenceLabel,
            payload: transmittedText
        ))
        let prompt = action.composerPrompt(referenceLabel: referenceLabel, bookID: bookID, transmittedText: transmittedText)
        switch action {
        case .ask:
            composerText = prompt
            updateComposerDraft(prompt)
            scriptureAutoSend = nil
        case .originalLanguageAnalysis:
            composerText = ""
            updateComposerDraft("")
            scriptureAutoSend = ScriptureAutoSend(
                conversationID: conversationID,
                displayContent: ScriptureCompanionPrompts.originalLanguageDisplayCard(referenceLabel: referenceLabel, transmittedText: transmittedText),
                providerContent: prompt
            )
        }
        selectedConversationID = conversationID
        scripturePanelConversationID = conversationID
        scheduleSave()
        return conversationID
    }

    enum ScriptureCompanionAction {
        case ask
        case originalLanguageAnalysis

        func composerPrompt(referenceLabel: String, bookID: String, transmittedText: String?) -> String {
            let passage = transmittedText.flatMap { text in
                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
            }
            switch self {
            case .ask:
                if let passage { return "Help me understand \(referenceLabel):\n\n\(passage)" }
                return "Help me understand \(referenceLabel)."
            case .originalLanguageAnalysis:
                return ScriptureCompanionPrompts.originalLanguageAnalysis(
                    referenceLabel: referenceLabel,
                    bookID: bookID,
                    transmittedText: passage
                )
            }
        }
    }

    func branchConversation(toProviderConfigID: UUID) -> UUID? {
        guard let source = selectedConversation,
              let config = providerRecord(for: toProviderConfigID),
              let adapter = registry.adapter(id: config.adapterID),
              let preset = presetCatalog.snapshot(for: source.presetSnapshot.presetID) else { return nil }
        let branch = CompanionConversation(
            title: source.title + " (continued)",
            providerConfigID: config.id,
            providerAdapterID: config.adapterID,
            modelID: config.defaultModelID,
            presetSnapshot: preset,
            capabilitySnapshot: ProviderCapabilitySnapshot.from(adapter: adapter, modelID: config.defaultModelID),
            parentConversationID: source.id,
            branchPointMessageID: messages(for: source.id).last?.id,
            passageAnchor: source.passageAnchor
        )
        conversations.insert(branch, at: 0)
        selectedConversationID = branch.id
        composerText = branch.composerDraft
        syncCollections(branch)
        scheduleSave()
        return branch.id
    }

    func editAndResend(userMessageID: UUID, newText: String) async {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let user = messages.first(where: { $0.id == userMessageID && $0.role == .user }),
              user.providerContent == nil else { return }
        let conversationID = user.conversationID
        let sequence = user.sequence
        messages.removeAll { $0.conversationID == conversationID && $0.sequence >= sequence }
        composerText = trimmed
        scheduleSave()
        await sendMessage()
    }

    func sendSuggestedPrompt(_ text: String) async {
        composerText = text
        await sendMessage()
    }

    func retryAssistantMessage(_ messageID: UUID) async {
        guard let assistant = messages.first(where: { $0.id == messageID }),
              assistant.role == .assistant,
              let conversation = conversations.first(where: { $0.id == assistant.conversationID }),
              let config = providerRecord(for: conversation.providerConfigID),
              let adapter = registry.adapter(id: config.adapterID),
              let apiKey = try? credentials.readKey(for: config.id), !apiKey.isEmpty else { return }
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].content = ""
        messages[index].deliveryState = .streaming
        messages[index].sourceIDs = []
        messages[index].retrievalPerformed = false
        messages[index].attempts.append(ResponseAttempt(outcome: .complete))
        let request = CompanionContextBuilder.completionRequest(
            conversation: conversation,
            messages: messages.filter { $0.conversationID == conversation.id && $0.sequence < assistant.sequence },
            attachments: attachments,
            pendingUserText: ""
        )
        isSending = true
        defer { isSending = false }
        activeStreamTask?.cancel()
        activeStreamTask = Task {
            do {
                for try await event in adapter.streamCompletion(apiKey: apiKey, request: request) {
                    await MainActor.run {
                        self.applyStreamEvent(event, assistantID: messageID, conversationID: conversation.id)
                    }
                }
            } catch {
                await MainActor.run {
                    self.markAssistant(messageID, state: .failed, outcome: .failed, error: error.localizedDescription)
                }
            }
            await MainActor.run { self.scheduleSave() }
        }
        await activeStreamTask?.value
    }

    func sources(for message: CompanionMessage) -> [CompanionSource] {
        message.sourceIDs.compactMap { id in sources.first { $0.id == id } }
    }

    @discardableResult
    func startQuiz(types: [QuizType], difficulty: QuizDifficulty, editionID: String, timed: Bool, recordReviewing: Bool = true) async throws -> UUID {
        let config = resolvedQuizProviderConfiguration() ?? preferredProviderConfiguration()
        guard let config,
              let adapter = registry.adapter(id: config.adapterID),
              let apiKey = try? credentials.readKey(for: config.id), !apiKey.isEmpty else {
            notice = LLMProviderError.missingCredential.errorDescription
            throw LLMProviderError.missingCredential
        }
        let selectedTypes = types.isEmpty ? QuizType.quizMeSelectable : types.filter { $0 != .completeVerse && $0 != .identifyReference }
        guard !selectedTypes.isEmpty else { throw AIQuizQuestionGenerator.GenerationError.invalid("Select at least one quiz type.") }
        let model = quizDefaultModelID ?? config.defaultModelID
        let scope = QuizQuestionCacheScope(
            providerConfigurationID: config.id,
            adapterID: config.adapterID,
            modelID: model,
            editionID: editionID
        )
        let quiz = QuizSession(
            id: UUID(), createdAt: Date(), difficulty: difficulty, types: selectedTypes, editionID: editionID,
            timed: timed, recordReviewing: recordReviewing, providerConfigID: config.id,
            providerAdapterID: config.adapterID, modelID: model,
            scoreEarned: 0, scoreAvailable: difficulty.questionCount * difficulty.pointsEach, completionState: "active"
        )
        let plannedTypes = AIQuizQuestionGenerator.questionTypePlan(
            types: selectedTypes,
            count: difficulty.questionCount
        )
        let missingPlan = missingQuestionPlan(for: plannedTypes, difficulty: difficulty, scope: scope)
        if !missingPlan.isEmpty {
            let generated = try await generatedQuestionsForColdStart(
                missingPlan: missingPlan,
                scope: scope,
                difficulty: difficulty,
                adapter: adapter,
                apiKey: apiKey
            )
            mergeCachedQuestions(generated)
        }
        guard let reserved = reserveCachedQuestions(plan: plannedTypes, difficulty: difficulty, scope: scope) else {
            throw AIQuizQuestionGenerator.GenerationError.invalid("The question cache could not prepare this quiz.")
        }
        let generated = AIQuizQuestionGenerator.materialize(reserved, sessionID: quiz.id)
        quizSessions.insert(quiz, at: 0)
        quizQuestions.append(contentsOf: generated)
        activeQuizSessionID = quiz.id
        scheduleSave()
        await flush()
        scheduleQuizCacheWarmup(prioritizedTypes: selectedTypes, prioritizedDifficulty: difficulty)
        return quiz.id
    }

    func submitQuizAnswer(sessionID: UUID, questionID: UUID, answer: String, choiceIndex: Int?) {
        guard var quiz = quizSessions.first(where: { $0.id == sessionID }),
              let question = quizQuestions.first(where: { $0.id == questionID && $0.sessionID == sessionID }) else { return }
        let result: QuizAnswerResult
        let points: Int
        switch question.type {
        case .completeVerse:
            result = ScriptureQuizEngine.gradeCompleteVerse(answer: answer, key: question.answerKey.canonicalText ?? "")
            points = result == .correct ? quiz.difficulty.pointsEach : (result == .nearlyCorrect ? quiz.difficulty.pointsEach / 2 : 0)
        case .scriptureOrCap:
            guard let choiceIndex else {
                result = .unanswered
                points = 0
                break
            }
            let isScripture = choiceIndex == 0
            result = (isScripture == (question.answerKey.canonicalText == "scripture")) ? .correct : .incorrect
            points = result == .correct ? quiz.difficulty.pointsEach : 0
        default:
            result = ScriptureQuizEngine.gradeMultipleChoice(selected: choiceIndex, keyIndex: question.answerKey.choiceIndex)
            points = result == .correct ? quiz.difficulty.pointsEach : 0
        }
        quizAttempts.append(QuizAttemptRecord(
            id: UUID(), questionID: questionID, ownerAnswer: answer, choiceIndex: choiceIndex,
            result: result, pointsEarned: points, answeredAt: Date()
        ))
        quiz.scoreEarned += points
        if let index = quizSessions.firstIndex(where: { $0.id == sessionID }) { quizSessions[index] = quiz }
        scheduleSave()
    }

    func addQuizQuestionActiveTime(sessionID: UUID, seconds: Int) {
        guard seconds > 0, let index = quizSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        quizSessions[index].activeQuestionSeconds += seconds
        scheduleSave()
    }

    func finishQuiz(sessionID: UUID, intentional: Bool) {
        guard let index = quizSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        var quiz = quizSessions[index]
        guard quiz.completionState == "active" else { return }
        quiz.completedAt = Date()
        quiz.completionState = intentional ? "completed" : "abandoned"
        let questionIDs = Set(quizQuestions.filter { $0.sessionID == sessionID }.map(\.id))
        let fullyAnswered = !questionIDs.isEmpty && questionIDs.allSatisfy { id in
            quizAttempts.contains { $0.questionID == id }
        }
        if intentional && fullyAnswered && !reviewingLinks.contains(where: { $0.quizSessionID == sessionID }) {
            let link = ReviewingActivityLink(
                id: UUID(), quizSessionID: sessionID, startedAt: quiz.createdAt, endedAt: Date(),
                activeSeconds: max(1, quiz.activeQuestionSeconds), sourceDeleted: false
            )
            reviewingLinks.append(link)
            quiz.reviewingLinkID = link.id
        }
        quizSessions[index] = quiz
        activeQuizSessionID = nil
        if intentional {
            recordRecentQuizFixtures(for: sessionID)
        }
        scheduleSave()
        scheduleQuizCacheWarmup(prioritizedTypes: quiz.types, prioritizedDifficulty: quiz.difficulty)
    }

    private func recordRecentQuizFixtures(for sessionID: UUID) {
        let keys = quizQuestions(for: sessionID).compactMap(\.fixtureKey)
        guard !keys.isEmpty else { return }
        var merged = keys + recentQuizFixtureKeys
        var seen = Set<String>()
        merged = merged.filter { seen.insert($0).inserted }
        recentQuizFixtureKeys = Array(merged.prefix(80))
    }

    func renameQuizSession(_ sessionID: UUID, title: String) {
        let cleaned = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        guard !cleaned.isEmpty,
              let index = quizSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        quizSessions[index].customTitle = cleaned
        scheduleSave()
    }

    func deleteQuizSession(_ sessionID: UUID) {
        quizSessions.removeAll { $0.id == sessionID }
        let questionIDs = Set(quizQuestions.filter { $0.sessionID == sessionID }.map(\.id))
        quizQuestions.removeAll { $0.sessionID == sessionID }
        quizAttempts.removeAll { questionIDs.contains($0.questionID) }
        for idx in reviewingLinks.indices where reviewingLinks[idx].quizSessionID == sessionID {
            reviewingLinks[idx].sourceDeleted = true
        }
        scheduleSave()
    }

    private func buildQuizQuestions(for session: QuizSession) throws {
        let scripture = try QuizFixtureCatalog.scripture()
        let history = try QuizFixtureCatalog.christianHistory()
        let baseSeed = ScriptureQuizEngine.mixedSeed(sessionID: session.id)
        let recent = Set(recentQuizFixtureKeys)
        var completeOrder = ScriptureQuizEngine.shuffledIndices(count: scripture.completeVerse.count, seed: baseSeed)
        var identifyOrder = ScriptureQuizEngine.shuffledIndices(count: scripture.identifyVerse.count, seed: baseSeed &+ 1)
        var whoOrder = ScriptureQuizEngine.shuffledIndices(count: scripture.whoSaidIt.count, seed: baseSeed &+ 2)
        var historyOrder = ScriptureQuizEngine.shuffledIndices(count: history.questions.count, seed: baseSeed &+ 3)
        var scripturePromptOrder = ScriptureQuizEngine.shuffledIndices(count: scripture.scriptureOrCap.scripturePrompts.count, seed: baseSeed &+ 4)
        var capPromptOrder = ScriptureQuizEngine.shuffledIndices(count: scripture.scriptureOrCap.capPrompts.count, seed: baseSeed &+ 5)
        var bibleQuizOrder = ScriptureQuizEngine.shuffledIndices(count: scripture.bibleQuiz.count, seed: baseSeed &+ 7)
        var bibleOrFalseOrder = ScriptureQuizEngine.shuffledIndices(count: scripture.bibleOrFalse.count, seed: baseSeed &+ 8)
        var completeCursor = 0
        var identifyCursor = 0
        var whoCursor = 0
        var historyCursor = 0
        var scripturePromptCursor = 0
        var capPromptCursor = 0
        var bibleQuizCursor = 0
        var bibleOrFalseCursor = 0

        var built: [QuizQuestionRecord] = []
        let typeCycle = session.types.isEmpty ? QuizType.quizMeSelectable : session.types.filter { $0 != .completeVerse }
        let plannedTypes = ScriptureQuizEngine.shuffledTypes(typeCycle, count: session.difficulty.questionCount, seed: baseSeed &+ 6)
        for (index, type) in plannedTypes.enumerated() {
            switch type {
            case .completeVerse:
                let pick = ScriptureQuizEngine.pickIndex(
                    from: &completeOrder, cursor: &completeCursor, count: scripture.completeVerse.count, reseed: baseSeed,
                    recentKeys: recent, fixtureKey: { scripture.completeVerse[$0].id }
                )
                let item = scripture.completeVerse[pick]
                built.append(QuizQuestionRecord(
                    id: UUID(), sessionID: session.id, index: index, type: type, prompt: item.prefix, choices: [],
                    answerKey: QuizAnswerKey(canonicalText: item.answer, referenceLabel: item.referenceLabel),
                    explanation: "The selected edition reads: \(item.answer)", sourceIDs: [], fixtureKey: "completeVerse:\(item.id)"
                ))
            case .identifyVerse, .identifyReference:
                let pick = ScriptureQuizEngine.pickIndex(
                    from: &identifyOrder, cursor: &identifyCursor, count: scripture.identifyVerse.count, reseed: baseSeed &+ 1,
                    recentKeys: recent, fixtureKey: { scripture.identifyVerse[$0].id }
                )
                let item = scripture.identifyVerse[pick]
                built.append(QuizQuestionRecord(
                    id: UUID(), sessionID: session.id, index: index, type: type, prompt: item.quote, choices: item.choices,
                    answerKey: QuizAnswerKey(referenceLabel: item.referenceLabel, choiceIndex: item.correctIndex),
                    explanation: item.referenceLabel, sourceIDs: [], fixtureKey: "identifyVerse:\(item.id)"
                ))
            case .whoSaidIt:
                let pick = ScriptureQuizEngine.pickIndex(
                    from: &whoOrder, cursor: &whoCursor, count: scripture.whoSaidIt.count, reseed: baseSeed &+ 2,
                    recentKeys: recent, fixtureKey: { scripture.whoSaidIt[$0].id }
                )
                let item = scripture.whoSaidIt[pick]
                built.append(QuizQuestionRecord(
                    id: UUID(), sessionID: session.id, index: index, type: type, prompt: item.quote, choices: item.choices,
                    answerKey: QuizAnswerKey(referenceLabel: item.referenceLabel, choiceIndex: item.correctIndex),
                    explanation: item.referenceLabel, sourceIDs: [], fixtureKey: "whoSaidIt:\(item.id)"
                ))
            case .scriptureOrCap:
                let useScripture = index.isMultiple(of: 2)
                if useScripture {
                    let pick = ScriptureQuizEngine.pickIndex(
                        from: &scripturePromptOrder, cursor: &scripturePromptCursor,
                        count: scripture.scriptureOrCap.scripturePrompts.count, reseed: baseSeed &+ 4,
                        recentKeys: recent, fixtureKey: { "scripturePrompt:\($0)" }
                    )
                    let prompt = scripture.scriptureOrCap.scripturePrompts[pick]
                    built.append(QuizQuestionRecord(
                        id: UUID(), sessionID: session.id, index: index, type: type, prompt: prompt, choices: ["Scripture", "Cap"],
                        answerKey: QuizAnswerKey(canonicalText: "scripture"),
                        explanation: "Matches permitted verse text.", sourceIDs: [], fixtureKey: "scripturePrompt:\(pick)"
                    ))
                } else {
                    let pick = ScriptureQuizEngine.pickIndex(
                        from: &capPromptOrder, cursor: &capPromptCursor,
                        count: scripture.scriptureOrCap.capPrompts.count, reseed: baseSeed &+ 5,
                        recentKeys: recent, fixtureKey: { "capPrompt:\($0)" }
                    )
                    let prompt = scripture.scriptureOrCap.capPrompts[pick]
                    built.append(QuizQuestionRecord(
                        id: UUID(), sessionID: session.id, index: index, type: type, prompt: prompt, choices: ["Scripture", "Cap"],
                        answerKey: QuizAnswerKey(canonicalText: "cap"),
                        explanation: "Altered decoy cap.", sourceIDs: [], fixtureKey: "capPrompt:\(pick)"
                    ))
                }
            case .christianHistory:
                let pick = ScriptureQuizEngine.pickIndex(
                    from: &historyOrder, cursor: &historyCursor, count: history.questions.count, reseed: baseSeed &+ 3,
                    recentKeys: recent, fixtureKey: { history.questions[$0].id }
                )
                let item = history.questions[pick]
                let source = CompanionSource(title: item.sourceTitle, authorOrPublisher: item.sourceAuthor, url: item.sourceURL, retrievalProvider: "curated-fixture")
                sources.append(source)
                built.append(QuizQuestionRecord(
                    id: UUID(), sessionID: session.id, index: index, type: type, prompt: item.prompt, choices: item.choices,
                    answerKey: QuizAnswerKey(choiceIndex: item.correctIndex, sourceID: source.id),
                    explanation: "See \(item.sourceTitle).", sourceIDs: [source.id], fixtureKey: "christianHistory:\(item.id)"
                ))
            case .bibleQuiz:
                let pick = ScriptureQuizEngine.pickIndex(
                    from: &bibleQuizOrder, cursor: &bibleQuizCursor, count: scripture.bibleQuiz.count, reseed: baseSeed &+ 7,
                    recentKeys: recent, fixtureKey: { scripture.bibleQuiz[$0].id }
                )
                let item = scripture.bibleQuiz[pick]
                built.append(QuizQuestionRecord(
                    id: UUID(), sessionID: session.id, index: index, type: type, prompt: item.prompt, choices: item.choices,
                    answerKey: QuizAnswerKey(referenceLabel: item.referenceLabel, choiceIndex: item.correctIndex),
                    explanation: item.explanation, sourceIDs: [], fixtureKey: "bibleQuiz:\(item.id)"
                ))
            case .bibleOrFalse:
                let pick = ScriptureQuizEngine.pickIndex(
                    from: &bibleOrFalseOrder, cursor: &bibleOrFalseCursor, count: scripture.bibleOrFalse.count, reseed: baseSeed &+ 8,
                    recentKeys: recent, fixtureKey: { scripture.bibleOrFalse[$0].id }
                )
                let item = scripture.bibleOrFalse[pick]
                built.append(QuizQuestionRecord(
                    id: UUID(), sessionID: session.id, index: index, type: type, prompt: item.statement, choices: ["True", "False"],
                    answerKey: QuizAnswerKey(canonicalText: item.isTrue ? "true" : "false", referenceLabel: item.referenceLabel, choiceIndex: item.isTrue ? 0 : 1),
                    explanation: item.explanation, sourceIDs: [], fixtureKey: "bibleOrFalse:\(item.id)"
                ))
            }
        }
        quizQuestions.append(contentsOf: built)
    }
}
