import XCTest
@testable import SophiaScriptura

@MainActor
final class ScriptureHubTests: XCTestCase {
    private let chapter = CompanionChapterAnchor(
        bookID: "MAT", chapter: 1, editionID: "web.engwebp", referenceLabel: "Matthew Chapter 1 (WEB)"
    )

    private func makeSession(adapter: CapturingStudyAdapter = CapturingStudyAdapter(),
                             repository: CompanionFileRepository? = nil,
                             credentials: InMemoryCompanionCredentialsStore = InMemoryCompanionCredentialsStore()) throws -> CompanionSession {
        let session = CompanionSession(presetCatalog: try PromptPresetCatalog.bundled(), repository: repository,
                                       credentials: credentials, registry: ProviderRegistry(adapters: [adapter]))
        try session.saveProviderKey("fixture-key", adapterID: adapter.id, accountLabel: "Test", defaultModelID: "fixture")
        return session
    }

    func testBothVerseEntryPointsSendVerseBesideQuestionInActualProviderRequest() async throws {
        for selected in ["wasn't in vain", "For you yourselves know, brothers, our visit to you wasn't in vain."] {
            let adapter = CapturingStudyAdapter()
            let session = try makeSession(adapter: adapter)
            let verse = "For you yourselves know, brothers, our visit to you wasn't in vain."
            let selection = ChapterTextMap.Selection(text: selected, editionID: "web.engwebp", contentRevision: "fixture",
                sourceLabels: ["1"], passages: [PassageRange(start: VerseID(book: "1TH", chapter: 2, verse: 1),
                                                           end: VerseID(book: "1TH", chapter: 2, verse: 1))])
            let id = try XCTUnwrap(session.askFromScripture(selection: selection, referenceLabel: "1 Thessalonians 2:1",
                transmittedText: selected, bookID: "1TH", chapter: 2, startVerse: 1, endVerse: 1,
                translationName: "WEB", verseContextText: verse))
            XCTAssertTrue(session.composerText.isEmpty)
            XCTAssertNil(session.scriptureAutoSend)
            session.updateComposerDraft("What does it mean?")
            await session.sendMessage()
            let request = try XCTUnwrap(adapter.requests.last)
            let turn = try XCTUnwrap(request.turns.last)
            XCTAssertEqual(turn.role, .user)
            XCTAssertTrue(turn.content.contains("1 Thessalonians 2:1 (WEB)"))
            XCTAssertTrue(turn.content.contains(verse))
            XCTAssertTrue(turn.content.hasSuffix("My question:\nWhat does it mean?"))
            XCTAssertTrue(request.systemInstruction.contains("do not announce a future discussion"))
            XCTAssertEqual(session.messages(for: id).first?.content, "What does it mean?")
            XCTAssertNil(session.messages(for: id).first?.providerContent)
            XCTAssertEqual(session.attachments.last?.selectedText, selected)
            let body = try OpenAICompatibleProviderAdapter.completionBody(for: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let outgoing = try XCTUnwrap(json["messages"] as? [[String: String]])
            XCTAssertEqual(outgoing.last?["content"], turn.content)
            XCTAssertEqual(outgoing.last?["role"], "user")
            XCTAssertEqual(json["stream"] as? Bool, true)

            let assistant = try XCTUnwrap(session.messages(for: id).last)
            await session.retryAssistantMessage(assistant.id)
            XCTAssertTrue(adapter.requests.last?.turns.last?.content.contains(verse) == true)
            await session.editAndResend(userMessageID: try XCTUnwrap(session.messages(for: id).first?.id), newText: "What is this about?")
            XCTAssertTrue(adapter.requests.last?.turns.last?.content.hasSuffix("My question:\nWhat is this about?") == true)
            XCTAssertTrue(adapter.requests.last?.turns.last?.content.contains(verse) == true)
        }
    }

    func testReferenceOnlyAndLocalOnlyNeverLeakWordingIntoQuestion() throws {
        let session = try makeSession()
        let selection = ChapterTextMap.Selection(text: "Restricted selection", editionID: "licensed", contentRevision: "fixture", sourceLabels: [], passages: [])
        let id = try XCTUnwrap(session.askFromScripture(selection: selection, referenceLabel: "Matthew 1:1",
            transmittedText: nil, bookID: "MAT", chapter: 1, startVerse: 1, endVerse: 1,
            translationName: "NLT", verseContextText: "Restricted full verse"))
        session.attachments.append(CompanionAttachment(conversationID: id, disclosure: .localOnly,
            referenceLabel: "Local note", payload: "Private wording", selectedText: "Private selection"))
        let request = CompanionContextBuilder.completionRequest(conversation: try XCTUnwrap(session.selectedConversation),
            messages: [], attachments: session.attachments, pendingUserText: "What does this mean?")
        let text = request.systemInstruction + request.turns.map(\.content).joined()
        for secret in ["Restricted selection", "Restricted full verse", "Private wording", "Private selection"] {
            XCTAssertFalse(text.contains(secret))
        }
        XCTAssertTrue(request.turns.last?.content.contains("Matthew 1:1 (NLT)") == true)
    }

    func testChapterAskPersistsReferenceOnlyAndNeverBecomesVerseConversation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("chapter-hub-" + UUID().uuidString)
        let repository = CompanionFileRepository(directory: directory)
        let credentials = InMemoryCompanionCredentialsStore()
        let adapter = CapturingStudyAdapter()
        let session = try makeSession(adapter: adapter, repository: repository, credentials: credentials)
        let id = try XCTUnwrap(session.askFromChapter(chapter))
        XCTAssertTrue(session.composerText.isEmpty)
        XCTAssertNil(session.scriptureAutoSend)
        XCTAssertNil(session.selectedConversation?.passageAnchor)
        XCTAssertEqual(session.selectedConversation?.chapterAnchor, chapter)
        XCTAssertEqual(session.attachments.last?.disclosure, .referenceOnly)
        XCTAssertNil(session.attachments.last?.payload)
        await session.sendMessage()
        XCTAssertTrue(adapter.requests.isEmpty)
        await session.flush()
        let reopened = CompanionSession(presetCatalog: try PromptPresetCatalog.bundled(), repository: repository,
            credentials: credentials, registry: ProviderRegistry(adapters: [adapter]))
        await reopened.load()
        reopened.selectConversation(id)
        XCTAssertEqual(reopened.selectedConversation?.chapterAnchor, chapter)
        reopened.updateComposerDraft("What is the main theme?")
        await reopened.sendMessage()
        let request = try XCTUnwrap(adapter.requests.last)
        XCTAssertTrue(request.turns.last?.content.contains("In \"Matthew Chapter 1 (WEB)\"") == true)
        XCTAssertTrue(request.turns.last?.content.contains("Chapter text is not attached") == true)
        XCTAssertFalse(request.turns.last?.content.contains("Attached verse(s):") == true)
        XCTAssertEqual(reopened.chapterConversations(for: chapter).map(\.id), [id])
        XCTAssertTrue(reopened.verseConversations(in: chapter).isEmpty)
        XCTAssertTrue(reopened.anchoredConversations(for: VerseID(book: "MAT", chapter: 1, verse: 1), editionID: chapter.editionID).isEmpty)
        let branchID = try XCTUnwrap(reopened.branchConversation(toProviderConfigID: try XCTUnwrap(reopened.selectedConversation?.providerConfigID)))
        XCTAssertEqual(reopened.selectedConversation?.chapterAnchor, chapter)
        XCTAssertEqual(reopened.attachments.first { $0.conversationID == branchID }?.disclosure, .referenceOnly)
    }

    func testChapterIndexFiltersAndOrdersLinksAndVerseRangesWithoutDuplicates() throws {
        let session = try makeSession()
        func add(_ verse: Int, book: String = "MAT", chapterNumber: Int = 1, edition: String = "web.engwebp") throws -> UUID {
            let selection = ChapterTextMap.Selection(text: "Verse", editionID: edition, contentRevision: "fixture", sourceLabels: [], passages: [])
            return try XCTUnwrap(session.askFromScripture(selection: selection, referenceLabel: "\(book) \(chapterNumber):\(verse)",
                transmittedText: "Verse", bookID: book, chapter: chapterNumber, startVerse: verse, endVerse: verse + 1))
        }
        let later = try add(10)
        let earlier = try add(2)
        _ = try add(1, book: "MRK")
        _ = try add(1, chapterNumber: 2)
        _ = try add(1, edition: "licensed")
        let chapterID = try XCTUnwrap(session.askFromChapter(chapter))
        XCTAssertEqual(session.verseConversations(in: chapter).map(\.id), [earlier, later])
        XCTAssertEqual(session.chapterConversations(for: chapter).map(\.id), [chapterID])
        func link(_ verse: Int?, book: String = "MAT", chapterNumber: Int = 1, edition: String = "web.engwebp") -> SavedLink {
            SavedLink(id: UUID(), title: "Article", url: "https://example.com", createdAt: Date(),
                verse: verse.map { VerseID(book: book, chapter: chapterNumber, verse: $0) }, editionID: edition)
        }
        let ten = link(10), two = link(2)
        let links = [ten, link(nil), link(1, book: "MRK"), link(1, chapterNumber: 2), link(1, edition: "licensed"), two]
        XCTAssertEqual(ChapterHubContent.links(links, in: chapter).map(\.id), [two.id, ten.id])
    }

    func testOldConversationAndAttachmentDecodeWithoutNewOptionalFields() throws {
        let session = try makeSession()
        _ = try XCTUnwrap(session.askFromChapter(chapter))
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(try XCTUnwrap(session.selectedConversation))) as? [String: Any])
        old.removeValue(forKey: "chapterAnchor")
        let decoded = try JSONDecoder().decode(CompanionConversation.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(decoded.chapterAnchor)
        let attachment = CompanionAttachment(conversationID: decoded.id, disclosure: .textTransmitted, referenceLabel: "Matthew 1:1", payload: "Verse")
        let roundTrip = try JSONDecoder().decode(CompanionAttachment.self, from: JSONEncoder().encode(attachment))
        XCTAssertNil(roundTrip.selectedText)
        XCTAssertEqual(roundTrip.payload, "Verse")
    }

    func testVerseContextPreservesCharacterBudgetAndExcludesOtherChats() throws {
        let session = try makeSession()
        let selection = ChapterTextMap.Selection(text: "Word", editionID: chapter.editionID, contentRevision: "fixture", sourceLabels: [], passages: [])
        let id = try XCTUnwrap(session.askFromScripture(selection: selection, referenceLabel: "Matthew 1:1",
            transmittedText: "Word", bookID: "MAT", chapter: 1, startVerse: 1, endVerse: 1,
            verseContextText: String(repeating: "Verse wording ", count: 250)))
        let request = CompanionContextBuilder.completionRequest(conversation: try XCTUnwrap(session.selectedConversation),
            messages: [CompanionMessage(conversationID: id, sequence: 0, role: .user, content: String(repeating: "Q", count: 23_500), deliveryState: .complete)],
            attachments: session.attachments + [CompanionAttachment(conversationID: UUID(), disclosure: .textTransmitted, referenceLabel: "Other chat", payload: "Unrelated private text")], pendingUserText: "")
        XCTAssertLessThanOrEqual(request.turns.reduce(0) { $0 + $1.content.count }, CompanionContextBuilder.maxTurnCharacters)
        XCTAssertTrue(request.turns.last?.content.contains("Reference only") == true)
        XCTAssertFalse((request.systemInstruction + request.turns.map(\.content).joined()).contains("Unrelated private text"))
    }
}

/// Captures exactly what Session passes across the provider boundary; no network or real keys.
private final class CapturingStudyAdapter: LLMProviderAdapter, @unchecked Sendable {
    let id = "study-fixture"
    let displayName = "Study fixture"
    private let lock = NSLock()
    private var captured: [LLMCompletionRequest] = []
    // Saving a provider also schedules Quiz Me warmup. Keep that independent traffic
    // out of chat assertions without disabling the app's lifecycle behavior.
    var requests: [LLMCompletionRequest] {
        lock.withLock { captured.filter { $0.systemInstruction.contains("Study scope:") } }
    }
    func advertisedCapabilities(modelID: String) -> Set<LLMProviderCapability> { [.streaming, .cancellation] }
    func validateConnection(apiKey: String, modelID: String) async throws {}
    func listModels(apiKey: String) async throws -> [String] { ["fixture"] }
    func streamCompletion(apiKey: String, request: LLMCompletionRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        lock.withLock { captured.append(request) }
        return AsyncThrowingStream {
            $0.yield(.responseStarted)
            $0.yield(.textDelta("Fixture response"))
            $0.yield(.completed)
            $0.finish()
        }
    }
}
