import SwiftUI

struct SettingsView: View {
    @Bindable var reader: ReaderSession
    @Bindable var narration: ScriptureNarrationSession
    var notes: NotesSession
    var annotations: AnnotationSession
    @ObservedObject var collections: CollectionsStore
    @ObservedObject var companion: CompanionSession
    @ObservedObject var activity: ActivityStore
    @ObservedObject var music: MusicSession
    @ObservedObject var shellPreferences: ShellPreferencesSession
    @ObservedObject var userProfile: UserProfileSession
    @ObservedObject var sophy: SophySession
    @Binding var showMusicLibrary: Bool
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var showTranslationDownloads = false
    @StateObject private var settingsToast = SettingsToastCenter()

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

                    profileSection
                    ladyWisdomSection
                    appearanceSection
                    readingSection
                    offlineSection
                    scriptureAudioSection
                    translationsSection
                    providerSection
                    musicSection
                    pictureInPictureSection
                    shellSection
                    protectionSection
                    archiveSection
                    trashSection
                    deleteDataSection
                    backupSection
                    aboutSection
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
        .environmentObject(settingsToast)
        .overlay(alignment: .topTrailing) {
            SettingsTransientToast(message: settingsToast.message)
                .animation(.easeOut(duration: 0.2), value: settingsToast.message)
        }
        .sheet(isPresented: $showTranslationDownloads) {
            NavigationStack {
                ScriptureTranslationDownloadsView(session: reader, narration: narration)
            }
        }
    }

    private var profileSection: some View {
        settingsCard {
            NavigationLink {
                SettingsUserProfileView(userProfile: userProfile)
            } label: {
                HStack(spacing: 14) {
                    settingsProfileAvatar(size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profileSectionTitle)
                            .font(.headline)
                            .foregroundStyle(Color(theme.palette.ink))
                        Text("Name, birthday, church, and photo")
                            .font(.footnote)
                            .foregroundStyle(Color(theme.palette.secondary))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(theme.palette.secondary))
                }
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("settings.profile")
        }
    }

    private var profileSectionTitle: String {
        let name = userProfile.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Your profile" : name
    }

    @ViewBuilder
    private func settingsProfileAvatar(size: CGFloat) -> some View {
        Group {
            if let image = userProfile.profilePhoto {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(theme.palette.secondary))
                    .padding(size * 0.12)
                    .background(Color(theme.palette.paper))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(theme.palette.rule), lineWidth: 1))
        .accessibilityHidden(true)
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

    private var protectionSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Protection")
                ProtectionSettingsSection(
                    notesProtected: notes.snapshot.notes.contains { $0.protectionID != nil },
                    collectionsProtected: collections.collections.contains { $0.protectionID != nil && !$0.isUnfiled }
                )
            }
        }
    }

    private var pictureInPictureSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Floating Player")
                Toggle("Allow Picture in Picture", isOn: Binding(
                    get: { shellPreferences.preferences.allowPictureInPicture },
                    set: { shellPreferences.setAllowPictureInPicture($0) }
                ))
                .accessibilityIdentifier("settings.allowPictureInPicture")
                Text("Show music and Activity in a floating player when you open PiP. Turning this off closes the floating player; music and Activity continue.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
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
                Text("Browse archived notes, collections, and Companion conversations. Unarchive to return them to your library.")
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

    private var trashSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Trash")
                Text("Deleted items stay for \(TrashRetention.dayCount) days. Restore them or delete permanently before auto-removal.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                NavigationLink {
                    SettingsTrashHubView(notes: notes, collections: collections, companion: companion)
                } label: {
                    settingsLinkRow("Open trash")
                }
                .accessibilityIdentifier("settings.trash")
            }
        }
    }

    private var deleteDataSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Delete data")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(.red)
                Text("Permanently clear notes, collections, conversations, quiz history, reminders, activity history, bookmarks, gleanings, and links on this iPad.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                NavigationLink {
                    SettingsDeleteDataHubView(
                        notes: notes,
                        collections: collections,
                        companion: companion,
                        activity: activity,
                        sophy: sophy
                    )
                } label: {
                    HStack {
                        Text("Open delete data")
                            .foregroundStyle(.red)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(theme.palette.secondary))
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("settings.delete")
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
                    companion: companion,
                    sophy: sophy
                )
            }
        }
    }

    private var ladyWisdomSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Turn on Companion Character", isOn: Binding(
                    get: { sophy.preferences.enabled },
                    set: { sophy.setEnabled($0) }
                ))
                .accessibilityIdentifier("settings.sophy.enabled")
                Text("Your study companion stays off until you turn this on. They use the same default provider and model as new Companion chats.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                Picker("Companion", selection: Binding(
                    get: { sophy.preferences.character },
                    set: { sophy.setCharacter($0) }
                )) {
                    ForEach(StudyCompanionCharacter.allCases) { character in
                        Text("\(character.displayName) · \(character.subtitle)").tag(character)
                    }
                }
                .accessibilityIdentifier("settings.sophy.character")
                Toggle("Show idle scripture quotes", isOn: Binding(
                    get: { sophy.preferences.idleScriptureQuotesEnabled },
                    set: { sophy.setIdleScriptureQuotesEnabled($0) }
                ))
                .accessibilityIdentifier("settings.sophy.idleQuotes")
                Picker("Show verse after idling for", selection: Binding(
                    get: { sophy.preferences.idleDelayBeforeQuoteSeconds },
                    set: { sophy.setIdleDelayBeforeQuoteSeconds($0) }
                )) {
                    ForEach(SophyPreferencesStore.idleDelayChoices, id: \.self) { seconds in
                        Text(SophyPreferencesStore.label(for: seconds)).tag(seconds)
                    }
                }
                .disabled(!sophy.preferences.idleScriptureQuotesEnabled)
                .accessibilityIdentifier("settings.sophy.quoteInterval")
                Text("After you idle long enough, one verse from \(sophy.preferences.character.subtitle) stays on screen until you scroll, tap, or move the companion. Quotes pause during active Notes and Scripture annotation.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
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
                        let accent = Color(palette.accent)
                        let selectionFill = colorScheme == .dark ? 0.16 : 0.24
                        let selectionStroke = colorScheme == .dark ? 0.62 : 0.92
                        HStack(spacing: 16) {
                            Text("Aa")
                                .font(Font(ScriptureFonts.font(appearance.readingFamily, size: 28)))
                                .frame(width: 54, height: 54)
                                .background(Color(palette.paper), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Color(palette.ink))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(accent)
                                        .frame(width: 5)
                                }
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
                                    .foregroundStyle(accent)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selected ? accent.opacity(selectionFill) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selected ? accent.opacity(selectionStroke) : Color.clear, lineWidth: 2)
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
                    .controlSize(.large)
                Picker("Appearance", selection: preference(\.theme)) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                .accessibilityIdentifier("settings.theme")
            }
        }
    }

    private var scriptureAudioSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeading("Scripture audio (BSB)")
                Text("Berean Standard Bible narration from AO Lab. Saved files on this iPad are always used when available.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                Picker("Playback", selection: Binding(
                    get: { narration.preferences.deliveryMode },
                    set: { narration.setDeliveryMode($0) }
                )) {
                    ForEach(ScriptureNarrationDeliveryMode.allCases, id: \.self) { mode in
                        Text(mode.settingsLabel).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.narration.delivery")
                if narration.preferences.deliveryMode == .streaming {
                    Text("Streams chapter audio over the network when you have not downloaded that chapter.")
                        .font(.footnote)
                        .foregroundStyle(Color(theme.palette.secondary))
                } else {
                    Text("Downloads each chapter to this iPad when you play or use Download all BSB audio in Translation downloads.")
                        .font(.footnote)
                        .foregroundStyle(Color(theme.palette.secondary))
                }
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
            VStack(alignment: .leading, spacing: 8) {
                sectionHeading("Translations")
                Text("Download or sync AO Lab and API.Bible editions. Choosing what you read stays in the Scripture reader.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                Button("Translation downloads") { showTranslationDownloads = true }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.accent))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                Toggle("Exam mode in Quiz Me", isOn: Binding(
                    get: { companion.examModeEnabled },
                    set: { companion.setExamModeEnabled($0) }
                ))
                .accessibilityIdentifier("settings.quizExamMode")
                Text("When on, Companion opens Exam setup (25, 50, or 100 random questions from the prepared pool) instead of the usual Quiz Me chooser.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
            }
        }
    }

    private var aboutSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("About")
                Text("Version, developer, and open-source licenses.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                NavigationLink {
                    SettingsAboutView()
                } label: {
                    settingsLinkRow("About Sophia Scriptura")
                }
                .accessibilityIdentifier("settings.about.link")
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
