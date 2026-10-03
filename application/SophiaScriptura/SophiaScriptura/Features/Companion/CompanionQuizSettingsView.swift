import SwiftUI

struct CompanionQuizSettingsView: View {
    @ObservedObject var session: CompanionSession
    @State private var providerConfigID = UUID()
    @State private var modelID = ""
    @State private var hasLoadedDefaults = false
    @State private var savedNotice: String?

    private var configurations: [ProviderConfigurationRecord] {
        session.providerConfigurationsWithCredentials()
    }

    var body: some View {
        Form {
            Section {
                Text("Quiz Me uses local question fixtures. Provider and model defaults are stored for Reviewing metadata and future AI-generated quizzes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Default provider") {
                if configurations.isEmpty {
                    Text("Save a provider key under Provider keys first.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Provider", selection: $providerConfigID) {
                        ForEach(configurations) { config in
                            Text(quizProviderLabel(config)).tag(config.id)
                        }
                    }
                    .onChange(of: providerConfigID) { _, configID in
                        Task { await refreshModels(for: configID) }
                    }
                    Picker("Model", selection: $modelID) {
                        ForEach(modelOptions, id: \.modelID) { option in
                            Text(option.label).tag(option.modelID)
                        }
                    }
                    .disabled(modelOptions.isEmpty)
                    Button("Save quiz defaults") { saveDefaults() }
                }
            }
        }
        .navigationTitle("Quiz Me defaults")
        .onAppear { loadDefaults() }
        .overlay(alignment: .top) {
            if let savedNotice {
                TransientBannerNotice(message: savedNotice)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { self.savedNotice = nil }
                        }
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: savedNotice != nil)
    }

    private var modelOptions: [CompanionModelOption] {
        return session.modelOptions(for: providerConfigID)
    }

    private func quizProviderLabel(_ config: ProviderConfigurationRecord) -> String {
        let name = session.adapter(id: config.adapterID)?.displayName ?? config.adapterID
        return "\(name) · \(config.accountLabel)"
    }

    private func loadDefaults() {
        guard !hasLoadedDefaults, let first = configurations.first else { return }
        hasLoadedDefaults = true
        providerConfigID = session.quizDefaultProviderConfigID ?? first.id
        modelID = session.quizDefaultModelID ?? first.defaultModelID
        Task { await refreshModels(for: providerConfigID) }
    }

    private func refreshModels(for configID: UUID) async {
        _ = await session.refreshModelCatalog(for: configID)
        if modelID.isEmpty, let first = session.modelOptions(for: configID).first {
            modelID = first.modelID
        }
    }

    private func saveDefaults() {
        guard !modelID.isEmpty else { return }
        session.updateQuizDefaults(providerConfigID: providerConfigID, modelID: modelID)
        savedNotice = "Quiz defaults saved successfully."
    }
}
