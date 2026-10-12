import SwiftUI

/// Choose an already-available translation for reading. Download and sync live in `ScriptureTranslationDownloadsView`.
struct ScriptureTranslationPickerView: View {
    @Bindable var session: ReaderSession
    var narration: ScriptureNarrationSession?
    @State private var filter = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var appearance: ScriptureAppearance { session.preferences.appearance }
    private var palette: ReaderPalette { session.preferences.palette(for: appearance, colorScheme: colorScheme) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Current: \(session.edition?.name ?? session.abbreviation)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color(palette.accent))
                }
                .listRowBackground(Color(palette.paper))

                Section("Bundled") {
                    pickerRow(
                        title: "World English Bible · WEB",
                        subtitle: "Included offline",
                        editionID: "web.engwebp",
                        enabled: true
                    )
                }
                .listRowBackground(Color(palette.paper))

                Section("AO Lab · installed") {
                    let installed = filteredHelloAO(session.helloAOEditions.filter(\.isAvailable))
                    if installed.isEmpty {
                        Text("No AO Lab translations installed. Use Manage Downloads to add one.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(installed) { status in
                        pickerRow(
                            title: "\(status.catalogName ?? status.eligible.name) · \(status.eligible.abbreviation)",
                            subtitle: "AO Lab · offline",
                            editionID: status.appEditionID,
                            enabled: true
                        )
                        .accessibilityIdentifier("version.helloao.\(status.eligible.abbreviation)")
                    }
                }
                .listRowBackground(Color(palette.paper))

                Section("API.Bible · downloaded") {
                    let available = session.translations.filter(\.isAvailable)
                    if available.isEmpty {
                        Text("No licensed translations downloaded. Use Manage Downloads after saving your API key.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(available) { status in
                        pickerRow(
                            title: "\(status.translation.name) · \(status.translation.abbreviation)",
                            subtitle: "API.Bible · offline",
                            editionID: status.translation.editionID,
                            enabled: true
                        )
                        .accessibilityIdentifier("version.\(status.translation.abbreviation)")
                    }
                    let missing = session.translations.filter { !$0.isAvailable }
                    if !missing.isEmpty {
                        ForEach(missing) { status in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(status.translation.name) · \(status.translation.abbreviation)")
                                    .foregroundStyle(.secondary)
                                Text("Not downloaded — open Manage Downloads")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listRowBackground(Color(palette.paper))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSeparatorTint(Color(palette.rule))
            .background(Color(palette.paper))
            .foregroundStyle(Color(palette.ink))
            .tint(Color(palette.accent))
            .searchable(text: $filter, prompt: "Translation or language")
            .navigationTitle("Translation")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ScriptureTranslationDownloadsView(session: session, narration: narration)
                    } label: {
                        Text("Manage Downloads")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarBackground(Color(palette.paper), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task { await session.refreshTranslations() }
        }
        .background(Color(palette.paper).ignoresSafeArea())
    }

    @ViewBuilder
    private func pickerRow(title: String, subtitle: String, editionID: String, enabled: Bool) -> some View {
        Button {
            Task {
                await session.selectEdition(editionID)
                dismiss()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if session.edition?.id == editionID {
                    Image(systemName: "checkmark").accessibilityHidden(true)
                }
            }
        }
        .disabled(!enabled)
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
