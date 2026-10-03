import Foundation

struct CompanionModelOption: Identifiable, Hashable, Sendable {
    var id: String { modelID }
    var modelID: String
    var label: String
    var isFree: Bool
}

enum ProviderModelCatalog {
    /// Adapters where a “free models only” filter is offered in the routing bar.
    static func supportsFreeModelFilter(adapterID: String) -> Bool {
        switch adapterID {
        case "openrouter", "groq", "cerebras", "gemini", "mistral", "nvidia":
            return true
        default:
            return false
        }
    }

    static func curatedModels(adapterID: String) -> [CompanionModelOption] {
        switch adapterID {
        case "openai":
            return options([
                ("gpt-4o-mini", "GPT-4o mini", false),
                ("gpt-4o", "GPT-4o", false),
                ("gpt-4.1-mini", "GPT-4.1 mini", false)
            ])
        case "anthropic":
            return options([
                ("claude-3-5-haiku-latest", "Claude 3.5 Haiku", false),
                ("claude-3-5-sonnet-latest", "Claude 3.5 Sonnet", false)
            ])
        case "gemini":
            return options([
                ("gemini-2.0-flash", "Gemini 2.0 Flash", true),
                ("gemini-2.5-flash", "Gemini 2.5 Flash", true)
            ])
        case "openrouter":
            return options([
                ("openai/gpt-4o-mini", "GPT-4o mini (OpenRouter)", false),
                ("google/gemma-3-4b-it:free", "Gemma 3 4B (free)", true)
            ])
        case "groq":
            return options([
                ("llama-3.3-70b-versatile", "Llama 3.3 70B", true),
                ("llama-3.1-8b-instant", "Llama 3.1 8B Instant", true)
            ])
        case "mistral":
            return options([
                ("mistral-small-latest", "Mistral Small", false),
                ("open-mistral-nemo", "Open Mistral Nemo", true)
            ])
        case "cerebras":
            return options([("llama3.1-8b", "Llama 3.1 8B", true)])
        case "nvidia":
            return options([("meta/llama-3.1-8b-instruct", "Llama 3.1 8B Instruct", false)])
        case "github":
            return options([("openai/gpt-4o", "GPT-4o (GitHub Models)", false)])
        case "mock":
            return options([
                ("mock", "Mock model", true),
                ("mock-fast", "Mock fast", false)
            ])
        default:
            return []
        }
    }

    static func defaultModelID(adapterID: String) -> String {
        curatedModels(adapterID: adapterID).first?.modelID ?? "default"
    }

    static func mergeRemote(ids: [String], adapterID: String) -> [CompanionModelOption] {
        let known = Dictionary(uniqueKeysWithValues: curatedModels(adapterID: adapterID).map { ($0.modelID, $0) })
        let merged = ids.map { id -> CompanionModelOption in
            if let hit = known[id] { return hit }
            let free = isLikelyFreeModel(modelID: id, adapterID: adapterID)
            let label = free ? "\(id) (free)" : id
            return CompanionModelOption(modelID: id, label: label, isFree: free)
        }
        if merged.isEmpty { return curatedModels(adapterID: adapterID) }
        return merged.sorted { lhs, rhs in
            if lhs.isFree != rhs.isFree { return lhs.isFree && !rhs.isFree }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }

    static func filteredModels(_ options: [CompanionModelOption], adapterID: String, freeOnly: Bool) -> [CompanionModelOption] {
        guard freeOnly, supportsFreeModelFilter(adapterID: adapterID) else { return options }
        return options.filter(\.isFree)
    }

    static func pickModel(
        currentID: String,
        options: [CompanionModelOption],
        adapterID: String,
        preferFree: Bool = false
    ) -> String {
        let pool = preferFree ? filteredModels(options, adapterID: adapterID, freeOnly: true) : options
        let effective = pool.isEmpty ? options : pool
        if !currentID.isEmpty, effective.contains(where: { $0.modelID == currentID }) { return currentID }
        if preferFree, let free = effective.first(where: \.isFree) { return free.modelID }
        if let first = effective.first?.modelID { return first }
        return defaultModelID(adapterID: adapterID)
    }

    static func isLikelyFreeModel(modelID: String, adapterID: String) -> Bool {
        let id = modelID.lowercased()
        if id.hasSuffix(":free") || id.contains(":free") { return true }
        switch adapterID {
        case "openrouter":
            return id.hasSuffix(":free")
        case "groq", "cerebras":
            return true
        case "gemini":
            return id.contains("flash") || id.contains("lite")
        case "mistral":
            return id.hasPrefix("open-mistral") || id.contains("free")
        case "nvidia":
            return id.contains("free")
        default:
            return false
        }
    }

    private static func options(_ triples: [(String, String, Bool)]) -> [CompanionModelOption] {
        triples.map { CompanionModelOption(modelID: $0.0, label: $0.1, isFree: $0.2) }
    }
}
