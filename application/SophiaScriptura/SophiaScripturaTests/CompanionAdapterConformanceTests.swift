import XCTest
@testable import SophiaScriptura

final class CompanionAdapterConformanceTests: XCTestCase {
    private let adapters: [any LLMProviderAdapter] = [
        MockLLMProviderAdapter(id: "openai"),
        MockLLMProviderAdapter(id: "anthropic"),
        MockLLMProviderAdapter(id: "gemini")
    ]

    func testMockAdaptersEmitNormalizedEventOrder() async throws {
        let request = LLMCompletionRequest(modelID: "mock", systemInstruction: "Test", turns: [LLMChatTurn(role: .user, content: "Hi")])
        for adapter in adapters {
            var events: [String] = []
            for try await event in adapter.streamCompletion(apiKey: "key", request: request) {
                switch event {
                case .responseStarted: events.append("start")
                case .textDelta: events.append("delta")
                case .completed: events.append("done")
                default: break
                }
            }
            XCTAssertEqual(events.first, "start")
            XCTAssertEqual(events.last, "done")
            XCTAssertTrue(events.contains("delta"))
        }
    }

    func testAllProductionAdaptersAdvertiseStreaming() {
        for adapter in ProviderRegistry.production().supportedAdapters {
            XCTAssertTrue(adapter.advertisedCapabilities(modelID: "test").contains(.streaming))
        }
    }

    func testProductionRegistryIncludesRequestedVendors() {
        let ids = Set(ProviderRegistry.production().supportedAdapters.map(\.id))
        XCTAssertEqual(ids.count, ProviderRegistry.production().supportedAdapters.count)
        for expected in ["openai", "anthropic", "gemini", "openrouter", "github", "nvidia", "cerebras", "groq", "mistral"] {
            XCTAssertTrue(ids.contains(expected), "Missing adapter \(expected)")
        }
    }

    func testPresetCatalogIncludesFiveApprovedPresets() throws {
        let catalog = try PromptPresetCatalog.bundled()
        XCTAssertEqual(catalog.presets.count, 5)
        XCTAssertEqual(catalog.defaultPresetID(), "default")
        XCTAssertNotNil(catalog.snapshot(for: "default"))
        XCTAssertNotNil(catalog.snapshot(for: "apologetics"))
        XCTAssertNotNil(catalog.snapshot(for: "tough-questions"))
        XCTAssertTrue(catalog.snapshot(for: "default")!.resolvedInstruction.contains("Pastoral and safety limits"))
    }
}
