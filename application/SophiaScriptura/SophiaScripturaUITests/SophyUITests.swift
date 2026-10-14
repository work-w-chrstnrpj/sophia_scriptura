import XCTest

final class SophyUITests: XCTestCase {
    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func launchAndEnable() -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["sophy.character"].exists)
        let toggle = app.switches["settings.sophy.enabled"]
        let scroll = app.scrollViews["settings.content"]
        for _ in 0..<5 {
            if toggle.exists && toggle.isHittable { break }
            let tabs = app.buttons["navigation.showTabs"]
            if tabs.exists && tabs.isHittable { tabs.tap() }
            let settings = app.buttons["tab.settings"]
            if settings.waitForExistence(timeout: 2), settings.isHittable { settings.tap() }
            if toggle.waitForExistence(timeout: 3), toggle.isHittable { break }
            if scroll.exists && scroll.isHittable { scroll.swipeUp() }
        }
        XCTAssertTrue(toggle.exists && toggle.isHittable, app.debugDescription)
        XCTAssertEqual(toggle.value as? String, "0")
        for _ in 0..<2 {
            if toggle.value as? String == "1" { break }
            toggle.tap()
            let enabled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in toggle.value as? String == "1" }, object: nil)
            if XCTWaiter.wait(for: [enabled], timeout: 3) == .completed { break }
        }
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertTrue(app.buttons["sophy.character"].waitForExistence(timeout: 10))
        app.buttons["sophy.character"].tap()
        XCTAssertTrue(app.buttons["sophy.send"].waitForExistence(timeout: 5), app.debugDescription)
        return app
    }
    private func send(_ text: String, app: XCUIApplication) {
        let field = app.textFields["sophy.composer"].exists ? app.textFields["sophy.composer"] : app.textViews["sophy.composer"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
        field.tap(); field.typeText(text)
        app.buttons["sophy.send"].tap()
    }
    private func capture(_ title: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = title; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testChatCommandsDedicatedHistoryAndAdaptiveComposer() {
        let app = launchAndEnable()
        XCTAssertTrue(app.staticTexts["Hi, I'm Sophy, how can I help you today?"].exists)
        capture("Sophy welcome portrait", app: app)
        send("/help", app: app)
        XCTAssertTrue(app.staticTexts["You"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "/create-bible-collection-tree")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["sophy.send"].isHittable)
        capture("Sophy message and composer", app: app)
        XCUIDevice.shared.orientation = .landscapeLeft
        let composer = app.textFields["sophy.composer"].exists ? app.textFields["sophy.composer"] : app.textViews["sophy.composer"]
        composer.tap() // Waits for app/rotation quiescence before the screenshot.
        // A multitasking window can remain tall after device rotation.
        XCTAssertTrue(app.frame.contains(composer.frame), "Composer \(composer.frame) must remain inside application frame \(app.frame)")
        XCTAssertTrue(app.buttons["sophy.send"].isHittable)
        capture("Sophy chat landscape", app: app)
        XCUIDevice.shared.orientation = .portrait
        app.buttons["sophy.options"].tap(); app.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["Sophy History"].waitForExistence(timeout: 5), app.debugDescription)
        capture("Sophy separate History", app: app)
    }
    func testEnabledCharacterRemainsVisibleAfterRelaunch() {
        let app = launchAndEnable()
        app.buttons["Done"].tap()
        let character = app.buttons["sophy.character"]
        XCTAssertTrue(character.isHittable)
        app.terminate()
        app.launch()
        XCTAssertTrue(character.waitForExistence(timeout: 30))
        XCTAssertTrue(character.isHittable, app.debugDescription)
        let window = app.frame
        XCTAssertTrue(window.contains(character.frame), "Character \(character.frame) must stay inside window \(window); app \(app.frame)")
        character.tap()
        XCTAssertTrue(app.buttons["sophy.send"].waitForExistence(timeout: 5))
    }
    func testEnhancementOffersAllOperationsWithoutReplacingPastedText() {
        let app = launchAndEnable()
        send("/enhance", app: app)
        XCTAssertTrue(app.navigationBars["Enhance with Sophy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Original text"].exists)
        let operation = app.buttons["sophy.enhance.operation"]
        XCTAssertTrue(operation.waitForExistence(timeout: 5), app.debugDescription)
        operation.tap(); app.buttons["Recreate Text Tone"].tap()
        XCTAssertTrue(app.buttons["sophy.enhance.tone"].waitForExistence(timeout: 5))
        operation.tap(); app.buttons["Rate"].tap()
        XCTAssertTrue(app.buttons["sophy.enhance.rating"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sophy.enhance.replace"].exists)
        capture("Sophy enhancement controls", app: app)
    }
}
