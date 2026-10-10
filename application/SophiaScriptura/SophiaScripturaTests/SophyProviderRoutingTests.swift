import XCTest
@testable import SophiaScriptura

private struct RoutingHTTPResponse {
    var status: Int
    var data: Data
    var mime: String = "application/json"
}

private final class RoutingHTTPStub: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> Result<RoutingHTTPResponse, Error>)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        switch handler(request) {
        case .success(let response):
            let http = HTTPURLResponse(
                url: request.url ?? URL(string: "https://router.huggingface.co")!,
                statusCode: response.status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": response.mime]
            )!
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@MainActor
final class SophyProviderRoutingTests: XCTestCase {
    override func tearDown() {
        RoutingHTTPStub.handler = nil
        super.tearDown()
    }

    func testLegacySnapshotOmitsSharedRouteAndResolvesFirstSavedKey() throws {
        let first = ProviderConfigurationRecord(adapterID: "groq", accountLabel: "Personal", defaultModelID: "llama-3.1-8b-instant")
        let second = ProviderConfigurationRecord(adapterID: "openai", accountLabel: "Personal", defaultModelID: "gpt-4o-mini")
        let legacy = """
        {"schemaVersion":3,"providerConfigurations":[
        {"id":"\(first.id.uuidString)","adapterID":"groq","accountLabel":"Personal","defaultModelID":"llama-3.1-8b-instant","createdAt":0,"updatedAt":0},
        {"id":"\(second.id.uuidString)","adapterID":"openai","accountLabel":"Personal","defaultModelID":"gpt-4o-mini","createdAt":1,"updatedAt":1}
        ]}
        """.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(CompanionSnapshot.self, from: legacy)
        XCTAssertNil(snapshot.defaultProviderConfigID)
        XCTAssertNil(snapshot.defaultModelID)

        let (session, credentials) = try makeSession()
        session.apply(snapshot)
        try credentials.writeKey("a", for: first.id)
        try credentials.writeKey("b", for: second.id)
        let route = try XCTUnwrap(session.resolvedSharedRoute())
        XCTAssertEqual(route.configurationID, first.id)
        XCTAssertEqual(route.modelID, "llama-3.1-8b-instant")
    }

    func testExplicitSharedRouteCreatesNewChatsWithoutRetargetingStoredOnes() throws {
        let (session, credentials) = try makeSession()
        let groq = ProviderConfigurationRecord(adapterID: "groq", accountLabel: "Personal", defaultModelID: "llama-3.1-8b-instant")
        let openAI = ProviderConfigurationRecord(adapterID: "openai", accountLabel: "Personal", defaultModelID: "gpt-4o-mini")
        session.apply(CompanionSnapshot(providerConfigurations: [groq, openAI]))
        try credentials.writeKey("g", for: groq.id)
        try credentials.writeKey("o", for: openAI.id)
        let existing = try XCTUnwrap(session.createConversation())
        XCTAssertEqual(session.conversations.first { $0.id == existing }?.modelID, "llama-3.1-8b-instant")

        session.setSharedProviderRoute(configurationID: openAI.id, modelID: "gpt-4o")
        session.selectConversation(existing)
        XCTAssertEqual(session.defaultProviderConfigID, openAI.id)
        XCTAssertEqual(session.conversations.first { $0.id == existing }?.providerConfigID, groq.id)
        XCTAssertEqual(session.conversations.first { $0.id == existing }?.modelID, "llama-3.1-8b-instant")

        let created = try XCTUnwrap(session.createConversation())
        XCTAssertEqual(session.conversations.first { $0.id == created }?.providerConfigID, openAI.id)
        XCTAssertEqual(session.conversations.first { $0.id == created }?.modelID, "gpt-4o")
        XCTAssertEqual(session.conversations.first { $0.id == existing }?.modelID, "llama-3.1-8b-instant")
    }

    func testQuizKeepsExplicitDefaultsAndInheritsSharedRouteOnlyWhenAbsent() throws {
        let (session, credentials) = try makeSession()
        let groq = ProviderConfigurationRecord(adapterID: "groq", accountLabel: "Personal", defaultModelID: "llama-3.3-70b-versatile")
        let openAI = ProviderConfigurationRecord(adapterID: "openai", accountLabel: "Personal", defaultModelID: "gpt-4o-mini")
        session.apply(CompanionSnapshot(providerConfigurations: [groq, openAI]))
        try credentials.writeKey("g", for: groq.id)
        try credentials.writeKey("o", for: openAI.id)
        session.setSharedProviderRoute(configurationID: openAI.id, modelID: "gpt-4o")

        let inherited = try XCTUnwrap(session.resolvedQuizProviderConfiguration())
        XCTAssertEqual(inherited.id, openAI.id)
        XCTAssertEqual(session.resolvedQuizModelID(for: inherited), "gpt-4o")

        session.updateQuizDefaults(providerConfigID: groq.id, modelID: "llama-3.1-8b-instant")
        let explicit = try XCTUnwrap(session.resolvedQuizProviderConfiguration())
        XCTAssertEqual(explicit.id, groq.id)
        XCTAssertEqual(session.resolvedQuizModelID(for: explicit), "llama-3.1-8b-instant")
        XCTAssertEqual(session.defaultProviderConfigID, openAI.id)
        XCTAssertEqual(session.defaultModelID, "gpt-4o")
    }

    func testRemovedSharedRouteDoesNotSilentlySwitchProvider() throws {
        let (session, credentials) = try makeSession()
        let groq = ProviderConfigurationRecord(adapterID: "groq", accountLabel: "Personal", defaultModelID: "llama-3.1-8b-instant")
        let openAI = ProviderConfigurationRecord(adapterID: "openai", accountLabel: "Personal", defaultModelID: "gpt-4o-mini")
        session.apply(CompanionSnapshot(providerConfigurations: [groq, openAI]))
        try credentials.writeKey("g", for: groq.id)
        try credentials.writeKey("o", for: openAI.id)
        session.setSharedProviderRoute(configurationID: groq.id, modelID: "llama-3.1-8b-instant")
        try credentials.deleteKey(for: groq.id)
        XCTAssertNil(session.resolvedSharedRoute())
        XCTAssertNil(session.createConversation())
    }

    func testSharedRouteRoundTripsAndLegacyBackupStillLoads() throws {
        let id = UUID()
        var snapshot = CompanionSnapshot(
            providerConfigurations: [ProviderConfigurationRecord(id: id, adapterID: "huggingface", accountLabel: "Personal", defaultModelID: "org/model:groq")],
            defaultProviderConfigID: id,
            defaultModelID: "org/model:groq"
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(CompanionSnapshot.self, from: data)
        XCTAssertEqual(decoded.defaultProviderConfigID, id)
        XCTAssertEqual(decoded.defaultModelID, "org/model:groq")

        snapshot.defaultProviderConfigID = nil
        snapshot.defaultModelID = nil
        let cleared = try JSONDecoder().decode(CompanionSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertNil(cleared.defaultProviderConfigID)
    }

    func testHuggingFaceDoesNotMarkModelsFreeOrAutoSelectOne() {
        XCTAssertFalse(ProviderModelCatalog.supportsFreeModelFilter(adapterID: "huggingface"))
        XCTAssertTrue(ProviderModelCatalog.allowsManualModelEntry(adapterID: "huggingface"))
        XCTAssertEqual(ProviderModelCatalog.defaultModelID(adapterID: "huggingface"), "")
        let merged = ProviderModelCatalog.mergeRemote(
            ids: ["meta/Llama:fastest", "org/model:free"],
            adapterID: "huggingface"
        )
        XCTAssertTrue(merged.allSatisfy { $0.isFree == false && !$0.label.contains("(free)") })
        XCTAssertEqual(
            ProviderModelCatalog.pickModel(currentID: "org/model:groq", options: merged, adapterID: "huggingface"),
            "org/model:groq"
        )
        XCTAssertEqual(
            ProviderModelCatalog.pickModel(currentID: "", options: merged, adapterID: "huggingface"),
            ""
        )
    }

    func testHuggingFaceInferenceFailureIsNotHiddenByModelList() async throws {
        let adapter = huggingFaceAdapter()
        var paths: [String] = []
        RoutingHTTPStub.handler = { request in
            paths.append(request.url?.path ?? "")
            if request.url?.path.contains("models") == true {
                return .success(RoutingHTTPResponse(status: 200, data: Data(#"{"data":[{"id":"org/model:groq"}]}"#.utf8)))
            }
            return .success(RoutingHTTPResponse(status: 401, data: Data(#"{"error":"no"}"#.utf8)))
        }
        do {
            try await adapter.validateConnection(apiKey: "hf_test", modelID: "org/model:groq")
            XCTFail("Expected inference rejection")
        } catch let error as LLMProviderError {
            XCTAssertEqual(error, .invalidCredential)
        }
        XCTAssertEqual(paths, ["/v1/chat/completions"])
    }

    func testHuggingFaceMapsAuthQuotaModelAndOfflineErrors() async throws {
        let adapter = huggingFaceAdapter()
        let cases: [(Int, LLMProviderError)] = [
            (403, .refused("The Hugging Face token needs the Inference Providers permission.")),
            (404, .refused("That model is unavailable. Enter the exact model id, including any routing suffix.")),
            (429, .rateLimited)
        ]
        for item in cases {
            RoutingHTTPStub.handler = { _ in .success(RoutingHTTPResponse(status: item.0, data: Data("secret-body".utf8))) }
            do {
                try await adapter.validateConnection(apiKey: "hf_test", modelID: "org/model:groq")
                XCTFail("Expected \(item.0)")
            } catch let error as LLMProviderError {
                XCTAssertEqual(error, item.1)
                XCTAssertFalse(String(describing: error).contains("secret-body"))
            }
        }
        RoutingHTTPStub.handler = { _ in .failure(URLError(.notConnectedToInternet)) }
        do {
            try await adapter.validateConnection(apiKey: "hf_test", modelID: "org/model:groq")
            XCTFail("Expected offline")
        } catch let error as LLMProviderError {
            XCTAssertEqual(error, .offline)
        }
        do {
            try await adapter.validateConnection(apiKey: "hf_test", modelID: "  ")
            XCTFail("Expected missing model")
        } catch let error as LLMProviderError {
            XCTAssertEqual(error, .refused("Enter an exact model id before testing this connection."))
        }
    }

    func testHuggingFaceStreamsSelectedModelAndRejectsMalformedPayloads() async throws {
        let adapter = huggingFaceAdapter()
        let probe = LLMCompletionRequest(
            modelID: "org/model:groq",
            systemInstruction: "rules",
            turns: [LLMChatTurn(role: .user, content: "Hi")],
            preferJSONObject: true
        )
        let encoded = try OpenAICompatibleProviderAdapter.completionBody(for: probe)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "org/model:groq")
        XCTAssertEqual((body["response_format"] as? [String: Any])?["type"] as? String, "json_object")
        RoutingHTTPStub.handler = { _ in
            let payload = """
            data: {"choices":[{"delta":{"content":"Hello"}}]}

            data: [DONE]

            """
            return .success(RoutingHTTPResponse(status: 200, data: Data(payload.utf8), mime: "text/event-stream"))
        }
        var text = ""
        var events: [String] = []
        for try await event in adapter.streamCompletion(
            apiKey: "hf_test",
            request: LLMCompletionRequest(modelID: "org/model:groq", systemInstruction: "rules", turns: [LLMChatTurn(role: .user, content: "Hi")])
        ) {
            switch event {
            case .responseStarted: events.append("start")
            case .textDelta(let delta):
                events.append("delta")
                text += delta
            case .completed: events.append("done")
            case .failed(let error):
                XCTFail("Unexpected \(error)")
            default: break
            }
        }
        XCTAssertEqual(events, ["start", "delta", "done"])
        XCTAssertEqual(text, "Hello")

        RoutingHTTPStub.handler = { _ in
            .success(RoutingHTTPResponse(status: 200, data: Data(#"{"error":{"message":"bad"}}"#.utf8)))
        }
        var failed: LLMProviderError?
        for try await event in adapter.streamCompletion(
            apiKey: "hf_test",
            request: LLMCompletionRequest(modelID: "org/model:groq", systemInstruction: "rules", turns: [])
        ) {
            if case .failed(let error) = event { failed = error }
        }
        XCTAssertEqual(failed, .malformedResponse)
    }

    func testHuggingFaceListKeepsRoutingSuffixWhenListingFailsSelectionStays() async throws {
        let adapter = huggingFaceAdapter()
        RoutingHTTPStub.handler = { _ in
            .success(RoutingHTTPResponse(status: 200, data: Data(#"{"data":[{"id":"org/model:featherless-ai"}]}"#.utf8)))
        }
        let ids = try await adapter.listModels(apiKey: "hf_test")
        XCTAssertEqual(ids, ["org/model:featherless-ai"])

        let (session, credentials) = try makeSession()
        try session.saveProviderKey("hf_test", adapterID: "huggingface", accountLabel: "Personal", defaultModelID: "org/kept:groq")
        let config = try XCTUnwrap(session.providerConfigurations.first { $0.adapterID == "huggingface" })
        try credentials.writeKey("hf_test", for: config.id)
        RoutingHTTPStub.handler = { _ in .success(RoutingHTTPResponse(status: 500, data: Data())) }
        let message = await session.refreshModelCatalog(for: config.id)
        XCTAssertNotNil(message)
        XCTAssertEqual(session.providerRecord(for: config.id)?.defaultModelID, "org/kept:groq")
        XCTAssertTrue(session.modelOptions(for: config.id).contains { $0.modelID == "org/kept:groq" && $0.isFree == false })
    }

    func testExistingGroqValidationStillUsesModelListOnly() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RoutingHTTPStub.self]
        let adapter = OpenAICompatibleProviderAdapter.groq(session: URLSession(configuration: configuration))
        var methods: [String] = []
        RoutingHTTPStub.handler = { request in
            methods.append(request.httpMethod ?? "")
            return .success(RoutingHTTPResponse(status: 200, data: Data(#"{"data":[{"id":"llama-3.1-8b-instant"}]}"#.utf8)))
        }
        try? await adapter.validateConnection(apiKey: "key", modelID: "llama-3.1-8b-instant")
        XCTAssertEqual(methods, ["GET"])
    }

    func testProductionRegistryIncludesHuggingFaceWithoutDroppingExistingAdapters() {
        let ids = Set(ProviderRegistry.production().supportedAdapters.map(\.id))
        XCTAssertTrue(ids.contains("huggingface"))
        XCTAssertEqual(ids.count, 10)
        let hugging = ProviderRegistry.production().adapter(id: "huggingface")
        XCTAssertEqual(hugging?.displayName, "Hugging Face")
        XCTAssertFalse(hugging?.advertisedCapabilities(modelID: "org/model:groq").contains(.tools) ?? true)
    }

    private func huggingFaceAdapter() -> OpenAICompatibleProviderAdapter {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RoutingHTTPStub.self]
        return OpenAICompatibleProviderAdapter.huggingface(session: URLSession(configuration: configuration))
    }

    private func makeSession() throws -> (CompanionSession, InMemoryCompanionCredentialsStore) {
        let credentials = InMemoryCompanionCredentialsStore()
        let session = CompanionSession(
            presetCatalog: try PromptPresetCatalog.bundled(),
            repository: nil,
            credentials: credentials,
            registry: ProviderRegistry(adapters: [
                OpenAIProviderAdapter(),
                OpenAICompatibleProviderAdapter.groq(session: stubSession()),
                OpenAICompatibleProviderAdapter.huggingface(session: stubSession())
            ])
        )
        return (session, credentials)
    }

    private func stubSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RoutingHTTPStub.self]
        return URLSession(configuration: configuration)
    }
}
