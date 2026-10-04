import SwiftUI

/// Provider and model selection for chat and quiz (Notable-style live catalog, Sophia layout).
struct CompanionModelRoutingBar: View {
    @ObservedObject var session: CompanionSession
    @Binding var providerConfigID: UUID
    @Binding var modelID: String
    var accessibilityPrefix: String = "companion"
    @Environment(\.appTheme) private var theme

    @State private var refreshTask: Task<Void, Never>?

    private var configurations: [ProviderConfigurationRecord] {
        session.providerConfigurationsWithCredentials()
    }

    private var adapterID: String {
        session.providerRecord(for: providerConfigID)?.adapterID ?? ""
    }

    private var supportsFreeFilter: Bool {
        ProviderModelCatalog.supportsFreeModelFilter(adapterID: adapterID)
    }

    private var modelOptions: [CompanionModelOption] {
        session.filteredModelOptions(for: providerConfigID)
    }

    private var isLoading: Bool {
        session.modelCatalogLoading.contains(providerConfigID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if configurations.isEmpty {
                Text("Add a provider key in Settings to choose a model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                if supportsFreeFilter {
                    Toggle("Free models only", isOn: Binding(
                        get: { session.showFreeModelsOnly },
                        set: { session.setShowFreeModelsOnly($0) }
                    ))
                    .font(.caption)
                    .accessibilityIdentifier("\(accessibilityPrefix).freeModelsOnly")
                    .onChange(of: session.showFreeModelsOnly) { _, _ in
                        alignModelSelection()
                    }
                }
                if session.showFreeModelsOnly && supportsFreeFilter && modelOptions.isEmpty {
                    Text("No free models in this catalog. Turn off the filter or refresh models.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Provider")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Picker("Provider", selection: $providerConfigID) {
                            ForEach(configurations) { config in
                                Text(providerLabel(config)).tag(config.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("\(accessibilityPrefix).provider")
                        .onChange(of: providerConfigID) { _, newValue in
                            Task { await applyProviderChange(newValue) }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if modelOptions.isEmpty {
                            Text("—")
                                .foregroundStyle(.secondary)
                        } else if modelOptions.count > 24 {
                            Menu {
                                ForEach(modelOptions) { option in
                                    Button(option.label) { modelID = option.modelID }
                                }
                            } label: {
                                HStack {
                                    Text(modelOptions.first(where: { $0.modelID == modelID })?.label ?? modelID)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                }
                            }
                            .accessibilityIdentifier("\(accessibilityPrefix).model")
                        } else {
                            Picker("Model", selection: $modelID) {
                                ForEach(modelOptions) { option in
                                    Text(option.label).tag(option.modelID)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("\(accessibilityPrefix).model")
                        }
                    }
                    Spacer(minLength: 0)
                    Button {
                        refreshTask?.cancel()
                        refreshTask = Task { await session.refreshModelCatalog(for: providerConfigID) }
                    } label: {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderless)
                    .tint(Color(theme.palette.accent))
                    .accessibilityLabel("Refresh models")
                    .disabled(isLoading || configurations.isEmpty)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .task(id: providerConfigID) {
            await session.refreshModelCatalog(for: providerConfigID)
            alignModelSelection()
        }
        .onChange(of: modelID) { _, newValue in
            guard !newValue.isEmpty else { return }
            if !modelOptions.contains(where: { $0.modelID == newValue }), !modelOptions.isEmpty {
                alignModelSelection()
            }
        }
    }

    private func providerLabel(_ config: ProviderConfigurationRecord) -> String {
        let name = session.adapter(id: config.adapterID)?.displayName ?? config.adapterID
        return "\(name) · \(config.accountLabel)"
    }

    private func alignModelSelection() {
        let picked = ProviderModelCatalog.pickModel(
            currentID: modelID,
            options: session.modelOptions(for: providerConfigID),
            adapterID: adapterID,
            preferFree: session.showFreeModelsOnly && supportsFreeFilter
        )
        if picked != modelID { modelID = picked }
    }

    private func applyProviderChange(_ configID: UUID) async {
        await session.refreshModelCatalog(for: configID)
        let adapter = session.providerRecord(for: configID)?.adapterID ?? ""
        modelID = ProviderModelCatalog.pickModel(
            currentID: modelID,
            options: session.modelOptions(for: configID),
            adapterID: adapter,
            preferFree: session.showFreeModelsOnly && ProviderModelCatalog.supportsFreeModelFilter(adapterID: adapter)
        )
    }
}

enum CompanionRoutingLabel {
    static func truncate(_ text: String, limit: Int = 14) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(max(1, limit - 1))) + "…"
    }
}

/// Preset, provider, and model on one row (caption labels + truncated menu values).
struct CompanionInlineRoutingBar: View {
    @ObservedObject var session: CompanionSession
    let conversationID: UUID
    @Binding var providerConfigID: UUID
    @Binding var modelID: String
    var accessibilityPrefix: String = "companion"
    @Environment(\.appTheme) private var theme

    @State private var refreshTask: Task<Void, Never>?

    private var conversation: CompanionConversation? {
        session.conversations.first { $0.id == conversationID }
    }

    private var configurations: [ProviderConfigurationRecord] {
        session.providerConfigurationsWithCredentials()
    }

    private var adapterID: String {
        session.providerRecord(for: providerConfigID)?.adapterID ?? ""
    }

    private var supportsFreeFilter: Bool {
        ProviderModelCatalog.supportsFreeModelFilter(adapterID: adapterID)
    }

    private var modelOptions: [CompanionModelOption] {
        session.filteredModelOptions(for: providerConfigID)
    }

    private var isLoading: Bool {
        session.modelCatalogLoading.contains(providerConfigID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if configurations.isEmpty {
                Text("Add a provider key in Settings to choose a model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    if conversation != nil {
                        routingColumn(title: "Preset") { presetControl }
                            .accessibilityIdentifier("\(accessibilityPrefix).preset")
                    }
                    routingColumn(title: "Provider") { providerControl }
                        .accessibilityIdentifier("\(accessibilityPrefix).provider")
                    routingColumn(title: "Model") { modelControl }
                        .accessibilityIdentifier("\(accessibilityPrefix).model")

                    if supportsFreeFilter {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Free")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Toggle("Free models only", isOn: Binding(
                                get: { session.showFreeModelsOnly },
                                set: { session.setShowFreeModelsOnly($0) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .scaleEffect(0.82)
                            .accessibilityIdentifier("\(accessibilityPrefix).freeModelsOnly")
                            .onChange(of: session.showFreeModelsOnly) { _, _ in
                                alignModelSelection()
                            }
                        }
                    }

                    Button {
                        refreshTask?.cancel()
                        refreshTask = Task { await session.refreshModelCatalog(for: providerConfigID) }
                    } label: {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                    .tint(Color(theme.palette.accent))
                    .accessibilityLabel("Refresh models")
                    .disabled(isLoading)
                }
            }
        }
        .task(id: providerConfigID) {
            await session.refreshModelCatalog(for: providerConfigID)
            alignModelSelection()
        }
        .onChange(of: modelID) { _, newValue in
            guard !newValue.isEmpty else { return }
            if !modelOptions.contains(where: { $0.modelID == newValue }), !modelOptions.isEmpty {
                modelID = modelOptions[0].modelID
            }
        }
        .onChange(of: providerConfigID) { _, newValue in
            Task { await applyProviderChange(newValue) }
        }
    }

    @ViewBuilder
    private var presetControl: some View {
        if let conversation {
            Menu {
                ForEach(session.presetCatalog.presets) { preset in
                    Button(preset.name) {
                        session.updateConversationPreset(conversationID, presetID: preset.id)
                    }
                }
            } label: {
                menuValueLabel(CompanionRoutingLabel.truncate(conversation.presetSnapshot.displayName))
            }
        }
    }

    private var providerControl: some View {
        Menu {
            ForEach(configurations) { config in
                Button(providerLabel(config)) { providerConfigID = config.id }
            }
        } label: {
            menuValueLabel(CompanionRoutingLabel.truncate(shortProviderName))
        }
    }

    @ViewBuilder
    private var modelControl: some View {
        if modelOptions.isEmpty {
            menuValueLabel("—")
        } else {
            Menu {
                ForEach(modelOptions) { option in
                    Button(option.label) { modelID = option.modelID }
                }
            } label: {
                menuValueLabel(CompanionRoutingLabel.truncate(currentModelLabel, limit: 16))
            }
        }
    }

    private func routingColumn(title: String, @ViewBuilder control: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            control()
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private func menuValueLabel(_ text: String) -> some View {
        HStack(spacing: 2) {
            Text(text)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var shortProviderName: String {
        guard let config = session.providerRecord(for: providerConfigID) else { return "—" }
        return session.adapter(id: config.adapterID)?.displayName ?? config.adapterID
    }

    private var currentModelLabel: String {
        modelOptions.first(where: { $0.modelID == modelID })?.label ?? modelID
    }

    private func providerLabel(_ config: ProviderConfigurationRecord) -> String {
        let name = session.adapter(id: config.adapterID)?.displayName ?? config.adapterID
        return "\(name) · \(config.accountLabel)"
    }

    private func alignModelSelection() {
        let picked = ProviderModelCatalog.pickModel(
            currentID: modelID,
            options: session.modelOptions(for: providerConfigID),
            adapterID: adapterID,
            preferFree: session.showFreeModelsOnly && supportsFreeFilter
        )
        if picked != modelID { modelID = picked }
    }

    private func applyProviderChange(_ configID: UUID) async {
        await session.refreshModelCatalog(for: configID)
        let adapter = session.providerRecord(for: configID)?.adapterID ?? ""
        modelID = ProviderModelCatalog.pickModel(
            currentID: modelID,
            options: session.modelOptions(for: configID),
            adapterID: adapter,
            preferFree: session.showFreeModelsOnly && ProviderModelCatalog.supportsFreeModelFilter(adapterID: adapter)
        )
    }
}
