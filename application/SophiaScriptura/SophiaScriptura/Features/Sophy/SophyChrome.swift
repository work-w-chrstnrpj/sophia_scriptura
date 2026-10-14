import SwiftUI

/// The character only owns its small hit area. Reading/writing remain available behind it.
struct SophyChrome: View {
    @ObservedObject var sophy: SophySession
    @ObservedObject var companion: CompanionSession
    @ObservedObject var collections: CollectionsStore
    @ObservedObject var activity: ActivityStore
    @ObservedObject var music: MusicSession
    var notes: NotesSession
    var books: [ScriptureBook]
    var referenceSystemID: String
    var editionID: String?
    var editionCatalog: String
    var scriptureRepositoryProvider: (String?) async throws -> any ScriptureContentRepository
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var dragOrigin: Double?
    @State private var panelDetent: PresentationDetent = .medium

    var body: some View {
        // Native SwiftUI hit testing preserves the character button while empty
        // overlay space remains available to the underlying screen.
        Group {
            GeometryReader { geometry in
                if sophy.preferences.enabled {
                    // The positioned view must use the same width as companionCenter.
                    // A screen-wide frame pushes its trailing character beyond the viewport.
                    let maxWidth = min(280, max(72, geometry.size.width - geometry.safeAreaInsets.leading - geometry.safeAreaInsets.trailing - 24))
                    character(maxWidth: maxWidth)
                        .position(companionCenter(in: geometry))
                        .simultaneousGesture(drag(in: geometry.size))
                }
            }
            .coordinateSpace(name: "sophy.overlay")
        }
        .onChange(of: sophy.preferences.character) { _, _ in restartIdleQuotes() }
        .onChange(of: sophy.preferences.idleDelayBeforeQuoteSeconds) { _, _ in restartIdleQuotes() }
        .onChange(of: sophy.preferences.idleScriptureQuotesEnabled) { _, _ in restartIdleQuotes() }
        .onChange(of: sophy.idleQuotesSuspended) { _, _ in restartIdleQuotes() }
        .onChange(of: sophy.preferences.enabled) { _, enabled in
            if enabled { restartIdleQuotes() } else { sophy.stopIdleQuotes() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { restartIdleQuotes() } else { sophy.stopIdleQuotes() }
        }
        .onChange(of: sophy.panelOpen) { _, open in if open { sophy.noteUserActivity() } }
        .onAppear { restartIdleQuotes() }
        .onDisappear { sophy.stopIdleQuotes() }
        .sheet(isPresented: Binding(get: { sophy.panelOpen || sophy.enhancementOpen }, set: { open in
            if !open {
                sophy.panelOpen = false
                if sophy.enhancementOpen {
                    if sophy.isWorking { sophy.cancel() } else { sophy.dismissEnhancement() }
                }
            }
        })) {
            if sophy.enhancementOpen {
                SophyEnhancementSheet(sophy: sophy, companion: companion, notes: notes)
                    .environment(\.appTheme, theme)
            } else {
                conversation.environment(\.appTheme, theme)
                    .presentationDetents([.fraction(0.42), .medium, .large], selection: $panelDetent)
                    .presentationDragIndicator(.visible)
            }
        }
    }
    private func character(maxWidth: CGFloat) -> some View {
        let isLeading = sophy.preferences.edge == "leading"
        return StudyCompanionCharacterView(
            poseName: sophy.poseName,
            character: sophy.character,
            edge: sophy.preferences.edge,
            quote: sophy.idleQuote,
            quoteVisible: sophy.idleQuoteVisible && !sophy.panelOpen && !sophy.enhancementOpen && !sophy.idleQuotesSuspended,
            reduceMotion: reduceMotion,
            sceneActive: scenePhase == .active,
            onTap: { sophy.noteUserActivity(); sophy.syncRoute(companion); sophy.openChatPanel() },
            onMoveOppositeEdge: {
                sophy.move(
                    edge: sophy.preferences.edge == "leading" ? "trailing" : "leading",
                    vertical: sophy.preferences.vertical
                )
            },
            onResetPosition: { sophy.move(edge: "trailing", vertical: 0.72) }
        )
        .frame(maxWidth: max(72, maxWidth), alignment: isLeading ? .leading : .trailing)
    }

    private func restartIdleQuotes() {
        sophy.startIdleQuotes(
            books: books,
            referenceSystemID: referenceSystemID,
            editionID: editionID,
            repositoryProvider: scriptureRepositoryProvider,
            sceneActive: scenePhase == .active
        )
    }
    private var conversation: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if sophy.turns.isEmpty { welcome }
                        ForEach(sophy.turns) { turn in message(turn).id(turn.id) }
                        if !sophy.sources.isEmpty { sourceCards }
                        if sophy.phase == .previewing {
                            SophyActionPreview(sophy: sophy, collections: collections, activity: activity) {
                                Task { await sophy.confirm(collections: collections, activity: activity, companion: companion, music: music) }
                            }.id("preview")
                        }
                        if sophy.isWorking {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text(sophy.phase == .committing ? "Saving your changes…" : "Sophy is thinking…").foregroundStyle(.secondary)
                            }.accessibilityIdentifier("sophy.progress")
                        }
                        if let notice = sophy.notice {
                            Label(notice, systemImage: sophy.phase == .failed || sophy.phase == .uncertain ? "exclamationmark.circle" : "info.circle")
                                .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                                .accessibilityIdentifier("sophy.notice")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(20).frame(maxWidth: 700).frame(maxWidth: .infinity)
                }
                .onChange(of: sophy.turns.count) { _, _ in withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: sophy.phase) { _, phase in if phase == .previewing { proxy.scrollTo("preview", anchor: .top) } }
            }
            .background(Color(theme.palette.paper))
            .navigationTitle(sophy.character.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("New Session", systemImage: "square.and.pencil") { sophy.newSession() }
                        Button("History", systemImage: "clock") { sophy.historyOpen = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .disabled(sophy.phase == .committing).accessibilityLabel("Sophy options").accessibilityIdentifier("sophy.options")
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { sophy.panelOpen = false } }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .navigationDestination(isPresented: $sophy.historyOpen) { SophyHistoryView(sophy: sophy, collections: collections, activity: activity) }
            .sheet(isPresented: $sophy.contextReviewOpen) {
                NavigationStack {
                    Form {
                        Section("Send selected excerpts to \(sophy.routeLabel)") {
                            Text("Only the sources shown below will be attached. Remove anything you do not want to send.").font(.callout)
                            ForEach(sophy.sources) { source in
                                DisclosureGroup(source.title) {
                                    Text(source.excerpt).font(.callout).textSelection(.enabled)
                                    Button("Remove source", role: .destructive) { sophy.sources.removeAll { $0.id == source.id } }
                                }
                            }
                        }
                        Section("Your question") { TextField("Ask about these sources", text: $sophy.sourceQuestion, axis: .vertical) }
                    }
                    .navigationTitle("Review Context").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { sophy.contextReviewOpen = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("Send") {
                            Task { await sophy.askWithSources(companion: companion, collections: collections, notes: notes, activity: activity, music: music) }
                        }.disabled(sophy.sources.isEmpty || sophy.sourceQuestion.isEmpty) }
                    }
                }
            }
            .alert("Clear Sophy History?", isPresented: $sophy.clearHistoryRequested) {
                Button("Cancel", role: .cancel) {}
                Button("Clear History", role: .destructive) { Task { await sophy.clearHistory() } }
            } message: { Text("This removes action summaries and recovery receipts. It does not delete the folders, reminders or records Sophy created.") }

        }
        .tint(Color(theme.palette.accent))
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sophy.character.welcomeGreeting)
                .font(.title3.weight(.semibold))
            (Text("\(sophy.character.subtitle). Try ")
                + Text("/help").fontWeight(.semibold).foregroundStyle(Color(theme.palette.accent))
                + Text(" or ask about folders, study habits, or a quiz."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    private func message(_ turn: SophyTurn) -> some View {
        let isUser = turn.role == "You"
        return HStack(alignment: .top) {
            if isUser { Spacer(minLength: 36) }
            VStack(alignment: .leading, spacing: 5) {
                Text(isUser ? "You" : sophy.character.displayName).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Group {
                    if isUser {
                        Text(SophySlashCommandStyle.attributedText(turn.text, accent: theme.palette.accent, ink: theme.palette.ink))
                    } else { Text(.init(turn.text)) }
                }.textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(isUser ? Color(theme.palette.accent).opacity(0.12) : Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16))
            if !isUser { Spacer(minLength: 24) }
        }
    }
    private var sourceCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Study sources").font(.headline)
            ForEach(sophy.sources) { source in
                Button { sophy.openSource(source, collections: collections, notes: notes) } label: {
                    Label(source.title, systemImage: source.handle.hasPrefix("n") ? "note.text" : "folder")
                }
            }
            Button("Review excerpts and ask Sophy", systemImage: "text.bubble") { sophy.contextReviewOpen = true }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 12))
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sophy.composer.hasPrefix("/") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(SophySlashCommandCatalog.composerSuggestions.filter { sophy.composer.trimmingCharacters(in: .whitespaces).isEmpty || $0.hasPrefix(sophy.composer.trimmingCharacters(in: .whitespaces)) || sophy.composer.contains(" ") }, id: \.self) { command in
                            Button(command) { sophy.composer = command + " " }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(theme.palette.accent))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(theme.palette.accent).opacity(0.14), in: Capsule())
                        }
                    }
                }
            }
            HStack(alignment: .bottom, spacing: 12) {
                Button { sophy.composer = "/" } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Sophy commands")
                ZStack(alignment: .topLeading) {
                    if SophySlashCommandStyle.showsHighlightedOverlay(for: sophy.composer) {
                        Text(SophySlashCommandStyle.attributedText(sophy.composer, accent: theme.palette.accent, ink: theme.palette.ink))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .allowsHitTesting(false)
                    }
                    TextField("Ask Sophy…", text: $sophy.composer, axis: .vertical)
                        .lineLimit(1...5)
                        .foregroundStyle(SophySlashCommandStyle.showsHighlightedOverlay(for: sophy.composer) ? .clear : Color(theme.palette.ink))
                        .tint(Color(theme.palette.accent))
                        .accessibilityIdentifier("sophy.composer")
                        .disabled(sophy.isWorking)
                }
                if sophy.isWorking {
                    Button { sophy.cancel() } label: { Image(systemName: "stop.circle.fill").font(.title2) }
                        .disabled(sophy.phase == .committing).accessibilityLabel("Stop request")
                } else {
                    Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                        .disabled(sophy.composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Send").accessibilityIdentifier("sophy.send")
                }
            }
            .padding(12).background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 18))
            Text(sophy.routeLabel).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(theme.palette.paper).shadow(color: .black.opacity(0.04), radius: 5, y: -2))
    }
    private func send() {
        let text = sophy.composer; sophy.composer = ""
        Task {
            await sophy.send(text, companion: companion, collections: collections, notes: notes, activity: activity,
                             music: music, books: books, editionCatalog: editionCatalog)
        }
    }
    /// Keeps the character anchored from the bottom while leaving room above for the speech bubble.
    private func bottomPadding(in size: CGSize, safe: EdgeInsets) -> CGFloat {
        let minBottom = safe.bottom + 108
        let preferred = size.height * (1 - sophy.preferences.vertical) - 52
        let maxBottom = max(minBottom, size.height - safe.top - 320)
        return min(maxBottom, max(minBottom, preferred))
    }

    /// Centers the companion cluster (bubble + character) without expanding hit testing to the full screen.
    private func companionCenter(in geometry: GeometryProxy) -> CGPoint {
        let safe = geometry.safeAreaInsets
        let isLeading = sophy.preferences.edge == "leading"
        let maxClusterWidth = min(280, geometry.size.width - safe.leading - safe.trailing - 24)
        let showsQuote = sophy.idleQuoteVisible && !sophy.panelOpen && !sophy.enhancementOpen && sophy.idleQuote != nil
        let clusterHeight: CGFloat = 96 + (showsQuote ? 132 : 0)
        let bottom = bottomPadding(in: geometry.size, safe: safe)
        let y = geometry.size.height - bottom - clusterHeight / 2
        let x = isLeading
            ? safe.leading + 12 + maxClusterWidth / 2
            : geometry.size.width - safe.trailing - 12 - maxClusterWidth / 2
        return CGPoint(x: x, y: max(safe.top + clusterHeight / 2 + 8, y))
    }
    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .named("sophy.overlay"))
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = sophy.preferences.vertical
                    sophy.noteUserActivity()
                }
                sophy.move(edge: sophy.preferences.edge, vertical: (dragOrigin ?? 0.72) + value.translation.height / max(size.height, 1))
            }
            .onEnded { value in
                sophy.move(edge: value.location.x < size.width / 2 ? "leading" : "trailing", vertical: sophy.preferences.vertical)
                dragOrigin = nil
            }
    }
}

extension SophyContextSource: Identifiable {}
