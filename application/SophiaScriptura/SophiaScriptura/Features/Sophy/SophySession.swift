import Foundation

struct SophyPreviewLine: Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String
    var detail = ""
    var depth = 0
    var date = ""
    var time = ""
    var endDate = ""
    var endTime = ""
    var duration = ""
    var mode = ""
    var repeatRule = "once"
    var resolution = ""
}

struct SophyEnhancementReview: Equatable {
    var selection: SophyNoteSelection?
    var original: String
    var replacement: String
    var feedback: String
    var scores: SophyEnhancementScore?
    var isRating: Bool
    var generation: UUID
    var route: String
}

@MainActor
final class SophySession: ObservableObject {
    @Published var preferences: SophyPreferences
    @Published var phase: SophySessionPhase = .idle
    @Published var panelOpen = false
    @Published var historyOpen = false
    @Published var turns: [SophyTurn] = []
    @Published var history: [SophyHistoryEntry] = []
    @Published var notice: String?
    @Published var previewMessage = ""
    @Published var previewLines: [SophyPreviewLine] = []
    @Published var enhancement: SophyEnhancementReview?
    @Published var enhancementOpen = false
    @Published var enhancementSelection: SophyNoteSelection?
    @Published var enhancementText = ""
    @Published var enhancementOperation: SophyEnhancementOperation = .grammar
    @Published var enhancementTone = "casual"
    @Published var enhancementRating = "both"
    @Published var enhancementConsent = false
    @Published var contextReviewOpen = false
    @Published var sources: [SophyContextSource] = []
    @Published var sourceQuestion = "Explain the selected study material."
    @Published var clearHistoryRequested = false
    @Published var composer = ""
    @Published private(set) var routeLabel = "Uses Companion's default provider"
    @Published private(set) var storageAvailable = true
    @Published var destinationHandle = ""
    @Published private(set) var destinations: [SophyContextSource] = []
    @Published private(set) var idleQuote: StudyCompanionIdleQuote?
    @Published private(set) var idleQuoteVisible = false
    @Published private(set) var idleQuotesSuspended = false
    var onOpenActivity: (() -> Void)?
    var onOpenQuiz: (() -> Void)?
    var onOpenContemplation: (() -> Void)?
    var onOpenChat: (() -> Void)?
    var onOpenScripture: ((SophyScriptureNavigationRequest) -> Void)?
    var onOpenSource: ((UUID, Bool) -> Void)?

    let repository: SophyFileRepository
    private let defaults: UserDefaults
    let clock: () -> Date
    let calendar: Calendar
    var protectedClipboardChangeCount: Int?
    var generation = UUID()
    var routeKey = ""
    private var task: Task<Result<String, SophySafeError>, Never>?
    private var draftActions: [SophyActionDraft] = []
    private var handles: [String: UUID] = [:]
    private var attachedSources: [SophyContextSource] = []
    private var sourceSnapshot: [UUID: SophyEligibleRecord] = [:]
    private var bookCatalog = ""
    private var editionCatalog = ""
    private var allowedBookIDs = Set<String>()
    private var allowedEditionAbbreviations = Set<String>()
    private var lastBooks: [ScriptureBook] = []
    private var previewTimeZone = TimeZone.current.identifier
    var completionOverride: ((String, String) async -> Result<String, SophySafeError>)?
    private var idleQuoteTask: Task<Void, Never>?
    private var lastQuoteSeed: CompanionQuoteSeed?
    private var lastUserActivityAt: Date?

    init(repository: SophyFileRepository = SophyFileRepository(directory: SophyFileRepository.defaultDirectory()),
         defaults: UserDefaults = .standard, clock: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.repository = repository
        #if DEBUG
        if defaults === UserDefaults.standard, let fixture = ProcessInfo.processInfo.environment["SP009_TEST_STORE"] {
            self.defaults = UserDefaults(suiteName: "Sophy.tests." + fixture)!
        } else { self.defaults = defaults }
        #else
        self.defaults = defaults
        #endif
        self.clock = clock; self.calendar = calendar
        preferences = SophyPreferencesStore.load(defaults: self.defaults)
    }

    var isWorking: Bool { [.interpreting, .answering, .enhancing, .committing].contains(phase) }
    var character: StudyCompanionCharacter { preferences.character }

    var poseName: String {
        let suffix: String
        switch phase {
        case .interpreting: suffix = "Thinking"
        case .clarifying: suffix = "Clarifying"
        case .previewing, .committing: suffix = "Previewing"
        case .answering, .enhancing: suffix = "Answering"
        case .completed, .partiallyCompleted: suffix = "Completed"
        case .idle where panelOpen: suffix = "Listening"
        default: suffix = "Idle"
        }
        return character.assetPrefix + suffix
    }

    func setEnabled(_ enabled: Bool) {
        preferences.enabled = enabled
        SophyPreferencesStore.save(preferences, defaults: defaults)
        if !enabled {
            panelOpen = false
            stopIdleQuotes()
            if phase != .committing { abortInFlightWork(showCancellationNotice: false); phase = .idle }
        }
    }

    /// Opens the companion chat sheet and drops stale cancellation banners from empty sessions.
    func openChatPanel() {
        if !isWorking, turns.isEmpty, phase == .cancelled {
            notice = nil
            phase = .idle
        }
        panelOpen = true
    }

    func setCharacter(_ character: StudyCompanionCharacter) {
        preferences.character = character
        SophyPreferencesStore.save(preferences, defaults: defaults)
        lastQuoteSeed = nil
        idleQuote = nil
        idleQuoteVisible = false
    }

    func setIdleDelayBeforeQuoteSeconds(_ seconds: Int) {
        let clamped = SophyPreferencesStore.idleDelayChoices.contains(seconds) ? seconds : 60
        preferences.idleDelayBeforeQuoteSeconds = clamped
        SophyPreferencesStore.save(preferences, defaults: defaults)
    }

    func noteUserActivity() {
        lastUserActivityAt = clock()
        if idleQuoteVisible {
            idleQuoteVisible = false
        }
    }

    func setIdleScriptureQuotesEnabled(_ enabled: Bool) {
        preferences.idleScriptureQuotesEnabled = enabled
        SophyPreferencesStore.save(preferences, defaults: defaults)
        if !enabled {
            idleQuote = nil
            idleQuoteVisible = false
        }
    }

    func stopIdleQuotes() {
        idleQuoteTask?.cancel()
        idleQuoteTask = nil
        idleQuoteVisible = false
    }

    func hideIdleQuoteBubble() {
        idleQuoteVisible = false
    }

    func setIdleQuotesSuspended(_ suspended: Bool) {
        guard idleQuotesSuspended != suspended else { return }
        idleQuotesSuspended = suspended
        idleQuoteVisible = false
        idleQuoteTask?.cancel()
        idleQuoteTask = nil
    }

    func startIdleQuotes(
        books: [ScriptureBook],
        referenceSystemID: String,
        editionID: String?,
        repositoryProvider: @escaping (String?) async throws -> any ScriptureContentRepository,
        sceneActive: Bool
    ) {
        idleQuoteTask?.cancel()
        guard preferences.enabled,
              preferences.idleScriptureQuotesEnabled,
              sceneActive,
              !idleQuotesSuspended else {
            idleQuoteTask = nil
            if !preferences.idleScriptureQuotesEnabled || idleQuotesSuspended { idleQuoteVisible = false }
            return
        }
        lastUserActivityAt = clock()
        let delay = TimeInterval(preferences.idleDelayBeforeQuoteSeconds)
        idleQuoteTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                while !Task.isCancelled {
                    if !self.idleQuotesMayRun {
                        try? await Task.sleep(for: .milliseconds(300))
                        continue
                    }
                    let anchor = self.lastUserActivityAt ?? self.clock()
                    let elapsed = self.clock().timeIntervalSince(anchor)
                    if elapsed >= delay { break }
                    let remaining = delay - elapsed
                    try? await Task.sleep(for: .seconds(min(remaining, 0.5)))
                }
                guard !Task.isCancelled else { return }
                await self.presentIdleQuote(
                    books: books,
                    referenceSystemID: referenceSystemID,
                    editionID: editionID,
                    repositoryProvider: repositoryProvider
                )
                while self.idleQuoteVisible, !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(300))
                }
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(400))
                self.lastUserActivityAt = self.clock()
            }
        }
    }

    private var idleQuotesMayRun: Bool {
        preferences.enabled
            && preferences.idleScriptureQuotesEnabled
            && !idleQuotesSuspended
            && !panelOpen
            && !enhancementOpen
    }

    private func presentIdleQuote(
        books: [ScriptureBook],
        referenceSystemID: String,
        editionID: String?,
        repositoryProvider: (String?) async throws -> any ScriptureContentRepository
    ) async {
        guard preferences.enabled,
              preferences.idleScriptureQuotesEnabled,
              !idleQuotesSuspended,
              !panelOpen,
              !enhancementOpen,
              !isWorking,
              phase == .idle || phase == .completed || phase == .cancelled || phase == .failed else {
            idleQuoteVisible = false
            return
        }
        let seed = CompanionQuoteCatalog.nextSeed(for: character, excluding: lastQuoteSeed)
        lastQuoteSeed = seed
        guard let repository = try? await repositoryProvider(editionID),
              let quote = await CompanionQuoteResolver.resolve(
                seed: seed, books: books, referenceSystemID: referenceSystemID, repository: repository
              ) else { return }
        idleQuote = quote
        idleQuoteVisible = true
    }
    func move(edge: String, vertical: Double) {
        noteUserActivity()
        preferences.edge = edge == "leading" ? "leading" : "trailing"
        preferences.vertical = vertical.isFinite ? min(0.9, max(0.15, vertical)) : 0.72
        SophyPreferencesStore.save(preferences, defaults: defaults)
    }
    func syncRoute(_ companion: CompanionSession) {
        let fresh = currentRoute(companion)
        if !routeKey.isEmpty, fresh != routeKey, phase != .committing {
            newSession(); notice = "The provider changed. Start a fresh request."
        }
        routeKey = fresh
    }
    func load(collections: CollectionsStore, activity: ActivityStore, recoveredOlderGeneration: Bool = false) async {
        do {
            let h = try await repository.loadHistory(), j = try await repository.loadJournal()
            storageAvailable = !h.mutationsDisabled && !j.mutationsDisabled
            history = h.value
            if !storageAvailable { notice = "Sophy recovery is needed. Saved actions are disabled to preserve your files."; return }
            let present = Set(collections.collections.map(\.id) + activity.records.map(\.id) + activity.reminders.map(\.id))
            let reconciled = SophyActionExecutor.reconcile(journal: j.value, presentIDs: present,
                featureRecoveredOlderGeneration: recoveredOlderGeneration, now: clock())
            if reconciled != j.value { try await repository.saveJournal(reconciled) }
            if h.recovered || j.recovered { notice = "Recovered Sophy's previous valid generation. Inspect prior actions before retrying." }
            if reconciled.contains(where: { $0.state == .uncertain }) { notice = SophySafeError.uncertain.message }
        } catch { storageAvailable = false; notice = SophySafeError.writeFailed.message }
    }
    func newSession() {
        guard phase != .committing else { notice = SophySafeError.busy.message; return }
        task?.cancel(); generation = UUID(); turns = []; draftActions = []; previewLines = []
        previewMessage = ""; sources = []; attachedSources = []; sourceSnapshot = [:]
        dismissEnhancement(); contextReviewOpen = false; notice = nil; phase = .idle
    }
    func clearHistory() async {
        guard phase != .committing else { notice = SophySafeError.busy.message; return }
        newSession()
        do { try await repository.deleteAll(); history = []; storageAvailable = true }
        catch { notice = SophySafeError.writeFailed.message }
    }
    func deleteHistory(_ id: UUID) async {
        guard phase != .committing else { return }
        let updated = history.filter { $0.id != id }
        do { try await repository.saveHistory(updated); history = updated }
        catch { notice = SophySafeError.writeFailed.message }
    }
    func cancel() {
        guard phase != .committing else { notice = "The current save is finishing. It cannot be undone by Stop."; return }
        abortInFlightWork(showCancellationNotice: true)
    }

    private func abortInFlightWork(showCancellationNotice: Bool) {
        let hadWork = isWorking || phase == .previewing || phase == .clarifying
            || !draftActions.isEmpty || !previewLines.isEmpty || enhancement != nil
        task?.cancel()
        generation = UUID()
        draftActions = []
        previewLines = []
        previewMessage = ""
        enhancement = nil
        if showCancellationNotice, hadWork {
            phase = .cancelled
            notice = SophySafeError.cancelled.message
        } else {
            notice = nil
            phase = turns.isEmpty ? .idle : .completed
        }
    }

    /// Dismisses an editable preview without ending the conversation or showing a cancellation error.
    func cancelPreview() {
        guard phase == .previewing else { cancel(); return }
        draftActions = []; previewLines = []; previewMessage = ""; destinationHandle = ""
        notice = nil; phase = turns.isEmpty ? .idle : .completed
    }
    func concealSensitive() {
        clearProtectedClipboard()
        guard phase != .committing else { return }
        cancel(); turns = []; attachedSources = []; sourceSnapshot = [:]; sources = []
        contextReviewOpen = false; dismissEnhancement(); phase = .idle
    }
    func privacyChanged(collections: CollectionsStore, notes: NotesSession) {
        let records = libraryRecords(collections: collections, notes: notes)
        let eligible = records.filter { !SophyEligibility.excludedIDs(records).contains($0.id) }
        let byID = Dictionary(uniqueKeysWithValues: eligible.map { ($0.id, $0) })
        if sourceSnapshot.contains(where: { byID[$0.key] != $0.value }) {
            concealSensitive(); notice = "Study material changed or is no longer available. Choose sources again."
        }
        if let selected = enhancementSelection, !notes.sophySelectionIsCurrent(selected) {
            dismissEnhancement(); task?.cancel(); generation = UUID(); phase = .idle
        }
    }

    func send(_ text: String, companion: CompanionSession, collections: CollectionsStore, notes: NotesSession,
              activity: ActivityStore, music: MusicSession, books: [ScriptureBook], editionCatalog: String = "") async {
        guard !isWorking else { notice = SophySafeError.busy.message; return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed.count <= SophyResponseValidator.userInputLimit else { notice = SophySafeError.inputTooLong.message; return }
        syncRoute(companion); notice = nil
        bookCatalog = books.map { "\($0.id)=\($0.title)" }.joined(separator: "; ")
        self.editionCatalog = editionCatalog
        lastBooks = books
        allowedBookIDs = Set(books.map(\.id))
        allowedEditionAbbreviations = Set(
            editionCatalog.split(separator: ";").compactMap { pair -> String? in
                let token = pair.split(separator: "=", maxSplits: 1).first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                return token?.isEmpty == false ? token : nil
            }
        )
        if let navigation = SophyScriptureNavigationParser.parse(trimmed, books: books) {
            append("You", trimmed)
            append("Sophy", openingScriptureMessage(for: navigation))
            performScriptureNavigation(navigation)
            return
        }
        if let folderNodes = SophyFolderIntentParser.parse(trimmed) {
            append("You", trimmed)
            refreshDestinations(collections: collections, notes: notes)
            showPreview(message: "Review the folder before saving.", actions: [.createFolders(destinationHandle: nil, nodes: folderNodes)])
            return
        }
        if trimmed.caseInsensitiveCompare("Create a Bible folder with books grouped by Testament") == .orderedSame, !books.isEmpty {
            append("You", trimmed)
            refreshDestinations(collections: collections, notes: notes)
            showPreview(message: "Review the Bible folder hierarchy and descriptions.", actions: [.createFolders(destinationHandle: nil, nodes: SophyBibleTree.folderDrafts(books: books))])
            return
        }
        if let parsed = SophyCommandParser.slashCommand(in: trimmed) {
            switch parsed.command {
            case .unknown:
                append("You", trimmed)
                append("Sophy", "Unknown command. Use /help for available commands."); phase = .completed; return
            case .help:
                append("You", trimmed)
                append("Sophy", "Use /folders, /bible-tree, /reminder, /activity, /music, /quiz, /contemplate, /find, /insights, /chat or /enhance. You can also ask me to open a book or passage in Scripture.")
                phase = .completed; return
            case .newSession: newSession(); return
            case .history: historyOpen = true; return
            case .clearHistory: clearHistoryRequested = true; return
            case .bibleTree:
                guard !books.isEmpty else { notice = "The Bible catalog is still loading."; return }
                append("You", trimmed)
                refreshDestinations(collections: collections, notes: notes)
                showPreview(message: "Review the Bible folder hierarchy and descriptions.", actions: [.createFolders(destinationHandle: nil, nodes: SophyBibleTree.folderDrafts(books: books))]); return
            case .folders:
                refreshDestinations(collections: collections, notes: notes)
                if let nodes = SophyFolderIntentParser.nodes(named: parsed.remainder) ?? SophyFolderIntentParser.parse(parsed.remainder) {
                    append("You", trimmed)
                    showPreview(message: "Review the folder before saving.", actions: [.createFolders(destinationHandle: nil, nodes: nodes)])
                    return
                }
                await interpret(parsed.remainder.isEmpty ? trimmed : parsed.remainder, companion: companion, collections: collections,
                                notes: notes, activity: activity, music: music)
                return
            case .enhance: stageEnhancement(notes: notes); return
            case .find:
                showLookup(parsed.remainder, scope: "both", collections: collections, notes: notes); await recordSummary("lookup"); return
            case .insights where parsed.remainder.isEmpty || SophyInsights.period(named: parsed.remainder) != nil:
                await insights(period: SophyInsights.period(named: parsed.remainder) ?? .week, anchor: nil, mode: nil,
                    companion: companion, activity: activity); return
            case .music where ["play", "pause"].contains(parsed.remainder.lowercased()):
                performMusic(parsed.remainder.lowercased(), track: nil, music: music); return
            default: break
            }
        }
        await interpret(trimmed, companion: companion, collections: collections, notes: notes, activity: activity, music: music)
    }

    private func interpret(_ text: String, companion: CompanionSession, collections: CollectionsStore,
                           notes: NotesSession, activity: ActivityStore, music: MusicSession) async {
        guard !isWorking else { return }
        phase = .interpreting; append("You", text); generation = UUID()
        let active = generation, route = currentRoute(companion); routeKey = route
        refreshDestinations(collections: collections, notes: notes)
        let context = validationContext(activity: activity, music: music, companion: companion)
        let prompt = contextPrompt(text, activity: activity, music: music, companion: companion)
        let first = await complete(SophyPrompt.response, prompt, companion: companion)
        guard callbackIsCurrent(active, route: route, companion: companion) else { return }
        privacyChanged(collections: collections, notes: notes)
        guard generation == active else { return }
        switch first {
        case .failure(let error): phase = error == .cancelled ? .cancelled : .failed; notice = error.message
        case .success(let raw):
            var response = validated(raw, context: context)
            if response == nil {
                // Repair the original request, never echo potentially sensitive/hostile malformed output.
                let repair = await complete(SophyPrompt.repair, prompt, companion: companion)
                guard callbackIsCurrent(active, route: route, companion: companion) else { return }
                privacyChanged(collections: collections, notes: notes); guard generation == active else { return }
                if case .success(let raw) = repair { response = validated(raw, context: context) }
            }
            guard let response else { phase = .failed; notice = SophySafeError.malformedPlan.message; return }
            await accept(response, companion: companion, collections: collections, notes: notes, activity: activity, music: music)
        }
    }

    private func accept(_ response: SophyValidatedResponse, companion: CompanionSession, collections: CollectionsStore,
                        notes: NotesSession, activity: ActivityStore, music: MusicSession) async {
        switch response.kind {
        case .reply: append("Sophy", response.message); phase = .completed
        case .clarification:
            append("Sophy", response.message + "\n" + response.questions.map { $0.prompt + ($0.choices.isEmpty ? "" : " (" + $0.choices.joined(separator: ", ") + ")") }.joined(separator: "\n")); phase = .clarifying
        case .plan:
            let reads = response.actions.filter { ["lookup", "insights", "enhance"].contains($0.typeName) }
            guard reads.isEmpty || response.actions.count == 1 else {
                phase = .failed; notice = "Ask for study lookups or enhancements separately from saved changes."; return
            }
            if let action = reads.first {
                switch action {
                case .lookup(let query, let scope):
                    showLookup(query, scope: scope, collections: collections, notes: notes)
                    await recordSummary("lookup")
                case .insights(let period, let anchor, let mode):
                    await insights(period: SophyInsights.period(named: period) ?? .week, anchor: anchor, mode: mode, companion: companion, activity: activity)
                case .enhance(let operation, let tone, let rating):
                    phase = .idle
                    stageEnhancement(notes: notes)
                    enhancementOperation = SophyEnhancementOperation(rawValue: operation) ?? .grammar
                    if let tone { enhancementTone = tone }
                    if let rating { enhancementRating = rating }
                default: break
                }
            } else if response.actions.count == 1, case .music(let op, let track) = response.actions[0] {
                performMusic(op, track: track, music: music)
            } else if response.actions.count == 1, case .openScripture = response.actions[0] {
                append("Sophy", response.message)
                runHandoffs(response.actions, companion: companion, activity: activity, music: music)
            } else { showPreview(message: response.message, actions: response.actions) }
        case .enhancement: phase = .failed; notice = SophySafeError.malformedPlan.message
        }
    }

    private func showPreview(message: String, actions: [SophyActionDraft]) {
        draftActions = actions; previewMessage = message; previewLines = lines(for: actions)
        destinationHandle = actions.compactMap { if case .createFolders(let destination, _) = $0 { return destination }; return nil }.first ?? ""
        previewTimeZone = TimeZone.current.identifier; phase = .previewing
    }

    func confirm(collections: CollectionsStore, activity: ActivityStore, companion: CompanionSession, music: MusicSession) async {
        guard phase == .previewing else { return }
        func rejectPreview(_ message: String) {
            notice = message
            phase = .previewing
        }
        guard storageAvailable else { rejectPreview(SophySafeError.writeFailed.message); return }
        guard previewTimeZone == TimeZone.current.identifier else { rejectPreview(SophySafeError.stalePlan.message); return }
        if !routeKey.isEmpty, routeKey != currentRoute(companion) { rejectPreview(SophySafeError.stalePlan.message); return }
        guard previewLines.filter({ $0.subtitle.hasPrefix("Activity ·") }).allSatisfy({ line in
            line.duration.isEmpty || Int(line.duration).map { (1...1440).contains($0) } == true
        }) else {
            rejectPreview("Enter a valid duration in minutes, or clear it and supply an end date and time.")
            return
        }
        let actions = editedActions()
        guard actions.allSatisfy(validEditedAction) else { rejectPreview(SophySafeError.invalidArguments.message); return }
        phase = .committing
        if actions.contains(where: \.mutatesSavedData) {
            let outcome = await SophyActionExecutor.commit(actions: actions, handles: handles, collections: collections,
                activity: activity, repository: repository, now: clock(), calendar: calendar)
            do { history = try await repository.loadHistory().value } catch { notice = SophySafeError.writeFailed.message }
            switch outcome {
            case .committed, .alreadyCommitted:
                phase = .completed
                notice = history.last?.status == "notScheduled" ? "Saved, but notifications are not scheduled. Check iPad notification Settings." : "Saved."
            case .partial(let ids, let error):
                phase = .partiallyCompleted
                notice = "Saved \(ids.count) items; a later step was not saved. " + error.message + " Check History before requesting the remaining changes."
                draftActions = []; previewLines = []; return
            case .rejected(let error): phase = .failed; notice = error.message; draftActions = []; previewLines = []; return
            case .uncertain: phase = .uncertain; notice = SophySafeError.uncertain.message; draftActions = []; previewLines = []; return
            }
        } else { phase = .completed }
        runHandoffs(actions, companion: companion, activity: activity, music: music)
        draftActions = []; previewLines = []
    }

    func complete(_ system: String, _ user: String, companion: CompanionSession) async -> Result<String, SophySafeError> {
        let operation = Task { @MainActor in
            if let override = self.completionOverride { return await override(system, user) }
            return await companion.completeForSophy(systemInstruction: system, userText: user)
        }
        task = operation
        return await withTaskCancellationHandler(operation: { await operation.value }, onCancel: { operation.cancel() })
    }
    func callbackIsCurrent(_ active: UUID, route: String, companion: CompanionSession) -> Bool {
        active == generation && route == routeKey && route == currentRoute(companion)
    }
    private func validated(_ raw: String, context: SophyValidationContext) -> SophyValidatedResponse? {
        if let data = try? SophyJSON.normalizedPayload(from: raw),
           let parsed = try? SophyResponseValidator.validate(data, context: context) {
            return parsed
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("{"), trimmed.count <= SophyResponseValidator.messageLimit else { return nil }
        let envelope: [String: Any] = [
            "version": 1, "kind": "reply", "message": trimmed,
            "questions": [] as [Any], "actions": [] as [Any], "sourceHandles": [] as [String]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: envelope) else { return nil }
        return try? SophyResponseValidator.validate(data, context: context)
    }
    func currentRoute(_ companion: CompanionSession) -> String {
        guard let route = companion.resolvedSharedRoute() else { routeLabel = "Choose a provider in Settings"; return "" }
        routeLabel = (companion.adapter(id: route.adapterID)?.displayName ?? route.adapterID) + " · " + route.modelID
        return route.configurationID.uuidString + ":" + route.modelID
    }
    func append(_ role: String, _ text: String) {
        let next = turns + [SophyTurn(id: UUID(), role: role, text: text)]
        turns = SophyContextBuilder.boundedTurns(next)
    }

    func libraryRecords(collections: CollectionsStore, notes: NotesSession) -> [SophyEligibleRecord] {
        let folders = collections.collections.map { folder in
            SophyEligibleRecord(id: folder.id, kind: .collection, title: folder.name, body: folder.detail, tags: [],
                protectionID: folder.protectionID, parentID: folder.parentID, membershipIDs: [],
                isArchived: folder.isArchived, isTrashed: folder.isTrashed, isVirtualUnfiled: folder.isUnfiled, modifiedAt: folder.modifiedAt)
        }
        let documents = notes.snapshot.notes.map { note in
            let typed = ([note.page?.body ?? ""] + note.objects.filter { $0.kind == .text }.map(\.text)).joined(separator: "\n")
            return SophyEligibleRecord(id: note.id, kind: .note, title: note.title, body: typed, tags: note.tags,
                protectionID: note.protectionID, parentID: nil, membershipIDs: Array(collections.collectionIDs(containing: note.id)).sorted { $0.uuidString < $1.uuidString },
                isArchived: note.isArchived, isTrashed: note.isTrashed, isVirtualUnfiled: false, modifiedAt: note.updatedAt)
        }
        return folders + documents
    }
    private func refreshDestinations(collections: CollectionsStore, notes: NotesSession) {
        let records = libraryRecords(collections: collections, notes: notes), excluded = SophyEligibility.excludedIDs(records)
        destinations = records.filter { $0.kind == .collection && !$0.isVirtualUnfiled && !excluded.contains($0.id) }
            .sorted { $0.id.uuidString < $1.id.uuidString }.prefix(100).enumerated().map {
                SophyContextSource(handle: "c\($0.offset + 1)", id: $0.element.id, title: $0.element.title, excerpt: "")
            }
        handles = Dictionary(uniqueKeysWithValues: destinations.map { ($0.handle, $0.id) })
    }
    private func validationContext(activity: ActivityStore, music: MusicSession, companion: CompanionSession) -> SophyValidationContext {
        SophyValidationContext(destinationHandles: Set(destinations.map(\.handle)), modeHandles: Set(activity.modes.map(\.id)),
            trackHandles: Set(music.tracks.map(\.id)), presetHandles: Set(companion.presetCatalog.presets.map(\.id)),
            sourceHandles: Set(attachedSources.map(\.handle)), quizTypes: Set(QuizType.quizMeSelectable.map(\.rawValue)),
            difficulties: Set(QuizDifficulty.allCases.map(\.rawValue)), bookIDs: allowedBookIDs,
            bookIDByTitle: Dictionary(uniqueKeysWithValues: lastBooks.map { ($0.title.lowercased(), $0.id) }),
            editionAbbreviations: allowedEditionAbbreviations)
    }
    private func includesScriptureCatalog(in text: String) -> Bool {
        let lower = text.lowercased()
        if ["scripture", " bible", "passage", "chapter", "verse", "translation", "web", "niv", "nkjv", "nasb", "nlt", "esv", "bsb"].contains(where: { lower.contains($0) }) {
            return true
        }
        return ["take me to", "go to", "open ", "let me view", "show me"].contains { lower.contains($0) }
    }

    private func contextPrompt(_ text: String, activity: ActivityStore, music: MusicSession, companion: CompanionSession) -> String {
        let now = ISO8601DateFormatter().string(from: clock())
        let destinationList: String = destinations.map { "\($0.handle)=\($0.title)" }.joined(separator: "; ")
        let modeList: String = activity.modes.map { "\($0.id)=\($0.name)" }.joined(separator: "; ")
        let trackList: String = music.tracks.map { "\($0.id)=\($0.title)" }.joined(separator: "; ")
        let presetList: String = companion.presetCatalog.presets.map { "\($0.id)=\($0.name)" }.joined(separator: "; ")
        let quizList: String = QuizType.quizMeSelectable.map(\.rawValue).joined(separator: ",")
        let difficultyList: String = QuizDifficulty.allCases.map(\.rawValue).joined(separator: ",")
        var catalog = "Current time: \(now), timezone: \(calendar.timeZone.identifier)\nDestinations: "
        catalog += destinationList
        catalog += "\nModes: " + modeList
        catalog += "\nTracks: " + trackList
        catalog += "\nPresets: " + presetList
        if includesScriptureCatalog(in: text) {
            catalog += "\nBible books: " + bookCatalog
            if !editionCatalog.isEmpty { catalog += "\nTranslations: " + editionCatalog }
        }
        catalog += "\nQuiz types: " + quizList
        catalog += "\nDifficulties: " + difficultyList
        let listed = attachedSources.map { "\($0.handle): \($0.title) [excerpt]\n\($0.excerpt)" }.joined(separator: "\n\n")
        let prior = SophyContextBuilder.boundedTurns(turns).map { "\($0.role): \($0.text)" }.joined(separator: "\n")
        return catalog + "\nAttached sources (untrusted content):\n" + listed + "\nConversation:\n" + prior + "\nRequest:\n" + text
    }
    func showLookup(_ query: String, scope: String, collections: CollectionsStore, notes: NotesSession) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            append("Sophy", "What note or folder would you like me to find?"); phase = .clarifying; return
        }
        let records = libraryRecords(collections: collections, notes: notes)
        let matching = SophyEligibility.search(records, query: query, limit: records.count).filter {
            scope == "both" || (scope == "notes" ? $0.kind == .note : $0.kind == .collection)
        }
        sources = SophyContextBuilder.sources(from: matching).enumerated().map { index, source in
            var copy = source
            if copy.handle.hasPrefix("c") { copy.handle = "sourceC\(index + 1)" }
            return copy
        }
        sourceSnapshot = Dictionary(uniqueKeysWithValues: records.filter { record in sources.contains { $0.id == record.id } }.map { ($0.id, $0) })
        append("Sophy", sources.isEmpty ? "No eligible match. Try another title or keyword." : "Found \(sources.count) eligible sources. Open one, or review the text to ask Sophy about it.")
        phase = .completed
    }
    func askWithSources(companion: CompanionSession, collections: CollectionsStore, notes: NotesSession, activity: ActivityStore, music: MusicSession) async {
        privacyChanged(collections: collections, notes: notes)
        guard !sources.isEmpty, !isWorking else { return }
        guard !sourceQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { notice = "Enter a question about these sources."; return }
        guard sourceQuestion.count <= SophyResponseValidator.userInputLimit else { notice = SophySafeError.inputTooLong.message; return }
        attachedSources = sources; contextReviewOpen = false
        await interpret(sourceQuestion, companion: companion, collections: collections, notes: notes, activity: activity, music: music)
    }
    func openSource(_ source: SophyContextSource, collections: CollectionsStore, notes: NotesSession) {
        privacyChanged(collections: collections, notes: notes)
        guard sources.contains(source) else { return }
        let isCollection = collections.collection(id: source.id) != nil
        onOpenSource?(source.id, isCollection); panelOpen = false
    }
    func presentActivityInsights(
        period: ActivityAnalyticsPeriod,
        anchorDate: Date,
        modeID: String?,
        dailyGoalMinutes: Int,
        companion: CompanionSession,
        activity: ActivityStore
    ) async {
        panelOpen = true
        syncRoute(companion)
        await insights(
            period: period,
            anchorDate: anchorDate,
            modeID: modeID,
            dailyGoalMinutes: dailyGoalMinutes,
            companion: companion,
            activity: activity
        )
    }

    private func insights(
        period: ActivityAnalyticsPeriod,
        anchorDate: Date,
        modeID: String?,
        dailyGoalMinutes: Int,
        companion: CompanionSession,
        activity: ActivityStore
    ) async {
        let name = character.displayName
        let date = anchorDate
        let records = activity.records.filter { modeID == nil || $0.modeID == modeID }
        let report = SophyInsights.report(records: records, modes: activity.modes, period: period, at: date, calendar: calendar, now: clock())
        append(name, report.ownerText + (report.incomplete ? "\nThis period is incomplete." : ""))
        phase = .answering
        generation = UUID()
        let active = generation, route = currentRoute(companion)
        routeKey = route
        var providerContext = report.providerLines
        providerContext.append("daily_goal_minutes=\(dailyGoalMinutes)")
        let instruction = """
        Return kind reply with no actions. The owner asked for study habit insight for the selected period.
        Compare aggregate minutes to daily_goal_minutes where the period allows, note gaps kindly, and offer practical tips for stronger biblical habits.
        Do not invent activity, titles, or citations. Stay humble and advisory.
        """
        let result = await complete(SophyPrompt.response + "\n" + instruction, providerContext.joined(separator: "\n"), companion: companion)
        guard callbackIsCurrent(active, route: route, companion: companion) else { return }
        if case .success(let raw) = result, let response = validated(raw, context: SophyValidationContext()), response.kind == .reply {
            append(name, response.message)
        } else {
            notice = "Local metrics are shown above. AI habit commentary is unavailable for this request."
        }
        phase = .completed
        await recordSummary("insights")
    }

    private func insights(period: ActivityAnalyticsPeriod, anchor: String?, mode: String?, companion: CompanionSession, activity: ActivityStore) async {
        let date = anchor.flatMap { SophyActionExecutor.localDateTime(date: $0, time: "12:00", calendar: calendar) } ?? clock()
        await insights(period: period, anchorDate: date, modeID: mode, dailyGoalMinutes: activity.goalMinutes, companion: companion, activity: activity)
    }
    func recordSummary(_ type: String) async {
        let active = generation
        do {
            let entries = try await repository.appendSummary(SophyHistoryEntry(id: UUID(), createdAt: clock(), actionType: type, status: "saved", resultIDs: [], resultCount: 0))
            if active == generation { history = entries }
        } catch { if active == generation { notice = "The result is available, but its History summary could not be saved." } }
    }
    private func performMusic(_ operation: String, track: String?, music: MusicSession) {
        if let track { guard music.selectApprovedTrack(track) else { notice = "That track is unavailable."; phase = .failed; return } }
        if operation == "pause" { music.handle(.pause) }
        else if operation == "play" {
            if music.currentTrack == nil {
                guard music.tracks.count == 1, let only = music.tracks.first else {
                    append("Sophy", music.tracks.isEmpty ? "There is no playable music in your library." : "Which track? " + music.tracks.map(\.title).joined(separator: ", "))
                    phase = .clarifying; return
                }
                _ = music.selectApprovedTrack(only.id)
            }
            music.handle(.play)
        }
        if operation == "select" {
            append("Sophy", "Selected " + (music.currentTrack?.title ?? "the track") + ". Tap Play when you are ready.")
        } else if operation == "pause" { append("Sophy", "Playback paused.") }
        else if music.snapshot.phase == .playing { append("Sophy", "Playing " + (music.currentTrack?.title ?? "your music") + ".") }
        else { notice = "Playback could not start. Check the music library and playback control."; phase = .failed; return }
        phase = .completed
    }
    private func runHandoffs(_ actions: [SophyActionDraft], companion: CompanionSession, activity: ActivityStore, music: MusicSession) {
        for action in actions {
            switch action {
            case .music(let op, let track): performMusic(op, track: track, music: music)
            case .openQuiz(let types, let difficulty, let timed):
                guard companion.activeQuizSessionID == nil else { notice = "Finish the active quiz first."; return }
                companion.sophyQuizRequest = SophyQuizRequest(difficulty: difficulty.flatMap(QuizDifficulty.init(rawValue:)) ?? .easy,
                    types: types?.compactMap(QuizType.init(rawValue:)) ?? [.identifyVerse, .whoSaidIt], timed: timed ?? false)
                panelOpen = false; onOpenQuiz?()
            case .openContemplation(let title, let passage):
                guard activity.draft == nil else { notice = "Finish the current activity first."; return }
                activity.sophyContemplationRequest = SophyContemplationRequest(title: title ?? "Contemplating", passage: passage)
                panelOpen = false; onOpenContemplation?()
            case .openChat(let preset, let prompt):
                guard companion.stageSophyChat(presetID: preset, draft: prompt) else { notice = companion.notice; return }
                panelOpen = false; onOpenChat?()
            case .openScripture(let book, let chapter, let verse, let edition):
                performScriptureNavigation(scriptureNavigationRequest(book: book, chapter: chapter, verse: verse, editionAbbreviation: edition))
            default: break
            }
        }
    }

    private func scriptureNavigationRequest(book: String, chapter: Int, verse: Int, editionAbbreviation: String?) -> SophyScriptureNavigationRequest {
        let title = lastBooks.first(where: { $0.id == book })?.title ?? book
        return SophyScriptureNavigationRequest(
            book: book,
            chapter: chapter,
            verse: verse,
            editionAbbreviation: editionAbbreviation,
            referenceLabel: "\(title) \(chapter):\(verse)"
        )
    }

    private func openingScriptureMessage(for request: SophyScriptureNavigationRequest) -> String {
        let translation = request.editionAbbreviation.map { " in \($0)" } ?? ""
        return "Opening \(request.referenceLabel)\(translation) in Scripture."
    }

    private func performScriptureNavigation(_ request: SophyScriptureNavigationRequest) {
        panelOpen = false
        onOpenScripture?(request)
        phase = .completed
    }

    func folderMatches(for line: SophyPreviewLine, collections: CollectionsStore) -> [StudyCollection] {
        guard let node = draftActions.compactMap({ action -> SophyFolderNodeDraft? in
            guard case .createFolders(_, let nodes) = action else { return nil }
            return nodes.first { line.id.hasSuffix(":" + $0.key) }
        }).first else { return [] }
        let group = line.id.components(separatedBy: ":").first ?? "0"
        var parentID = handles[destinationHandle]
        if let parentKey = node.parentKey {
            guard let parent = previewLines.first(where: { $0.id == group + ":" + parentKey }),
                  parent.resolution.hasPrefix("reuse:"), let existing = UUID(uuidString: String(parent.resolution.dropFirst(6))) else { return [] }
            parentID = existing
        }
        return collections.children(of: parentID).filter {
            !collections.sophyFolderIsProtected($0.id) && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(line.title.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }
    private func editedActions() -> [SophyActionDraft] {
        draftActions.enumerated().map { index, action in
            let line = previewLines.first { $0.id == "\(index)" }
            switch action {
            case .createFolders(_, let nodes):
                let edited = nodes.map { node in
                    var copy = node
                    if let row = previewLines.first(where: { $0.id == "\(index):\(node.key)" }) {
                        copy.name = row.title; copy.description = row.detail
                        copy.existingID = row.resolution.hasPrefix("reuse:") ? UUID(uuidString: String(row.resolution.dropFirst(6))) : nil
                        copy.allowDuplicateName = row.resolution == "new"
                    }
                    return copy
                }
                return .createFolders(destinationHandle: destinationHandle.isEmpty ? nil : destinationHandle, nodes: edited)
            case .createReminder(let title, let detail, let mode, let date, let time, let rule, let remove):
                return .createReminder(title: line?.title ?? title, description: line?.detail ?? detail, modeHandle: line?.mode ?? mode,
                    localDate: line?.date ?? date, localTime: line?.time ?? time, repeatRule: line?.repeatRule ?? rule, deleteAfterFiring: remove)
            case .createActivity:
                guard let line else { return action }
                return .createActivity(title: line.title, description: line.detail, modeHandle: line.mode,
                    localDate: line.date, localStartTime: line.time.isEmpty ? nil : line.time,
                    localEndDate: line.endDate.isEmpty ? nil : line.endDate,
                    localEndTime: line.endTime.isEmpty ? nil : line.endTime,
                    durationMinutes: line.duration.isEmpty ? nil : Int(line.duration))
            default: return action
            }
        }
    }
    private func validEditedAction(_ action: SophyActionDraft) -> Bool {
        switch action {
        case .createFolders(_, let nodes):
            return (try? SophyResponseValidator.validateTree(nodes)) != nil && nodes.allSatisfy {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.name.count <= 120 && $0.description.count <= 2_000 && $0.name.localizedCaseInsensitiveCompare("No Folder") != .orderedSame
            }
        case .createReminder(let title, let detail, _, let date, let time, _, _):
            return !title.isEmpty && title.count <= 200 && detail.count <= 2_000 && SophyActionExecutor.localDateTime(date: date, time: time, calendar: calendar) != nil
        case .createActivity(let title, let detail, _, let date, let time, _, _, _):
            return !title.isEmpty && title.count <= 200 && detail.count <= 2_000 && time.flatMap { SophyActionExecutor.localDateTime(date: date, time: $0, calendar: calendar) } != nil
        default: return true
        }
    }
    private func lines(for actions: [SophyActionDraft]) -> [SophyPreviewLine] {
        actions.enumerated().flatMap { index, action in
            switch action {
            case .createFolders(_, let nodes):
                func depth(_ node: SophyFolderNodeDraft, visited: Set<String> = []) -> Int {
                    guard !visited.contains(node.key), let key = node.parentKey, let parent = nodes.first(where: { $0.key == key }) else { return 0 }
                    return 1 + depth(parent, visited: visited.union([node.key]))
                }
                return nodes.map { node in
                    let parent = nodes.first { $0.key == node.parentKey }?.name ?? "Selected destination"
                    return SophyPreviewLine(id: "\(index):\(node.key)", title: node.name, subtitle: "In \(parent)", detail: node.description, depth: depth(node))
                }
            case .createReminder(let title, let detail, let mode, let date, let time, let rule, _):
                return [SophyPreviewLine(id: "\(index)", title: title, subtitle: "Reminder · \(calendar.timeZone.identifier)", detail: detail, date: date, time: time, mode: mode, repeatRule: rule)]
            case .createActivity(let title, let detail, let mode, let date, let start, let endDate, let end, let duration):
                return [SophyPreviewLine(id: "\(index)", title: title, subtitle: "Activity · \(calendar.timeZone.identifier)", detail: detail,
                    date: date, time: start ?? "", endDate: endDate ?? "", endTime: end ?? "", duration: duration.map(String.init) ?? "", mode: mode)]
            case .openChat(let preset, let prompt):
                return [SophyPreviewLine(id: "\(index)", title: "Open Companion", subtitle: "Preset: \(preset) · Draft only", detail: prompt)]
            case .openQuiz(let types, let level, let timed):
                return [SophyPreviewLine(id: "\(index)", title: "Open Quiz Me", subtitle: "\(level ?? "easy") · \(timed == true ? "timed" : "untimed")", detail: (types ?? ["Identify Verse", "Who Said It"]).joined(separator: ", "))]
            case .openContemplation(let title, let range):
                return [SophyPreviewLine(id: "\(index)", title: title ?? "Contemplation", subtitle: "Review setup before Start", detail: range.map { "\($0.book) \($0.chapter):\($0.startVerse)–\($0.endVerse)" } ?? "Seven curated passages")]
            default: return [SophyPreviewLine(id: "\(index)", title: action.typeName, subtitle: "Review before continuing")]
            }
        }
    }
}
