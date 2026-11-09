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
        case "openrouter", "groq", "cerebras", "gemini", "mistral", "nvidia", "qwen-intl":
            return true
        default:
            return false
        }
    }

    /// Hugging Face accepts an exact model id, including a `:provider` routing suffix.
    /// Listed models are not labeled free, and none is selected automatically.
    static func allowsManualModelEntry(adapterID: String) -> Bool {
        adapterID == "huggingface"
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
                ("openai/gpt-oss-120b", "GPT OSS 120B", true),
                ("openai/gpt-oss-20b", "GPT OSS 20B", true),
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
        case "qwen-cn":
            return qwenCuratedModels()
        case "qwen-intl":
            return QwenFreeQuota.chatPriority.map { CompanionModelOption(modelID: $0, label: "\($0) (free quota)", isFree: true) }
        case "huggingface":
            return []
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
        if allowsManualModelEntry(adapterID: adapterID) { return "" }
        return curatedModels(adapterID: adapterID).first?.modelID ?? "default"
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
            let preferred = curatedModels(adapterID: adapterID).map(\.modelID)
            let leftRank = preferred.firstIndex(of: lhs.modelID) ?? Int.max
            let rightRank = preferred.firstIndex(of: rhs.modelID) ?? Int.max
            if leftRank != rightRank { return leftRank < rightRank }
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
        if allowsManualModelEntry(adapterID: adapterID) {
            return currentID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let pool = preferFree ? filteredModels(options, adapterID: adapterID, freeOnly: true) : options
        let effective = pool.isEmpty ? options : pool
        if !currentID.isEmpty, effective.contains(where: { $0.modelID == currentID }) { return currentID }
        if let recommended = curatedModels(adapterID: adapterID).first(where: { candidate in
            effective.contains { $0.modelID == candidate.modelID }
        }) { return recommended.modelID }
        if preferFree, let free = effective.first(where: \.isFree) { return free.modelID }
        if let first = effective.first?.modelID { return first }
        return defaultModelID(adapterID: adapterID)
    }

    /// Repairs the observed ALLaM fallback for newly created manual Scripture chats.
    /// An explicit model choice after creation is retained by pickModel.
    static func scriptureAskModel(currentID: String, options: [CompanionModelOption], adapterID: String) -> String {
        guard adapterID == "groq", currentID == "allam-2-7b" else { return currentID }
        return pickModel(currentID: "", options: options, adapterID: adapterID)
    }

    static func isLikelyFreeModel(modelID: String, adapterID: String) -> Bool {
        if adapterID == "huggingface" { return false }
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
        case "qwen-intl":
            return QwenFreeQuota.freeModelIDs.contains(id)
        case "qwen-cn":
            return false
        default:
            return false
        }
    }

    /// Free-quota models to try after `modelID` when its quota is used up, in priority order.
    static func freeQuotaFallbacks(after modelID: String, adapterID: String) -> [String] {
        guard adapterID == "qwen-intl" else { return [] }
        let chain = QwenFreeQuota.chatPriority
        guard let index = chain.firstIndex(of: modelID) else { return chain.filter { $0 != modelID } }
        return Array(chain[(index + 1)...]) + Array(chain[..<index])
    }

    private static func qwenCuratedModels() -> [CompanionModelOption] {
        options([
            ("qwen-flash", "Qwen Flash", false),
            ("qwen-turbo", "Qwen Turbo", false),
            ("qwen-plus", "Qwen Plus", false),
            ("qwen-max", "Qwen Max", false),
            ("qwen2.5-72b-instruct", "Qwen 2.5 72B Instruct", false),
            ("qwen2.5-32b-instruct", "Qwen 2.5 32B Instruct", false)
        ])
    }

    private static func options(_ triples: [(String, String, Bool)]) -> [CompanionModelOption] {
        triples.map { CompanionModelOption(modelID: $0.0, label: $0.1, isFree: $0.2) }
    }
}

/// Alibaba Model Studio free quota for the Singapore (international) region.
/// Captured 2026-11-09 from the owner's console (SpeechCoachAI docs/api/alibaba-free-quota-models.json).
/// Most quotas expire 2027-01-13; `qwen-plus` expires 2026-11-14. Exhausted quotas return
/// HTTP 403 `AllocationQuota.FreeTierOnly` when Stop-on-Exhaust is on.
enum QwenFreeQuota {
    /// Text chat models tried in this order; on quota exhaustion the next one is used.
    static let chatPriority = [
        "qwen-flash", "qwen3.5-flash", "qwen3.6-flash", "qwen3.7-flash", "qwen3.8-flash",
        "qwen-flash-2025-07-28", "deepseek-v4.1-flash", "qwen-plus", "qwen3.5-plus",
        "qwen3.6-plus", "qwen3.7-plus", "qwen-plus-latest", "qwen-max", "qwen3.7-max"
    ]

    /// Every enabled language model with free quota remaining at capture time.
    static let freeModelIDs: Set<String> = [
        "deepseek-v4-flash-0731", "deepseek-v4-pro", "deepseek-v4-pro-0813", "deepseek-v4.1-flash",
        "glm-5.1", "glm-5.2", "glm-5.3", "kimi-k2.7-code", "kimi-k3",
        "qwen-flash", "qwen-flash-2025-07-28", "qwen-flash-character", "qwen-max",
        "qwen-mt-flash", "qwen-mt-lite", "qwen-mt-plus",
        "qwen-plus", "qwen-plus-2025-04-28", "qwen-plus-2025-07-14", "qwen-plus-2025-12-01",
        "qwen-plus-character", "qwen-plus-latest", "qwen-vl-ocr", "qwen-vl-ocr-2025-11-20",
        "qwen3-coder-flash", "qwen3-coder-flash-2025-07-28", "qwen3-vl-plus",
        "qwen3.5-122b-a10b", "qwen3.5-35b-a3b", "qwen3.5-397b-a17b", "qwen3.5-flash",
        "qwen3.5-flash-2026-02-23", "qwen3.5-plus", "qwen3.5-plus-2026-02-15", "qwen3.5-plus-2026-04-20",
        "qwen3.6-27b", "qwen3.6-35b-a3b", "qwen3.6-flash", "qwen3.6-flash-2026-04-16",
        "qwen3.6-plus", "qwen3.6-plus-2026-04-02", "qwen3.7-flash", "qwen3.7-flash-2026-07-15",
        "qwen3.7-max", "qwen3.7-max-2026-05-17", "qwen3.7-max-2026-05-20", "qwen3.7-max-2026-06-08",
        "qwen3.7-max-preview", "qwen3.7-plus", "qwen3.7-plus-2026-05-26",
        "qwen3.8-2.4t-a95b", "qwen3.8-27b", "qwen3.8-flash", "qwen3.8-max", "qwen3.8-max-0902"
    ]

    /// True for Alibaba's free-tier-only exhaustion response.
    static func isExhausted(status: Int, body: Data) -> Bool {
        guard status == 403 else { return false }
        let text = String(data: body, encoding: .utf8) ?? ""
        return text.contains("FreeTierOnly") || text.localizedCaseInsensitiveContains("free tier")
            || text.localizedCaseInsensitiveContains("free quota")
    }
}

/// Models whose free quota ran out during this app session, skipped on later requests.
final class FreeQuotaExhaustionRegistry: @unchecked Sendable {
    static let shared = FreeQuotaExhaustionRegistry()
    private let lock = NSLock()
    private var exhausted: Set<String> = []
    func markExhausted(_ modelID: String, adapterID: String) {
        lock.lock(); defer { lock.unlock() }
        exhausted.insert(adapterID + "|" + modelID)
    }
    func isExhausted(_ modelID: String, adapterID: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return exhausted.contains(adapterID + "|" + modelID)
    }
    func reset() {
        lock.lock(); defer { lock.unlock() }
        exhausted.removeAll()
    }
}
