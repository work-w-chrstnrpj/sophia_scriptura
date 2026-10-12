import XCTest

final class ScriptureReaderUITests: XCTestCase {
    private func showTabs(_ app: XCUIApplication) {
        let handle = app.buttons["navigation.showTabs"]
        if handle.exists { handle.tap() }
        XCTAssertTrue(app.buttons["tab.scripture"].waitForExistence(timeout:5))
    }
    func testAppearancePresetPersistsAcrossRelaunch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout:20))
        showTabs(app)
        app.buttons["tab.settings"].tap()
        let preset = app.buttons["preset.midnightLibrary"]
        XCTAssertTrue(preset.waitForExistence(timeout:5))
        preset.tap()
        XCTAssertTrue(preset.isSelected)
        showTabs(app)
        app.buttons["tab.scripture"].tap()
        XCTAssertTrue(app.textViews["scripture.text"].exists)
        let night = XCTAttachment(screenshot:app.screenshot())
        night.name = "Midnight Library reader"; night.lifetime = .keepAlways; add(night)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout:20))
        showTabs(app)
        app.buttons["tab.settings"].tap()
        let restoredPreset = app.buttons["preset.midnightLibrary"]
        XCTAssertTrue(restoredPreset.waitForExistence(timeout: 5))
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in restoredPreset.isSelected }, object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        app.buttons["preset.oldPaper"].tap()
        showTabs(app)
        app.buttons["tab.scripture"].tap()
        let paper = XCTAttachment(screenshot:app.screenshot())
        paper.name = "OldPaper reader"; paper.lifetime = .keepAlways; add(paper)
    }

    func testNavigateRelaunchSettingsAndBottomTabs() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout:20))
        XCTAssertEqual(app.buttons["reader.book"].value as? String,"Genesis 1")
        app.buttons["reader.book"].tap()
        let search = app.textFields["reader.bookSearch"]
        XCTAssertTrue(search.waitForExistence(timeout:5))
        search.tap(); search.typeText("Romans")
        app.buttons["Romans"].tap()
        app.buttons["reader.chapter.8"].tap()
        XCTAssertTrue(app.buttons["reader.verse.28"].waitForExistence(timeout:5))
        app.buttons["reader.verse.28"].tap()
        XCTAssertEqual(app.buttons["reader.book"].value as? String,"Romans 8")
        XCTAssertTrue(app.textViews["scripture.text"].exists)
        showTabs(app)
        let tab = app.buttons["tab.settings"]
        XCTAssertGreaterThan(tab.frame.minY,app.frame.height * 0.8)
        tab.tap()
        XCTAssertTrue(app.staticTexts["Reading"].waitForExistence(timeout:5))
        let attachment = XCTAttachment(screenshot:app.screenshot())
        attachment.name = "M2 reading settings"; attachment.lifetime = .keepAlways; add(attachment)
        showTabs(app)
        app.buttons["tab.scripture"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout:20))
        XCTAssertEqual(app.buttons["reader.book"].value as? String,"Romans 8")
        XCUIDevice.shared.orientation = .landscapeLeft
        let settled = XCTNSPredicateExpectation(predicate:NSPredicate { _, _ in
            app.frame.width > app.frame.height && app.buttons["reader.book"].frame.maxX <= app.frame.width
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[settled],timeout:10),.completed)
        let landscape = XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        landscape.name = "M2 reader landscape"; landscape.lifetime = .keepAlways; add(landscape)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["reader.book"].exists)
        XCTAssertTrue(app.buttons["reader.version"].exists)
        XCTAssertFalse(app.buttons["reader.verse"].exists)
        let portrait = XCTAttachment(screenshot:app.screenshot())
        portrait.name = "M2 reader portrait"; portrait.lifetime = .keepAlways; add(portrait)

    }
    func testPickerIncludesLastVerseAndBrowsingDoesNotNavigate() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout:20))
        app.buttons["reader.book"].tap()
        app.buttons["Genesis"].tap()
        app.buttons["reader.chapter.1"].tap()
        let last = app.buttons["reader.verse.31"]
        XCTAssertTrue(last.waitForExistence(timeout:5))
        last.tap()
        XCTAssertEqual(app.buttons["reader.book"].value as? String,"Genesis 1")
        let focus = XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        focus.name = "Whole verse focus Genesis 1 verse 31"; focus.lifetime = .keepAlways; add(focus)
        app.buttons["reader.book"].tap()
        app.buttons["Exodus"].tap()
        app.buttons["reader.chapter.2"].tap()
        XCTAssertTrue(app.buttons["Read chapter"].waitForExistence(timeout:5))
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(app.buttons["reader.book"].value as? String,"Genesis 1")
        app.buttons["reader.book"].tap()
        app.buttons["Exodus"].tap()
        app.buttons["reader.chapter.2"].tap()
        app.buttons["Read chapter"].tap()
        XCTAssertEqual(app.buttons["reader.book"].value as? String,"Exodus 2")
    }

    func testContinuousScrollBottomAndChapterSwipes() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        let text = app.textViews["scripture.text"]
        XCTAssertTrue(text.waitForExistence(timeout:20))
        let controls = app.buttons["reader.book"]
        let originalFrame = text.frame
        let nextChapter = app.buttons["Next chapter"]
        XCTAssertTrue(nextChapter.exists)
        XCTAssertGreaterThan(nextChapter.frame.minY,text.frame.minY)
        for _ in 0..<6 {
            text.swipeUp()
            XCTAssertTrue(controls.isHittable)
            XCTAssertEqual(text.frame,originalFrame,"Scrolling must not resize the viewport")
        }
        text.swipeLeft()
        let next = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@","Genesis 2"),object:controls)
        XCTAssertEqual(XCTWaiter.wait(for:[next],timeout:5),.completed)
        text.swipeRight()
        let previous = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@","Genesis 1"),object:controls)
        XCTAssertEqual(XCTWaiter.wait(for:[previous],timeout:5),.completed)
        XCTAssertTrue(controls.isHittable)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Page ")).firstMatch.exists)
        let screenshot = XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        screenshot.name = "Continuous chapter reader"; screenshot.lifetime = .keepAlways; add(screenshot)
    }

}
