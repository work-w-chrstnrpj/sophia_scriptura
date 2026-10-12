import SwiftUI

/// Download, sync, update, and remove offline translations. Does not change the active reader edition.
struct ScriptureTranslationDownloadsView: View {
    @Bindable var session: ReaderSession
    var narration: ScriptureNarrationSession?
    @State private var key = ""
    @State private var filter = ""
    @State private var sourceFilter: TranslationDownloadsSourceFilter = .all
    @State private var helloAODeletionID: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var appearance: ScriptureAppearance { session.preferences.appearance }
    private var palette: ReaderPalette { session.preferences.palette(for: appearance, colorScheme: colorScheme) }

    var body: some View {
        List {
            statusSection
            bundledInfoSection
            helloAOInstalledSection
            if let narration, sourceFilter == .all || sourceFilter == .helloAO {
                ScriptureBSBNarrationDownloadsSection(session: session, narration: narration)
            }
            helloAOBrowseSection
            apiBibleSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listRowSeparatorTint(Color(palette.rule))
        .background(Color(palette.paper))
        .foregroundStyle(Color(palette.ink))
        .tint(Color(palette.accent))
        .searchable(text: $filter, prompt: "Translation or language")
        .navigationTitle("Translation Downloads")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu("Source") {
                    Picker("Source", selection: $sourceFilter) {
                        ForEach(TranslationDownloadsSourceFilter.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .toolbarBackground(Color(palette.paper), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await session.refreshTranslations() }
        .overlay {
            if let id = helloAODeletionID,
               let status = session.helloAOEditions.first(where: { $0.id == id }) {
                StudyCenteredConfirmationOverlay(
                    title: "Delete \(status.eligible.abbreviation)?",
                    message: "This removes the offline translation from your iPad. You can download it again from AO Lab.",
                    confirmLabel: "Delete Translation",
                    onConfirm: {
                        helloAODeletionID = nil
                        Task { await session.deleteHelloAODownload(id) }
                    },
                    onCancel: { helloAODeletionID = nil }
                )
            }
        }
        .animation(.easeOut(duration: 0.18), value: helloAODeletionID != nil)
    }

    private var statusSection: some View {
        Section {
            if session.syncing {
                ProgressView(value: session.syncFraction)
                if let id = session.helloAODownloadID,
                   let name = HelloAOEligibility.edition(providerID: id)?.abbreviation {
                    Text("Downloading AO Lab · \(name)… Keep Sophia open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Downloading… Keep Sophia open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let message = session.syncMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("downloads.status")
            }
        }
        .listRowBackground(Color(palette.paper))
    }

    @ViewBuilder private var bundledInfoSection: some View {
        if sourceFilter == .all || sourceFilter == .bundled {
            Section("Bundled") {
                Text("World English Bible (WEB) is included with the app and does not need a download.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color(palette.paper))
        }
    }

    @ViewBuilder private var helloAOInstalledSection: some View {
        if sourceFilter == .all || sourceFilter == .helloAO {
            Section("Installed · AO Lab") {
                let rows = filteredHelloAO(session.helloAOEditions.filter { $0.state == .installed })
                if rows.isEmpty {
                    Text("No AO Lab translations installed yet.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(rows) { status in
                    HelloAODownloadRow(session: session, status: status) {
                        helloAODeletionID = status.id
                    }
                }
            }
            .listRowBackground(Color(palette.paper))
        }
    }

    @ViewBuilder private var helloAOBrowseSection: some View {
        if sourceFilter == .all || sourceFilter == .helloAO {
            Section("Download · AO Lab") {
                Button("Refresh Catalog") { Task { await session.refreshHelloAOCatalog() } }
                    .disabled(session.syncing)
                if let refreshed = session.helloAOEditions.compactMap(\.lastCatalogRefresh).max() {
                    Text("Last catalog refresh: \(refreshed.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Refresh the catalog once to confirm eligible editions on this device.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(filteredHelloAO(session.helloAOEditions.filter { $0.state != .installed })) { status in
                    HelloAODownloadRow(session: session, status: status)
                }
            }
            .listRowBackground(Color(palette.paper))
        }
    }

    @ViewBuilder private var apiBibleSection: some View {
        if sourceFilter == .all || sourceFilter == .apiBible {
            Section("API.Bible") {
                ForEach(session.translations) { status in
                    APIBibleDownloadRow(session: session, status: status)
                }
                Button("Sync all three now") { Task { await session.syncAllTranslations() } }
                    .disabled(session.syncing)
            }
            .listRowBackground(Color(palette.paper))

            Section("API.Bible connection") {
                SecureField("API key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("downloads.key")
                Button("Save key on this device") {
                    let value = key
                    key = ""
                    Task { await session.configureProvider(key: value) }
                }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.syncing)
                Text(OfflineContentPolicy.current.enforcesRefresh
                     ? "Sync manually at least every 30 days. Keep Sophia open while downloading."
                     : "Development authorization is active for NASB, NLT and NKJV.")
                .font(.caption)
            }
            .listRowBackground(Color(palette.paper))
        }
    }

    private func filteredHelloAO(_ rows: [HelloAOEditionStatus]) -> [HelloAOEditionStatus] {
        let needle = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return rows }
        return rows.filter { status in
            [
                status.eligible.name,
                status.eligible.abbreviation,
                status.catalogName ?? "",
                status.catalogLanguage ?? "",
                status.eligible.language
            ].joined(separator: " ").lowercased().contains(needle)
        }
    }
}

private enum TranslationDownloadsSourceFilter: String, CaseIterable, Identifiable {
    case all = "All sources"
    case bundled = "Bundled"
    case apiBible = "API.Bible"
    case helloAO = "AO Lab"
    var id: String { rawValue }
}

private struct APIBibleDownloadRow: View {
    @Bindable var session: ReaderSession
    let status: TranslationStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status.translation.name + " · " + status.translation.abbreviation)
                .font(.headline)
            if let expiry = status.expiresAt {
                Text(status.isAvailable
                     ? (OfflineContentPolicy.current.enforcesRefresh ? "Offline until \(expiry.formatted(date: .abbreviated, time: .shortened))" : "Development authorization · cached locally")
                     : "Locked — sync to renew access")
                .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Not downloaded").font(.caption).foregroundStyle(.secondary)
            }
            Button(status.expiresAt == nil ? "Download \(status.translation.abbreviation)" : "Sync \(status.translation.abbreviation)") {
                Task { await session.syncTranslation(status.id) }
            }
            .disabled(session.syncing)
            .accessibilityIdentifier("download.api.\(status.translation.abbreviation)")
        }
        .padding(.vertical, 5)
    }
}

private struct HelloAODownloadRow: View {
    @Bindable var session: ReaderSession
    let status: HelloAOEditionStatus
    var onRequestDelete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(status.catalogName ?? status.eligible.name) · \(status.eligible.abbreviation)")
                .font(.headline)
            Text(status.summaryLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            switch status.state {
            case .installed:
                Button("Check for update") { Task { await session.downloadHelloAO(status.id) } }
                    .disabled(session.syncing)
                Button("Delete translation") { onRequestDelete?() }
                    .foregroundStyle(.red)
                    .disabled(session.syncing || onRequestDelete == nil)
                    .accessibilityIdentifier("download.helloao.delete.\(status.eligible.abbreviation)")
            case .downloading, .paused:
                ProgressView(value: Double(status.progressCompleted), total: Double(max(1, status.progressTotal)))
                Text("\(status.progressCompleted) of \(status.progressTotal) chapters").font(.caption).foregroundStyle(.secondary)
                if status.state == .downloading {
                    Button("Cancel Download", role: .cancel) { Task { await session.cancelHelloAODownload() } }
                } else {
                    Button("Resume Download") { Task { await session.downloadHelloAO(status.id) } }.disabled(session.syncing)
                }
            case .notInstalled, .failed:
                Button("Download") { Task { await session.downloadHelloAO(status.id) } }
                    .disabled(session.syncing || !status.eligible.permittedOperations.install)
            }
        }
        .padding(.vertical, 5)
        .accessibilityIdentifier("download.helloao.\(status.eligible.abbreviation)")
    }
}

private extension HelloAOEditionStatus {
    var summaryLine: String {
        let language = catalogLanguage ?? HelloAODisplay.languageName(for: eligible.language)
        let books = "\(eligible.expectedBookCount) books"
        let statusLabel: String = {
            switch state {
            case .installed: "Installed offline"
            case .downloading: "Downloading"
            case .paused: "Paused · \(progressCompleted)/\(progressTotal) chapters"
            case .notInstalled: "Not installed"
            case .failed: "Not installed"
            }
        }()
        return "AO Lab · \(language) · \(books) · \(statusLabel)"
    }
}

private enum HelloAODisplay {
    static func languageName(for code: String) -> String {
        switch code.lowercased() {
        case "eng": "English"
        default: code.uppercased()
        }
    }
}

// MARK: - BSB narration bulk download

private struct ScriptureBSBNarrationDownloadsSection: View {
    @Bindable var session: ReaderSession
    @Bindable var narration: ScriptureNarrationSession
    @ObservedObject private var queue: ScriptureNarrationDownloadQueue
    @Environment(\.colorScheme) private var colorScheme
    @State private var savedCount = 0
    @State private var totalChapters = 0

    private var palette: ReaderPalette {
        session.preferences.palette(for: session.preferences.appearance, colorScheme: colorScheme)
    }

    init(session: ReaderSession, narration: ScriptureNarrationSession) {
        self.session = session
        self.narration = narration
        _queue = ObservedObject(wrappedValue: narration.downloadQueue)
    }

    private var bsbInstalled: Bool {
        session.helloAOEditions.contains {
            $0.id == ScriptureNarrationCatalog.bsbAOTranslationID && $0.state == .installed
        }
    }

    private var narratorLabel: String {
        ScriptureNarrationNarrator(
            rawValue: ScriptureNarrationPreferencesStore.load().preferredNarratorID
        )?.displayName ?? ScriptureNarrationNarrator.defaultID
    }

    var body: some View {
        if bsbInstalled {
            Section("Scripture audio · BSB") {
                Text("Human narration for Berean Standard Bible. Saved separately from the text download. Uses narrator: \(narratorLabel). Change stream vs save in Settings → Scripture audio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if totalChapters > 0 {
                    Text("\(savedCount) of \(totalChapters) chapter recordings saved on this iPad")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if queue.snapshot.isRunning {
                    ProgressView(
                        value: Double(queue.snapshot.completed),
                        total: Double(max(1, queue.snapshot.total))
                    )
                    if let current = queue.snapshot.currentChapterID {
                        Text("Saving \(current)…").font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Cancel audio download", role: .cancel) { queue.cancel() }
                } else {
                    Button("Download all BSB audio") {
                        Task { await startBulkDownload() }
                    }
                    .disabled(session.syncing)
                    .accessibilityIdentifier("download.bsb.audio.all")
                }

                if let message = queue.snapshot.statusMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Color(palette.paper))
            .task(id: refreshID) { await refreshCounts() }
            .onChange(of: queue.snapshot.completed) { _, _ in
                Task { await refreshCounts() }
            }
        }
    }

    private var refreshID: String {
        "\(session.helloAOEditions.map(\.id).joined())-\(queue.snapshot.isRunning)"
    }

    private func refreshCounts() async {
        guard bsbInstalled else {
            savedCount = 0
            totalChapters = 0
            return
        }
        let chapters = await session.installedHelloAOChapterIDs(
            providerEditionID: ScriptureNarrationCatalog.bsbAOTranslationID
        ) ?? []
        totalChapters = chapters.count
        let narratorID = ScriptureNarrationPreferencesStore.load().preferredNarratorID
        savedCount = await queue.downloadedCount(
            aoTranslationID: ScriptureNarrationCatalog.bsbAOTranslationID,
            narratorID: narratorID,
            chapterIDs: chapters
        )
    }

    private func startBulkDownload() async {
        guard let chapters = await session.installedHelloAOChapterIDs(
            providerEditionID: ScriptureNarrationCatalog.bsbAOTranslationID
        ), !chapters.isEmpty else {
            return
        }
        let narratorID = ScriptureNarrationPreferencesStore.load().preferredNarratorID
        queue.downloadAllChapters(
            aoTranslationID: ScriptureNarrationCatalog.bsbAOTranslationID,
            narratorID: narratorID,
            chapterIDs: chapters
        )
    }
}
