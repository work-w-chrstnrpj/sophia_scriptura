import SwiftUI

/// Keeps destinations mounted while the shell animates navigation and its quiet tab dock.
struct RootTabView: View {
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
        AppTheme(appearance: reader.preferences.appearance, dark: reader.preferences.appearance == .midnightLibrary || reader.preferences.theme == "dark" || (reader.preferences.theme == "system" && colorScheme == .dark))
    }
    private var palette: ReaderPalette { theme.palette }
    @State private var annotations = AnnotationSession()
    @State private var notes = NotesSession()
    @State private var selection: Tab = .scripture
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
    private var editingNote: Bool { selection == .notes && notes.selectedNoteID != nil }
    var body: some View {
        GeometryReader { geometry in
                ZStack {
                    ScriptureView(session:reader, annotations:annotations, notes:notes, openNote: { id in notes.open(id); selection = .notes; chrome.reveal() }, active: selection == .scripture).tabPresentation(.scripture, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    CollectionsView().tabPresentation(.collections, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    NotesView(session: notes, reader: reader).tabPresentation(.notes, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    CompanionView().tabPresentation(.companion, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    ActivityView().tabPresentation(.activity, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                    SettingsView(reader:reader).tabPresentation(.settings, selection:selection, width:geometry.size.width, reduceMotion:reduceMotion)
                }
                .animation(tabAnimation, value:selection)
                .contentMargins(.bottom, editingNote ? 0 : 100, for: .scrollContent)
                .clipped()
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .overlay(alignment: .bottom) { navigationDock.fixedSize(horizontal: false, vertical: true).padding(.bottom, 12) }
        .background(Color(palette.paper).ignoresSafeArea())
        .background(ScrollActivityObserver { chrome.reveal() })
        .tint(Color(palette.accent))
        .preferredColorScheme(reader.preferences.appearance == .midnightLibrary ? .dark : reader.preferences.theme == "system" ? nil : reader.preferences.theme == "dark" ? .dark : .light)
        .environment(\.appTheme, theme)
        .environment(notes)
        .task { await notes.load() }
        .onChange(of: selection) { _, tab in notes.active = tab == .notes; if tab != .notes { notes.flushSurface?(); Task { await notes.save() } } }
        .onAppear { chrome.reveal() }
        .onDisappear { chrome.stop() }
        .onChange(of:scenePhase) { _, phase in
            annotations.active = phase == .active && selection == .scripture
            notes.active = phase == .active && selection == .notes
            if phase == .active { chrome.reveal() }
            else { chrome.stop() }
        }
    }
    private var navigationDock: some View {
        ZStack {
            ViewThatFits(in:.horizontal) {
                tabButtons(compact:false)
                tabButtons(compact:true)
            }
            .padding(6).frame(maxWidth:740)
            .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:28,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:28,style:.continuous).stroke(Color(palette.ink).opacity(0.18),lineWidth:1))
            .shadow(color:.black.opacity(0.06),radius:12,y:4)
            .padding(.horizontal,16).padding(.vertical,10)
            .opacity(chrome.isVisible ? 1 : 0)
            .offset(y:reduceMotion || chrome.isVisible ? 0 : 22)
            .allowsHitTesting(chrome.isVisible)
            .accessibilityHidden(!chrome.isVisible)

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
        // Navigation floats over every tab and never changes the content frame.
        .frame(maxWidth:.infinity)
        .animation(reduceMotion ? .easeOut(duration:0.16) : .easeInOut(duration:0.28), value:chrome.isVisible)
    }
    private func tabButtons(compact: Bool) -> some View {
        HStack(spacing:0) {
            ForEach(Tab.allCases,id:\.self) { tab in
                Button {
                    Task {
                        if annotations.loaded {
                            await annotations.transition { reader.save(); chrome.reveal(); selection = tab; annotations.active = tab == .scripture }
                        } else { reader.save(); chrome.reveal(); selection = tab; annotations.active = tab == .scripture }
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
