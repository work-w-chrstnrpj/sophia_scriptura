import SwiftUI

struct CompanionProviderSettingsView: View {
    @ObservedObject var session: CompanionSession
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                Text("API keys stay in the device Keychain. Sophia fetches models from each provider after you save a key—no manual model ids.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(0..<session.supportedAdapters.count, id: \.self) { index in
                ProviderKeySection(session: session, adapter: session.supportedAdapters[index], statusMessage: $statusMessage)
            }
            if let statusMessage {
                Section { Text(statusMessage).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Provider keys")
    }
}

private struct ProviderKeySection: View {
    @ObservedObject var session: CompanionSession
    let adapter: any LLMProviderAdapter
    @Binding var statusMessage: String?
    @State private var apiKey = ""
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
                Button("Test connection") { Task { await test(config.id) } }.disabled(testing)
                Button("Delete key", role: .destructive) {
                    try? session.deleteProviderKey(configurationID: config.id)
                    apiKey = ""
                    statusMessage = "\(adapter.displayName) key removed."
                }
            }
            Text(adapter.advertisedCapabilities(modelID: "default").map(\.rawValue).sorted().joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try session.saveProviderKey(apiKey, adapterID: adapter.id, accountLabel: "Personal")
            apiKey = ""
            statusMessage = "\(adapter.displayName) key saved."
            if let config = session.providerConfigurations.first(where: { $0.adapterID == adapter.id }) {
                await refreshModels(config.id)
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func refreshModels(_ configurationID: UUID) async {
        if let message = await session.refreshModelCatalog(for: configurationID) {
            statusMessage = message
        } else {
            statusMessage = "\(adapter.displayName) models updated."
        }
    }

    private func test(_ configurationID: UUID) async {
        testing = true
        defer { testing = false }
        statusMessage = await session.testConnection(configurationID: configurationID)
        if statusMessage == nil { statusMessage = "\(adapter.displayName) connection succeeded." }
    }
}
