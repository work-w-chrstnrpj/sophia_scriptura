import Foundation

enum LLMProviderCapability: String, Codable, Sendable, CaseIterable {
    case streaming
    case structuredOutput
    case tools
    case providerRetrieval
    case usageReporting
    case cancellation
}

enum LLMProviderError: Error, LocalizedError, Sendable, Equatable {
    case missingCredential
    case offline
    case invalidCredential
    case rateLimited
    case refused(String)
    case malformedResponse
    case transport(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingCredential: return "Add an API key in Settings before sending."
        case .offline: return "Companion needs a network connection to reach the provider."
        case .invalidCredential: return "The provider rejected the API key."
        case .rateLimited: return "The provider rate-limited this request. Try again shortly."
        case .refused(let reason): return reason
        case .malformedResponse: return "The provider returned an unreadable response."
        case .transport(let detail): return detail
        case .cancelled: return "The response was cancelled."
        }
    }
}

enum LLMStreamEvent: Sendable {
    case responseStarted
    case textDelta(String)
    case sourceEvidence(CompanionSource)
    case completed
    case refused(String)
    case failed(LLMProviderError)
}

struct LLMChatTurn: Sendable {
    var role: CompanionMessageRole
    var content: String
}

struct LLMCompletionRequest: Sendable {
    var modelID: String
    var systemInstruction: String
    var turns: [LLMChatTurn]
    /// When true, adapters that support OpenAI-style `response_format` request a JSON object.
    var preferJSONObject: Bool = false
}

/// Provider-neutral streaming boundary. Concrete adapters live in Infrastructure/Companion.
protocol LLMProviderAdapter: Sendable {
    var id: String { get }
    var displayName: String { get }

    func advertisedCapabilities(modelID: String) -> Set<LLMProviderCapability>
    func validateConnection(apiKey: String, modelID: String) async throws
    func listModels(apiKey: String) async throws -> [String]
    func streamCompletion(apiKey: String, request: LLMCompletionRequest) -> AsyncThrowingStream<LLMStreamEvent, Error>
}
