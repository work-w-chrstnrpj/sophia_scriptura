import SwiftUI

/// Keeps destinations mounted while the shell animates navigation and its quiet tab dock.
struct RootTabView: View {
    private static var tabDockMaxWidth: CGFloat { ShellChromeLayout.tabDockMaxWidth }
    private static var tabDockHorizontalInset: CGFloat { ShellChromeLayout.tabDockHorizontalInset }

    enum Tab: String, CaseIterable, Hashable {
        case scripture = "Scripture", collections = "Collections", notes = "Notes"
        case companion = "Companion", activity = "Activity", settings = "Settings"
        var icon: String {
            switch self {
            case .scripture: "book"
            case .collections: "folder"
            case .notes: "note.text"
            case .companion: "bubble.left.and.bubble.right"
            case .activity: "chart.bar"
            case .settings: "gearshape"
            }
        }
    }
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var selectionGlow
    @State private var chrome = ShellChromeState()
    private var theme: AppTheme {
        AppTheme(appearance: reader.preferences.appearance, dark: reader.preferences.theme == "dark" || (reader.preferences.theme == "system" && colorScheme == .dark))
    }
    private var palette: ReaderPalette { theme.palette }
    @State private var annotations = AnnotationSession()
    @State private var notes = NotesSession()
    @ObservedObject private var protection = ItemProtectionSession.shared
    @StateObject private var collections = CollectionsStore(repository: CollectionsFileRepository(directory: CollectionsFileRepository.defaultDirectory()))
    @StateObject private var companion = CompanionSession.live()
    @StateObject private var activity = ActivityStore()
    @StateObject private var music = MusicSession()
    @StateObject private var meditationJourney = MeditationJourneyCoordinator()
    @StateObject private var shellPreferences = ShellPreferencesSession()
    @StateObject private var userProfile = UserProfileSession()
    @State private var selection: Tab = .scripture
    @State private var showMusicLibrary = false
    @State private var shellFABEngagedUntil = Date.distantPast
    @State private var showShellNewCollection = false
    @State private var showShellNoteKindPicker = false
    @State private var reader = ReaderSession(content:BundledScriptureRepository(),state:Self.makeStateStore(),library:OfflineTranslationLibrary())
    private static func makeStateStore() -> ReaderStateStore? {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["SP009_TEST_STORE"], let id = UUID(uuidString:raw) {
            return try? ReaderStateStore(storageName:"Reader-test-" + id.uuidString)
        }
        #endif
        return try? ReaderStateStore()
    }
    private var tabAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.42, dampingFraction: 0.9)
    }
    private var shellChromeAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .easeInOut(duration: 0.28)
    }
    private var editingNote: Bool { selection == .notes && notes.selectedNoteID != nil }
    var body: some View {
        GeometryReader { geometry in
                ZStack {
                    ScriptureView(session:reader, annotations:annotations, notes:notes, collections:collections, companion:companion, openNote: { id in notes.open(id); selection = .notes; chrome.reveal() }, openCompanion: { selection = .companion; chrome.reveal() }, active: selection == .scripture).tabPresentation(.scripture, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    CollectionsView(store:collections, notes:notes, openNote: { id, collectionID in notes.open(id, from: collectionID); selection = .notes; chrome.reveal() }, openPassage: openPassage, openCompanion: { selection = .companion; chrome.reveal() }, createConversation: { companion.createConversation() }).tabPresentation(.collections, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    NotesView(session: notes, reader: reader, collections: collections, isTabActive: selection == .notes)
                        .tabPresentation(.notes, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    CompanionView(session: companion, openNote: { id in notes.open(id); selection = .notes; chrome.reveal() })
                        .tabPresentation(.companion, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    ActivityView(store: activity, books: reader.books, editionID: reader.edition?.id,
                                 referenceSystemID: reader.edition?.referenceSystemID ?? "org.sophia.web.engwebp", startReading: { verse in
                        selection = .scripture
                        chrome.reveal()
                        Task {
                            await reader.navigate(book: verse.book, chapter: verse.chapter, verse: verse.verse, emphasis: [verse.verse])
                            let navigation = reader.navigationID
                            try? await Task.sleep(for: .seconds(3))
                            reader.clearTemporaryEmphasis(ifNavigationID: navigation)
                        }
                    }, beginMeditationJourney: { launch in
                        meditationJourney.begin(
                            launch: launch,
                            books: reader.books,
                            repositoryProvider: { editionID in try await reader.contentRepository(editionID: editionID) }
                        )
                    }, availableVerses: { book, chapter, editionID in
                        try await reader.availableVerses(book: book, chapter: chapter, editionID: editionID)
                    }).tabPresentation(.activity, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    SettingsView(
                        reader: reader,
                        notes: notes,
                        annotations: annotations,
                        collections: collections,
                        companion: companion,
                        activity: activity,
                        music: music,
                        shellPreferences: shellPreferences,
                        userProfile: userProfile,
                        showMusicLibrary: $showMusicLibrary
                    )
                        .tabPresentation(.settings, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                }
                .animation(tabAnimation, value:selection)
                .contentMargins(.bottom, editingNote ? 0 : 100, for: .scrollContent)
                .clipped()
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(isPresented: $showShellNoteKindPicker) {
            NoteCreatorSheet(notes: notes) { id in
                selection = .notes
                chrome.reveal()
                notes.open(id)
            }
        }
        .overlay {
            if meditationJourney.isActive {
                MeditationJourneyView(coordinator: meditationJourney)
            }
        }
        .overlay {
            if let draft = activity.draft {
                ActivityFloatingRecorder(
                    draft: draft,
                    fabEngagedUntil: $shellFABEngagedUntil,
                    pauseOrResume: {
                        if activity.draft?.runningSince == nil { activity.resume() } else { activity.pause() }
                    },
                    finish: {
                        selection = .activity
                        chrome.reveal()
                        activity.requestFinish()
                    }
                )
                .shellFABEngagementOpacity(engagedUntil: $shellFABEngagedUntil)
            }
        }
        .overlay(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                if !meditationJourney.isActive {
                    navigationDock.fixedSize(horizontal: false, vertical: true)
                }
                shellFABRow
                    .padding(.bottom, shellFABBottomPadding)
            }
            .padding(.bottom, 12)
            .animation(shellChromeAnimation, value: chrome.isVisible)
        }
        .sheet(isPresented: $showMusicLibrary) {
            NavigationStack {
                BackgroundMusicLibraryView(session: music)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showShellNewCollection) {
            CollectionEditorSheet(store: collections, parentID: nil)
        }
        .background(Color(palette.paper).ignoresSafeArea())
        .background(ScrollActivityObserver { chrome.reveal() })
        .background(ProtectionWindowObserver(protection: protection, domain: selection == .notes ? .notes : selection == .collections ? .collections : nil))
        .sheet(item: Binding(get: { protection.prompt }, set: { _ in })) { prompt in
            ItemUnlockView(protection: protection, prompt: prompt).id(prompt.id)
        }
        .tint(Color(palette.accent))
        .preferredColorScheme(reader.preferences.theme == "system" ? nil : reader.preferences.theme == "dark" ? .dark : .light)
        .environment(\.appTheme, theme)
        .environment(notes)
        .environmentObject(userProfile)
        .onAppear {
            notes.collections = collections
            protection.willLock = { domains in
                if domains.contains(.notes) { notes.concealProtectedNote() }
                else { notes.flushSurface?(); Task { await notes.save() } }
                collections.objectWillChange.send()
            }
            companion.onCollectionsSync = { collections.upsertCompanionConversation($0) }
            companion.onCollectionsRemove = { collections.removeCompanionConversation($0) }
            music.load()
            shellPreferences.load()
        }
        .task { await notes.load(); await collections.load(); await companion.load();
            let activeIDs = Set(companion.activeConversations.map(\.id))
            for conversation in collections.conversations where !activeIDs.contains(conversation.id) { collections.removeCompanionConversation(conversation.id) }
            await activity.load(); activity.importQuizStudyLinks(companion.reviewingLinks) }
        .onChange(of: companion.reviewingLinks) { _, links in activity.importQuizStudyLinks(links) }
        .onChange(of: activity.draft) { _, value in
            if value == nil { activity.importQuizStudyLinks(companion.reviewingLinks) }
            if value?.modeID == ActivityModeID.meditating.id, (value?.guidedWorkflow ?? true), !music.preferences.showFloatingControl {
                music.setShowFloatingControl(true)
            }
        }
        .onChange(of: companion.panelExpandedToTab) { _, expanded in
            if expanded { selection = .companion; chrome.reveal(); companion.panelExpandedToTab = false }
        }
        .onChange(of: selection) { _, tab in
            notes.active = tab == .notes
            if tab != .notes {
                notes.toolsVisible = false
                notes.toolsRequest = UUID()
                notes.flushSurface?()
                Task { await notes.save() }
            }
        }
        .onAppear { chrome.reveal() }
        .onDisappear { chrome.stop() }
        .onChange(of:scenePhase) { _, phase in
            protection.sceneActive(phase == .active, background: phase == .background)
            annotations.active = phase == .active && selection == .scripture
            notes.active = phase == .active && selection == .notes
            if phase == .active { chrome.reveal(); activity.pruneExpiredReminders() }
            else { chrome.stop(); Task { await collections.flush(); await companion.flush(); await activity.flush() } }
        }
    }
    private var shellFABBottomPadding: CGFloat {
        guard !meditationJourney.isActive, chrome.isVisible else { return 0 }
        return ShellChromeLayout.shellFABBottomPaddingWhenTabsVisible
    }

    /// Keeps music and Start Activity aligned with the tab dock’s width and horizontal inset.
    @ViewBuilder
    private var shellFABRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if !editingNote && music.preferences.showFloatingControl {
                BackgroundMusicFloatingControl(session: music, showLibrary: $showMusicLibrary, fabEngagedUntil: $shellFABEngagedUntil)
                    .shellFABEngagementOpacity(engagedUntil: $shellFABEngagedUntil)
            }
            Spacer(minLength: 12)
            tabSpecificShellFAB
        }
        .frame(maxWidth: Self.tabDockMaxWidth)
        .padding(.horizontal, Self.tabDockHorizontalInset)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var tabSpecificShellFAB: some View {
        if editingNote || !shellPreferences.preferences.showTabActionButtons { EmptyView() }
        else if selection == .collections {
            shellCapsuleFAB(title: "Add Collection", systemImage: "folder.badge.plus", id: "shell.addCollection") {
                showShellNewCollection = true
            }
        } else if selection == .notes, notes.loaded {
            shellCapsuleFAB(title: "Add Note", systemImage: "note.text.badge.plus", id: "shell.addNote") {
                showShellNoteKindPicker = true
            }
        } else if selection == .companion, companion.activeConversations.isEmpty {
            shellCapsuleFAB(title: "Start Conversation", systemImage: "square.and.pencil", id: "shell.startConversation") {
                _ = companion.createConversation()
            }
        } else if selection == .activity, activity.isReady, activity.draft == nil, !meditationJourney.isActive {
            shellCapsuleFAB(title: "Start Activity", systemImage: "play.fill", id: "activity.start") {
                activity.requestStart()
            }
        }
    }

    private func shellCapsuleFAB(title: String, systemImage: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 20)
                .frame(height: 56)
                .foregroundStyle(Color(palette.paper))
                .background(Color(palette.accent), in: Capsule())
                .shadow(color: Color(palette.ink).opacity(0.18), radius: 12, y: 5)
        }
        .accessibilityIdentifier(id)
    }

    private func openPassage(_ passage: SavedPassage) {
        selection = .scripture
        chrome.reveal()
        Task {
            if reader.edition?.id != passage.editionID {
                await reader.selectEdition(passage.editionID)
            }
            await reader.navigate(book: passage.bookID, chapter: passage.chapter, verse: passage.startVerse, spans: passage.spans)
        }
    }
    private var navigationDock: some View {
        ZStack {
            ViewThatFits(in:.horizontal) {
                tabButtons(compact:false)
                tabButtons(compact:true)
            }
            .padding(6).frame(maxWidth: Self.tabDockMaxWidth)
            .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:28,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:28,style:.continuous).stroke(Color(palette.ink).opacity(0.18),lineWidth:1))
            .shadow(color:.black.opacity(0.06),radius:12,y:4)
            .padding(.horizontal, Self.tabDockHorizontalInset).padding(.vertical, 10)
            .opacity(chrome.isVisible ? 1 : 0)
            .offset(y:reduceMotion || chrome.isVisible ? 0 : 22)
            .allowsHitTesting(chrome.isVisible)
            .accessibilityHidden(!chrome.isVisible)
            .gesture(tabDockSwipeToHide)

            if !chrome.isVisible {
                Button { chrome.reveal() } label: {
                    Capsule().fill(Color(palette.secondary).opacity(0.65))
                        .frame(width:28,height:4).frame(width:64,height:44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show tab menu")
                .accessibilityIdentifier("navigation.showTabs")
                .transition(.opacity)
            }
        }
        .frame(maxWidth:.infinity)
        .animation(shellChromeAnimation, value:chrome.isVisible)
    }

    private var tabDockSwipeToHide: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onEnded { value in
                guard chrome.isVisible else { return }
                guard value.translation.height > 20,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                if reduceMotion {
                    chrome.hideImmediately()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        chrome.hideImmediately()
                    }
                }
            }
    }

    private func tabButtons(compact: Bool) -> some View {
        HStack(spacing:0) {
            ForEach(Tab.allCases,id:\.self) { tab in
                Button {
                    Task {
                        chrome.reveal()
                        let leavingScripture = selection == .scripture && tab != .scripture
                        if leavingScripture, annotations.loaded {
                            _ = await annotations.prepareForNavigation()
                        }
                        reader.save()
                        selection = tab
                        annotations.active = tab == .scripture
                    }
                } label: {
                    VStack(spacing:4) {
                        Image(systemName:tab.icon).font(.system(size:20))
                            .shadow(color:Color(palette.accent).opacity(selection == tab && !reduceMotion ? 0.3 : 0),radius:5)
                        if !compact { Text(tab.rawValue).font(.caption).lineLimit(1).fixedSize() }
                    }.frame(maxWidth:.infinity,minHeight:44).padding(.horizontal,compact ? 4 : 12)
                    .padding(.vertical,4)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius:22,style:.continuous)
                                .fill(Color(palette.accent).opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius:22,style:.continuous)
                                    .stroke(Color(palette.accent).opacity(0.28),lineWidth:1))
                                .shadow(color:Color(palette.accent).opacity(reduceMotion ? 0 : 0.24),radius:10)
                                .matchedGeometryEffect(id:reduceMotion ? "\(compact)-\(tab.rawValue)" : (compact ? "activeCompactTab" : "activeTab"),in:selectionGlow)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == tab ? Color(palette.ink) : Color(palette.secondary))
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
                .accessibilityIdentifier("tab.\(tab.rawValue.lowercased())")
            }
        }.animation(tabAnimation, value:selection)
    }
}

private extension View {
    func tabPresentation(_ tab: RootTabView.Tab, selection: RootTabView.Tab, width: CGFloat, reduceMotion: Bool) -> some View {
        let visible = tab == selection
        let index = RootTabView.Tab.allCases.firstIndex(of:tab) ?? 0
        let selectedIndex = RootTabView.Tab.allCases.firstIndex(of:selection) ?? 0
        let offset = reduceMotion || visible ? 0 : (index < selectedIndex ? -width : width)
        return opacity(visible ? 1 : 0)
            .offset(x:offset)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}
