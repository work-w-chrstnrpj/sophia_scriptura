import XCTest
@testable import SophiaScriptura

final class SophyProductTests: XCTestCase {
    func testInsightsHideCustomNamesAndMarkEmptyPeriods() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let now = Date(timeIntervalSince1970: 1_772_000_000)
        let empty = SophyInsights.report(records: [], modes: [], period: .week, at: now, calendar: calendar)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.timeZoneID, "America/New_York")
        XCTAssertTrue(empty.providerLines.contains("empty=true"))

        let custom = ActivityMode(id: "custom-b", name: "Private name", isBuiltIn: false)
        let earlier = ActivityMode(id: "custom-a", name: "Also private", isBuiltIn: false)
        let record = ActivityRecord(
            id: UUID(), title: "Study", modeID: "custom-b", modeLabel: "Private name",
            activityDate: now, activeSeconds: 600, source: "manual", timeZoneID: "America/New_York",
            intervals: [], description: "", readingRange: nil, editionID: nil, quizSessionID: nil,
            createdAt: now, updatedAt: now
        )
        let report = SophyInsights.report(records: [record], modes: [earlier, custom], period: .day, at: now, calendar: calendar)
        XCTAssertTrue(report.ownerText.contains("Private name"))
        XCTAssertTrue(report.providerLines.contains { $0.hasPrefix("Custom activity 2:") })
        XCTAssertFalse(report.providerLines.joined().contains("Private"))
    }

    func testContextBuilderCapsSourcesAndTurns() {
        let records = (0..<12).map { index in
            SophyEligibleRecord(
                id: UUID(), kind: .note, title: "Note \(index)", body: String(repeating: "a", count: 3_000),
                tags: [], protectionID: nil, parentID: nil, membershipIDs: [], isArchived: false,
                isTrashed: false, isVirtualUnfiled: false, modifiedAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        let sources = SophyContextBuilder.sources(from: records)
        XCTAssertLessThanOrEqual(sources.count, 8)
        XCTAssertLessThanOrEqual(sources.reduce(0) { $0 + $1.excerpt.count }, 16_000)
        let turns = (0..<30).map { _ in SophyTurn(id: UUID(), role: "You", text: String(repeating: "b", count: 1_000)) }
        let kept = SophyContextBuilder.boundedTurns(turns)
        XCTAssertLessThanOrEqual(kept.count, 20)
        XCTAssertLessThanOrEqual(kept.reduce(0) { $0 + $1.text.count }, 24_000)
    }

    func testReconcileDoesNotReplayAMissingOrDeletedResult() {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 10)
        let applying = SophyJournalEntry(id: UUID(), planID: UUID(), actionType: "createReminder", resultIDs: [id], state: .applying, createdAt: now, updatedAt: now, safeErrorCode: nil)
        let resolved = SophyActionExecutor.reconcile(journal: [applying], presentIDs: [], featureRecoveredOlderGeneration: false, now: now)
        XCTAssertEqual(resolved.first?.state, .rejected)
        XCTAssertEqual(resolved.first?.safeErrorCode, SophySafeError.notApplied.code)

        let committed = SophyJournalEntry(id: UUID(), planID: UUID(), actionType: "createReminder", resultIDs: [id], state: .committed, createdAt: now, updatedAt: now, safeErrorCode: nil)
        let still = SophyActionExecutor.reconcile(journal: [committed], presentIDs: [], featureRecoveredOlderGeneration: false, now: now)
        XCTAssertEqual(still, [committed])
    }

    func testSlashAliasesAndUnknownCommandStayLocal() {
        XCTAssertEqual(SophyCommandParser.slashCommand(in: "/bible-tree")?.command, .bibleTree)
        let books = [ScriptureBook(id: "JAS", title: "James", testament: "NT", order: 59, chapterCount: 5),
                     ScriptureBook(id: "GEN", title: "Genesis", testament: "OT", order: 1, chapterCount: 50)]
        let james = SophyScriptureNavigationParser.parse("Take me to the book of James in Scripture", books: books)
        XCTAssertEqual(james?.book, "JAS")
        let genesis = SophyScriptureNavigationParser.parse("Let me view Genesis 2:13 WEB translation in Scripture's tab", books: books)
        XCTAssertEqual(genesis?.book, "GEN")
        XCTAssertEqual(genesis?.chapter, 2)
        XCTAssertEqual(genesis?.verse, 13)
        XCTAssertEqual(genesis?.editionAbbreviation, "WEB")
        XCTAssertTrue(ScriptureVerseText.shouldInsertSpace(after: ";", before: "f"))
        let folder = SophyFolderIntentParser.parse("Create a folder called Prayer")
        XCTAssertEqual(folder?.first?.name, "Prayer")
        let bibleRequest = "Create me folder in collections called Bible, add subfolder called New & Old Testament then, for each subfolder, populate it with subfolders of books associated to it, only add the 66 books"
        XCTAssertTrue(SophyBibleTree.requestsHierarchy(bibleRequest))
        XCTAssertNil(SophyFolderIntentParser.parse(bibleRequest))
        XCTAssertEqual(SophyCommandParser.slashCommand(in: "/create-collection-folder Prayer")?.command, .folders)
        XCTAssertEqual(SophyCommandParser.slashCommand(in: "/create-bible-collection-tree")?.command, .bibleTree)
        XCTAssertTrue(SophySlashCommandCatalog.helpMessage.contains("/create-bible-collection-tree"))
        XCTAssertTrue(SophySlashCommandStyle.showsHighlightedOverlay(for: "/create-collection-folder Bible"))
        XCTAssertFalse(SophySlashCommandStyle.showsHighlightedOverlay(for: "Create a folder"))
        XCTAssertEqual(SophyCommandParser.slashCommand(in: "/search grace")?.command, .find)
        XCTAssertEqual(SophyCommandParser.slashCommand(in: "/not-a-command")?.command, .unknown("not-a-command"))
    }
}

@MainActor
final class SophyCommandTests: XCTestCase {
    func testBibleTreePreviewCanBeCancelledWithoutWriting() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sophy-ui-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let collectionsDirectory = directory.appendingPathComponent("collections", isDirectory: true)
        let sophyDirectory = directory.appendingPathComponent("sophy", isDirectory: true)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let sophy = SophySession(repository: SophyFileRepository(directory: sophyDirectory), defaults: defaults)
        XCTAssertFalse(sophy.preferences.enabled)
        let collections = CollectionsStore(collections: [], artifacts: [], memberships: [], repository: CollectionsFileRepository(directory: collectionsDirectory))
        await collections.load()
        let activity = ActivityStore(repository: ActivityFileRepository(directory: directory.appendingPathComponent("activity", isDirectory: true)))
        await activity.load()
        let notes = NotesSession(repository: NotesFileRepository(directory: directory.appendingPathComponent("notes", isDirectory: true)))
        await notes.load()
        let music = MusicSession()
        let companion = CompanionSession(
            presetCatalog: PromptPresetCatalog(seed: PromptPresetSeedFile(
                sharedGuardrail: "Stay faithful.",
                presets: [PromptPresetDefinition(id: "study", name: "Study", isBuiltIn: true, systemInstruction: "Be faithful.", reviewStatus: "approved")],
                contextVersion: 1
            )),
            repository: nil,
            credentials: InMemoryCompanionCredentialsStore()
        )
        let books = [
            ScriptureBook(id: "GEN", title: "Genesis", testament: "OT", order: 1, chapterCount: 50),
            ScriptureBook(id: "MAT", title: "Matthew", testament: "NT", order: 40, chapterCount: 28)
        ]
        await sophy.send("/create-bible-collection-tree", companion: companion, collections: collections, notes: notes, activity: activity, music: music, books: books)
        XCTAssertEqual(sophy.phase, .previewing)
        XCTAssertEqual(sophy.previewLines.count, 5)
        XCTAssertEqual(collections.collections.filter { !$0.isUnfiled }.count, 0)
        sophy.cancelPreview()
        XCTAssertEqual(sophy.phase, .completed)
        XCTAssertTrue(sophy.previewLines.isEmpty)
        let journal = try await sophy.repository.loadJournal()
        XCTAssertTrue(journal.value.isEmpty)
        XCTAssertEqual(collections.collections.filter { !$0.isUnfiled }.count, 0)
    }

    func testReminderRetryDoesNotCreateASecondReminder() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sophy-reminder-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let activity = ActivityStore(repository: ActivityFileRepository(directory: directory), syncReminderNotifications: { _, _ in false })
        await activity.load()
        let id = UUID()
        let mode = ActivityMode(id: ActivityModeID.reading.id, name: "Reading", isBuiltIn: true)
        let when = Date().addingTimeInterval(86_400)
        let first = await activity.createReminderFromSophy(id: id, title: "Read", description: "", date: when, mode: mode, repeatRule: .once, deleteAfterFiring: false)
        XCTAssertEqual(first, .committed(resultIDs: [id]))
        let second = await activity.createReminderFromSophy(id: id, title: "Read", description: "", date: when, mode: mode, repeatRule: .once, deleteAfterFiring: false)
        XCTAssertEqual(second, .alreadyCommitted(resultIDs: [id]))
        XCTAssertEqual(activity.reminders.count, 1)
    }

    func testStaleEnhancementDoesNotReplaceTheNote() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sophy-notes-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let notes = NotesSession(repository: NotesFileRepository(directory: directory))
        await notes.load()
        let id = try XCTUnwrap(notes.create(title: "Draft"))
        notes.open(id)
        notes.replaceBody(NSRange(location: 0, length: 0), with: "Hello world")
        let range = NSRange(location: 6, length: 5)
        guard let selection = notes.sophySelection(range: range) else { return XCTFail("Missing selection") }
        XCTAssertTrue(notes.applySophyReplacement(noteID: selection.noteID, range: selection.range,
            digest: selection.digest, replacement: "grace", canvasObjectID: selection.objectID))
        XCTAssertEqual(notes.note?.page?.body, "Hello grace")
        XCTAssertFalse(notes.applySophyReplacement(noteID: selection.noteID, range: selection.range,
            digest: selection.digest, replacement: "again", canvasObjectID: selection.objectID))
        XCTAssertEqual(notes.note?.page?.body, "Hello grace")

        notes.edit { note in
            var object = NoteObject(kind: .text)
            object.id = UUID(uuidString: "00000000-0000-4000-8000-0000000000AA")!
            object.text = "Canvas line"
            note.objects.append(object)
        }
        let canvasRange = NSRange(location: 0, length: 11)
        let objectID = UUID(uuidString: "00000000-0000-4000-8000-0000000000AA")!
        guard let canvasSelection = notes.sophySelection(range: canvasRange, objectID: objectID) else { return XCTFail("Missing canvas selection") }
        XCTAssertTrue(notes.applySophyReplacement(noteID: canvasSelection.noteID, range: canvasSelection.range,
            digest: canvasSelection.digest, replacement: "Revised", canvasObjectID: canvasSelection.objectID))
        XCTAssertEqual(notes.note?.objects.first { $0.id == objectID }?.text, "Revised")
        notes.replaceBody(NSRange(location: 0, length: 5), with: "Changed")
        XCTAssertFalse(notes.sophySelectionIsCurrent(canvasSelection))
    }
}
