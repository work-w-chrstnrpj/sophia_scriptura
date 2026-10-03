import Foundation

struct ProviderRegistry: Sendable {
    private let adapters: [String: any LLMProviderAdapter]

    init(adapters: [any LLMProviderAdapter]) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.id, $0) })
    }

    static func production() -> ProviderRegistry {
        ProviderRegistry(adapters: [
            OpenAIProviderAdapter(),
            AnthropicProviderAdapter(),
            GeminiProviderAdapter(),
            OpenAICompatibleProviderAdapter.openRouter(),
            OpenAICompatibleProviderAdapter.githubModels(),
            OpenAICompatibleProviderAdapter.nvidia(),
            OpenAICompatibleProviderAdapter.cerebras(),
            OpenAICompatibleProviderAdapter.groq(),
            OpenAICompatibleProviderAdapter.mistral()
        ])
    }

    func adapter(id: String) -> (any LLMProviderAdapter)? { adapters[id] }

    var supportedAdapters: [any LLMProviderAdapter] {
        adapters.values.sorted { $0.displayName < $1.displayName }
    }
}
