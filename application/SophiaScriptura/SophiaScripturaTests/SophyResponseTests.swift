import XCTest
@testable import SophiaScriptura

final class SophyResponseTests: XCTestCase {
    private var context: SophyValidationContext {
        SophyValidationContext(
            destinationHandles: ["dest"],
            modeHandles: ["reading"],
            trackHandles: ["track-1"],
            presetHandles: ["default"],
            sourceHandles: ["n1"],
            quizTypes: ["identifyVerse"],
            difficulties: ["easy"]
        )
    }

    func testFolderPlanFixtureValidatesAndRejectsUnsafeActions() throws {
        let fixture = """
        {"version":1,"kind":"plan","message":"Review these folders.","questions":[],"actions":[{"type":"createFolders","arguments":{"destinationHandle":null,"nodes":[{"key":"bible","parentKey":null,"name":"Bible","description":"Bible study notes."},{"key":"old","parentKey":"bible","name":"Old Testament","description":"Old Testament study notes."},{"key":"genesis","parentKey":"old","name":"Genesis","description":"This folder is notes about the Genesis."}]}}],"sourceHandles":[]}
        """
        let plan = try SophyResponseValidator.validate(Data(fixture.utf8), context: context)
        guard case .createFolders(let destination, let nodes) = plan.actions.first else {
            return XCTFail("Expected folders")
        }
        XCTAssertNil(destination)
        XCTAssertEqual(nodes.map(\.name), ["Bible", "Old Testament", "Genesis"])

        XCTAssertThrowsError(try SophyResponseValidator.validate(Data(planJSON(type: "deleteNote", arguments: "{}").utf8), context: context)) { error in
            XCTAssertEqual(error as? SophySafeError, .unknownAction)
        }
        let injected = planJSON(type: "createFolders", arguments: #"{"destinationHandle":null,"nodes":[{"key":"a","parentKey":null,"name":"A","description":""}],"script":"rm"}"#)
        XCTAssertThrowsError(try SophyResponseValidator.validate(Data(injected.utf8), context: context)) { error in
            XCTAssertEqual(error as? SophySafeError, .invalidArguments)
        }
        let duplicate = #"{"version":1,"version":2,"kind":"reply","message":"Hi","questions":[],"actions":[],"sourceHandles":[]}"#
        XCTAssertThrowsError(try SophyResponseValidator.validate(Data(duplicate.utf8), context: context)) { error in
            XCTAssertEqual(error as? SophySafeError, .malformedPlan)
        }
        let forged = #"{"version":1,"kind":"reply","message":"Hi","questions":[],"actions":[],"sourceHandles":["secret"]}"#
        XCTAssertThrowsError(try SophyResponseValidator.validate(Data(forged.utf8), context: context)) { error in
            XCTAssertEqual(error as? SophySafeError, .forgedHandle)
        }
        let missingDestination = planJSON(type: "createFolders", arguments: #"{"destinationHandle":"missing","nodes":[{"key":"a","parentKey":null,"name":"A","description":""}]}"#)
        XCTAssertThrowsError(try SophyResponseValidator.validate(Data(missingDestination.utf8), context: context)) { error in
            XCTAssertEqual(error as? SophySafeError, .forgedHandle)
        }
        let cycle = planJSON(type: "createFolders", arguments: #"{"destinationHandle":null,"nodes":[{"key":"a","parentKey":"b","name":"A","description":""},{"key":"b","parentKey":"a","name":"B","description":""}]}"#)
        XCTAssertThrowsError(try SophyResponseValidator.validate(Data(cycle.utf8), context: context)) { error in
            XCTAssertEqual(error as? SophySafeError, .invalidArguments)
        }
        let reserved = planJSON(type: "createFolders", arguments: #"{"nodes":[{"key":"a","parentKey":null,"name":"No Folder","description":""}]}"#)
        XCTAssertThrowsError(try SophyResponseValidator.validate(Data(reserved.utf8), context: context)) { error in
            XCTAssertEqual(error as? SophySafeError, .invalidArguments)
        }
        let huge = Data(String(repeating: "a", count: 70_000).utf8)
        XCTAssertThrowsError(try SophyResponseValidator.validate(huge, context: context))

        let looseProvider = """
        {"version":"1","kind":"Plan","message":"Review","questions":[],"actions":[{"type":"createFolders","arguments":{"destinationHandle":"","nodes":[{"key":"bible","parentKey":"","name":"Bible","description":null}]}}],"sourceHandles":[],"notes":"ignored"}
        """
        let relaxed = try SophyResponseValidator.validate(Data(looseProvider.utf8), context: context)
        guard case .createFolders(let destination, let nodes) = relaxed.actions.first else {
            return XCTFail("Expected relaxed folder plan")
        }
        XCTAssertNil(destination)
        XCTAssertEqual(nodes.first?.name, "Bible")

        let lowercasedType = """
        {"version":1,"kind":"plan","message":"Review","questions":[],"actions":[{"type":"createfolders","arguments":{"nodes":[{"key":"a","parentKey":null,"name":"Prayer","description":""}]}}],"sourceHandles":[]}
        """
        let lowered = try SophyResponseValidator.validate(Data(lowercasedType.utf8), context: context)
        XCTAssertEqual(lowered.actions.first?.typeName, "createFolders")
    }

    func testReplyCannotAuthorizeActionsAndClarificationDoesNotMutate() throws {
        let fenced = """
        ```json
        {"version":1,"kind":"reply","message":"Hello","questions":[],"actions":[],"sourceHandles":[]}
        ```
        """
        let fromFence = try SophyResponseValidator.validate(try SophyJSON.normalizedPayload(from: fenced), context: context)
        XCTAssertEqual(fromFence.message, "Hello")

        let reply = #"{"version":1,"kind":"reply","message":"I created it.","questions":[],"actions":[],"sourceHandles":["n1"]}"#
        let parsed = try SophyResponseValidator.validate(Data(reply.utf8), context: context)
        XCTAssertEqual(parsed.kind, .reply)
        XCTAssertTrue(parsed.actions.isEmpty)
        let badReply = #"{"version":1,"kind":"reply","message":"Done","questions":[],"actions":[{"type":"music","arguments":{"operation":"pause"}}],"sourceHandles":[]}"#
        XCTAssertThrowsError(try SophyResponseValidator.validate(Data(badReply.utf8), context: context))
        let question = #"{"version":1,"kind":"clarification","message":"What time?","questions":[{"field":"time","prompt":"What time?","choices":[]}],"actions":[],"sourceHandles":[]}"#
        let clarification = try SophyResponseValidator.validate(Data(question.utf8), context: context)
        XCTAssertEqual(clarification.questions.count, 1)
        XCTAssertTrue(clarification.actions.isEmpty)
    }

    func testBibleTreeUsesCatalogOrderAndBookDescriptions() {
        let books = [
            ScriptureBook(id: "MAT", title: "Matthew", testament: "NT", order: 40, chapterCount: 28),
            ScriptureBook(id: "GEN", title: "Genesis", testament: "OT", order: 1, chapterCount: 50),
            ScriptureBook(id: "EXO", title: "Exodus", testament: "OT", order: 2, chapterCount: 40)
        ]
        let nodes = SophyBibleTree.folderDrafts(books: books)
        XCTAssertEqual(nodes.map(\.name), ["Bible", "Old Testament", "New Testament", "Genesis", "Exodus", "Matthew"])
        XCTAssertEqual(nodes.first { $0.key == "GEN" }?.parentKey, "ot")
        XCTAssertEqual(nodes.first { $0.key == "MAT" }?.parentKey, "nt")
        XCTAssertEqual(nodes.first { $0.key == "GEN" }?.description, "This folder is notes about the Genesis.")
    }

    func testUnknownSlashCommandDoesNotLookLikeAMutation() {
        let parsed = SophyCommandParser.slashCommand(in: "/delete everything")
        XCTAssertEqual(parsed?.command, .unknown("delete"))
        XCTAssertEqual(SophyCommandParser.slashCommand(in: "/folders Bible")?.command, .folders)
        XCTAssertNil(SophyCommandParser.slashCommand(in: "please remind me"))
    }

    private func planJSON(type: String, arguments: String) -> String {
        #"{"version":1,"kind":"plan","message":"Review","questions":[],"actions":[{"type":""# + type + #"","arguments":"# + arguments + #"}],"sourceHandles":[]}"#
    }
}

final class SophyStateTests: XCTestCase {
    func testSavedCommitCannotBeCancelledAndLateCallbacksRequireTheSameGeneration() {
        XCTAssertEqual(SophyExecutionState.transition(.idle, .send), .interpreting)
        XCTAssertEqual(SophyExecutionState.transition(.previewing, .confirm), .committing)
        XCTAssertNil(SophyExecutionState.transition(.committing, .cancel))
        XCTAssertEqual(SophyExecutionState.transition(.committing, .uncertain), .uncertain)
        XCTAssertEqual(SophyExecutionState.transition(.previewing, .cancel), .cancelled)
        XCTAssertEqual(SophyExecutionState.transition(.enhancing, .cancel), .cancelled)
        let generation = UUID()
        XCTAssertTrue(SophyExecutionState.acceptsLateCallback(activeGeneration: generation, callbackGeneration: generation, activeRoute: "a", callbackRoute: "a"))
        XCTAssertFalse(SophyExecutionState.acceptsLateCallback(activeGeneration: generation, callbackGeneration: UUID(), activeRoute: "a", callbackRoute: "a"))
        XCTAssertFalse(SophyExecutionState.acceptsLateCallback(activeGeneration: generation, callbackGeneration: generation, activeRoute: "a", callbackRoute: "b"))
    }

    func testCrashReconciliationNeverTreatsAbsenceAfterRecoveryAsProof() {
        let ids = [UUID(), UUID()]
        let applying = SophyJournalEntry(id: UUID(), planID: UUID(), actionType: "createFolders", resultIDs: ids, state: .applying, createdAt: Date(), updatedAt: Date(), safeErrorCode: nil)
        XCTAssertEqual(SophyReconciler.disposition(entry: applying, presentResultIDs: Set(ids), featureRecoveredOlderGeneration: false), .committed)
        XCTAssertEqual(SophyReconciler.disposition(entry: applying, presentResultIDs: [], featureRecoveredOlderGeneration: false), .notApplied)
        XCTAssertEqual(SophyReconciler.disposition(entry: applying, presentResultIDs: [ids[0]], featureRecoveredOlderGeneration: false), .integrityError)
        XCTAssertEqual(SophyReconciler.disposition(entry: applying, presentResultIDs: [], featureRecoveredOlderGeneration: true), .uncertain)
        var committed = applying
        committed.state = .committed
        XCTAssertEqual(SophyReconciler.disposition(entry: committed, presentResultIDs: [], featureRecoveredOlderGeneration: false), .terminal)
    }
}

final class SophyPlanResponseTests: XCTestCase {
    private var plan: StudyPlan {
        .init(title: "Shared study", preferredEditionID: ScriptureReferenceIdentity.bundledEditionID,
            referenceSystemID: "org.sophia.web.engwebp", sections: [.init(items: [
                .init(payload: .scripture(referenceSystemID: "org.sophia.web.engwebp", book: "JHN", chapter: 1), completedAt: Date())])])
    }
    private func parse(_ arguments: String, shared: StudyPlan? = nil) throws -> SophyActionDraft {
        let raw = "{\"version\":1,\"kind\":\"plan\",\"message\":\"Review\",\"questions\":[],\"actions\":[{\"type\":\"updatePlan\",\"arguments\":" + arguments + "}],\"sourceHandles\":[]}"
        let response = try SophyResponseValidator.validate(Data(raw.utf8), context: .init(sharedPlan: shared,
            chapterCounts: ["GEN": 50, "1KI": 22], bookIDs: ["GEN", "1KI"],
            bookIDByTitle: ["genesis": "GEN", "1 kings": "1KI"]))
        return try XCTUnwrap(response.actions.first)
    }
    func testAdditiveAndTotalCountsPreserveExistingContentAndCompletion() throws {
        let before = plan
        for (arguments, count) in [(#"{"addSections":15}"#, 16), (#"{"totalSections":60}"#, 60)] {
            guard case .updatePlan(let original, let after) = try parse(arguments, shared: before) else { return XCTFail() }
            XCTAssertEqual(original, before); XCTAssertEqual(after.sections.count, count)
            XCTAssertEqual(after.sections.first, before.sections.first)
            XCTAssertEqual(Set(after.sections.map(\.id)).count, count)
            XCTAssertEqual(after.revision, before.revision)
        }
    }
    func testMultipleReferencesTargetExplicitSectionsIncludingNewDays() throws {
        let before = plan
        let arguments = #"{"addSections":2,"assignments":[{"sectionNumber":1,"book":"Genesis","chapter":1,"startVerse":1},{"sectionNumber":3,"book":"1 Kings","chapter":1,"startVerse":1,"endVerse":3}]}"#
        guard case .updatePlan(_, let after) = try parse(arguments, shared: before) else { return XCTFail() }
        XCTAssertEqual(after.sections[0].items[0], before.sections[0].items[0])
        XCTAssertEqual(after.sections[0].items.last?.payload.referenceLabel, "GEN 1:1")
        XCTAssertEqual(after.sections[2].items.last?.payload.referenceLabel, "1KI 1:1–3")
        XCTAssertTrue(after.sections[1].items.isEmpty)
    }
    func testAddingToFinishedSectionPreservesItsActivitySessionAndOpensNewItem() throws {
        var before = plan
        let sessionID = UUID()
        before.cursor = .init(kind: .sectionSummary, sectionID: before.sections[0].id, activitySessionID: sessionID)
        guard case .updatePlan(_, let after) = try parse(#"{"assignments":[{"sectionNumber":1,"book":"GEN","chapter":1,"startVerse":1}]}"#, shared: before) else { return XCTFail() }
        XCTAssertEqual(after.cursor?.kind, .item)
        XCTAssertEqual(after.cursor?.itemID, after.items.last?.id)
        XCTAssertEqual(after.cursor?.activitySessionID, sessionID)
        XCTAssertTrue(SophyPlanEdit.isAdditive(before: before, after: after))
        var destructive = after; destructive.sections[0].items.removeFirst()
        XCTAssertFalse(SophyPlanEdit.isAdditive(before: before, after: destructive))
        destructive = after; destructive.title = "Injected rename"
        XCTAssertFalse(SophyPlanEdit.isAdditive(before: before, after: destructive))
    }

    func testInvalidOrUnsharedRequestsFailClosed() throws {
        XCTAssertThrowsError(try parse(#"{"addSections":1}"#))
        var empty = plan; empty.sections = []
        XCTAssertThrowsError(try parse(#"{"assignments":[{"sectionNumber":1,"book":"GEN","chapter":1}]}"#, shared: empty))
        var protected = plan; protected.access.notesCredentialIDs.insert(UUID())
        XCTAssertThrowsError(try parse(#"{"addSections":1}"#, shared: protected))
        for arguments in [#"{"addSections":0}"#, #"{"addSections":-1}"#, #"{"totalSections":0}"#,
            #"{"totalSections":201}"#, #"{"addSections":200}"#, #"{"addSections":2,"totalSections":5}"#,
            #"{"assignments":[{"book":"GEN","chapter":1}]}"#,
            #"{"assignments":[{"sectionNumber":2,"book":"GEN","chapter":1}]}"#,
            #"{"assignments":[{"sectionNumber":1,"book":"GEN","chapter":51}]}"#,
            #"{"assignments":[{"sectionNumber":1,"book":"unknown","chapter":1}]}"#,
            #"{"assignments":[{"sectionNumber":1,"book":"GEN","chapter":1,"startVerse":4,"endVerse":1}]}"#,
            #"{"deleteSections":1}"#, #"{}"#] {
            XCTAssertThrowsError(try parse(arguments, shared: plan), arguments)
        }
    }
}
