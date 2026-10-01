import XCTest

final class CanvasExperimentUITests: XCTestCase {
    private func open(_ app: XCUIApplication) {
        app.launch()
        let notes = app.buttons["Notes"].firstMatch
        XCTAssertTrue(notes.waitForExistence(timeout: 10))
        notes.tap()
        app.buttons["notes.backups"].tap()
        let link = app.buttons["notes.openCanvasExperiment"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(app.staticTexts["canvas.observation"].waitForExistence(timeout: 10))
    }

    private func waitFor(_ app: XCUIApplication, status: String) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", status),
            object: app.staticTexts["canvas.status"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }

    func testMoveGroupUndoEditAndReopenAcrossLaunches() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SP006_UI_TEST_FIXTURE"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        open(app)
        let text = app.staticTexts["canvas.observation"]
        let origin = text.frame.origin
        app.buttons["Move selected objects right"].tap()
        XCTAssertEqual(text.frame.minX, origin.x + 20, accuracy: 1)
        app.buttons["Undo document edit"].tap()
        XCTAssertEqual(text.frame.minX, origin.x, accuracy: 1)
        app.buttons["canvas.select.ink"].tap()
        app.buttons["canvas.group"].tap()
        XCTAssertTrue(app.buttons["Ungroup"].isEnabled)
        let before = text.frame.origin
        app.buttons["Move selected objects down"].tap()
        XCTAssertEqual(text.frame.minY, before.y + 20, accuracy: 1)
        app.buttons["Edit text"].tap()
        let editor = app.textViews["Observation text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(" Native test.")
        app.buttons["Done"].tap()
        app.buttons["canvas.sample"].tap()
        app.buttons["Save and reopen"].tap()
        waitFor(app, status: "Reopened from disk")
        XCTAssertTrue((text.value as? String ?? text.label).contains("Native test."))
        app.buttons["canvas.sample"].tap()
        app.buttons["Check damaged restore"].tap()
        waitFor(app, status: "saved sample unchanged")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["Edit text"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Canvas experiment — landscape"
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
        open(app)
        XCTAssertTrue((text.value as? String ?? text.label).contains("Native test."))
        XCTAssertTrue(app.buttons["Ungroup"].isEnabled)
    }

    func testGroupingUngroupingPreservesIndependentObjects() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SP006_UI_TEST_FIXTURE"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        open(app)
        // Fit the whole ink object on screen so its accessibility frame is not
        // clipped. Each 20-point document move is 10 screen points at 50% zoom.
        app.buttons["Zoom out"].tap()
        app.buttons["Zoom out"].tap()
        app.buttons["canvas.select.ink"].tap()
        let text = app.staticTexts["canvas.observation"]
        let ink = app.descendants(matching: .any)["canvas.ink"].firstMatch
        let image = app.images["Morning reflection, illustrated landscape"]
        XCTAssertTrue(ink.exists)
        XCTAssertTrue(image.exists)
        let textContent = text.value as? String
        let inkContent = ink.value as? String
        XCTAssertNotNil(textContent)
        XCTAssertEqual(inkContent, "1 strokes")

        func checkFrame(_ actual: CGRect, _ expected: CGRect,
                        file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(actual.minX, expected.minX, accuracy: 1, file: file, line: line)
            XCTAssertEqual(actual.minY, expected.minY, accuracy: 1, file: file, line: line)
            XCTAssertEqual(actual.width, expected.width, accuracy: 1, file: file, line: line)
            XCTAssertEqual(actual.height, expected.height, accuracy: 1, file: file, line: line)
        }
        let initialText = text.frame
        let initialInk = ink.frame
        let initialImage = image.frame
        app.buttons["canvas.group"].tap()
        XCTAssertTrue(app.buttons["Ungroup"].isEnabled)
        checkFrame(text.frame, initialText)
        checkFrame(ink.frame, initialInk)
        app.buttons["Move selected objects right"].tap()
        app.buttons["Move selected objects right"].tap()
        checkFrame(text.frame, initialText.offsetBy(dx: 20, dy: 0))
        checkFrame(ink.frame, initialInk.offsetBy(dx: 20, dy: 0))
        checkFrame(image.frame, initialImage)

        let groupedText = text.frame
        let groupedInk = ink.frame
        app.buttons["Ungroup"].tap()
        XCTAssertFalse(app.buttons["Ungroup"].isEnabled)
        checkFrame(text.frame, groupedText)
        checkFrame(ink.frame, groupedInk)
        checkFrame(image.frame, initialImage)
        app.buttons["canvas.select.ink"].tap()
        app.buttons["Move selected objects right"].tap()
        checkFrame(text.frame, groupedText.offsetBy(dx: 10, dy: 0))
        checkFrame(ink.frame, groupedInk)
        checkFrame(image.frame, initialImage)
        XCTAssertEqual(text.value as? String, textContent)
        XCTAssertEqual(ink.value as? String, inkContent)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Ungrouped text moves independently of ink and image"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testTextEditingSavesCancelsAndPreservesGroupedInk() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SP006_UI_TEST_FIXTURE"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        open(app)
        app.buttons["Zoom out"].tap()
        app.buttons["Zoom out"].tap()
        app.buttons["canvas.select.ink"].tap()
        app.buttons["canvas.group"].tap()
        // Group members are selected as a unit; retain that selection while editing.
        let text = app.staticTexts["canvas.observation"]
        let ink = app.descendants(matching: .any)["canvas.ink"].firstMatch
        let image = app.images["Morning reflection, illustrated landscape"]
        XCTAssertTrue(ink.exists)
        XCTAssertTrue(image.exists)
        let originalText = text.value as? String
        let originalInk = ink.value as? String
        XCTAssertNotNil(originalText)
        XCTAssertEqual(originalInk, "1 strokes")
        let frames = [text.frame, ink.frame, image.frame]
        func checkGeometry(_ expected: [CGRect], file: StaticString = #filePath, line: UInt = #line) {
            for (element, frame) in zip([text, ink, image], expected) {
                XCTAssertEqual(element.frame.minX, frame.minX, accuracy: 1, file: file, line: line)
                XCTAssertEqual(element.frame.minY, frame.minY, accuracy: 1, file: file, line: line)
                XCTAssertEqual(element.frame.width, frame.width, accuracy: 1, file: file, line: line)
                XCTAssertEqual(element.frame.height, frame.height, accuracy: 1, file: file, line: line)
            }
        }
        app.buttons["Edit text"].tap()
        let editor = app.textViews["Observation text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        let addition = " More reflection changes the length of this observation."
        editor.typeText(addition)
        let savedText = editor.value as? String
        XCTAssertTrue(savedText?.contains(addition) == true)
        XCTAssertNotEqual(savedText, originalText)
        app.buttons["Done"].tap()
        XCTAssertEqual(text.value as? String, savedText)
        XCTAssertEqual(ink.value as? String, originalInk)
        checkGeometry(frames)
        XCTAssertTrue(app.buttons["Ungroup"].isEnabled)

        app.buttons["Edit text"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, savedText)
        editor.tap()
        editor.typeText(" DISCARD THIS DRAFT.")
        XCTAssertTrue((editor.value as? String)?.contains("DISCARD THIS DRAFT.") == true)
        app.buttons["Cancel"].tap()
        XCTAssertEqual(text.value as? String, savedText)
        XCTAssertEqual(ink.value as? String, originalInk)
        checkGeometry(frames)
        app.buttons["Move selected objects right"].tap()
        let moved = [frames[0].offsetBy(dx: 10, dy: 0),
                     frames[1].offsetBy(dx: 10, dy: 0), frames[2]]
        checkGeometry(moved)
        app.buttons["Undo document edit"].tap()
        checkGeometry(frames)

        app.buttons["canvas.sample"].tap()
        app.buttons["Save and reopen"].tap()
        waitFor(app, status: "Reopened from disk")
        XCTAssertEqual(text.value as? String, savedText)
        XCTAssertEqual(ink.value as? String, originalInk)
        XCTAssertTrue(app.buttons["Ungroup"].isEnabled)
        checkGeometry(frames)
        app.buttons["Edit text"].tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertEqual(editor.value as? String, savedText)
        app.buttons["Cancel"].tap()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Saved text and grouped ink after canceled draft and reopen"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testFingerInkSurvivesReopen() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["SP006_UI_TEST_FIXTURE"] = UUID().uuidString
        XCUIDevice.shared.orientation = .portrait
        open(app)
        app.segmentedControls.buttons["Draw"].tap()
        let finger = app.switches["Finger drawing"]
        XCTAssertTrue(finger.waitForExistence(timeout: 5))
        finger.tap()
        XCTAssertEqual(finger.value as? String, "1")
        XCTAssertTrue(app.staticTexts["Draw with a finger or Pencil; use two fingers to pan."].waitForExistence(timeout: 5))
        let ink = app.descendants(matching: .any)["canvas.ink"].firstMatch
        XCTAssertTrue(ink.waitForExistence(timeout: 5))
        let start = ink.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.32))
        let end = ink.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.40))
        start.press(forDuration: 0.1, thenDragTo: end)
        let diagnostic = XCTAttachment(screenshot: app.screenshot())
        diagnostic.name = "After finger stroke"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", "1 strokes"), object: ink)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed)
        let strokeCount = ink.value as? String
        XCTAssertNotNil(strokeCount)
        app.segmentedControls.buttons["Select"].tap()
        // A visible Select segment is insufficient: the reported failure hangs
        // the responder graph. Exercise an action after repeated mode changes.
        for _ in 0..<3 {
            app.segmentedControls.buttons["Draw"].tap()
            app.segmentedControls.buttons["Select"].tap()
            let text = app.staticTexts["canvas.observation"]
            let before = text.frame.minX
            app.buttons["Move selected objects right"].tap()
            XCTAssertEqual(text.frame.minX, before + 20, accuracy: 1)
            app.buttons["Undo document edit"].tap()
            XCTAssertEqual(text.frame.minX, before, accuracy: 1)
            XCTAssertEqual(ink.value as? String, strokeCount)
        }
        app.buttons["canvas.sample"].tap()
        app.buttons["Save and reopen"].tap()
        waitFor(app, status: "Reopened from disk")
        XCTAssertEqual(ink.value as? String, strokeCount)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Canvas experiment — persisted PencilKit ink"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
