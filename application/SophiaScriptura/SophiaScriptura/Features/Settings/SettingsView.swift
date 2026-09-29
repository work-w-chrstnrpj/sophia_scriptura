import SwiftUI

struct SettingsView: View {
    @Bindable var reader: ReaderSession
    @Environment(\.colorScheme) private var colorScheme
    @State private var showVersions = false
    private func preference<Value>(_ path: WritableKeyPath<ReaderPreferences,Value>) -> Binding<Value> {
        Binding(get:{ reader.preferences[keyPath:path] },set:{ value in
            var preferences = reader.preferences
            preferences[keyPath:path] = value
            reader.updatePreferences(preferences)
        })
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance presets") {
                    ForEach(ScriptureAppearance.allCases) { appearance in
                        let palette = reader.preferences.palette(for:appearance,colorScheme:colorScheme)
                        Button {
                            var preferences = reader.preferences
                            preferences.appearancePreset = appearance.rawValue
                            reader.updatePreferences(preferences)
                        } label: {
                            HStack(spacing:16) {
                                Text("Aa").font(Font(ScriptureFonts.font(appearance.readingFamily,size:28)))
                                    .frame(width:54,height:54)
                                    .background(Color(palette.paper),in:RoundedRectangle(cornerRadius:12))
                                    .foregroundStyle(Color(palette.ink))
                                    .overlay(RoundedRectangle(cornerRadius:12).stroke(Color(palette.rule)))
                                VStack(alignment:.leading,spacing:5) {
                                    Text(appearance.title).font(.headline)
                                    Text(appearance.readingFamily + " · " + appearance.interfaceFamily)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if reader.preferences.appearance == appearance {
                                    Image(systemName:"checkmark.circle.fill").accessibilityHidden(true)
                                }
                            }.padding(.vertical,4).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("preset." + appearance.rawValue)
                            .accessibilityAddTraits(reader.preferences.appearance == appearance ? [.isSelected] : [])
                    }
                }
                Section("Reading") {
                    Stepper("Text size: \(reader.preferences.sizeStep + 1)",value:preference(\.sizeStep),in:0...8)
                    Picker("Appearance",selection:preference(\.theme)) {
                        Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark")
                    }
                }
                Section("Offline Bible") {
                    Text("World English Bible (WEB)")
                    Text("American English, Protestant edition · eBible.org · Public domain.").foregroundStyle(.secondary)
                    Link("Edition and public-domain notice",destination:URL(string:"https://ebible.org/engwebp/")!)
                }
                Section("Translations") { Button("Manage offline Bibles") { showVersions = true } }
                if let notice = reader.notice { Section("Reader storage") { Text(notice) } }
            }
            .scrollContentBackground(.hidden)
            .background(Color(reader.preferences.palette(for:reader.preferences.appearance,colorScheme:colorScheme).paper).ignoresSafeArea())
            .navigationTitle("Settings")
        }.sheet(isPresented:$showVersions) { ScriptureVersionsView(session:reader) }
    }
}
