import XCTest

final class PlanUITests: XCTestCase {
    func testCreateAssignmentAndReopenPlanAfterRelaunch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20))
        openFolder(app)
        app.buttons["collections.addMaterial"].tap()
        XCTAssertTrue(app.buttons["collections.newPlan"].waitForExistence(timeout: 5))
        app.buttons["collections.newPlan"].tap()
        let title = app.textFields["plans.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("My Reading Plan")
        app.swipeUp()
        let assignment = app.buttons["plans.addAssignment"].firstMatch
        XCTAssertTrue(assignment.waitForExistence(timeout: 5)); assignment.tap()
        let scripture = app.buttons["plans.addScripture"]
        if !scripture.waitForExistence(timeout: 10) {
            let attachment = XCTAttachment(string: app.debugDescription); attachment.name = "Missing assignment picker"; attachment.lifetime = .keepAlways; add(attachment)
            XCTFail("Assignment picker must expose Add Scripture"); return
        }
        app.segmentedControls.buttons["Notes"].tap()
        XCTAssertTrue(app.textFields["plans.assignment.noteTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["plans.addScripture"].exists)
        XCTAssertFalse(app.textFields["plans.assignment.linkTitle"].exists)
        app.segmentedControls.buttons["Links"].tap()
        XCTAssertTrue(app.textFields["plans.assignment.linkTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["plans.assignment.noteTitle"].exists)
        app.segmentedControls.buttons["Scripture"].tap()
        let wholeChapters = app.switches["plans.wholeChapters"]
        if (wholeChapters.value as? String) == "1" {
            wholeChapters.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.steppers.matching(NSPredicate(format: "label CONTAINS 'First verse'")).firstMatch.waitForExistence(timeout: 5))
        scripture.tap()
        XCTAssertTrue(app.staticTexts["Genesis 1:1"].waitForExistence(timeout: 5))
        app.buttons["plans.save"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5)); app.buttons["Done"].tap()
        let item = app.buttons["collections.open.My Reading Plan"]
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        XCTAssertTrue(app.staticTexts["Genesis 1:1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["plans.title"].exists, "Opening a Plan must show its contents, not its editor")
        XCTAssertTrue(app.buttons["plans.start"].isEnabled)
        app.buttons["plans.start"].tap()
        XCTAssertTrue(app.textViews["scripture.text"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["plans.next"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["plans.addNote"].exists)
        XCTAssertTrue(app.buttons["plans.addLink"].exists)
        XCTAssertTrue(app.buttons["plans.music"].exists)
        let fullscreen = XCTAttachment(screenshot: app.screenshot()); fullscreen.name = "Fullscreen Plan reader"; fullscreen.lifetime = .keepAlways; add(fullscreen)
        app.buttons["plans.addNote"].tap()
        let noteTitle = app.textFields["notes.new.title"]
        XCTAssertTrue(noteTitle.waitForExistence(timeout: 5)); noteTitle.tap(); noteTitle.typeText("Reading reflection")
        app.buttons["notes.new.create"].tap()
        let body = app.textViews["notes.body"]
        XCTAssertTrue(body.waitForExistence(timeout: 15)); body.tap(); body.typeText("My reflection stays inside the Plan.")
        app.buttons["plans.note.back"].tap()
        XCTAssertTrue(app.buttons["plans.addLink"].waitForExistence(timeout: 5)); app.buttons["plans.addLink"].tap()
        let linkTitle = app.textFields["plans.link.title"]
        XCTAssertTrue(linkTitle.waitForExistence(timeout: 5)); linkTitle.tap(); linkTitle.typeText("Study source")
        let linkURL = app.textFields["plans.link.url"]; linkURL.tap(); linkURL.typeText("example.com")
        app.buttons["plans.link.save"].tap()
        XCTAssertTrue(app.buttons["plans.music"].waitForExistence(timeout: 5)); app.buttons["plans.music"].tap()
        XCTAssertTrue(app.buttons["plans.music.toggle"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["plans.next"].tap()
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        XCTAssertTrue((body.value as? String)?.contains("My reflection stays inside the Plan.") == true)
        app.buttons["plans.next"].tap()
        XCTAssertTrue(app.staticTexts["Study source"].waitForExistence(timeout: 5))
        app.buttons["plans.next"].tap()
        XCTAssertTrue(app.staticTexts["Section complete"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Plan authoring"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        XCTAssertTrue(app.staticTexts["Genesis 1:1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["3 of 3 completed"].exists)
        XCTAssertFalse(app.images["plans.completedStamp"].exists, "The stamp belongs only on the outside Collection record")
        let noteRow = app.buttons.containing(.staticText, identifier: "Reading reflection").firstMatch
        XCTAssertTrue(noteRow.waitForExistence(timeout: 5)); noteRow.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        XCTAssertTrue((body.value as? String)?.contains("My reflection stays inside the Plan.") == true)
        app.buttons["plans.note.back"].tap()
        app.buttons["plans.start"].tap()
        XCTAssertTrue(app.staticTexts["Section complete"].waitForExistence(timeout: 5))
        app.buttons["plans.next"].tap()
        XCTAssertTrue(app.staticTexts["Plan complete"].waitForExistence(timeout: 5))
        app.buttons["plans.next"].tap()
        app.buttons["plans.edit"].tap()
        XCTAssertTrue(app.textFields["plans.title"].waitForExistence(timeout: 5))
        app.swipeUp()
        let manageSection = app.buttons["Manage section"].firstMatch
        XCTAssertTrue(manageSection.waitForExistence(timeout: 5))
        let originalSectionID = manageSection.identifier
        manageSection.tap()
        XCTAssertTrue(app.buttons["Duplicate section"].waitForExistence(timeout: 5)); app.buttons["Duplicate section"].tap()
        let manageItem = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'plans.manageItem.'")).firstMatch
        XCTAssertTrue(manageItem.waitForExistence(timeout: 5)); manageItem.tap()
        XCTAssertTrue(app.buttons["Remove assignment"].waitForExistence(timeout: 5)); app.buttons["Remove assignment"].tap()
        let originalSection = app.buttons[originalSectionID]
        XCTAssertTrue(originalSection.waitForExistence(timeout: 5)); originalSection.tap()
        XCTAssertTrue(app.buttons["Remove section"].waitForExistence(timeout: 5)); app.buttons["Remove section"].tap()
        XCTAssertTrue(app.buttons["plans.addSection"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.buttons["Duplicate Plan"].exists)
        XCTAssertTrue(app.buttons["Archive Plan"].exists)
        XCTAssertTrue(app.buttons["Move Plan to Trash"].exists)
        let actions = XCTAttachment(screenshot: app.screenshot()); actions.name = "Plan lifecycle actions"; actions.lifetime = .keepAlways; add(actions)
        app.buttons["Reset whole Plan"].tap()
        XCTAssertTrue(app.buttons["Reset progress"].waitForExistence(timeout: 5)); app.buttons["Reset progress"].tap()
        app.buttons["plans.save"].tap()
        XCTAssertTrue(app.staticTexts["0 of 3 completed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["plans.completedStamp"].exists)
        let retainedNote = app.buttons.containing(.staticText, identifier: "Reading reflection").firstMatch
        retainedNote.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        XCTAssertTrue((body.value as? String)?.contains("My reflection stays inside the Plan.") == true)
        app.buttons["plans.note.back"].tap()
        app.buttons["plans.edit"].tap(); app.swipeUp()
        let lastSection = app.buttons["Manage section"].firstMatch
        XCTAssertTrue(lastSection.waitForExistence(timeout: 5)); lastSection.tap()
        app.buttons["Remove section"].tap()
        XCTAssertTrue(app.buttons["plans.addSection"].waitForExistence(timeout: 5)); app.buttons["plans.save"].tap()
        XCTAssertTrue(app.staticTexts["0 of 0 completed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["plans.start"].isEnabled)
    }
    func testRemovingOnlySectionDoesNotTerminateEditor() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20))
        openFolder(app)
        app.buttons["collections.addMaterial"].tap()
        XCTAssertTrue(app.buttons["collections.newPlan"].waitForExistence(timeout: 5))
        app.buttons["collections.newPlan"].tap()
        let title = app.textFields["plans.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        app.swipeUp()
        let manage = app.buttons["Manage section"].firstMatch
        XCTAssertTrue(manage.waitForExistence(timeout: 5)); manage.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
        let remove = app.buttons["Remove section"]
        if !remove.waitForExistence(timeout: 2) { manage.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap() }
        XCTAssertTrue(remove.waitForExistence(timeout: 5)); remove.tap()
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.buttons["plans.addSection"].waitForExistence(timeout: 5))
        app.buttons["plans.addSection"].tap()
        XCTAssertTrue(app.buttons["Manage section"].firstMatch.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Deletion regression")
        app.buttons["plans.save"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5)); app.buttons["Done"].tap()
        let item = app.buttons["collections.open.Deletion regression"]
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        app.buttons["plans.edit"].tap()
        app.swipeUp()
        let storedManage = app.buttons["Manage section"].firstMatch
        XCTAssertTrue(storedManage.waitForExistence(timeout: 5)); storedManage.tap()
        let storedRemove = app.buttons["Remove section"]
        XCTAssertTrue(storedRemove.waitForExistence(timeout: 5)); storedRemove.tap()
        XCTAssertTrue(app.buttons["plans.addSection"].waitForExistence(timeout: 5))
        app.buttons["plans.save"].tap()
        XCTAssertTrue(app.staticTexts["0 of 0 completed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["plans.start"].isEnabled)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        XCTAssertTrue(app.staticTexts["0 of 0 completed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["plans.start"].isEnabled)
    }
    private func openFolder(_ app: XCUIApplication) {
        let reveal = app.buttons["navigation.showTabs"]
        let collections = app.buttons["tab.collections"]
        let folder = app.buttons["collections.folder.No Folder"]
        // The shell retains offscreen tabs in the accessibility tree. Existence alone
        // cannot establish a selected tab, and its dock can collapse during relaunch.
        for _ in 0..<3 {
            if reveal.exists && reveal.isHittable { reveal.tap() }
            if collections.waitForExistence(timeout: 5), collections.isHittable { collections.tap() }
            let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: folder)
            if XCTWaiter.wait(for: [visible], timeout: 5) == .completed { folder.tap(); return }
        }
        XCTFail("Collections folder must be visible after selecting its tab")
    }
}
