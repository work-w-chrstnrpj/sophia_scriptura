import XCTest
import SwiftUI
@testable import SophiaScriptura

@MainActor
final class CompanionTests: XCTestCase {
    func testMessageLayoutExpandsToPanelWidthForTableReplies() {
        let markdown = """
        | Book | Author | Theme |
        | --- | --- | --- |
        | Genesis | Moses | Creation |
        | Exodus | Moses | Deliverance |
        """
        func measured(wide: Bool, panel: CGFloat) -> CGSize {
            let host = UIHostingController(rootView: CompanionMessageLayout(allowsWideExpansion: wide) {
                CompanionMarkdownText(content: markdown)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            })
            return host.sizeThatFits(in: CGSize(width: panel, height: 10_000))
        }
        XCTAssertLessThanOrEqual(measured(wide: false, panel: 900).width, 560)
        XCTAssertEqual(measured(wide: true, panel: 900).width, 900)
    }

    func testMessageLayoutHugsShortPromptsAndWrapsLongPromptsInNarrowPanel() {
        func measured(_ text: String, width: CGFloat) -> CGSize {
            let host = UIHostingController(rootView: CompanionMessageLayout {
                Text(text).padding(.horizontal, 12).padding(.vertical, 10)
            })
            return host.sizeThatFits(in: CGSize(width: width, height: 10_000))
        }
        let short = measured("Hi", width: 560)
        let long = measured(String(repeating: "Study this passage in context. ", count: 20), width: 240)
        XCTAssertLessThan(short.width, 120)
        XCTAssertLessThanOrEqual(long.width, 240)
        XCTAssertGreaterThan(long.height, short.height * 2)
    }

    func testPromptPresetCatalogResolvesSharedGuardrail() throws {
        let catalog = try PromptPresetCatalog.bundled()
        let snapshot = try XCTUnwrap(catalog.snapshot(for: "biblical-studies"))
        XCTAssertTrue(snapshot.resolvedInstruction.contains("historic orthodox Christian faith"))
        XCTAssertFalse(snapshot.resolvedInstruction.contains("{{sharedGuardrail}}"))
    }

    func testContextBuilderRespectsCharacterBudget() throws {
        let preset = try XCTUnwrap(try PromptPresetCatalog.bundled().snapshot(for: "biblical-studies"))
        let conversation = CompanionConversation(
            providerConfigID: UUID(),
            providerAdapterID: "mock",
            modelID: "mock",
            presetSnapshot: preset,
            capabilitySnapshot: ProviderCapabilitySnapshot(
                adapterID: "mock",
                modelID: "mock",
                streaming: true,
                providerRetrieval: false,
                tools: false,
                usageReporting: false,
                cancellation: true
            )
        )
        let long = String(repeating: "a", count: 30_000)
        let messages = [
            CompanionMessage(conversationID: conversation.id, sequence: 0, role: .user, content: long, deliveryState: .complete)
        ]
        let request = CompanionContextBuilder.completionRequest(conversation: conversation, messages: messages, attachments: [], pendingUserText: "hi")
        XCTAssertLessThanOrEqual(request.turns.map(\.content.count).reduce(0, +), CompanionContextBuilder.maxTurnCharacters)
        XCTAssertTrue(request.systemInstruction.contains("Output contract (required)"))
        XCTAssertTrue(request.systemInstruction.contains("Every assistant reply MUST be valid Markdown"))
        XCTAssertFalse(request.systemInstruction.contains("First short paragraph."))
        XCTAssertTrue(request.systemInstruction.contains("The app previews standard Markdown"))
        XCTAssertTrue(request.systemInstruction.contains("Use actual newline characters"))
        XCTAssertFalse(request.systemInstruction.contains("you may use the literal"))
        XCTAssertTrue(request.systemInstruction.contains("Study scope:"))
        XCTAssertTrue(request.systemInstruction.contains("Pastoral and safety limits."))
    }

    func testStreamingPreservesBoldDelimitersAcrossChunkBoundaries() {
        let chunks = ["The theme is ", "**", "abiding sufficiency", "**",
                      " as Shepherd.\n\n- ", "**", "The Lord as Host:", "**", " He provides."]
        let expected = chunks.joined()
        let streamed = chunks.reduce("") {
            CompanionResponseFormatting.joinStreamDelta(existing: $0, delta: $1)
        }
        XCTAssertEqual(streamed, expected)
        XCTAssertEqual(CompanionResponseFormatting.finalizeAssistantMarkdown(streamed), expected)
        let blocks = CompanionMarkdownText.blocks(for: streamed)
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks.last?.marker, "•")
        XCTAssertFalse(blocks.contains { String($0.text.characters).contains("**") })
        XCTAssertTrue(blocks[0].text.runs.contains {
            $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
        })
    }

    func testEveryCharacterStreamPreservesMarkdownURLsAndCode() {
        let sample = """
        ## A heading

        **Grace** and *peace*. A [link](https://example.com/A.B?q=C#D).

        > A quote

        `literal\\n **markers**`
        """
        let streamed = sample.reduce("") {
            CompanionResponseFormatting.joinStreamDelta(existing: $0, delta: String($1))
        }
        XCTAssertEqual(streamed, sample)
        XCTAssertEqual(CompanionResponseFormatting.finalizeAssistantMarkdown("  " + streamed + "\n"),
                       "  " + sample + "\n")
        XCTAssertEqual(CompanionResponseFormatting.joinStreamDelta(existing: sample, delta: ""), sample)
    }

    private var psalmMarkdown: String {
        """
        ## The Main Theme: The Lord as the Sufficient Shepherd

        The central theme of Psalm 23 is the **abiding sufficiency and presence of the Lord** as the Shepherd of His people. Through the imagery of a shepherd caring for his sheep, David expresses trust in God's provision.

        ## Literary Structure and Meaning

        - **The Lord as Shepherd (Verses 1–4):** The imagery is that of a gentle provider.
        - **The Lord as Host (Verses 5–6):** The imagery shifts to the pasture and the banquet table.

        See [Psalm 23](https://example.com/psalm23) and consider *His presence*.

        > The Lord is my shepherd.
        """
    }

    func testFullMarkdownParserKeepsEmphasisInsideParagraphsAndLists() throws {
        let blocks = CompanionMarkdownText.blocks(for: psalmMarkdown)
        XCTAssertEqual(blocks.count, 7)
        XCTAssertEqual(blocks.compactMap(\.headingLevel), [2, 2])
        XCTAssertEqual(blocks.compactMap(\.marker), ["•", "•"])
        XCTAssertTrue(blocks.last?.isQuote == true)
        XCTAssertFalse(blocks.contains { String($0.text.characters).contains("**") })
        for index in [1, 3, 4] {
            XCTAssertTrue(blocks[index].text.runs.contains {
                $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
            })
        }
        let link = try XCTUnwrap(blocks[5].text.runs.compactMap(\.link).first)
        XCTAssertEqual(link.absoluteString, "https://example.com/psalm23")
        XCTAssertTrue(blocks[5].text.runs.contains {
            $0.inlinePresentationIntent?.contains(.emphasized) == true
        })
    }

    func testMarkdownPreviewUsesParserForOrderedNestedListsAndCode() {
        let markdown = """
        3. **Read** the passage.
        4. Compare the context.
           - A nested item

        ```text
        **literal code**
        second line
        ```
        """
        let blocks = CompanionMarkdownText.blocks(for: markdown)
        XCTAssertEqual(blocks.compactMap(\.marker), ["3.", "4.", "•"])
        XCTAssertEqual(blocks[2].listDepth, 1)
        XCTAssertTrue(blocks.last?.isCode == true)
        XCTAssertTrue(String(blocks.last!.text.characters).contains("**literal code**"))
    }

    func testMarkdownTableRendersAsTableSegmentNotListRows() {
        let markdown = """
        Compare these books:

        | Book | Theme |
        | --- | --- |
        | Genesis | Creation |
        | Exodus | Deliverance |

        Both point to Christ.
        """
        let segments = CompanionMarkdownTableParser.segments(from: markdown)
        XCTAssertEqual(segments.count, 3)
        guard case .prose(let lead) = segments[0] else { return XCTFail("Expected opening prose") }
        XCTAssertTrue(lead.contains("Compare these books"))
        guard case .table(let table) = segments[1] else { return XCTFail("Expected table segment") }
        XCTAssertEqual(table.headers, ["Book", "Theme"])
        XCTAssertEqual(table.rows, [["Genesis", "Creation"], ["Exodus", "Deliverance"]])
        let tableBlocks = CompanionMarkdownText.blocks(for: "| A | B |\n| --- | --- |\n| 1 | 2 |")
        XCTAssertTrue(tableBlocks.count > 1, "Unsplit pipe markdown would fragment into multiple blocks")
        guard case .prose(let tail) = segments[2] else { return XCTFail("Expected trailing prose") }
        XCTAssertTrue(tail.contains("Both point to Christ"))
    }

    func testMarkdownDoesNotInventParagraphsOrAlterEscapedCode() {
        let markdown = "First sentence. Second sentence. **Inline bold** follows. `\\n` is code."
        let blocks = CompanionMarkdownText.blocks(for: markdown)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertTrue(String(blocks[0].text.characters).contains("\\n"))
        XCTAssertEqual(CompanionResponseFormatting.finalizeAssistantMarkdown(markdown), markdown)
        XCTAssertTrue(CompanionMarkdownText.blocks(for: "").isEmpty)
    }

    func testMarkdownPreviewVisualSnapshotsInLightAndDarkPanels() throws {
        for (width, scheme) in [(CGFloat(560), ColorScheme.light), (CGFloat(360), ColorScheme.dark)] {
            let preview = CompanionMarkdownText(content: psalmMarkdown)
                .padding(16)
                .frame(width: width)
                .background(scheme == .light ? Color.white : Color(red: 0.17, green: 0.15, blue: 0.19))
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: preview)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertGreaterThan(image.size.height, 300)
            let attachment = XCTAttachment(image: image)
            attachment.name = "Markdown-preview-\(Int(width))-\(scheme)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testOriginalLanguageAnalysisBuildsStructuredContextualPrompt() {
        let prompt = CompanionSession.ScriptureCompanionAction.originalLanguageAnalysis.composerPrompt(
            referenceLabel: "John 1:1",
            bookID: "JHN",
            transmittedText: "In the beginning was the Word"
        )
        XCTAssertTrue(prompt.contains("Koine Greek"))
        XCTAssertTrue(prompt.contains("## Key words and grammar"))
        XCTAssertTrue(prompt.contains("sentence and passage context"))
        XCTAssertTrue(prompt.contains("> In the beginning was the Word"))
        let card = ScriptureCompanionPrompts.originalLanguageDisplayCard(
            referenceLabel: "John 1:1",
            transmittedText: "In the beginning was the Word"
        )
        XCTAssertTrue(card.contains("Original Language Analysis — Phrase analysis"))
        XCTAssertTrue(card.contains("In the beginning was the Word"))
        XCTAssertTrue(card.contains("*John 1:1*"))
        XCTAssertFalse(card.contains("Koine Greek"))
    }

    func testSourcesAppendixIsStrippedAndParsed() {
        let raw = """
        ## Meaning
        Main answer here.

        ### Sophia bibliography (app only)
        - Brown-Driver-Briggs | Hendrickson | https://example.org/bdb | Hebrew lexicon
        - none | Local note | none | Context from MT
        """
        let parsed = CompanionResponseFormatting.splitSourcesAppendix(from: raw)
        XCTAssertFalse(parsed.displayMarkdown.contains("Sophia bibliography"))
        XCTAssertEqual(parsed.appendixSources.count, 1)
        XCTAssertEqual(parsed.appendixSources[0].title, "Brown-Driver-Briggs")
        XCTAssertEqual(parsed.appendixSources[0].url, "https://example.org/bdb")
    }

    func testGenesisOriginalLanguagePromptUsesHebrewNotGreek() {
        let prompt = ScriptureCompanionPrompts.originalLanguageAnalysis(
            referenceLabel: "Genesis 1:1–2",
            bookID: "GEN",
            transmittedText: "In the beginning"
        )
        XCTAssertTrue(prompt.contains("Biblical Hebrew"))
        XCTAssertFalse(prompt.contains("Koine Greek"))
    }

    func testOLAAutomaticallyClassifiesSelectedWordingWithoutCountingAttribution() {
        XCTAssertEqual(ScriptureCompanionPrompts.analysisMode(selectedText: "  “covetousness,” \n"), .word)
        XCTAssertEqual(ScriptureCompanionPrompts.analysisMode(selectedText: "well-being"), .word)
        XCTAssertEqual(ScriptureCompanionPrompts.analysisMode(selectedText: "God's"), .word)
        XCTAssertEqual(ScriptureCompanionPrompts.analysisMode(selectedText: "we wanted to come"), .phrase)
        XCTAssertEqual(ScriptureCompanionPrompts.analysisMode(selectedText: "wanted\nto come"), .phrase)
        XCTAssertEqual(ScriptureCompanionPrompts.analysisMode(selectedText: "— …"), .referenceOnly)
        XCTAssertEqual(ScriptureCompanionPrompts.analysisMode(selectedText: nil), .referenceOnly)
    }

    func testOLAWordPromptContainsTranslationFullVerseAndContextualUsageRules() {
        let prompt = ScriptureCompanionPrompts.originalLanguageAnalysis(
            referenceLabel: "1 Thessalonians 2:5", bookID: "1TH", transmittedText: "covetousness",
            translationName: "World English Bible (WEB)",
            verseContextText: "For neither were we at any time found using words of flattery, nor a cloak of covetousness."
        )
        XCTAssertTrue(prompt.contains("I selected the word below from 1 Thessalonians 2:5"))
        XCTAssertTrue(prompt.contains("World English Bible (WEB) translation"))
        XCTAssertTrue(prompt.contains("Analysis mode: Word study"))
        XCTAssertTrue(prompt.contains("Koine Greek"))
        XCTAssertTrue(prompt.contains("> covetousness"))
        XCTAssertTrue(prompt.contains("Attached verse(s) — 1 Thessalonians 2:5"))
        XCTAssertTrue(prompt.contains("words of flattery"))
        XCTAssertTrue(prompt.contains("## Possible meanings"))
        XCTAssertTrue(prompt.contains("## Biblical usage"))
        XCTAssertTrue(prompt.contains("same original-language lemma"))
        XCTAssertTrue(prompt.contains("which sense fits this sentence"))
        XCTAssertTrue(prompt.contains("Do not claim the examples cover every occurrence"))
        XCTAssertTrue(prompt.contains("Model recollection is not verified lexical evidence"))
        XCTAssertTrue(prompt.contains("do not invent wording"))
        XCTAssertTrue(prompt.contains("Perform the analysis directly"))
        XCTAssertFalse(prompt.contains("## Key words and grammar"))
    }

    func testOLAPhrasePromptFocusesOnGrammarAlignmentAndExactReference() {
        let prompt = ScriptureCompanionPrompts.originalLanguageAnalysis(
            referenceLabel: "1 Thessalonians 2:18", bookID: "1TH", transmittedText: "Satan hindered us",
            translationName: "WEB", verseContextText: "We wanted to come to you, but Satan hindered us."
        )
        XCTAssertTrue(prompt.contains("Analysis mode: Phrase analysis"))
        XCTAssertTrue(prompt.contains("## Key words and grammar"))
        XCTAssertTrue(prompt.contains("grammatical relationships, syntax and idioms"))
        XCTAssertTrue(prompt.contains("Do not mechanically reverse-translate English"))
        XCTAssertTrue(prompt.contains("several translated words represent one original word"))
        XCTAssertTrue(prompt.contains("Keep the exact book and reference 1 Thessalonians 2:18"))
        XCTAssertFalse(prompt.contains("## Biblical usage"))
        let card = ScriptureCompanionPrompts.originalLanguageDisplayCard(
            referenceLabel: "1 Thessalonians 2:18", transmittedText: "Satan hindered us", translationName: "WEB"
        )
        XCTAssertTrue(card.contains("I selected the words below"))
        XCTAssertTrue(card.contains("> Satan hindered us"))
        XCTAssertTrue(card.contains("1 Thessalonians 2:18 (WEB)"))
    }

    func testOLARestrictedWordingDoesNotLeakSelectionOrInventContext() async throws {
        let session = CompanionSession(
            presetCatalog: try PromptPresetCatalog.bundled(), repository: nil,
            credentials: InMemoryCompanionCredentialsStore(),
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter()])
        )
        try session.saveProviderKey("fixture-key", adapterID: "mock", accountLabel: "Test")
        let selection = ChapterTextMap.Selection(
            text: "restricted target", editionID: "api.bible.fixture", contentRevision: "test",
            sourceLabels: ["18"],
            passages: [PassageRange(start: VerseID(book: "1TH", chapter: 2, verse: 18),
                                    end: VerseID(book: "1TH", chapter: 2, verse: 18))]
        )
        let id = try XCTUnwrap(session.askFromScripture(
            selection: selection, referenceLabel: "1 Thessalonians 2:18", transmittedText: nil,
            bookID: "1TH", chapter: 2, startVerse: 18, endVerse: 18,
            action: .originalLanguageAnalysis, translationName: "Fixture",
            verseContextText: "restricted full verse"
        ))
        let attachment = try XCTUnwrap(session.attachments.first { $0.conversationID == id })
        XCTAssertEqual(attachment.disclosure, .referenceOnly)
        XCTAssertNil(attachment.payload)
        let pending = try XCTUnwrap(session.scriptureAutoSend)
        XCTAssertFalse(pending.providerContent.contains("restricted target"))
        XCTAssertFalse(pending.providerContent.contains("restricted full verse"))
        XCTAssertFalse(pending.displayContent.contains("restricted target"))
        XCTAssertTrue(pending.providerContent.contains("Do not guess the selection"))
    }

    func testOLATitleAttachmentAndHiddenPromptSurviveSendSaveAndReopen() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("companion-ola-" + UUID().uuidString, isDirectory: true)
        let repository = CompanionFileRepository(directory: directory)
        let catalog = try PromptPresetCatalog.bundled()
        let credentials = InMemoryCompanionCredentialsStore()
        let registry = ProviderRegistry(adapters: [MockLLMProviderAdapter()])
        let session = CompanionSession(
            presetCatalog: catalog, repository: repository, credentials: credentials, registry: registry
        )
        await session.load()
        try session.saveProviderKey("fixture-key", adapterID: "mock", accountLabel: "Test")
        let selection = ChapterTextMap.Selection(
            text: "hindered", editionID: "web.engwebp", contentRevision: "test", sourceLabels: ["18"],
            passages: [PassageRange(start: VerseID(book: "1TH", chapter: 2, verse: 18),
                                    end: VerseID(book: "1TH", chapter: 2, verse: 18))]
        )
        let fullVerse = "We wanted to come to you, but Satan hindered us."
        let id = try XCTUnwrap(session.askFromScripture(
            selection: selection, referenceLabel: "1 Thessalonians 2:18", transmittedText: "hindered",
            bookID: "1TH", chapter: 2, startVerse: 18, endVerse: 18,
            action: .originalLanguageAnalysis, translationName: "WEB", verseContextText: fullVerse
        ))
        XCTAssertEqual(session.selectedConversation?.title, "OLA: 1 Thessalonians 2:18")
        XCTAssertEqual(session.selectedConversation?.passageAnchor?.startVerse, 18)
        XCTAssertEqual(session.attachments.last?.payload, fullVerse)
        XCTAssertTrue(session.scriptureAutoSend?.providerContent.contains("Analysis mode: Word study") == true)
        await session.flushScriptureAutoSendIfNeeded(conversationID: id)
        await session.flush()

        let reopened = CompanionSession(
            presetCatalog: catalog, repository: repository, credentials: credentials, registry: registry
        )
        await reopened.load()
        let conversation = try XCTUnwrap(reopened.conversations.first { $0.id == id })
        XCTAssertEqual(conversation.title, "OLA: 1 Thessalonians 2:18")
        XCTAssertEqual(reopened.attachments.first { $0.conversationID == id }?.payload, fullVerse)
        let messages = reopened.messages(for: id)
        let user = try XCTUnwrap(messages.first)
        XCTAssertTrue(user.content.contains("I selected the word below"))
        XCTAssertTrue(user.content.contains("WEB"))
        XCTAssertTrue(user.providerContent?.contains("## Biblical usage") == true)
        let request = CompanionContextBuilder.completionRequest(
            conversation: conversation, messages: messages, attachments: reopened.attachments, pendingUserText: ""
        )
        XCTAssertTrue(request.turns.first?.content.contains("Analysis mode: Word study") == true)
        XCTAssertTrue(request.systemInstruction.contains(fullVerse))
        XCTAssertTrue(request.systemInstruction.contains("Study scope:"))

        // Ordinary Ask retains its existing title and fragment attachment.
        let askID = try XCTUnwrap(session.askFromScripture(
            selection: selection, referenceLabel: "1 Thessalonians 2:18", transmittedText: "hindered",
            bookID: "1TH", chapter: 2, startVerse: 18, endVerse: 18
        ))
        XCTAssertEqual(session.selectedConversation?.title, "1 Thessalonians 2:18")
        XCTAssertEqual(session.attachments.first { $0.conversationID == askID }?.payload, "hindered")
        XCTAssertNil(session.scriptureAutoSend)
        XCTAssertTrue(session.composerText.isEmpty)
        XCTAssertTrue(session.selectedConversation?.composerDraft.isEmpty == true)
    }

    func testAskOpensBlankDraftAndSendsOnlyOwnersQuestionWithPassageContext() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("companion-manual-ask-" + UUID().uuidString, isDirectory: true)
        let repository = CompanionFileRepository(directory: directory)
        let catalog = try PromptPresetCatalog.bundled()
        let credentials = InMemoryCompanionCredentialsStore()
        let registry = ProviderRegistry(adapters: [MockLLMProviderAdapter()])
        let session = CompanionSession(
            presetCatalog: catalog, repository: repository, credentials: credentials, registry: registry
        )
        await session.load()
        try session.saveProviderKey("fixture-key", adapterID: "mock", accountLabel: "Test")
        session.composerText = "An unrelated previous draft"
        let passage = "For you yourselves know, brothers, our visit to you wasn't in vain."
        let selection = ChapterTextMap.Selection(
            text: passage, editionID: "web.engwebp", contentRevision: "test", sourceLabels: ["1"],
            passages: [PassageRange(start: VerseID(book: "1TH", chapter: 2, verse: 1),
                                    end: VerseID(book: "1TH", chapter: 2, verse: 1))]
        )
        let id = try XCTUnwrap(session.askFromScripture(
            selection: selection, referenceLabel: "1 Thessalonians 2:1", transmittedText: passage,
            bookID: "1TH", chapter: 2, startVerse: 1, endVerse: 1
        ))
        XCTAssertEqual(session.selectedConversation?.title, "1 Thessalonians 2:1")
        XCTAssertEqual(session.selectedConversation?.passageAnchor?.startVerse, 1)
        XCTAssertEqual(session.attachments.first { $0.conversationID == id }?.payload, passage)
        XCTAssertTrue(session.composerText.isEmpty)
        XCTAssertEqual(session.selectedConversation?.composerDraft, "")
        XCTAssertNil(session.scriptureAutoSend)
        await session.flushScriptureAutoSendIfNeeded(conversationID: id)
        await session.sendMessage()
        XCTAssertTrue(session.messages(for: id).isEmpty, "Opening Ask or sending an empty draft must not generate a turn.")
        await session.flush()

        let reopened = CompanionSession(
            presetCatalog: catalog, repository: repository, credentials: credentials, registry: registry
        )
        await reopened.load()
        reopened.selectConversation(id)
        XCTAssertEqual(reopened.composerText, "")
        XCTAssertEqual(reopened.selectedConversation?.composerDraft, "")
        XCTAssertTrue(reopened.messages(for: id).isEmpty)
        XCTAssertEqual(reopened.attachments.first { $0.conversationID == id }?.payload, passage)
        let question = "What does 'wasn't in vain' mean here?"
        reopened.updateComposerDraft(question)
        await reopened.sendMessage()
        let messages = reopened.messages(for: id)
        XCTAssertEqual(messages.first?.content, question)
        XCTAssertNil(messages.first?.providerContent)
        let request = CompanionContextBuilder.completionRequest(
            conversation: try XCTUnwrap(reopened.selectedConversation),
            messages: messages, attachments: reopened.attachments, pendingUserText: ""
        )
        XCTAssertTrue(request.turns.first?.content.hasSuffix("My question:\n" + question) == true)
        XCTAssertTrue(request.turns.first?.content.contains(passage) == true)
        XCTAssertTrue(request.systemInstruction.contains("Attached passage 1 Thessalonians 2:1"))
        XCTAssertTrue(request.systemInstruction.contains(passage))
        XCTAssertFalse(request.turns.contains { $0.content.contains("Help me understand") })
    }

    func testAskReferenceOnlyAlsoHasBlankComposerWithoutExposingRestrictedText() throws {
        XCTAssertEqual(CompanionSession.ScriptureCompanionAction.ask.composerPrompt(
            referenceLabel: "1 Thessalonians 2:1", bookID: "1TH", transmittedText: nil
        ), "")
        let session = CompanionSession(
            presetCatalog: try PromptPresetCatalog.bundled(), repository: nil,
            credentials: InMemoryCompanionCredentialsStore(),
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter()])
        )
        try session.saveProviderKey("fixture-key", adapterID: "mock", accountLabel: "Test")
        let selection = ChapterTextMap.Selection(
            text: "Restricted verse wording", editionID: "api.bible.fixture", contentRevision: "test",
            sourceLabels: ["1"], passages: []
        )
        _ = try XCTUnwrap(session.askFromScripture(
            selection: selection, referenceLabel: "1 Thessalonians 2:1", transmittedText: nil,
            bookID: "1TH", chapter: 2, startVerse: 1, endVerse: 1
        ))
        XCTAssertTrue(session.composerText.isEmpty)
        XCTAssertNil(session.scriptureAutoSend)
        XCTAssertEqual(session.attachments.last?.disclosure, .referenceOnly)
        XCTAssertNil(session.attachments.last?.payload)
        let request = CompanionContextBuilder.completionRequest(
            conversation: try XCTUnwrap(session.selectedConversation), messages: [],
            attachments: session.attachments, pendingUserText: "What is the meaning of this verse?"
        )
        XCTAssertTrue(request.systemInstruction.contains("Attached passage reference (reference only): 1 Thessalonians 2:1"))
        XCTAssertFalse(request.systemInstruction.contains("Restricted verse wording"))
    }

    func testRepositoryRoundTripAndRecovery() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("companion-" + UUID().uuidString, isDirectory: true)
        let repository = CompanionFileRepository(directory: directory)
        var snapshot = CompanionSnapshot()
        snapshot.conversations = [
            CompanionConversation(
                providerConfigID: UUID(),
                providerAdapterID: "openai",
                modelID: "gpt-4o-mini",
                presetSnapshot: PromptPresetSnapshot(
                    presetID: "biblical-studies",
                    displayName: "Biblical Studies",
                    resolvedInstruction: "Study",
                    contextVersion: 2,
                    contentHash: "abc"
                ),
                capabilitySnapshot: ProviderCapabilitySnapshot(
                    adapterID: "openai",
                    modelID: "gpt-4o-mini",
                    streaming: true,
                    providerRetrieval: false,
                    tools: false,
                    usageReporting: true,
                    cancellation: true
                )
            )
        ]
        let saved = try await repository.save(snapshot, expectedRevision: 0)
        XCTAssertEqual(saved.revision, 1)

        let reopened = try await repository.load()
        XCTAssertEqual(reopened.snapshot.conversations.count, 1)
        XCTAssertEqual(reopened.snapshot.revision, 1)
    }

    func testMockAdapterStreamsDeterministicText() async throws {
        let adapter = MockLLMProviderAdapter(scriptedChunks: ["Grace", " and", " peace."])
        let request = LLMCompletionRequest(modelID: "mock", systemInstruction: "Test", turns: [LLMChatTurn(role: .user, content: "Hi")])
        var deltas = ""
        for try await event in adapter.streamCompletion(apiKey: "test-key", request: request) {
            if case .textDelta(let chunk) = event { deltas += chunk }
        }
        XCTAssertEqual(deltas, "Grace and peace.")
    }

    func testSessionPersistsConversationWithoutProviderKey() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("companion-" + UUID().uuidString, isDirectory: true)
        let catalog = try PromptPresetCatalog.bundled()
        let session = CompanionSession(
            presetCatalog: catalog,
            repository: CompanionFileRepository(directory: directory),
            credentials: InMemoryCompanionCredentialsStore(),
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter()])
        )
        await session.load()
        XCTAssertNil(session.createConversation())
        try session.saveProviderKey("secret", adapterID: "mock", accountLabel: "Test")
        let id = try XCTUnwrap(session.createConversation())
        await session.flush()
        let reopened = CompanionSession(
            presetCatalog: catalog,
            repository: CompanionFileRepository(directory: directory),
            credentials: InMemoryCompanionCredentialsStore(),
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter()])
        )
        await reopened.load()
        XCTAssertEqual(reopened.conversations.first?.id, id)
    }

    @MainActor func testCollectionsVisibilityTracksArchiveAndTrash() throws {
        let session = CompanionSession(presetCatalog: try PromptPresetCatalog.bundled(), credentials: InMemoryCompanionCredentialsStore(), registry: ProviderRegistry(adapters: [MockLLMProviderAdapter()]))
        let store = CollectionsStore(collections: [], artifacts: [], memberships: [])
        session.onCollectionsSync = { store.upsertCompanionConversation($0) }
        session.onCollectionsRemove = { store.removeCompanionConversation($0) }
        try session.saveProviderKey("fixture", adapterID: "mock", accountLabel: "Test")
        let id = try XCTUnwrap(session.createConversation())
        XCTAssertNotNil(store.conversation(id: id))
        session.archiveConversation(id)
        XCTAssertNil(store.conversation(id: id))
        session.unarchiveConversation(id)
        XCTAssertNotNil(store.conversation(id: id))
        session.moveConversationToTrash(id)
        XCTAssertNil(store.conversation(id: id))
        session.restoreConversationFromTrash(id)
        XCTAssertNotNil(store.conversation(id: id))
    }

    func testScriptureQuizSeedHasMultipleFixturesPerType() throws {
        let seed = try QuizFixtureCatalog.scripture()
        XCTAssertGreaterThanOrEqual(seed.completeVerse.count, 10)
        XCTAssertGreaterThanOrEqual(seed.identifyVerse.count, 10)
        XCTAssertGreaterThanOrEqual(seed.whoSaidIt.count, 10)
        XCTAssertGreaterThanOrEqual(seed.bibleQuiz.count, 10)
        XCTAssertGreaterThanOrEqual(seed.bibleOrFalse.count, 10)
        let history = try QuizFixtureCatalog.christianHistory()
        XCTAssertGreaterThanOrEqual(history.questions.count, 10)
    }

    func testQuizMeReplacesIdentifyReferenceWithBibleQuizAndBibleOrFalse() {
        XCTAssertFalse(QuizType.quizMeSelectable.contains(.identifyReference))
        XCTAssertTrue(QuizType.quizMeSelectable.contains(.bibleQuiz))
        XCTAssertTrue(QuizType.quizMeSelectable.contains(.bibleOrFalse))
    }

    func testBibleQuizAndBibleOrFalseBuildRunnableQuestions() async throws {
        let response = try generatedQuizJSON(types: [.bibleQuiz, .bibleOrFalse], difficulty: .difficult)
        let session = CompanionSession(
            presetCatalog: try PromptPresetCatalog.bundled(),
            repository: nil,
            credentials: InMemoryCompanionCredentialsStore(),
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter(scriptedChunks: [response])])
        )
        try session.saveProviderKey("key", adapterID: "mock", accountLabel: "Test")
        let quizID = try await session.startQuiz(
            types: [.bibleQuiz, .bibleOrFalse],
            difficulty: .difficult,
            editionID: "web-engwebp",
            timed: false
        )
        let questions = session.quizQuestions.filter { $0.sessionID == quizID }
        XCTAssertEqual(questions.count, QuizDifficulty.difficult.questionCount)
        XCTAssertTrue(questions.contains { $0.type == .bibleQuiz })
        XCTAssertTrue(questions.contains { $0.type == .bibleOrFalse })
        XCTAssertTrue(questions.allSatisfy { $0.choices.count >= 2 })
    }

    func testCompletedQuizRecordsReviewingAndQuizDeletionKeepsActivityTime() async throws {
        let response = try generatedQuizJSON(types: [.bibleQuiz], difficulty: .difficult)
        let session = CompanionSession(
            presetCatalog: try PromptPresetCatalog.bundled(), repository: nil,
            credentials: InMemoryCompanionCredentialsStore(),
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter(scriptedChunks: [response])])
        )
        try session.saveProviderKey("key", adapterID: "mock", accountLabel: "Test")
        let quizID = try await session.startQuiz(types: [.bibleQuiz], difficulty: .difficult,
                                                 editionID: "web-engwebp", timed: false, recordReviewing: false)
        for question in session.quizQuestions where question.sessionID == quizID {
            session.addQuizQuestionActiveTime(sessionID: quizID, seconds: 7)
            session.submitQuizAnswer(sessionID: quizID, questionID: question.id, answer: "Correct", choiceIndex: 0)
        }
        session.finishQuiz(sessionID: quizID, intentional: true)
        let link = try XCTUnwrap(session.reviewingLinks.first { $0.quizSessionID == quizID })
        XCTAssertEqual(link.activeSeconds, 7 * QuizDifficulty.difficult.questionCount)
        session.deleteQuizSession(quizID)
        XCTAssertTrue(session.reviewingLinks.contains { $0.quizSessionID == quizID && $0.sourceDeleted })

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let activity = ActivityStore(repository: ActivityFileRepository(directory: directory))
        await activity.load()
        activity.importQuizStudyLinks(session.reviewingLinks)
        XCTAssertEqual(activity.records.first?.activeSeconds, Double(link.activeSeconds))
        XCTAssertEqual(activity.records.first?.quizSessionID, quizID)
        XCTAssertEqual(activity.records.first?.modeID, ActivityModeID.studying.id)
    }

    func testAIQuizPromptOmitsRecentQuestionPaddingAndIncludesDifficultyRubric() {
        let recent = (1...12).map { "Recent question \($0)" }
        let request = AIQuizQuestionGenerator.request(
            modelID: "mock",
            types: [.identifyVerse],
            difficulty: .difficult,
            count: 3,
            recentPrompts: [.identifyVerse: recent],
            nonce: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        XCTAssertTrue(request.systemInstruction.contains("Difficult: require precise canonical context"))
        XCTAssertFalse(request.systemInstruction.contains("Recent question 1"))
        XCTAssertTrue(request.systemInstruction.contains("materially distinct"))
    }

    func testAIQuizDecoderRejectsAnExactRecentQuestion() throws {
        let data = AIQuizQuestionGenerator.Payload(questions: [
            .init(
                type: QuizType.bibleQuiz.rawValue,
                prompt: "Who built the ark?",
                choices: ["Noah", "Moses"],
                correctIndex: 0,
                referenceLabel: "Genesis 6",
                explanation: "God instructed Noah to build the ark."
            )
        ])
        let json = String(decoding: try JSONEncoder().encode(data), as: UTF8.self)
        XCTAssertThrowsError(try AIQuizQuestionGenerator.decode(
            json,
            sessionID: UUID(),
            plannedTypes: [.bibleQuiz],
            recentPrompts: [.bibleQuiz: ["Who built the ark?"]]
        ))
    }

    func testAIQuizDecoderRejectsNearDuplicateHistoryLocally() throws {
        let data = AIQuizQuestionGenerator.Payload(questions: [
            .init(
                type: QuizType.bibleQuiz.rawValue,
                prompt: "Which person received clear instructions from God to build the ark?",
                choices: ["Noah", "Moses"],
                correctIndex: 0,
                referenceLabel: "Genesis 6",
                explanation: "God instructed Noah to build the ark."
            )
        ])
        let json = String(decoding: try JSONEncoder().encode(data), as: UTF8.self)
        XCTAssertThrowsError(try AIQuizQuestionGenerator.decode(
            json,
            sessionID: UUID(),
            plannedTypes: [.bibleQuiz],
            recentPrompts: [.bibleQuiz: ["Which person received instructions from God to build the ark?"]]
        ))
    }

    func testWarmCacheStartsQuizWithoutProviderRequest() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("companion-" + UUID().uuidString, isDirectory: true)
        let repository = CompanionFileRepository(directory: directory)
        let credentials = InMemoryCompanionCredentialsStore()
        let configuration = ProviderConfigurationRecord(adapterID: "mock", accountLabel: "Test", defaultModelID: "mock")
        try credentials.writeKey("key", for: configuration.id)
        let scope = QuizQuestionCacheScope(
            providerConfigurationID: configuration.id,
            adapterID: "mock",
            modelID: "mock",
            editionID: "web-engwebp"
        )
        let cached = (0..<QuizDifficulty.difficult.questionCount).map { index in
            CachedQuizQuestion(
                id: UUID(), scope: scope, difficulty: .difficult, type: .bibleQuiz,
                prompt: "Cached difficult question \(index)", choices: ["Correct", "Wrong"],
                answerKey: QuizAnswerKey(referenceLabel: "Genesis \(index + 1):1", choiceIndex: 0),
                explanation: "Cached explanation \(index)", generatedAt: Date(), promptHash: "cached-\(index)"
            )
        }
        _ = try await repository.save(
            CompanionSnapshot(providerConfigurations: [configuration], cachedQuizQuestions: cached),
            expectedRevision: 0
        )
        let session = CompanionSession(
            presetCatalog: try PromptPresetCatalog.bundled(),
            repository: repository,
            credentials: credentials,
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter(failure: .offline)])
        )
        await session.load()
        let quizID = try await session.startQuiz(
            types: [.bibleQuiz], difficulty: .difficult, editionID: "web-engwebp", timed: false
        )
        XCTAssertEqual(session.quizQuestions(for: quizID).count, 3)
        XCTAssertEqual(session.cachedQuizQuestions.filter { $0.scope == scope && $0.difficulty == .difficult && $0.type == .bibleQuiz }.count, 0)
    }

    func testCacheRoundTripKeepsDifficultyBuckets() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("companion-" + UUID().uuidString, isDirectory: true)
        let repository = CompanionFileRepository(directory: directory)
        let scope = QuizQuestionCacheScope(
            providerConfigurationID: UUID(), adapterID: "mock", modelID: "mock", editionID: "web-engwebp"
        )
        let question = CachedQuizQuestion(
            id: UUID(), scope: scope, difficulty: .average, type: .whoSaidIt,
            prompt: "Who said this?", choices: ["Peter", "Paul"],
            answerKey: QuizAnswerKey(referenceLabel: "Acts 2", choiceIndex: 0),
            explanation: "Peter said it.", generatedAt: Date(), promptHash: "hash"
        )
        _ = try await repository.save(CompanionSnapshot(cachedQuizQuestions: [question]), expectedRevision: 0)
        let reopened = try await repository.load()
        XCTAssertEqual(reopened.snapshot.schemaVersion, 3)
        XCTAssertEqual(reopened.snapshot.cachedQuizQuestions, [question])
    }

    func testCacheWarmupFillsExactTargetsAndOnlyReplenishesDeficit() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("companion-" + UUID().uuidString, isDirectory: true)
        let repository = CompanionFileRepository(directory: directory)
        let credentials = InMemoryCompanionCredentialsStore()
        let configuration = ProviderConfigurationRecord(adapterID: "dynamic-quiz", accountLabel: "Test", defaultModelID: "mock")
        try credentials.writeKey("key", for: configuration.id)
        _ = try await repository.save(CompanionSnapshot(providerConfigurations: [configuration]), expectedRevision: 0)
        let recorder = DynamicQuizAdapter.Recorder()
        let session = CompanionSession(
            presetCatalog: try PromptPresetCatalog.bundled(),
            repository: repository,
            credentials: credentials,
            registry: ProviderRegistry(adapters: [DynamicQuizAdapter(recorder: recorder)])
        )
        session.apply(CompanionSnapshot(providerConfigurations: [configuration]))

        await session.warmQuizCache(types: [.bibleQuiz])
        XCTAssertEqual(session.cachedQuizQuestions.filter { $0.type == .bibleQuiz && $0.difficulty == .easy }.count, 100)
        XCTAssertEqual(session.cachedQuizQuestions.filter { $0.type == .bibleQuiz && $0.difficulty == .average }.count, 100)
        XCTAssertEqual(session.cachedQuizQuestions.filter { $0.type == .bibleQuiz && $0.difficulty == .difficult }.count, 100)
        let batchesPerBucket = QuizQuestionCachePolicy.bucketTargetCount / QuizQuestionCachePolicy.refillBatchSize
        XCTAssertEqual(recorder.callCount, 3 * batchesPerBucket)

        await session.warmQuizCache(types: [.bibleQuiz])
        XCTAssertEqual(recorder.callCount, 3 * batchesPerBucket)

        let scope = try XCTUnwrap(session.cachedQuizQuestions.first?.scope)
        let reserved = session.reserveCachedQuestions(
            plan: Array(repeating: .bibleQuiz, count: 3), difficulty: .difficult, scope: scope
        )
        XCTAssertEqual(reserved?.count, 3)
        XCTAssertTrue(session.hasCachedQuestions(types: [.bibleQuiz], difficulty: .difficult, editionID: "web-engwebp"))
        await session.warmQuizCache(types: [.bibleQuiz])
        XCTAssertEqual(session.cachedQuizQuestions.filter { $0.type == .bibleQuiz && $0.difficulty == .difficult }.count, 100)
        XCTAssertEqual(recorder.callCount, 3 * batchesPerBucket + 1)
    }

    func testExamStartDrawsFromMixedCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("companion-" + UUID().uuidString, isDirectory: true)
        let repository = CompanionFileRepository(directory: directory)
        let credentials = InMemoryCompanionCredentialsStore()
        let configuration = ProviderConfigurationRecord(adapterID: "mock", accountLabel: "Test", defaultModelID: "mock")
        try credentials.writeKey("key", for: configuration.id)
        let scope = QuizQuestionCacheScope(
            providerConfigurationID: configuration.id,
            adapterID: "mock",
            modelID: "mock",
            editionID: "web-engwebp"
        )
        let cached = QuizDifficulty.allCases.flatMap { difficulty in
            QuizType.quizMeSelectable.flatMap { type in
                (0..<2).map { index in
                CachedQuizQuestion(
                    id: UUID(), scope: scope, difficulty: difficulty, type: type,
                    prompt: "Cached \(type.rawValue) \(difficulty.rawValue) \(index)",
                    choices: ["Correct", "Wrong"],
                    answerKey: QuizAnswerKey(referenceLabel: "Genesis 1:1", choiceIndex: 0),
                    explanation: "Cached.", generatedAt: Date(), promptHash: "\(type.rawValue)-\(difficulty.rawValue)-\(index)"
                )
                }
            }
        }
        let session = CompanionSession(
            presetCatalog: try PromptPresetCatalog.bundled(),
            repository: repository,
            credentials: credentials,
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter(failure: .offline)])
        )
        session.apply(CompanionSnapshot(providerConfigurations: [configuration], cachedQuizQuestions: cached))

        let quizID = try await session.startExamQuiz(
            questionCount: 25,
            editionID: "web-engwebp",
            timed: true,
            sessionTimeLimitSeconds: ExamTimeLimit.tenMinutes.rawValue
        )
        let quiz = try XCTUnwrap(session.quizSessions.first { $0.id == quizID })
        XCTAssertEqual(quiz.mode, .exam)
        XCTAssertEqual(quiz.effectiveQuestionCount, 25)
        XCTAssertEqual(session.quizQuestions(for: quizID).count, 25)
        XCTAssertEqual(session.cachedQuizQuestions.count, cached.count - 25)
    }

    func testFinishAndQuitRequestRefillOnlyOnce() throws {
        let session = CompanionSession(
            presetCatalog: try PromptPresetCatalog.bundled(),
            repository: nil,
            credentials: InMemoryCompanionCredentialsStore(),
            registry: ProviderRegistry(adapters: [])
        )
        let completed = QuizSession(
            id: UUID(), createdAt: Date(), difficulty: .average, types: [.bibleQuiz],
            editionID: "web-engwebp", timed: false, recordReviewing: true,
            providerAdapterID: "mock", modelID: "mock", scoreEarned: 0,
            scoreAvailable: 15, completionState: "active"
        )
        let abandoned = QuizSession(
            id: UUID(), createdAt: Date(), difficulty: .easy, types: [.whoSaidIt],
            editionID: "web-engwebp", timed: false, recordReviewing: true,
            providerAdapterID: "mock", modelID: "mock", scoreEarned: 0,
            scoreAvailable: 10, completionState: "active"
        )
        session.quizSessions = [completed, abandoned]
        session.finishQuiz(sessionID: completed.id, intentional: true)
        XCTAssertEqual(session.quizCachePriorityTypes, [.bibleQuiz])
        XCTAssertEqual(session.quizCachePriorityDifficulty, .average)
        XCTAssertEqual(session.reviewingLinks.count, 0, "A quiz fixture without answered questions is not a completed review")
        session.finishQuiz(sessionID: completed.id, intentional: true)
        XCTAssertEqual(session.reviewingLinks.count, 0)

        session.activeQuizSessionID = abandoned.id
        session.abandonActiveQuiz()
        XCTAssertEqual(session.quizCachePriorityTypes, [.whoSaidIt])
        XCTAssertEqual(session.quizCachePriorityDifficulty, .easy)
        XCTAssertEqual(session.quizSessions.first(where: { $0.id == abandoned.id })?.completionState, "abandoned")
        XCTAssertEqual(session.reviewingLinks.count, 0)
    }

    func testAIQuizRepositionsCorrectChoicesAcrossQuestions() throws {
        let questions = (0..<4).map { index in
            AIQuizQuestionGenerator.GeneratedQuestion(
                type: QuizType.bibleQuiz.rawValue,
                prompt: "Position test \(index)",
                choices: ["Correct \(index)", "Wrong A \(index)", "Wrong B \(index)", "Wrong C \(index)"],
                correctIndex: 0,
                referenceLabel: "Genesis \(index + 1):1",
                explanation: "Position test explanation \(index)."
            )
        }
        let json = String(decoding: try JSONEncoder().encode(AIQuizQuestionGenerator.Payload(questions: questions)), as: UTF8.self)
        let decoded = try AIQuizQuestionGenerator.decode(
            json,
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            plannedTypes: Array(repeating: .bibleQuiz, count: 4),
            recentPrompts: [:]
        )
        XCTAssertEqual(Set(decoded.compactMap(\.answerKey.choiceIndex)), Set(0..<4))
        for (index, question) in decoded.enumerated() {
            XCTAssertEqual(question.choices[question.answerKey.choiceIndex!], "Correct \(index)")
        }
    }

    func testSessionSerializesQueuedSavesWithoutStaleNotice() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("companion-" + UUID().uuidString, isDirectory: true)
        let session = CompanionSession(
            presetCatalog: try PromptPresetCatalog.bundled(),
            repository: CompanionFileRepository(directory: directory),
            credentials: InMemoryCompanionCredentialsStore(),
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter()])
        )
        await session.load()
        session.setSidebarChatHistoryExpanded(false)
        session.setSidebarQuizHistoryExpanded(false)
        await session.flush()
        XCTAssertNil(session.notice)
        XCTAssertEqual(session.revision, 2)
    }

    func testQuizGradingAndReviewingLink() throws {
        let nearly = ScriptureQuizEngine.gradeCompleteVerse(answer: "son that whoever believes", key: "Son, that whoever believes in him should not perish but have eternal life.")
        XCTAssertEqual(nearly, .nearlyCorrect)
        let session = QuizSession(
            id: UUID(), createdAt: Date(), difficulty: .easy, types: [.identifyVerse], editionID: "web-engwebp",
            timed: false, recordReviewing: true, providerAdapterID: "mock", modelID: "mock",
            scoreEarned: 1, scoreAvailable: 10, completionState: "active"
        )
        var link = ReviewingActivityLink(id: UUID(), quizSessionID: session.id, startedAt: Date(), endedAt: Date(), activeSeconds: 120, sourceDeleted: false)
        link.sourceDeleted = true
        XCTAssertTrue(link.sourceDeleted)
    }

    func testFreeModelFilterForOpenRouterSuffix() {
        let merged = ProviderModelCatalog.mergeRemote(
            ids: ["vendor/a:free", "vendor/b-paid"],
            adapterID: "openrouter"
        )
        let freeOnly = ProviderModelCatalog.filteredModels(merged, adapterID: "openrouter", freeOnly: true)
        XCTAssertEqual(freeOnly.map(\.modelID), ["vendor/a:free"])
        XCTAssertTrue(ProviderModelCatalog.isLikelyFreeModel(modelID: "x:free", adapterID: "openrouter"))
    }

    func testRefreshModelCatalogUsesAdapterList() async throws {
        let session = CompanionSession(
            presetCatalog: try PromptPresetCatalog.bundled(),
            repository: nil,
            credentials: InMemoryCompanionCredentialsStore(),
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter()])
        )
        try session.saveProviderKey("key", adapterID: "mock", accountLabel: "Test")
        let configID = try XCTUnwrap(session.providerConfigurations.first?.id)
        let refreshError = await session.refreshModelCatalog(for: configID)
        XCTAssertNil(refreshError)
        XCTAssertEqual(session.modelOptions(for: configID).map(\.modelID), ["mock", "mock-fast"])
    }

    func testReflectionQuestionUsesSeparateConversationPresetAndSendPipeline() async throws {
        let credentials = InMemoryCompanionCredentialsStore()
        let session = CompanionSession(presetCatalog: try PromptPresetCatalog.bundled(), repository: nil,
            credentials: credentials, registry: ProviderRegistry(adapters: [MockLLMProviderAdapter()]))
        XCTAssertNil(session.prepareReflectionQuestion("What is faith?"))
        try session.saveProviderKey("key", adapterID: "mock", accountLabel: "Test")
        let existing = try XCTUnwrap(session.createConversation())
        session.updateComposerDraft("Keep my existing draft")
        XCTAssertNil(session.prepareReflectionQuestion("  "))
        let id = try XCTUnwrap(session.prepareReflectionQuestion("What is faith?"))
        XCTAssertNotEqual(existing, id)
        XCTAssertEqual(session.conversations.first(where: { $0.id == existing })?.composerDraft, "Keep my existing draft")
        XCTAssertEqual(session.conversations.first(where: { $0.id == id })?.composerDraft, "What is faith?")
        XCTAssertTrue(session.conversations.first(where: { $0.id == id })?.presetSnapshot.resolvedInstruction.contains("historic orthodox Christian faith") == true)
        await session.sendMessage()
        XCTAssertEqual(session.messages.first(where: { $0.conversationID == id && $0.role == .user })?.content, "What is faith?")
        XCTAssertEqual(session.messages.last?.deliveryState, .complete)
        XCTAssertEqual(session.messages.last?.role, .assistant)
    }

    func testSendMessageUsesMockStream() async throws {
        let catalog = try PromptPresetCatalog.bundled()
        let credentials = InMemoryCompanionCredentialsStore()
        let session = CompanionSession(
            presetCatalog: catalog,
            repository: nil,
            credentials: credentials,
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter()])
        )
        try session.saveProviderKey("key", adapterID: "mock", accountLabel: "Test")
        _ = session.createConversation()
        session.composerText = "What is faith?"
        await session.sendMessage()
        let assistant = session.messages.last
        XCTAssertEqual(assistant?.role, .assistant)
        XCTAssertEqual(assistant?.content, "Hello from Sophia.")
        XCTAssertEqual(assistant?.deliveryState, .complete)
    }

    func testSessionStoresAndReopensVerbatimMarkdownWithSplitDelimiters() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("companion-markdown-" + UUID().uuidString, isDirectory: true)
        let repository = CompanionFileRepository(directory: directory)
        let catalog = try PromptPresetCatalog.bundled()
        let credentials = InMemoryCompanionCredentialsStore()
        let chunks = ["## Main idea\n\nThe theme is ", "**", "the Lord's presence", "**",
                      ".\n\n- ", "**", "Shepherd:", "**", " He provides.\n"]
        let session = CompanionSession(
            presetCatalog: catalog, repository: repository, credentials: credentials,
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter(scriptedChunks: chunks)])
        )
        await session.load()
        try session.saveProviderKey("fixture-key", adapterID: "mock", accountLabel: "Test")
        let conversationID = try XCTUnwrap(session.createConversation())
        session.composerText = "Summarize Psalm 23."
        await session.sendMessage()
        await session.flush()
        let expected = chunks.joined()
        let assistant = try XCTUnwrap(session.messages.last)
        XCTAssertEqual(assistant.content, expected)
        XCTAssertEqual(assistant.attempts.last?.content, expected)
        XCTAssertEqual(assistant.deliveryState, .complete)

        let reopened = CompanionSession(
            presetCatalog: catalog, repository: repository, credentials: credentials,
            registry: ProviderRegistry(adapters: [MockLLMProviderAdapter()])
        )
        await reopened.load()
        let restored = try XCTUnwrap(reopened.messages.first { $0.id == assistant.id })
        XCTAssertEqual(restored.conversationID, conversationID)
        XCTAssertEqual(restored.content, expected)
        XCTAssertEqual(restored.attempts.last?.content, expected)
        let blocks = CompanionMarkdownText.blocks(for: restored.content)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertFalse(blocks.contains { String($0.text.characters).contains("**") })
    }

    private func generatedQuizJSON(types: [QuizType], difficulty: QuizDifficulty) throws -> String {
        let planned = AIQuizQuestionGenerator.questionTypePlan(types: types, count: difficulty.questionCount)
        let questions = planned.enumerated().map { index, type in
            AIQuizQuestionGenerator.GeneratedQuestion(
                type: type.rawValue,
                prompt: "Generated \(type.rawValue) question \(index)",
                choices: type == .bibleOrFalse ? ["True", "False"] : ["Answer A", "Answer B", "Answer C"],
                correctIndex: 0,
                referenceLabel: "Genesis \(index + 1):1",
                explanation: "Fixture explanation \(index)."
            )
        }
        return String(decoding: try JSONEncoder().encode(AIQuizQuestionGenerator.Payload(questions: questions)), as: UTF8.self)
    }
}

private struct DynamicQuizAdapter: LLMProviderAdapter {
    final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var storedCallCount = 0

        var callCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return storedCallCount
        }

        func nextCall() -> Int {
            lock.lock()
            defer { lock.unlock() }
            storedCallCount += 1
            return storedCallCount
        }
    }

    let id = "dynamic-quiz"
    let displayName = "Dynamic Quiz"
    let recorder: Recorder

    func advertisedCapabilities(modelID: String) -> Set<LLMProviderCapability> { [.streaming] }
    func validateConnection(apiKey: String, modelID: String) async throws {}
    func listModels(apiKey: String) async throws -> [String] { ["mock"] }

    func streamCompletion(apiKey: String, request: LLMCompletionRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        let call = recorder.nextCall()
        let pattern = #"Return exactly ([0-9]+) questions"#
        let match = try? NSRegularExpression(pattern: pattern).firstMatch(
            in: request.systemInstruction,
            range: NSRange(request.systemInstruction.startIndex..., in: request.systemInstruction)
        )
        let count: Int
        if let match,
           let countRange = Range(match.range(at: 1), in: request.systemInstruction) {
            count = Int(request.systemInstruction[countRange]) ?? 0
        } else {
            count = 0
        }
        let planned = Array(repeating: QuizType.bibleQuiz, count: count)
        let questions = planned.enumerated().map { index, type in
            let choices: [String]
            switch type {
            case .bibleOrFalse: choices = ["True", "False"]
            case .scriptureOrCap: choices = ["Scripture", "Cap"]
            default: choices = ["Correct", "Wrong A", "Wrong B"]
            }
            return AIQuizQuestionGenerator.GeneratedQuestion(
                type: type.rawValue,
                prompt: "Generated batch\(call) question item\(index) for \(type.rawValue)",
                choices: choices,
                correctIndex: 0,
                referenceLabel: "Genesis \(index + 1):1",
                explanation: "Generated explanation \(call)-\(index)."
            )
        }
        let text = (try? JSONEncoder().encode(AIQuizQuestionGenerator.Payload(questions: questions)))
            .map { String(decoding: $0, as: UTF8.self) } ?? ""
        return AsyncThrowingStream { continuation in
            continuation.yield(.responseStarted)
            continuation.yield(.textDelta(text))
            continuation.yield(.completed)
            continuation.finish()
        }
    }
}
