import XCTest
@testable import SophiaScriptura

@MainActor
final class SophyAcceptanceRegressionTests: XCTestCase {
    private struct Harness {
        var sophy: SophySession
        var companion: CompanionSession
        var notes: NotesSession
        var collections: CollectionsStore
        var activity: ActivityStore
        var music: MusicSession
        func send(_ text: String) async {
            await sophy.send(text, companion: companion, collections: collections, notes: notes,
                activity: activity, music: music, books: [])
        }
    }
    private func harness() async throws -> Harness {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Sophy-review-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let sophy = SophySession(repository: SophyFileRepository(directory: root.appendingPathComponent("sophy")), defaults: defaults)
        let notes = NotesSession(repository: NotesFileRepository(directory: root.appendingPathComponent("notes")))
        let collections = CollectionsStore(collections: [], artifacts: [], memberships: [], repository: CollectionsFileRepository(directory: root.appendingPathComponent("collections")))
        let activity = ActivityStore(repository: ActivityFileRepository(directory: root.appendingPathComponent("activity")))
        await notes.load(); await collections.load(); await activity.load()
        notes.collections = collections
        let companion = CompanionSession(presetCatalog: PromptPresetCatalog(seed: PromptPresetSeedFile(
            sharedGuardrail: "Stay faithful.", presets: [PromptPresetDefinition(id: "study", name: "Study", isBuiltIn: true, systemInstruction: "Be faithful.", reviewStatus: "approved")], contextVersion: 1)),
            repository: nil, credentials: InMemoryCompanionCredentialsStore())
        return Harness(sophy: sophy, companion: companion, notes: notes, collections: collections, activity: activity, music: MusicSession())
    }
    private var reply: String { #"{"version":1,"kind":"reply","message":"Hello","questions":[],"actions":[],"sourceHandles":[]}"# }

    func testOrdinaryChatNeverAttachesNoteBodiesAndProvidesTheActionContract() async throws {
        let h = try await harness()
        _ = h.notes.create(title: "Private study title")
        h.notes.replaceBody(NSRange(location: 0, length: 0), with: "BODY-MUST-NOT-BE-SENT")
        var sent = "", system = ""
        h.sophy.completionOverride = { instruction, prompt in system = instruction; sent = prompt; return .success(self.reply) }
        await h.send("Hello")
        XCTAssertEqual(h.sophy.phase, .completed)
        XCTAssertFalse(sent.contains("BODY-MUST-NOT-BE-SENT"))
        XCTAssertFalse(sent.contains("Private study title"))
        XCTAssertTrue(system.contains("localStartTime"))
        XCTAssertTrue(system.contains("parentKey"))
        XCTAssertTrue(system.contains("divine"))
        XCTAssertTrue(sent.contains("Presets: study=Study"))
    }
    func testLookupStaysLocalUntilSourcesAreReviewedAndPrivacyChangesClearContext() async throws {
        let h = try await harness()
        let id = try XCTUnwrap(h.notes.create(title: "Grace"))
        h.notes.replaceBody(NSRange(location: 0, length: 0), with: "A selected study excerpt")
        var calls = 0
        h.sophy.completionOverride = { _, prompt in
            calls += 1; XCTAssertTrue(prompt.contains("A selected study excerpt")); return .success(self.reply)
        }
        await h.send("/find Grace")
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(h.sophy.sources.first?.id, id)
        await h.sophy.askWithSources(companion: h.companion, collections: h.collections, notes: h.notes, activity: h.activity, music: h.music)
        XCTAssertEqual(calls, 1)
        h.notes.edit { $0.protectionID = UUID() }
        h.sophy.privacyChanged(collections: h.collections, notes: h.notes)
        XCTAssertTrue(h.sophy.sources.isEmpty)
        XCTAssertTrue(h.sophy.turns.isEmpty)
    }
    func testStopCancelsTheActualProviderTaskAndLateReplyCannotChangeState() async throws {
        let h = try await harness()
        var pending: CheckedContinuation<Result<String, SophySafeError>, Never>?
        var observedCancellation = false
        h.sophy.completionOverride = { _, _ in
            let result = await withCheckedContinuation { pending = $0 }
            observedCancellation = Task.isCancelled
            return result
        }
        let request = Task { await h.send("Hello") }
        for _ in 0..<1_000 { if pending != nil { break }; await Task.yield() }
        XCTAssertNotNil(pending)
        h.sophy.cancel()
        pending?.resume(returning: .success(reply))
        await request.value
        XCTAssertTrue(observedCancellation)
        XCTAssertEqual(h.sophy.phase, .cancelled)
        XCTAssertFalse(h.sophy.turns.contains { $0.role == "Sophy" })
    }
    func testRepairDoesNotEchoMalformedProviderPayload() async throws {
        let h = try await harness()
        var calls = 0
        h.sophy.completionOverride = { _, prompt in
            calls += 1
            if calls == 1 { return .success("{INVALID-PRIVATE-PROVIDER-CONTENT") }
            XCTAssertFalse(prompt.contains("INVALID-PRIVATE-PROVIDER-CONTENT"))
            XCTAssertTrue(prompt.contains("Original question"))
            return .success(self.reply)
        }
        await h.send("Original question")
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(h.sophy.phase, .completed)
    }
    func testPlainProviderReplyCompletesWithoutRepairOrActions() async throws {
        let h = try await harness()
        var calls = 0
        h.sophy.completionOverride = { _, _ in
            calls += 1
            return .success("Let us study this passage together.")
        }
        await h.send("Hello")
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(h.sophy.phase, .completed)
        XCTAssertTrue(h.sophy.turns.contains { $0.role == "Sophy" && $0.text == "Let us study this passage together." })
    }
    func testSlashCommandRetainsItsIntentForTheProvider() async throws {
        let h = try await harness()
        h.sophy.completionOverride = { _, prompt in
            XCTAssertTrue(prompt.contains("/reminder Read John tomorrow")); return .success(self.reply)
        }
        await h.send("/reminder Read John tomorrow")
    }
    func testClearHistorySlashRequestsConfirmationInsteadOfDeletingImmediately() async throws {
        let h = try await harness()
        let entry = SophyHistoryEntry(id: UUID(), createdAt: Date(), actionType: "lookup", status: "committed", resultIDs: [], resultCount: 0)
        h.sophy.history = [entry]; try await h.sophy.repository.saveHistory([entry])
        await h.send("/clear-history")
        XCTAssertTrue(h.sophy.clearHistoryRequested)
        let loaded = try await h.sophy.repository.loadHistory()
        XCTAssertEqual(loaded.value, [entry])
    }
    func testChatHandoffPreservesExistingComposerAndCreatesANewConversationWhenFree() async throws {
        let h = try await harness()
        h.companion.composerText = "Existing unsent draft"
        XCTAssertFalse(h.companion.stageSophyChat(presetID: "study", draft: "New question"))
        XCTAssertEqual(h.companion.composerText, "Existing unsent draft")
        try h.companion.saveProviderKey("test-only", adapterID: "openai", accountLabel: "Test", defaultModelID: "test-model")
        h.companion.composerText = ""
        XCTAssertTrue(h.companion.stageSophyChat(presetID: "study", draft: "New question"))
        XCTAssertEqual(h.companion.composerText, "New question")
        XCTAssertNotNil(h.companion.selectedConversationID)
        XCTAssertTrue(h.companion.messages.isEmpty)
    }
    func testDeletingExplicitProviderCannotSilentlySwitchToAnother() async throws {
        let h = try await harness()
        try h.companion.saveProviderKey("a", adapterID: "openai", accountLabel: "A", defaultModelID: "model-a")
        try h.companion.saveProviderKey("b", adapterID: "groq", accountLabel: "B", defaultModelID: "model-b")
        let first = try XCTUnwrap(h.companion.providerConfigurations.first)
        h.companion.setSharedProviderRoute(configurationID: first.id, modelID: "model-a")
        try h.companion.deleteProviderKey(configurationID: first.id)
        XCTAssertNil(h.companion.resolvedSharedRoute())
    }
    func testEnhancementRatingNeverProvidesAnApplyActionOrLeaksIntoChat() async throws {
        let h = try await harness()
        _ = h.notes.create(title: "Draft")
        h.notes.replaceBody(NSRange(location: 0, length: 0), with: "My selected text")
        let selection = try XCTUnwrap(h.notes.sophySelection(range: NSRange(location: 0, length: 16)))
        h.sophy.stageEnhancement(selection)
        h.sophy.enhancementOperation = .rate; h.sophy.enhancementRating = "grammar"
        h.sophy.completionOverride = { _, prompt in
            XCTAssertTrue(prompt.contains("My selected text"))
            XCTAssertFalse(prompt.contains("Draft"))
            return .success(#"{"version":1,"kind":"enhancement","replacementText":"DO NOT APPLY","feedback":"Helpful feedback","scores":{"grammar":8}}"#)
        }
        await h.sophy.generateEnhancement(companion: h.companion, notes: h.notes)
        XCTAssertTrue(h.sophy.enhancement?.isRating == true)
        XCTAssertEqual(h.sophy.enhancement?.scores?.grammar, 8)
        h.sophy.applyEnhancement(notes: h.notes)
        XCTAssertEqual(h.notes.note?.page?.body, "My selected text")
        XCTAssertTrue(h.sophy.turns.isEmpty)
    }
    func testChangingTheDocumentOutsideSelectionRejectsAnOldReview() async throws {
        let h = try await harness()
        _ = h.notes.create(title: "Draft")
        h.notes.replaceBody(NSRange(location: 0, length: 0), with: "Hello world")
        let selection = try XCTUnwrap(h.notes.sophySelection(range: NSRange(location: 6, length: 5)))
        h.sophy.stageEnhancement(selection)
        h.sophy.completionOverride = { _, _ in .success(#"{"version":1,"kind":"enhancement","replacementText":"grace","feedback":"Revised"}"#) }
        await h.sophy.generateEnhancement(companion: h.companion, notes: h.notes)
        h.notes.replaceBody(NSRange(location: 0, length: 5), with: "Howdy")
        h.sophy.applyEnhancement(notes: h.notes)
        XCTAssertEqual(h.notes.note?.page?.body, "Howdy world")
    }
    func testCanvasSelectionReplacesOnlyTheSelectedRangeAndUndoRestoresIt() async throws {
        let h = try await harness()
        let id = try XCTUnwrap(h.notes.create(title: "Draft"))
        var object = NoteObject(kind: .text); object.text = "Hello world"
        h.notes.edit { $0.objects.append(object) }
        XCTAssertTrue(h.notes.applySophyReplacement(noteID: id, range: NSRange(location: 6, length: 5), digest: SophyContextBuilder.digest("world"), replacement: "grace", canvasObjectID: object.id))
        XCTAssertEqual(h.notes.note?.objects.first?.text, "Hello grace")
        h.notes.undo(); XCTAssertEqual(h.notes.note?.objects.first?.text, "Hello world")
    }
    func testInvalidUnicodeRangesAreRejected() {
        XCTAssertNil(NotesSession.utf16Slice("A😀B", NSRange(location: 2, length: 1)))
        XCTAssertNil(NotesSession.utf16Slice("Hello", NSRange(location: NSNotFound, length: 1)))
        XCTAssertEqual(NotesSession.utf16Slice("A😀B", NSRange(location: 1, length: 2)), "😀")
    }
    func testImpossibleAndDaylightSavingDatesAreNotNormalizedSilently() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!
        XCTAssertNil(SophyActionExecutor.localDateTime(date: "2026-02-30", time: "08:00", calendar: calendar))
        XCTAssertNil(SophyActionExecutor.localDateTime(date: "2026-03-08", time: "02:30", calendar: calendar))
        XCTAssertNil(SophyActionExecutor.localDateTime(date: "2026-11-01", time: "01:30", calendar: calendar))
        XCTAssertNotNil(SophyActionExecutor.localDateTime(date: "2026-10-10", time: "08:00", calendar: calendar))
    }
    func testRecoveredHistoryKeepsItsGoodPreviousGenerationWhenSavedAgain() async throws {
        let h = try await harness()
        let repo = h.sophy.repository
        let entry = SophyHistoryEntry(id: UUID(), createdAt: Date(), actionType: "lookup", status: "committed", resultIDs: [], resultCount: 0)
        try await repo.saveHistory([entry]); try await repo.saveHistory([entry])
        let current = await repo.directory.appendingPathComponent("history/current.json")
        try Data("broken".utf8).write(to: current)
        let recovery = try await repo.loadHistory(); XCTAssertTrue(recovery.recovered)
        try await repo.saveHistory([entry])
        try Data("broken again".utf8).write(to: current)
        let again = try await repo.loadHistory(); XCTAssertTrue(again.recovered); XCTAssertEqual(again.value, [entry])
    }
    func testMissingCurrentHistoryRecoversPreviousInsteadOfReturningEmpty() async throws {
        let h = try await harness(), repo = h.sophy.repository
        let entry = SophyHistoryEntry(id: UUID(), createdAt: Date(), actionType: "lookup", status: "committed", resultIDs: [], resultCount: 0)
        try await repo.saveHistory([entry]); try await repo.saveHistory([entry])
        let current = await repo.directory.appendingPathComponent("history/current.json")
        try FileManager.default.removeItem(at: current)
        let recovery = try await repo.loadHistory(); XCTAssertTrue(recovery.recovered); XCTAssertEqual(recovery.value, [entry])
    }
    func testCorruptJournalBlocksExecutionWithoutCreatingAnything() async throws {
        let h = try await harness()
        let folder = await h.sophy.repository.directory.appendingPathComponent("journal")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("corrupt".utf8).write(to: folder.appendingPathComponent("current.json"))
        let result = await SophyActionExecutor.commit(actions: [.createFolders(destinationHandle: nil, nodes: [SophyFolderNodeDraft(key: "a", parentKey: nil, name: "A", description: "")])], handles: [:], collections: h.collections, activity: h.activity, repository: h.sophy.repository, now: Date(), calendar: .current)
        XCTAssertEqual(result, .rejected(.writeFailed))
        XCTAssertTrue(h.collections.children(of: nil).isEmpty)
    }
    func testInvalidLaterActionRejectsWholePlanBeforeAnyFolderIsSaved() async throws {
        let h = try await harness()
        let outcome = await SophyActionExecutor.commit(actions: [
            .createFolders(destinationHandle: nil, nodes: [SophyFolderNodeDraft(key: "a", parentKey: nil, name: "A", description: "")]),
            .createActivity(title: "Missing start", description: "", modeHandle: ActivityModeID.reading.id,
                localDate: "2026-10-01", localStartTime: nil, localEndDate: nil, localEndTime: nil, durationMinutes: 30)
        ], handles: [:], collections: h.collections, activity: h.activity, repository: h.sophy.repository, now: Date(), calendar: .current)
        XCTAssertEqual(outcome, .rejected(.invalidArguments))
        XCTAssertTrue(h.collections.children(of: nil).isEmpty)
        let journal = try await h.sophy.repository.loadJournal()
        XCTAssertTrue(journal.value.isEmpty)
    }
    func testHistoricalInsightsDoNotLabelAClosedPeriodIncomplete() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = calendar.date(from: DateComponents(year: 2025, month: 1, day: 2))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        let report = SophyInsights.report(records: [], modes: [], period: .month, at: anchor, calendar: calendar, now: now)
        XCTAssertFalse(report.incomplete)
    }

    func testFullBackupRoundTripIncludesHistoryButNeverJournalAndOldBackupsKeepHistory() async throws {
        let h = try await harness()
        let directory = await h.sophy.repository.directory
        let annotations = AnnotationSession(repository: AnnotationFileRepository(directory: directory.appendingPathComponent("annotations")))
        await annotations.open(nil)
        let entry = SophyHistoryEntry(id: UUID(), createdAt: Date(timeIntervalSince1970: 100), actionType: "lookup", status: "saved", resultIDs: [], resultCount: 0)
        let archive = try await StudyBackupService.export(notes: h.notes, annotations: annotations, activity: h.activity,
            collections: h.collections, companion: h.companion, sophyHistory: [entry])
        XCTAssertFalse(String(decoding: archive, as: UTF8.self).contains("journal"))
        try await StudyBackupService.restore(archive, notes: h.notes, annotations: annotations, activity: h.activity,
            collections: h.collections, companion: h.companion, readerDocument: nil, sophyRepository: h.sophy.repository)
        let restored = try await h.sophy.repository.loadHistory()
        XCTAssertEqual(restored.value, [entry])
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var old = try decoder.decode(StudyFullBackupEnvelope.self, from: archive); old.sophyHistory = nil
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try await StudyBackupService.restore(encoder.encode(old), notes: h.notes, annotations: annotations, activity: h.activity,
            collections: h.collections, companion: h.companion, readerDocument: nil, sophyRepository: h.sophy.repository)
        let kept = try await h.sophy.repository.loadHistory()
        XCTAssertEqual(kept.value, [entry])
    }
    func testInvalidBackupHistoryIsRejectedBeforeAnyRestoreWrites() async throws {
        let h = try await harness()
        _ = h.notes.create(title: "Keep this note")
        let directory = await h.sophy.repository.directory
        let annotations = AnnotationSession(repository: AnnotationFileRepository(directory: directory.appendingPathComponent("annotations")))
        await annotations.open(nil)
        let archive = try await StudyBackupService.export(notes: h.notes, annotations: annotations, activity: h.activity,
            collections: h.collections, companion: h.companion, sophyHistory: [])
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let before = h.notes.snapshot
        var envelope = try decoder.decode(StudyFullBackupEnvelope.self, from: archive)
        envelope.sophyHistory = [SophyHistoryEntry(id: UUID(), createdAt: Date(), actionType: "unknown", status: "saved", resultIDs: [], resultCount: 0)]
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        do {
            try await StudyBackupService.restore(encoder.encode(envelope), notes: h.notes, annotations: annotations, activity: h.activity,
                collections: h.collections, companion: h.companion, readerDocument: nil, sophyRepository: h.sophy.repository)
            XCTFail("Invalid history must stop restore")
        } catch {}
        XCTAssertEqual(h.notes.snapshot, before)
    }

    func testProtectedSelectionNeedsFreshConsentAndRelockDiscardsProviderResult() async throws {
        let h = try await harness()
        let password = "Sophy consent test 42"
        let credential = try ItemLockCredential.make(password: password)
        let protection = ItemProtectionSession(vault: ItemProtectionTests.Vault(credential), startTimer: false)
        h.notes.protection = protection
        let unlock = Task { try await protection.authenticate([.notes]) }
        for _ in 0..<100 { if protection.prompt != nil { break }; await Task.yield() }
        await protection.password(password, confirmation: ""); try await unlock.value
        _ = h.notes.create(title: "Protected draft")
        h.notes.replaceBody(NSRange(location: 0, length: 0), with: "Chosen text. Surrounding private words.")
        h.notes.edit { $0.protectionID = credential.id }
        let selection = try XCTUnwrap(h.notes.sophySelection(range: NSRange(location: 0, length: 12)))
        XCTAssertTrue(selection.requiresConsent)
        h.sophy.stageEnhancement(selection)
        var calls = 0
        h.sophy.completionOverride = { _, prompt in
            calls += 1
            XCTAssertTrue(prompt.contains("Chosen text.")); XCTAssertFalse(prompt.contains("Surrounding private"))
            protection.lock([.notes])
            return .success(#"{"version":1,"kind":"enhancement","replacementText":"A suggestion","feedback":"Checked"}"#)
        }
        await h.sophy.generateEnhancement(companion: h.companion, notes: h.notes)
        XCTAssertEqual(calls, 0)
        h.sophy.enhancementConsent = true
        await h.sophy.generateEnhancement(companion: h.companion, notes: h.notes)
        XCTAssertEqual(calls, 1)
        XCTAssertNil(h.sophy.enhancement); XCTAssertFalse(h.sophy.enhancementOpen)
    }

    func testNaturalEnhancementOpensReviewWithRequestedOperation() async throws {
        let h = try await harness()
        h.sophy.completionOverride = { _, _ in .success(#"{"version":1,"kind":"plan","message":"Review your text","questions":[],"actions":[{"type":"enhance","arguments":{"operation":"tone","tone":"professional"}}],"sourceHandles":[]}"#) }
        await h.send("Make my text professional")
        XCTAssertTrue(h.sophy.enhancementOpen)
        XCTAssertEqual(h.sophy.enhancementOperation, .tone)
        XCTAssertEqual(h.sophy.enhancementTone, "professional")
    }

    func testEditedActivityDurationNeverFallsBackToHiddenOriginalValue() async throws {
        let h = try await harness()
        h.sophy.completionOverride = { _, _ in .success(#"{"version":1,"kind":"plan","message":"Review activity","questions":[],"actions":[{"type":"createActivity","arguments":{"title":"Study","modeHandle":"reading","localDate":"2026-10-01","localStartTime":"08:00","durationMinutes":30}}],"sourceHandles":[]}"#) }
        await h.send("Record study")
        XCTAssertEqual(h.sophy.phase, .previewing)
        guard h.sophy.previewLines.count == 1 else { XCTFail(h.sophy.notice ?? "Missing preview"); return }
        h.sophy.previewLines[0].duration = "oops"
        await h.sophy.confirm(collections: h.collections, activity: h.activity, companion: h.companion, music: h.music)
        XCTAssertEqual(h.sophy.phase, .previewing); XCTAssertTrue(h.activity.records.isEmpty)
        guard h.sophy.previewLines.count == 1 else { XCTFail(h.sophy.notice ?? "Preview was discarded"); return }
        h.sophy.previewLines[0].duration = "45"
        await h.sophy.confirm(collections: h.collections, activity: h.activity, companion: h.companion, music: h.music)
        XCTAssertEqual(h.sophy.phase, .completed)
        XCTAssertEqual(h.activity.records.first?.activeSeconds, 2700)
    }

    func testCanvasListSelectionsUseExactNativeRangesAndKeepObjectStyle() async throws {
        let h = try await harness()
        let id = try XCTUnwrap(h.notes.create(title: "List"))
        for kind in [NoteObject.Kind.bullets, .numbered] {
            var object = NoteObject(kind: kind); object.text = "Cafe\u{301} study"; object.fontSize = 26
            h.notes.edit { $0.objects = [object] }
            let range = NSRange(location: 4, length: 1)
            let selection = try XCTUnwrap(h.notes.sophySelection(range: range, objectID: object.id))
            XCTAssertEqual(selection.text, "\u{301}")
            XCTAssertTrue(h.notes.applySophyReplacement(noteID: id, range: range, digest: selection.digest, replacement: "", canvasObjectID: object.id))
            XCTAssertEqual(h.notes.note?.objects.first?.text, "Cafe study")
            XCTAssertEqual(h.notes.note?.objects.first?.kind, kind)
            XCTAssertEqual(h.notes.note?.objects.first?.fontSize, 26)
            h.notes.undo(); XCTAssertEqual(h.notes.note?.objects.first?.text, "Cafe\u{301} study")
        }
    }

    func testExplicitClearHistoryRecoversADisabledStoreWithoutDeletingStudyItemsOrPreferences() async throws {
        let h = try await harness()
        let note = try XCTUnwrap(h.notes.create(title: "Keep"))
        h.sophy.setEnabled(true)
        let directory = await h.sophy.repository.directory.appendingPathComponent("history")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: directory.appendingPathComponent("current.json"))
        await h.sophy.load(collections: h.collections, activity: h.activity)
        XCTAssertFalse(h.sophy.storageAvailable)
        await h.sophy.clearHistory()
        XCTAssertTrue(h.sophy.storageAvailable); XCTAssertTrue(h.sophy.history.isEmpty)
        XCTAssertTrue(h.sophy.preferences.enabled)
        XCTAssertEqual(h.notes.note?.id, note)
        let result = try await h.sophy.repository.loadHistory()
        XCTAssertFalse(result.mutationsDisabled); XCTAssertTrue(result.value.isEmpty)
    }

}
