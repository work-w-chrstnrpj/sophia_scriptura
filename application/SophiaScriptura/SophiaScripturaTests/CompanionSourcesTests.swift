import XCTest
@testable import SophiaScriptura

@MainActor
final class CompanionSourcesTests: XCTestCase {
    private func session(adapterID: String = "mock", model: String = "mock", chunks: [String] = ["Fixture answer"]) throws -> CompanionSession {
        let session = CompanionSession(presetCatalog: try PromptPresetCatalog.bundled(), repository: nil,
            credentials: InMemoryCompanionCredentialsStore(), registry: ProviderRegistry(adapters: [MockLLMProviderAdapter(id: adapterID, scriptedChunks: chunks)]))
        try session.saveProviderKey("fixture-key", adapterID: adapterID, accountLabel: "Test", defaultModelID: model)
        return session
    }

    func testSourcesNormalizeMarkdownURLsRejectUnsafeLinksAndOfferLookup() throws {
        let parsed = CompanionResponseFormatting.splitSourcesAppendix(from: """
        An explanation.
        ### Sophia bibliography (app only)
        - Reference | Author | [Read](https://example.org/reference) | Context
        - Printed work | Author | none | Background
        - none | none | none | none
        - Unsafe | Author | javascript:alert(1) | Claim
        """)
        XCTAssertEqual(parsed.appendixSources.count, 3)
        XCTAssertEqual(parsed.appendixSources.first?.url, "https://example.org/reference")
        XCTAssertNil(parsed.appendixSources[1].url)
        XCTAssertNotNil(CompanionStudySources.lookupURL(for: parsed.appendixSources[1]))
        XCTAssertNil(parsed.appendixSources[2].url)
        XCTAssertNil(CompanionResponseFormatting.validWebURL("https://user:password@example.org"))
        XCTAssertNil(CompanionResponseFormatting.validWebURL("file:///private/data"))
        XCTAssertEqual(CompanionStudySources.provenanceLabel(for: parsed.appendixSources[0]), "Model reference · not verified")
    }

    func testSourcesIncludesActualSelectedPassageLinkEvenWithoutBibliography() throws {
        let session = try session()
        let id = try XCTUnwrap(session.askFromChapter(CompanionChapterAnchor(bookID: "1TH", chapter: 2,
            editionID: "web.engwebp", referenceLabel: "1 Thessalonians Chapter 2 (WEB)")))
        let message = CompanionMessage(conversationID: id, sequence: 1, role: .assistant,
            content: "An explanation with [a reference](https://example.org/study).", deliveryState: .complete)
        let sources = session.sources(for: message)
        XCTAssertEqual(sources.first?.url, "https://ebible.org/engwebp/1TH02.htm")
        XCTAssertTrue(sources.contains { $0.url == "https://example.org/study" })
        XCTAssertFalse(message.retrievalPerformed)
    }

    func testBibliographyDoesNotPretendToBeRetrievedEvidence() async throws {
        let session = try session(chunks: ["Answer.\n\n### Sophia bibliography (app only)\n- Work | Author | https://example.org | Claim"])
        let id = try XCTUnwrap(session.createConversation())
        session.updateComposerDraft("Explain this passage")
        await session.sendMessage()
        let completed = try XCTUnwrap(session.messages(for: id).last)
        XCTAssertEqual(completed.deliveryState, .complete)
        XCTAssertFalse(completed.retrievalPerformed)
        XCTAssertNotEqual(completed.retrievalAvailable, true)
        XCTAssertEqual(session.sources(for: completed).first?.url, "https://example.org")
    }

    func testScreenshotDraftArtifactsFailAndPreserveAttemptForRecovery() async throws {
        for text in ["<div class=\"verse\">2 Thessalonians 2:14</div>", "Verse 3:3-<PRESIDIO_ANDROID: Mate", "[Question or engagement prompt, if necessary: Who?"] {
            let session = try session(chunks: [text])
            let id = try XCTUnwrap(session.createConversation())
            session.updateComposerDraft("Explain this passage")
            await session.sendMessage()
            let result = try XCTUnwrap(session.messages(for: id).last)
            XCTAssertEqual(result.deliveryState, .failed)
            XCTAssertFalse(result.content.contains(text))
            XCTAssertEqual(result.attempts.last?.content, text)
        }
        XCTAssertFalse(CompanionResponseFormatting.containsDraftArtifacts("## Meaning\n\nPaul speaks to please God, who tests hearts."))
    }

    func testGroqModelFallbackPrefersCuratedChatModelOverAlphabeticalFirst() {
        let options = ProviderModelCatalog.mergeRemote(ids: ["allam-2-7b", "openai/gpt-oss-120b", "openai/gpt-oss-20b"], adapterID: "groq")
        XCTAssertEqual(options.first?.modelID, "openai/gpt-oss-120b")
        XCTAssertEqual(ProviderModelCatalog.pickModel(currentID: "missing", options: options, adapterID: "groq", preferFree: true), "openai/gpt-oss-120b")
        XCTAssertEqual(ProviderModelCatalog.pickModel(currentID: "allam-2-7b", options: options, adapterID: "groq"), "allam-2-7b", "Explicit selections remain available.")
        XCTAssertEqual(ProviderModelCatalog.scriptureAskModel(currentID: "allam-2-7b", options: options, adapterID: "groq"), "openai/gpt-oss-120b")
    }

    func testNewManualAskCorrectsAllamFallbackWithoutChangingOLASelection() throws {
        let session = try session(adapterID: "groq", model: "allam-2-7b")
        let selection = ChapterTextMap.Selection(text: "approved", editionID: "web.engwebp", contentRevision: "fixture", sourceLabels: [], passages: [])
        _ = session.askFromScripture(selection: selection, referenceLabel: "1 Thessalonians 2:4", transmittedText: "approved",
            bookID: "1TH", chapter: 2, startVerse: 4, endVerse: 4, translationName: "WEB", verseContextText: "Approved by God.")
        XCTAssertEqual(session.selectedConversation?.modelID, "openai/gpt-oss-120b")
        XCTAssertTrue(session.notice?.contains("Using openai/gpt-oss-120b") == true)
        _ = session.askFromScripture(selection: selection, referenceLabel: "1 Thessalonians 2:4", transmittedText: "approved",
            bookID: "1TH", chapter: 2, startVerse: 4, endVerse: 4, action: .originalLanguageAnalysis,
            translationName: "WEB", verseContextText: "Approved by God.")
        XCTAssertEqual(session.selectedConversation?.modelID, "allam-2-7b")
    }
}
