import SwiftUI

struct ActivityView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: ActivityStore
    @ObservedObject var sophy: SophySession
    @ObservedObject var companion: CompanionSession
    var liveActivityStatus: ActivityLiveActivityPresentationStatus = .unavailable
    var books: [ScriptureBook]
    var editionID: String?
    var referenceSystemID: String
    var startReading: (VerseID) -> Void
    var beginMeditationJourney: (MeditationJourneyLaunch) -> Void
    var availableVerses: (String, Int, String?) async throws -> [Int]
    var currentReaderLocation: () -> (book: String, chapter: Int)? = { nil }
    @State private var modeID = ActivityModeID.reading.id
    @State private var title = ""
    @State private var details = ""
    @State private var minutes = 10
    @State private var usesEndTime = false
    @State private var clockStart = Date()
    @State private var clockEnd = Date().addingTimeInterval(600)
    @State private var editingID: UUID?
    @State private var book = "GEN"
    @State private var chapter = 1
    @State private var verse = 1
    @State private var endBook = "GEN"
    @State private var endChapter = 1
    @State private var endVerse = 1
    @State private var startVerseOptions: [Int] = []
    @State private var endVerseOptions: [Int] = []
    @State private var verseError: String?
    @State private var finishStartVerseError: String?
    @State private var finishEndVerseError: String?
    @State private var meditateOnPassage = false
    @State private var meditateEndVerse = 1
    @State private var startReadingWorkflow = true
    @State private var startContemplationWorkflow = true
    @State private var sophySetupGeneration = UUID()
    @State private var customName = ""
    @State private var showingStart = false
    @State private var showingAddChooser = false
    @State private var showingTodayDetails = false
    @State private var showingDistribution = false
    @State private var showingManual = false
    @State private var showingFinish = false
    @State private var showingModes = false
    @State private var showingReminders = false
    @State private var reminderToEdit: ActivityReminder?
    @State private var reminderToDelete: ActivityReminder?
    @State private var showingExport = false
    @State private var showingAnalyticsExport = false
    @State private var showingImport = false
    @State private var showingInsights = false
    @State private var archiveDocument: ActivityArchiveDocument?
    @State private var analyticsDocument: ActivityPNGDocument?
    @State private var analyticsPeriod: ActivityAnalyticsPeriod = .week
    @State private var analyticsAnchor = Date()
    @State private var analyticsModeID = "all"
    @State private var pendingRestore: Data?
    @State private var confirmRestore = false
    @State private var recordToDelete: ActivityRecord?
    @State private var selectedRecord: ActivityRecord?
    @State private var pendingEdit: ActivityRecord?
    private var mode: ActivityMode { store.modeIncludingArchived(modeID) ?? store.modes[0] }
    private var selectableModes: [ActivityMode] {
        let active = store.modes
        if let archived = store.modeIncludingArchived(modeID), !active.contains(where: { $0.id == archived.id }) {
            return active + [archived]
        }
        return active
    }
    private var contemplationRecords: [ActivityRecord] {
        store.records.filter { $0.modeID == ActivityModeID.meditating.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                commandBar
                if store.draft != nil, let notice = liveActivityNotice {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)
                        .accessibilityIdentifier("activity.liveActivityNotice")
                }
                List {
                Section {
                    ActivityAnalyticsView(store: store, period: $analyticsPeriod,
                        anchor: $analyticsAnchor, modeID: $analyticsModeID,
                        onExport: { exportAnalytics() },
                        onShowDistribution: { showingDistribution = true })
                        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 12, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                Section {
                    todayCard
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 12, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    if let draft = store.draft {
                        activeCard(draft)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 12, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                Section {
                    ActivityPrimaryActionButton(
                        title: "Add or start a new activity",
                        systemImage: "plus",
                        action: { showingAddChooser = true },
                        accessibilityID: "activity.history.add"
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .disabled(!store.isReady)
                    if store.records.isEmpty {
                        Text("No activities recorded yet.")
                            .foregroundStyle(Color(theme.palette.secondary))
                            .listRowBackground(Color.clear)
                    }
                    ForEach(Array(store.records.prefix(5))) { record in
                        historyRow(record)
                    }
                } header: {
                    HStack {
                        Text("History")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(Color(theme.palette.ink))
                        Spacer()
                        NavigationLink("View all") {
                            ActivityHistoryView(store: store, books: books,
                                open: { selectedRecord = $0 },
                                edit: { prepareCorrection($0) },
                                delete: { recordToDelete = $0 })
                        }
                        .font(.subheadline.weight(.semibold))
                        .textCase(nil)
                    }
                }
                Section {
                    ActivityPrimaryActionButton(
                        title: "Start new scripture contemplation",
                        systemImage: "sparkles",
                        action: prepareContemplationStart,
                        accessibilityID: "activity.contemplation.start"
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .disabled(!store.isReady || store.draft != nil)
                    ForEach(Array(contemplationRecords.prefix(5))) { record in
                        historyRow(record)
                    }
                } header: {
                    HStack {
                        Text("Scripture Contemplation")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(Color(theme.palette.ink))
                        Spacer()
                        NavigationLink("View all") {
                            ActivityHistoryView(store: store, books: books, open: { selectedRecord = $0 },
                                edit: { prepareCorrection($0) }, delete: { recordToDelete = $0 },
                                modeFilter: ActivityModeID.meditating.id, onStartNew: prepareContemplationStart)
                        }
                        .accessibilityIdentifier("activity.contemplation.history")
                        .font(.subheadline.weight(.semibold))
                        .textCase(nil)
                    }
                }
                Section {
                    ActivityPrimaryActionButton(
                        title: "Add new reminder",
                        systemImage: "plus",
                        action: { openReminder(nil) },
                        accessibilityID: "activity.reminder.new"
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    if store.reminders.isEmpty {
                        Text("No reminders yet.")
                            .foregroundStyle(Color(theme.palette.secondary))
                            .listRowBackground(Color.clear)
                    }
                    ForEach(Array(ActivityReminderGrouping.groups(store.reminders)
                        .flatMap(\.reminders).prefix(5))) { reminder in
                        reminderRow(reminder)
                    }
                } header: {
                    HStack {
                        Text("Reminders")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(Color(theme.palette.ink))
                        Spacer()
                        NavigationLink("View all") {
                            ActivityReminderHistoryView(store: store,
                                edit: { openReminder($0) }, delete: { reminderToDelete = $0 })
                        }
                        .font(.subheadline.weight(.semibold))
                        .textCase(nil)
                    }
                }
                Section {
                    auxiliaryCard
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 20, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Auxiliary")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(Color(theme.palette.ink))
                        .textCase(nil)
                }
            }
            .listStyle(.plain)
            }
            .contentMargins(.bottom, 160, for: .scrollContent)
            .accessibilityIdentifier("activity.content")
            .scrollContentBackground(.hidden)
            .background(Color(theme.palette.paper).ignoresSafeArea())
            .foregroundStyle(Color(theme.palette.ink))
            .toolbar(.hidden, for: .navigationBar)
            .alert("Activity", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
            .sheet(isPresented: $showingStart) { startSheet }
            .sheet(isPresented: $showingTodayDetails) { ActivityTodayDetailView(store: store) }
            .sheet(isPresented: $showingDistribution) {
                ActivityDistributionDetailView(store: store, period: analyticsPeriod,
                    anchor: analyticsAnchor, modeID: analyticsModeID)
            }
            .sheet(isPresented: $showingManual) { manualSheet }
            .sheet(isPresented: $showingInsights) {
                ActivityInsightsSheet(store: store, sophy: sophy, companion: companion)
                    .environment(\.appTheme, theme)
            }
            .sheet(isPresented: $showingFinish) { finishSheet }
            .sheet(isPresented: $showingModes) { modesSheet }
            .sheet(isPresented: $showingReminders, onDismiss: { reminderToEdit = nil }) {
                ActivityRemindersView(store: store, reminder: reminderToEdit)
            }
            .sheet(item: $selectedRecord, onDismiss: {
                if let pendingEdit { self.pendingEdit = nil; prepareCorrection(pendingEdit) }
            }) { record in
                ActivityRecordDetailView(record: record, books: books,
                    edit: { pendingEdit = record; selectedRecord = nil },
                    delete: {
                        selectedRecord = nil
                        recordToDelete = record
                    })
            }
            .fileExporter(isPresented: $showingExport, document: archiveDocument, contentType: .json, defaultFilename: "Sophia-Activity") { result in
                if case .failure(let error) = result { store.errorMessage = error.localizedDescription }
            }
            .fileExporter(isPresented: $showingAnalyticsExport, document: analyticsDocument,
                          contentType: .png, defaultFilename: "Sophia-Analytics") { result in
                if case .failure(let error) = result { store.errorMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $showingImport, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    do {
                        pendingRestore = try Data(contentsOf: url)
                        confirmRestore = true
                    } catch { store.errorMessage = error.localizedDescription }
                case .failure(let error): store.errorMessage = error.localizedDescription
                }
            }
            .confirmationDialog("Replace all Activity records and settings?", isPresented: $confirmRestore) {
                Button("Replace Activity Data", role: .destructive) {
                    if let pendingRestore { Task { await store.restoreArchive(pendingRestore) } }
                    pendingRestore = nil
                }
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            } message: { Text("Sophia keeps a pre-restore Activity archive on this device.") }
            .overlay {
                if showingAddChooser {
                    StudyCenteredActionOverlay(
                        title: "Add activity",
                        cardMaxWidth: 272,
                        actions: [
                            .init(id: "activity.add.start", title: "Start Activity", systemImage: "play.fill") {
                                showingAddChooser = false
                                prepareStart()
                            },
                            .init(id: "activity.add.manual", title: "Add Manual Record", systemImage: "plus.square") {
                                showingAddChooser = false
                                prepareManual()
                            },
                        ],
                        onCancel: { showingAddChooser = false }
                    )
                }
                if let record = recordToDelete {
                    StudyCenteredConfirmationOverlay(
                        title: "Delete \(record.title)?",
                        message: "This removes the saved time from goals and analytics.",
                        confirmLabel: "Delete Activity",
                        onConfirm: {
                            store.delete(record.id)
                            recordToDelete = nil
                        },
                        onCancel: { recordToDelete = nil }
                    )
                }
            }
            .overlay {
                if let reminder = reminderToDelete {
                    StudyCenteredConfirmationOverlay(
                        title: "Delete \(reminder.title)?",
                        message: "This reminder will no longer notify you.",
                        confirmLabel: "Delete Reminder",
                        onConfirm: {
                            store.deleteReminder(reminder.id)
                            reminderToDelete = nil
                        },
                        onCancel: { reminderToDelete = nil }
                    )
                }
            }
            .animation(.easeOut(duration: 0.18), value: showingAddChooser)
            .animation(.easeOut(duration: 0.18), value: recordToDelete != nil)
            .animation(.easeOut(duration: 0.18), value: reminderToDelete != nil)
            .onChange(of: store.finishRequestID) { _, request in
                if request != nil { prepareFinish(); store.clearFinishRequest() }
            }
            .onChange(of: store.startRequestID) { _, request in
                if request != nil { showingStart = true; store.clearStartRequest() }
            }
            .onChange(of: store.sophyContemplationRequest) { _, request in
                guard let request else { return }
                Task { await prepareSophyContemplation(request) }
            }
            .onAppear {
                if store.finishRequestID != nil { prepareFinish(); store.clearFinishRequest() }
                if store.startRequestID != nil { showingStart = true; store.clearStartRequest() }
            }
        }
        .background(Color(theme.palette.paper).ignoresSafeArea())
    }

    private var liveActivityNotice: String? {
        switch liveActivityStatus {
        case .disabled: "Live Activities are turned off. Your timer still runs in Sophia."
        case .denied: "Live Activity unavailable. Your timer still runs in Sophia."
        case .failed: "Live Activity could not update. Your timer still runs in Sophia."
        default: nil
        }
    }

    private var commandBar: some View {
        HStack(spacing: 4) {
            LibraryHeaderTitle(title: "Activity")
                .accessibilityIdentifier("activity.title")
            Spacer(minLength: 12)
            Button {
                showingAddChooser = true
            } label: {
                LibraryHeaderIcon(systemImage: "plus")
            }
            .buttonStyle(.plain)
            .disabled(!store.isReady)
            .accessibilityLabel("Add activity")
            .accessibilityIdentifier("activity.add")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var auxiliaryCard: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 175), spacing: 12)], spacing: 12) {
            auxiliaryButton("Insights", icon: "chart.line.uptrend.xyaxis") { showingInsights = true }
            auxiliaryButton("Custom Modes", icon: "square.grid.2x2") { showingModes = true }
            auxiliaryButton("Export Data", icon: "archivebox") {
                Task {
                    if let data = await store.exportArchive() {
                        archiveDocument = ActivityArchiveDocument(data: data)
                        showingExport = true
                    }
                }
            }
            auxiliaryButton("Restore Data", icon: "arrow.counterclockwise") { showingImport = true }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(theme.palette.rule), lineWidth: 1))
    }

    private func auxiliaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(Color(theme.palette.ink))
        .tint(Color(theme.palette.accent))
        .accessibilityIdentifier("activity.auxiliary." + title.replacingOccurrences(of: " ", with: "").lowercased())
    }

    private func exportAnalytics() {
        let view = ActivityAnalyticsView(store: store, period: .constant(analyticsPeriod),
            anchor: .constant(analyticsAnchor), modeID: .constant(analyticsModeID), exporting: true)
            .environment(\.appTheme, theme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let data = renderer.uiImage?.pngData() else {
            store.errorMessage = "Analytics image could not be created."
            return
        }
        analyticsDocument = ActivityPNGDocument(data: data)
        showingAnalyticsExport = true
    }

    private var todayCard: some View {
        Button { showingTodayDetails = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Today")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                    Spacer()
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(Color(theme.palette.secondary))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(theme.palette.secondary))
                }
                let seconds = ActivityMetrics.seconds(on: Date(), records: store.records)
                Text("\(Int(seconds / 60)) of \(store.goalMinutes) mins (Total)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                ProgressView(value: min(1, seconds / Double(store.goalMinutes * 60)))
                    .tint(Color(theme.palette.accent))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(theme.palette.rule), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(theme.palette.ink))
        .accessibilityIdentifier("activity.today")
    }

    private func activeCard(_ draft: ActivityDraft) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Now Active").font(.caption.weight(.semibold)).foregroundStyle(Color(theme.palette.secondary))
                Text(draft.modeLabel).font(.headline)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(ActivityDuration.text(draft.activeSeconds(at: context.date)))
                    .monospacedDigit().font(.headline)
            }
            Button {
                if draft.runningSince == nil { store.resume() } else { store.pause() }
            } label: { Image(systemName: draft.runningSince == nil ? "play.fill" : "pause.fill") }
                .accessibilityLabel(draft.runningSince == nil ? "Resume activity" : "Pause activity")
            Button { prepareFinish() } label: { Image(systemName: "checkmark.circle.fill") }
                .accessibilityLabel("Finish activity")
        }
        .padding(18)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color(theme.palette.rule), lineWidth: 1))
    }

    private func historyRow(_ record: ActivityRecord) -> some View {
        ActivityHistoryRow(record: record, books: books,
            open: { selectedRecord = record },
            edit: { prepareCorrection(record) },
            delete: { recordToDelete = record })
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private func reminderRow(_ reminder: ActivityReminder) -> some View {
        ActivityReminderRow(reminder: reminder,
            open: { openReminder(reminder) }, edit: { openReminder(reminder) },
            delete: { reminderToDelete = reminder })
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private func openReminder(_ reminder: ActivityReminder?) {
        reminderToEdit = reminder
        showingReminders = true
    }

    private func prepareStart() {
        modeID = ActivityModeID.reading.id
        title = ""
        meditateOnPassage = false
        startReadingWorkflow = store.automaticReadingWorkflow
        startContemplationWorkflow = store.automaticContemplationWorkflow
        showingStart = true
    }

    private func prepareContemplationStart() {
        prepareStart()
        modeID = ActivityModeID.meditating.id
    }

    private func prepareManual() {
        editingID = nil; title = ""; details = ""; usesEndTime = false
        minutes = 10; clockStart = Date(); clockEnd = clockStart.addingTimeInterval(600)
        showingManual = true
    }

    private var modePicker: some View {
        Picker("Mode", selection: $modeID) { ForEach(selectableModes) { item in Text(item.name).tag(item.id) } }
            .accessibilityIdentifier("activity.start.mode")
            .onChange(of: modeID) { _, value in
                if value != ActivityModeID.meditating.id { meditateOnPassage = false }
            }
    }

    private var startsGuidedWorkflow: Bool {
        switch modeID {
        case ActivityModeID.reading.id: startReadingWorkflow
        case ActivityModeID.meditating.id: startContemplationWorkflow
        default: false
        }
    }

    private var startDisabled: Bool {
        guard startsGuidedWorkflow else { return false }
        if modeID == ActivityModeID.reading.id { return !startVerseOptions.contains(verse) }
        if modeID == ActivityModeID.meditating.id, meditateOnPassage {
            return !startVerseOptions.contains(verse) || !meditationEndVerseOptions.contains(meditateEndVerse)
        }
        return false
    }

    private var meditationRange: PassageRange {
        let end = MeditationPassageRules.clampedEndVerse(start: verse, proposedEnd: meditateEndVerse, available: startVerseOptions)
        return MeditationPassageRules.range(
            book: book,
            chapter: chapter,
            startVerse: verse,
            endVerse: end,
            referenceSystemID: referenceSystemID
        )
    }

    @MainActor
    private func prepareSophyContemplation(_ request: SophyContemplationRequest) async {
        let generation = UUID(); sophySetupGeneration = generation
        defer { if generation == sophySetupGeneration { store.sophyContemplationRequest = nil } }
        guard store.draft == nil else { store.errorMessage = "Finish your current activity first."; return }
        startContemplationWorkflow = true
        if let passage = request.passage {
            guard let selectedBook = books.first(where: { $0.id == passage.book }),
                  (1...selectedBook.chapterCount).contains(passage.chapter), passage.startVerse > 0,
                  (0...1).contains(passage.endVerse - passage.startVerse) else {
                store.errorMessage = "Choose one or two verses in a valid chapter for Contemplation."; return
            }
            do {
                let verses = try await availableVerses(passage.book, passage.chapter, editionID)
                guard generation == sophySetupGeneration, store.draft == nil else { return }
                guard verses.contains(passage.startVerse), verses.contains(passage.endVerse) else {
                    store.errorMessage = "The requested verses are unavailable. Choose an available passage in Activity."; return
                }
            } catch { store.errorMessage = "The requested passage could not be loaded. Choose an available passage in Activity."; return }
        }
        guard generation == sophySetupGeneration, store.draft == nil else { return }
        modeID = ActivityModeID.meditating.id; title = request.title
        if let passage = request.passage {
            meditateOnPassage = true; book = passage.book; chapter = passage.chapter
            verse = passage.startVerse; meditateEndVerse = passage.endVerse
        } else { meditateOnPassage = false }
        showingStart = true
    }

    private var meditationEndVerseOptions: [Int] {
        guard startVerseOptions.contains(verse) else { return [] }
        let second = verse + 1
        if startVerseOptions.contains(second) { return [verse, second] }
        return [verse]
    }

    private var meditationEndVersePicker: some View {
        Picker("Through verse", selection: $meditateEndVerse) {
            ForEach(meditationEndVerseOptions, id: \.self) { number in
                Text(number == verse ? "Verse \(number)" : "Verses \(verse)–\(number)").tag(number)
            }
        }
        .onChange(of: verse) { _, _ in
            meditateEndVerse = MeditationPassageRules.clampedEndVerse(
                start: verse,
                proposedEnd: meditateEndVerse,
                available: startVerseOptions
            )
        }
        .onChange(of: startVerseOptions) { _, options in
            meditateEndVerse = MeditationPassageRules.clampedEndVerse(
                start: verse,
                proposedEnd: meditateEndVerse,
                available: options
            )
        }
    }
    private func readingSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(theme.palette.ink))
            .textCase(nil)
    }

    private func versePicker(
        book: Binding<String>,
        chapter: Binding<Int>,
        verse: Binding<Int>,
        options: Binding<[Int]>,
        selectedEditionID: String?,
        loadError: Binding<String?>
    ) -> some View {
        Group {
            Picker("Book", selection: book) { ForEach(books, id: \.id) { item in Text(item.title).tag(item.id) } }
            let chapterCount = max(1, books.first { $0.id == book.wrappedValue }?.chapterCount ?? 150)
            Picker("Chapter", selection: chapter) {
                ForEach(1...chapterCount, id: \.self) { number in
                    Text(String(number)).tag(number)
                }
            }
            if options.wrappedValue.isEmpty { ProgressView("Loading verses") }
            else { Picker("Verse", selection: verse) { ForEach(options.wrappedValue, id: \.self) { number in Text(String(number)).tag(number) } } }
            if let message = loadError.wrappedValue { Text(message).foregroundStyle(.red) }
        }
        .onChange(of: book.wrappedValue) { _, bookID in
            let count = max(1, books.first { $0.id == bookID }?.chapterCount ?? 150)
            if chapter.wrappedValue > count { chapter.wrappedValue = count }
        }
        .task(id: "\(selectedEditionID ?? "")-\(book.wrappedValue)-\(chapter.wrappedValue)") {
            options.wrappedValue = []
            loadError.wrappedValue = nil
            do {
                let loaded = try await availableVerses(book.wrappedValue, chapter.wrappedValue, selectedEditionID)
                guard !Task.isCancelled else { return }
                options.wrappedValue = loaded
                if !loaded.contains(verse.wrappedValue) { verse.wrappedValue = loaded.first ?? 1 }
            } catch { loadError.wrappedValue = error.localizedDescription }
        }
    }
    private var startSheet: some View {
        NavigationStack {
            Form {
                modePicker
                TextField("Title", text: $title)
                if modeID == ActivityModeID.reading.id, startReadingWorkflow {
                    Section {
                        versePicker(book: $book, chapter: $chapter, verse: $verse, options: $startVerseOptions,
                                    selectedEditionID: editionID, loadError: $verseError)
                    } header: { readingSectionHeader("Start") }
                }
                if modeID == ActivityModeID.meditating.id, startContemplationWorkflow {
                    Toggle("Contemplate a specific passage", isOn: $meditateOnPassage)
                    if meditateOnPassage {
                        versePicker(book: $book, chapter: $chapter, verse: $verse, options: $startVerseOptions,
                                    selectedEditionID: editionID, loadError: $verseError)
                        meditationEndVersePicker
                    } else {
                        Text("Sophia will guide you through seven short passages (up to two verses each).")
                            .font(.subheadline)
                            .foregroundStyle(Color(theme.palette.secondary))
                    }
                }
                if modeID == ActivityModeID.reading.id {
                    Toggle("Start Reading workflow", isOn: $startReadingWorkflow)
                        .accessibilityIdentifier("activity.start.readingWorkflow")
                }
                if modeID == ActivityModeID.meditating.id {
                    Toggle("Start Scripture Contemplation workflow", isOn: $startContemplationWorkflow)
                        .accessibilityIdentifier("activity.start.contemplationWorkflow")
                }
            }.navigationTitle("Start Activity")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingStart = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Start") {
                            let selected = mode
                            let guided = selected.id == ActivityModeID.reading.id ? startReadingWorkflow
                                : selected.id == ActivityModeID.meditating.id ? startContemplationWorkflow : false
                            let start = selected.id == ActivityModeID.reading.id && startReadingWorkflow
                                ? VerseID(referenceSystemID: referenceSystemID, book: book, chapter: chapter, verse: verse) : nil
                            store.start(mode: selected, title: title.isEmpty ? selected.name : title, readingStart: start,
                                        editionID: editionID, guidedWorkflow: guided)
                            guard store.errorMessage == nil else { return }
                            if selected.id == ActivityModeID.reading.id {
                                store.setAutomaticWorkflow(startReadingWorkflow, for: ActivityModeID.reading.id)
                            } else if selected.id == ActivityModeID.meditating.id {
                                store.setAutomaticWorkflow(startContemplationWorkflow, for: ActivityModeID.meditating.id)
                            }
                            showingStart = false
                            if let start { startReading(start) }
                            if selected.id == ActivityModeID.meditating.id, startContemplationWorkflow {
                                let chosen: PassageRange? = meditateOnPassage ? meditationRange : nil
                                beginMeditationJourney(MeditationJourneyLaunch(
                                    referenceSystemID: referenceSystemID,
                                    editionID: editionID,
                                    chosenRange: chosen
                                ))
                            }
                        }.disabled(startDisabled).accessibilityIdentifier("activity.start.confirm")
                    }
                }
        }
    }
    private var manualSheet: some View {
        NavigationStack {
            Form {
                modePicker
                TextField("Title", text: $title)
                DatePicker("Start", selection: $clockStart, displayedComponents: [.date, .hourAndMinute])
                Toggle("Enter end time", isOn: $usesEndTime)
                if usesEndTime {
                    DatePicker("End", selection: $clockEnd, displayedComponents: [.date, .hourAndMinute])
                    Text("Duration: \(ActivityDuration.text(max(0, clockEnd.timeIntervalSince(clockStart))))")
                        .foregroundStyle(Color(theme.palette.secondary))
                } else {
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 1...1440)
                    Text("End: \(clockStart.addingTimeInterval(Double(minutes * 60)).formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(Color(theme.palette.secondary))
                }
                TextField("Description", text: $details)
            }.navigationTitle(editingID == nil ? "Add Manual Activity" : "Correct Activity")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingManual = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.addManual(title: title, mode: mode, startedAt: clockStart,
                                endedAt: usesEndTime ? clockEnd : nil,
                                durationSeconds: usesEndTime ? nil : Double(minutes * 60),
                                description: details, replacing: editingID)
                            if store.errorMessage == nil { showingManual = false }
                        }
                    }
                }
        }
    }
    private var finishSheet: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Description", text: $details)
                if store.draft?.readingStart != nil {
                    let edition = store.draft?.editionID
                    Section {
                        versePicker(book: $book, chapter: $chapter, verse: $verse, options: $startVerseOptions,
                                    selectedEditionID: edition, loadError: $finishStartVerseError)
                    } header: { readingSectionHeader("Start") }
                    Section {
                        versePicker(book: $endBook, chapter: $endChapter, verse: $endVerse, options: $endVerseOptions,
                                    selectedEditionID: edition, loadError: $finishEndVerseError)
                    } header: { readingSectionHeader("End") }
                }
                Button("Discard Activity", role: .destructive) { store.discardDraft(); showingFinish = false }
            }.navigationTitle("Finish Activity")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Keep Session") { showingFinish = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let draft = store.draft else { return }
                            let systemID = draft.readingStart?.referenceSystemID ?? referenceSystemID
                            let start = draft.readingStart == nil
                                ? nil
                                : VerseID(referenceSystemID: systemID, book: book, chapter: chapter, verse: verse)
                            let end = draft.readingStart == nil
                                ? nil
                                : VerseID(referenceSystemID: systemID, book: endBook, chapter: endChapter, verse: endVerse)
                            store.finish(title: title, description: details, readingStart: start, readingEnd: end,
                                bookOrder: Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0.order) }))
                            if store.errorMessage == nil { showingFinish = false }
                        }.disabled(finishSaveDisabled)
                    }
                }
        }
    }

    private var finishSaveDisabled: Bool {
        guard store.draft?.readingStart != nil else { return false }
        guard startVerseOptions.contains(verse), endVerseOptions.contains(endVerse) else { return true }
        return false
    }
    private var modesSheet: some View {
        NavigationStack {
            Form {
                HStack { TextField("Mode name", text: $customName); Button("Add") { store.addMode(customName); customName = "" } }
                ForEach(store.modes.filter { !$0.isBuiltIn }) { item in
                    HStack { Text(item.name); Spacer(); Button("Archive") { store.archiveMode(item.id) } }
                }
            }.navigationTitle("Custom Modes").toolbar { Button("Done") { showingModes = false } }
        }
    }
    private func prepareFinish() {
        guard let draft = store.draft else { return }
        title = draft.title; details = draft.description
        finishStartVerseError = nil
        finishEndVerseError = nil
        if let start = draft.readingStart {
            book = start.book
            chapter = start.chapter
            verse = start.verse
            let reader = currentReaderLocation()
            let suggested = ReadingWorkflowEndSuggestion.suggestedEnd(
                start: start,
                readerBook: reader?.book,
                readerChapter: reader?.chapter
            )
            endBook = suggested.book
            endChapter = suggested.chapter
            endVerse = suggested.verse
        }
        showingFinish = true
    }
    private func prepareCorrection(_ record: ActivityRecord) {
        editingID = record.id; title = record.title; details = record.description
        modeID = record.modeID
        minutes = max(1, Int(record.activeSeconds / 60))
        usesEndTime = !record.intervals.isEmpty
        clockStart = record.intervals.first?.start ?? record.activityDate
        clockEnd = record.intervals.last?.end ?? clockStart.addingTimeInterval(record.activeSeconds)
        showingManual = true
    }
}
