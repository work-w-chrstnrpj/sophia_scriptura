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
    @State private var studyAudio = StudyAudioCoordinator()
    @State private var scriptureNarration = ScriptureNarrationSession()
    @StateObject private var studyPiP = StudyPiPPlayer()
    @State private var showStudyPiP = false
    @StateObject private var activityLiveActivity = ActivityLiveActivityCoordinator()
    @StateObject private var sophy = SophySession()
    @StateObject private var meditationJourney = MeditationJourneyCoordinator()
    @StateObject private var shellPreferences = ShellPreferencesSession()
    @StateObject private var userProfile = UserProfileSession()
    @State private var selection: Tab = .scripture
    @State private var showMusicLibrary = false
    @State private var restoreMusicAfterPiP = false
    @State private var shellFABEngagedUntil = Date.distantPast
    @State private var showShellNewCollection = false
    @State private var showShellNoteKindPicker = false
    @State private var reader = ReaderSession(content:BundledScriptureRepository(),state:Self.makeStateStore(),library:MultiSourceTranslationLibrary())
    private static func makeStateStore() -> ReaderStateStore? {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["SP009_TEST_STORE"], let id = UUID(uuidString:raw) {
            return try? ReaderStateStore(storageName:"Reader-test-" + id.uuidString)
        }
        #endif
        return try? ReaderStateStore()
    }
    private var studyPiPState: StudyPiPState {
        StudyPiPState(musicTitle: music.showsNowActiveItem ? music.currentTrack?.title : nil,
                      musicPlaying: music.snapshot.phase == .playing, activity: activity.committedProjection)
    }
    private func syncStudyPiP() {
        studyPiP.setEnabled(shellPreferences.preferences.allowPictureInPicture)
        studyPiP.bind(music: music, activity: activity)
        studyPiP.restore = {
            let musicOnly = activity.committedProjection == nil && music.showsNowActiveItem
            restoreMusicAfterPiP = musicOnly && showStudyPiP
            showStudyPiP = false
            selection = .activity
            if musicOnly && !restoreMusicAfterPiP { showMusicLibrary = true }
            chrome.reveal()
        }
    }
    private var tabAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.42, dampingFraction: 0.9)
    }
    private var shellChromeAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .easeInOut(duration: 0.28)
    }
    private var editingNote: Bool { selection == .notes && notes.selectedNoteID != nil }
    private var sophyIdleQuotesSuspended: Bool {
        if selection == .notes, notes.selectedNoteID != nil { return true }
        if selection == .scripture, annotations.mode != .hidden { return true }
        return false
    }
    private var tabContent: some View {
        GeometryReader { geometry in
                ZStack {
                    ScriptureView(session:reader, narration:scriptureNarration, annotations:annotations, notes:notes, collections:collections, companion:companion, openNote: { id in notes.open(id); selection = .notes; chrome.reveal() }, openCompanion: { selection = .companion; chrome.reveal() }, active: selection == .scripture).tabPresentation(.scripture, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    CollectionsView(
                        store: collections,
                        notes: notes,
                        openNote: { id, collectionID in notes.open(id, from: collectionID); selection = .notes; chrome.reveal() },
                        openPassage: openPassage,
                        openAnnotation: openAnnotation,
                        annotationSnapshot: annotations.loaded ? annotations.snapshot : nil,
                        bookTitleForCode: { code in reader.books.first { $0.id == code }?.title ?? code },
                        openCompanion: { selection = .companion; chrome.reveal() },
                        createConversation: { companion.createConversation() }
                    ).tabPresentation(.collections, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    NotesView(session: notes, reader: reader, collections: collections, isTabActive: selection == .notes)
                        .tabPresentation(.notes, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    CompanionView(session: companion, openNote: { id in notes.open(id); selection = .notes; chrome.reveal() })
                        .tabPresentation(.companion, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    ActivityView(store: activity, sophy: sophy, companion: companion, liveActivityStatus: activityLiveActivity.status, books: reader.books, editionID: reader.edition?.id,
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
                    }, currentReaderLocation: {
                        guard let document = reader.document else { return nil }
                        return (document.book, document.chapter)
                    }).tabPresentation(.activity, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    SettingsView(
                        reader: reader,
                        narration: scriptureNarration,
                        notes: notes,
                        annotations: annotations,
                        collections: collections,
                        companion: companion,
                        activity: activity,
                        music: music,
                        shellPreferences: shellPreferences,
                        userProfile: userProfile,
                        sophy: sophy,
                        showMusicLibrary: $showMusicLibrary
                    )
                        .tabPresentation(.settings, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                }
                .animation(tabAnimation, value:selection)
                .contentMargins(.bottom, editingNote ? 0 : 100, for: .scrollContent)
                .clipped()
        }
    }

    private var shellContent: some View {
        tabContent
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
            SophyChrome(
                sophy: sophy,
                companion: companion,
                collections: collections,
                activity: activity,
                music: music,
                notes: notes,
                books: reader.books,
                referenceSystemID: reader.edition?.referenceSystemID ?? "org.sophia.web.engwebp",
                editionID: reader.edition?.id,
                editionCatalog: sophyEditionCatalog(for: reader),
                scriptureRepositoryProvider: { editionID in try await reader.contentRepository(editionID: editionID) }
            )
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
        .background(ScrollActivityObserver {
            chrome.reveal()
            sophy.noteUserActivity()
        })
        .background(ProtectionWindowObserver(protection: protection, domain: selection == .notes ? .notes : selection == .collections ? .collections : nil))
        .sheet(item: Binding(get: { protection.prompt }, set: { _ in })) { prompt in
            ItemUnlockView(protection: protection, prompt: prompt).id(prompt.id)
        }
        .tint(Color(palette.accent))
        .preferredColorScheme(reader.preferences.theme == "system" ? nil : reader.preferences.theme == "dark" ? .dark : .light)
        .environment(\.appTheme, theme)
        .environment(notes)
        .environmentObject(userProfile)
    }

    private var studyLifecycleContent: some View {
        shellContent
        .onAppear {
            sophy.setIdleQuotesSuspended(sophyIdleQuotesSuspended)
            notes.collections = collections
            notes.onSophyEnhance = { selection in
                sophy.syncRoute(companion)
                sophy.stageEnhancement(selection)
            }
            sophy.onOpenQuiz = { selection = .companion; chrome.reveal() }
            sophy.onOpenContemplation = { selection = .activity; chrome.reveal() }
            sophy.onOpenActivity = { selection = .activity; chrome.reveal() }
            sophy.onOpenChat = { selection = .companion; chrome.reveal() }
            sophy.onOpenScripture = { request in
                selection = .scripture
                chrome.reveal()
                Task {
                    if let abbreviation = request.editionAbbreviation,
                       let editionID = reader.editionID(matchingAbbreviation: abbreviation) {
                        await reader.selectEdition(editionID)
                    }
                    await reader.navigate(
                        book: request.book,
                        chapter: request.chapter,
                        verse: request.verse,
                        emphasis: [request.verse]
                    )
                }
            }
            sophy.onOpenSource = { id, isCollection in
                if isCollection { selection = .collections; collections.sophyOpenCollectionID = id }
                else { notes.open(id); selection = .notes }
                chrome.reveal()
            }
            protection.willLock = { domains in
                if domains.contains(.notes) { notes.concealProtectedNote() }
                else { notes.flushSurface?(); Task { await notes.save() } }
                collections.objectWillChange.send()
                sophy.concealSensitive()
            }
            companion.onCollectionsSync = { collections.upsertCompanionConversation($0) }
            companion.onCollectionsRemove = { collections.removeCompanionConversation($0) }
            music.load()
            shellPreferences.load()
            studyAudio.narration = scriptureNarration
            music.attachStudyAudio(studyAudio)
            scriptureNarration.bind(music: music, reader: reader)
        }
        .task { await notes.load(); await collections.load(); await companion.load();
            let activeIDs = Set(companion.activeConversations.map(\.id))
            for conversation in collections.conversations where !activeIDs.contains(conversation.id) { collections.removeCompanionConversation(conversation.id) }
            await activity.load(); activity.importQuizStudyLinks(companion.reviewingLinks)
            activityLiveActivity.reconcile(projection: activity.committedProjection, sceneActive: scenePhase == .active)
            await sophy.load(collections: collections, activity: activity, recoveredOlderGeneration: collections.recoveredOlderGeneration || activity.recoveredOlderGeneration) }
        .onChange(of: activity.committedProjection) { _, projection in
            activityLiveActivity.reconcile(projection: projection, sceneActive: scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { sophy.concealSensitive() }
            activityLiveActivity.reconcile(projection: activity.committedProjection, sceneActive: phase == .active)
        }
        .onChange(of: studyPiPState) { _, _ in syncStudyPiP() }
        .onAppear { syncStudyPiP() }
        .onChange(of: shellPreferences.preferences.allowPictureInPicture) { _, enabled in
            if !enabled {
                restoreMusicAfterPiP = false
                showStudyPiP = false
            }
            studyPiP.setEnabled(enabled)
        }
        .sheet(isPresented: $showStudyPiP, onDismiss: {
            if restoreMusicAfterPiP {
                restoreMusicAfterPiP = false
                showMusicLibrary = true
            }
        }) {
            StudyPiPSheet(player: studyPiP, controlLabel: studyPiPState.controlLabel)
        }
        .onOpenURL { url in
            _ = SystemControlsRouting.openActivityTab(from: url) {
                selection = .activity
                chrome.reveal()
            }
        }
    }

    var body: some View {
        studyLifecycleContent
        .onChange(of: companion.resolvedSharedRoute()) { _, _ in sophy.syncRoute(companion) }
        .onChange(of: notes.snapshot.notes) { _, _ in sophy.privacyChanged(collections: collections, notes: notes) }
        .onChange(of: collections.collections) { _, _ in sophy.privacyChanged(collections: collections, notes: notes) }
        .onChange(of: collections.memberships) { _, _ in sophy.privacyChanged(collections: collections, notes: notes) }
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
        .onChange(of: selection) { _, _ in
            sophy.noteUserActivity()
            sophy.setIdleQuotesSuspended(sophyIdleQuotesSuspended)
        }
        .onChange(of: notes.selectedNoteID) { _, _ in
            sophy.noteUserActivity()
            sophy.setIdleQuotesSuspended(sophyIdleQuotesSuspended)
        }
        .onChange(of: annotations.mode) { _, _ in
            sophy.noteUserActivity()
            sophy.setIdleQuotesSuspended(sophyIdleQuotesSuspended)
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
            if shellPreferences.preferences.allowPictureInPicture && studyPiPState.hasContent && !editingNote {
                Button { syncStudyPiP(); showStudyPiP = true } label: { Image(systemName: "pip.enter").padding(12) }
                    .background(.regularMaterial, in: Capsule()).accessibilityLabel("Floating Player").accessibilityIdentifier("study.pip.open")
                    .padding(.trailing, 12)
            }
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

    private func sophyEditionCatalog(for reader: ReaderSession) -> String {
        var entries: [String] = []
        if let edition = reader.edition {
            entries.append("\(edition.abbreviation.uppercased())=\(edition.id)")
        }
        for status in reader.translations {
            entries.append("\(status.translation.abbreviation.uppercased())=\(status.translation.editionID)")
        }
        for status in reader.helloAOEditions where status.isAvailable {
            entries.append("\(status.eligible.abbreviation.uppercased())=\(status.appEditionID)")
        }
        return entries.joined(separator: "; ")
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

    private func openAnnotation(_ saved: SavedAnnotation) {
        selection = .scripture
        chrome.reveal()
        Task {
            if reader.edition?.id != saved.source.editionID {
                await reader.selectEdition(saved.source.editionID)
            }
            await reader.navigate(book: saved.source.book, chapter: saved.source.chapter)
            await annotations.open(reader.document)
            guard let document = reader.document else { return }
            await annotations.activateSavedLayer(groupID: saved.groupID, layerID: saved.id, document: document, reader: reader)
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
                    .contentShape(Rectangle())
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
