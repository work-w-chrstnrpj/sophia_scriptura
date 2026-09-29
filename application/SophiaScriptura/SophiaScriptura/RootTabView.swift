import SwiftUI

/// An accessible bottom container keeps the six destinations at the bottom on iPadOS 18+.
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
    private var palette: ReaderPalette { reader.preferences.palette(for:reader.preferences.appearance,colorScheme:colorScheme) }
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
    var body: some View {
        ZStack {
            ScriptureView(session:reader).tabVisibility(selection == .scripture)
            CollectionsView().tabVisibility(selection == .collections)
            NotesView().tabVisibility(selection == .notes)
            CompanionView().tabVisibility(selection == .companion)
            ActivityView().tabVisibility(selection == .activity)
            SettingsView(reader:reader).tabVisibility(selection == .settings)
        }
        .background(Color(palette.paper).ignoresSafeArea())
        .safeAreaInset(edge:.bottom,spacing:0) {
            ViewThatFits(in:.horizontal) {
                tabButtons(compact:false)
                tabButtons(compact:true)
            }
            .padding(6).frame(maxWidth:740)
            .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:28,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:28,style:.continuous).stroke(Color(palette.ink).opacity(0.18),lineWidth:1))
            .shadow(color:.black.opacity(0.06),radius:12,y:4)
            .padding(.horizontal,16).padding(.vertical,10)
            .frame(maxWidth:.infinity)
            .background(.clear)
        }
        .tint(Color(palette.accent))
        .preferredColorScheme(reader.preferences.appearance == .midnightLibrary ? .dark : reader.preferences.theme == "system" ? nil : reader.preferences.theme == "dark" ? .dark : .light)
    }
    private func tabButtons(compact: Bool) -> some View {
        HStack(spacing:0) {
            ForEach(Tab.allCases,id:\.self) { tab in
                Button { reader.save(); selection = tab } label: {
                    VStack(spacing:4) {
                        Image(systemName:tab.icon).font(.system(size:20))
                        if !compact { Text(tab.rawValue).font(.caption).lineLimit(1).fixedSize() }
                    }.frame(maxWidth:.infinity,minHeight:44).padding(.horizontal,compact ? 4 : 12)
                    .padding(.vertical,4)
                    .background(selection == tab ? Color(palette.ink).opacity(0.10) : .clear,in:RoundedRectangle(cornerRadius:22,style:.continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == tab ? Color(palette.ink) : Color(palette.secondary))
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
                .accessibilityIdentifier("tab.\(tab.rawValue.lowercased())")
            }
        }
    }
}

private extension View {
    func tabVisibility(_ visible: Bool) -> some View {
        opacity(visible ? 1 : 0).allowsHitTesting(visible).accessibilityHidden(!visible)
    }
}
