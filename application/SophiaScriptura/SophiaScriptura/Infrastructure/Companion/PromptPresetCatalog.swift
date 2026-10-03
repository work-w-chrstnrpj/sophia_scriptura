import Foundation

struct PromptPresetDefinition: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var isBuiltIn: Bool
    var systemInstruction: String
    var reviewStatus: String
}

struct PromptPresetSeedFile: Codable {
    var sharedGuardrail: String
    var presets: [PromptPresetDefinition]
    var contextVersion: Int
}

enum PromptPresetCatalogError: Error {
    case missingResource
    case invalid
}

struct PromptPresetCatalog: Sendable {
    let seed: PromptPresetSeedFile

    init(seed: PromptPresetSeedFile) { self.seed = seed }

    static func bundled() throws -> PromptPresetCatalog {
        guard let url = Bundle.main.url(forResource: "prompt-presets", withExtension: "seed.json") else {
            throw PromptPresetCatalogError.missingResource
        }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(PromptPresetSeedFile.self, from: data)
        guard !decoded.presets.isEmpty else { throw PromptPresetCatalogError.invalid }
        return PromptPresetCatalog(seed: decoded)
    }

    var presets: [PromptPresetDefinition] { seed.presets }

    func snapshot(for presetID: String) -> PromptPresetSnapshot? {
        guard let preset = seed.presets.first(where: { $0.id == presetID }) else { return nil }
        let resolved = preset.systemInstruction.replacingOccurrences(of: "{{sharedGuardrail}}", with: seed.sharedGuardrail)
        return PromptPresetSnapshot(
            presetID: preset.id,
            displayName: preset.name,
            resolvedInstruction: resolved,
            contextVersion: seed.contextVersion,
            contentHash: CompanionContentHash.digest(resolved)
        )
    }

    func defaultPresetID() -> String {
        seed.presets.first(where: { $0.id == "default" })?.id ?? seed.presets[0].id
    }
}
