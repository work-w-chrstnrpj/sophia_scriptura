import SwiftUI

struct SettingsView: View {
    @Bindable var reader: ReaderSession
    var notes: NotesSession
    var annotations: AnnotationSession
    @ObservedObject var collections: CollectionsStore
    @ObservedObject var companion: CompanionSession
    @ObservedObject var activity: ActivityStore
    @ObservedObject var music: MusicSession
    @ObservedObject var shellPreferences: ShellPreferencesSession
    @Binding var showMusicLibrary: Bool
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var showVersions = false

    private func preference<Value>(_ path: WritableKeyPath<ReaderPreferences, Value>) -> Binding<Value> {
        Binding(get: { reader.preferences[keyPath: path] }, set: { value in
            var preferences = reader.preferences
            preferences[keyPath: path] = value
            reader.updatePreferences(preferences)
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    LibraryHeaderTitle(title: "Settings")
                        .accessibilityIdentifier("settings.title")

                    appearanceSection
                    readingSection
                    offlineSection
                    translationsSection
                    providerSection
                    musicSection
                    shellSection
                    archiveSection
                    backupSection
                    if let notice = reader.notice {
                        settingsCard {
                            Text(notice)
                                .font(.footnote)
                                .foregroundStyle(Color(theme.palette.secondary))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("settings.content")
            .appSurface()
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showVersions) { ScriptureVersionsView(session: reader) }
    }

    private var shellSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Tab shortcuts")
                Text("Add Collection, Add Note, Start Conversation, and Start Activity appear above the tab bar on their tabs.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                Toggle("Show Add and Start buttons", isOn: Binding(
                    get: { shellPreferences.preferences.showTabActionButtons },
                    set: { shellPreferences.setShowTabActionButtons($0) }
                ))
                .accessibilityIdentifier("settings.shellTabActionsVisible")
            }
        }
    }

    private var musicSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Background music")
                Text("Instrumental study tracks play only after you press Play. They continue across tabs and while the iPad is locked.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                Toggle("Show music button", isOn: Binding(
                    get: { music.preferences.showFloatingControl },
                    set: { music.setShowFloatingControl($0) }
                ))
                .accessibilityIdentifier("settings.musicFabVisible")
                if !music.preferences.showFloatingControl {
                    BackgroundMusicInlineControls(session: music) { showMusicLibrary = true }
                }
                NavigationLink {
                    BackgroundMusicLibraryView(session: music)
                } label: {
                    settingsLinkRow("Choose track")
                }
                .accessibilityIdentifier("settings.musicLibrary")
                if let error = music.loadError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var archiveSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Archive")
                Text("Browse archived notes, collections, and Companion conversations in one place.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                NavigationLink {
                    SettingsArchiveHubView(notes: notes, collections: collections, companion: companion)
                } label: {
                    settingsLinkRow("Open archive")
                }
                .accessibilityIdentifier("settings.archive")
            }
        }
    }

    private var backupSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Backup data")
                SettingsStudyBackupSection(
                    reader: reader,
                    notes: notes,
                    annotations: annotations,
                    activity: activity,
                    collections: collections,
                    companion: companion
                )
            }
        }
    }

    private var appearanceSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeading("Appearance presets")
                ForEach(ScriptureAppearance.allCases) { appearance in
                    let palette = reader.preferences.palette(for: appearance, colorScheme: colorScheme)
                    let selected = reader.preferences.appearance == appearance
                    Button {
                        var preferences = reader.preferences
                        preferences.appearancePreset = appearance.rawValue
                        reader.updatePreferences(preferences)
                    } label: {
                        HStack(spacing: 16) {
                            Text("Aa")
                                .font(Font(ScriptureFonts.font(appearance.readingFamily, size: 28)))
                                .frame(width: 54, height: 54)
                                .background(Color(palette.paper), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Color(palette.ink))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(palette.rule)))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(appearance.title).font(.headline)
                                    .foregroundStyle(Color(theme.palette.ink))
                                Text(appearance.readingFamily + " · " + appearance.interfaceFamily)
                                    .font(.caption)
                                    .foregroundStyle(Color(theme.palette.secondary))
                            }
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(theme.palette.accent))
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selected ? Color(theme.palette.accent).opacity(0.12) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selected ? Color(theme.palette.accent).opacity(0.55) : Color.clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("preset." + appearance.rawValue)
                    .accessibilityAddTraits(reader.preferences.appearance == appearance ? [.isSelected] : [])
                }
            }
        }
    }

    private var readingSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeading("Reading")
                Stepper("Text size: \(reader.preferences.sizeStep + 1)", value: preference(\.sizeStep), in: 0...8)
                    .foregroundStyle(Color(theme.palette.ink))
                Picker("Appearance", selection: preference(\.theme)) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.theme")
            }
        }
    }

    private var offlineSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeading("Offline Bible")
                Text("World English Bible (WEB)")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
                Text("American English, Protestant edition · eBible.org · Public domain.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                Link("Edition and public-domain notice", destination: URL(string: "https://ebible.org/engwebp/")!)
                    .font(.subheadline)
            }
        }
    }

    private var translationsSection: some View {
        settingsCard {
            Button("Manage offline Bibles") { showVersions = true }
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(theme.palette.accent))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var providerSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Provider keys")
                NavigationLink {
                    CompanionProviderSettingsView(session: companion)
                } label: {
                    settingsLinkRow("Companion providers and models")
                }
                .accessibilityIdentifier("settings.companionProviders")
                NavigationLink {
                    CompanionQuizSettingsView(session: companion)
                } label: {
                    settingsLinkRow("Quiz Me defaults")
                }
                .accessibilityIdentifier("settings.quizDefaults")
            }
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(.title3, design: .serif).weight(.semibold))
            .foregroundStyle(Color(theme.palette.ink))
    }

    private func settingsLinkRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color(theme.palette.ink))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(theme.palette.secondary))
        }
        .padding(.vertical, 4)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(theme.palette.rule), lineWidth: 1))
    }
}
