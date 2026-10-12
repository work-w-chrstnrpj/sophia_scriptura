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
