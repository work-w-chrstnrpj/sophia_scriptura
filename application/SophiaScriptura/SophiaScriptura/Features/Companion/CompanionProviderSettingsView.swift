import SwiftUI

struct CompanionProviderSettingsView: View {
    @ObservedObject var session: CompanionSession
    @EnvironmentObject private var settingsToast: SettingsToastCenter
    @Environment(\.appTheme) private var theme

    var body: some View {
        Form {
            Section {
                Text("API keys stay in the device Keychain. Sophia fetches models after you save a key. Hugging Face also accepts an exact model id, including a routing suffix such as :provider. A model list does not prove that the token can run that model, and Hugging Face models are not marked free.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
            }
            .listRowBackground(Color(theme.palette.soft))
            if !session.providerConfigurationsWithCredentials().isEmpty {
                SharedRouteSettingsSection(session: session)
            }
            ForEach(0..<session.supportedAdapters.count, id: \.self) { index in
                ProviderKeySection(session: session, adapter: session.supportedAdapters[index])
            }
        }
        .appSurface()
        .navigationTitle("Provider keys")
    }
}

private struct SharedRouteSettingsSection: View {
    @ObservedObject var session: CompanionSession
    @EnvironmentObject private var settingsToast: SettingsToastCenter
    @Environment(\.appTheme) private var theme
    @State private var providerConfigID = UUID()
    @State private var modelID = ""

    var body: some View {
        Section("Default provider and model") {
            Text("New chats and Sophy use this route. Quiz keeps its own defaults until those are absent. Opening an existing chat does not change this choice.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            CompanionModelRoutingBar(
                session: session,
                providerConfigID: $providerConfigID,
                modelID: $modelID,
                accessibilityPrefix: "sharedRoute"
            )
            Button("Save default route") {
                session.setSharedProviderRoute(configurationID: providerConfigID, modelID: modelID)
                settingsToast.show("Default provider route saved.")
            }
            .disabled(modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .listRowBackground(Color(theme.palette.soft))
        .onAppear(perform: load)
    }

    private func load() {
        if let route = session.resolvedSharedRoute() {
            providerConfigID = route.configurationID
            modelID = route.modelID
        } else if let first = session.providerConfigurationsWithCredentials().first {
            providerConfigID = first.id
            modelID = first.defaultModelID
        }
    }
}

private struct ProviderKeySection: View {
    @ObservedObject var session: CompanionSession
    let adapter: any LLMProviderAdapter
    @EnvironmentObject private var settingsToast: SettingsToastCenter
    @Environment(\.appTheme) private var theme
    @State private var apiKey = ""
    @State private var manualModelID = ""
    @State private var testing = false
    @State private var saving = false

    var body: some View {
        Section(adapter.displayName) {
            SecureField("API key", text: $apiKey)
                .textContentType(.password)
            Button("Save key") { Task { await save() } }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
            if let config = session.providerConfigurations.first(where: { $0.adapterID == adapter.id }) {
                Label("Key saved", systemImage: "checkmark.seal").foregroundStyle(.secondary)
                if session.modelCatalogLoading.contains(config.id) {
                    ProgressView("Fetching models…")
                } else {
                    let count = session.modelOptions(for: config.id).count
                    Text("\(count) model\(count == 1 ? "" : "s") available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Refresh models") { Task { await refreshModels(config.id) } }
                    .disabled(session.modelCatalogLoading.contains(config.id))
                if ProviderModelCatalog.allowsManualModelEntry(adapterID: adapter.id) {
                    TextField("Exact model id", text: $manualModelID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("provider.manualModel.\(adapter.id)")
                    Button("Save model id") {
                        session.setConfigurationModel(configurationID: config.id, modelID: manualModelID)
                        settingsToast.show("Saved \(adapter.displayName) model id.")
                    }
                    .disabled(manualModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Button("Test connection") { Task { await test(config.id) } }.disabled(testing)
                Button("Delete key", role: .destructive) {
                    try? session.deleteProviderKey(configurationID: config.id)
                    apiKey = ""
                    settingsToast.show("\(adapter.displayName) key removed.")
                }
            }
            Text(adapter.advertisedCapabilities(modelID: "default").map(\.rawValue).sorted().joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(Color(theme.palette.soft))
        .onAppear {
            if manualModelID.isEmpty,
               let config = session.providerConfigurations.first(where: { $0.adapterID == adapter.id }) {
                manualModelID = config.defaultModelID
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try session.saveProviderKey(apiKey, adapterID: adapter.id, accountLabel: "Personal")
            apiKey = ""
            settingsToast.show("\(adapter.displayName) key saved.")
            if let config = session.providerConfigurations.first(where: { $0.adapterID == adapter.id }) {
                await refreshModels(config.id)
            }
        } catch {
            settingsToast.show(error.localizedDescription)
        }
    }

    private func refreshModels(_ configurationID: UUID) async {
        if let message = await session.refreshModelCatalog(for: configurationID) {
            settingsToast.show(message)
        } else {
            settingsToast.show("\(adapter.displayName) models updated.")
        }
    }

    private func test(_ configurationID: UUID) async {
        testing = true
        defer { testing = false }
        if let message = await session.testConnection(configurationID: configurationID) {
            settingsToast.show(message)
        } else {
            settingsToast.show("\(adapter.displayName) connection succeeded.")
        }
    }
}
