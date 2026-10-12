import XCTest

final class ActivityWorkflowUITests: XCTestCase {
    private func tab(_ name: String, app: XCUIApplication) {
        let ready = name == "activity" ? app.buttons["Add activity"] : app.scrollViews["settings.content"]
        for _ in 0..<3 {
            if ready.exists && ready.isHittable { return }
            let button = app.buttons["tab." + name]
            if !button.isHittable {
                let show = app.buttons["navigation.showTabs"]
                if show.waitForExistence(timeout: 3) { show.tap() }
            }
            let tabReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in button.exists && button.isHittable }, object: nil)
            if XCTWaiter.wait(for: [tabReady], timeout: 2) == .completed { button.tap() }
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in ready.exists && ready.isHittable }, object: nil)
            if XCTWaiter.wait(for: [expectation], timeout: 3) == .completed { return }
        }
        XCTAssertTrue(ready.exists && ready.isHittable, app.debugDescription)
    }

    private func setStartWorkflow(_ enabled: Bool, identifier: String, app: XCUIApplication) {
        let toggle = app.switches[identifier]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), app.debugDescription)
        if (toggle.value as? String == "1") != enabled {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in toggle.value as? String == (enabled ? "1" : "0") }, object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
    }

    private func finish(_ app: XCUIApplication) {
        let finish = app.buttons["activity.recorder.finish"]
        if !finish.isHittable { app.buttons["activity.recorder.expand"].tap() }
        XCTAssertTrue(finish.waitForExistence(timeout: 5)); finish.tap()
        let save = app.navigationBars.buttons["Save"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in save.exists && save.isEnabled }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        save.tap()
    }

    private func startReading(_ app: XCUIApplication, guided: Bool) {
        tab("activity", app: app)
        app.buttons["Add activity"].tap(); app.buttons["activity.add.start"].tap()
        setStartWorkflow(guided, identifier: "activity.start.readingWorkflow", app: app)
        let start = app.buttons["activity.start.confirm"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in start.exists && start.isEnabled }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        start.tap()
    }

    private func startContemplation(_ app: XCUIApplication, guided: Bool) {
        tab("activity", app: app)
        let button = app.buttons["activity.contemplation.start"]
        for _ in 0..<8 {
            if button.exists && button.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(button.exists && button.isHittable, app.debugDescription)
        button.tap()
        setStartWorkflow(guided, identifier: "activity.start.contemplationWorkflow", app: app)
        app.buttons["activity.start.confirm"].tap()
    }

    func testFloatingPlayerPreviewForActivity() { floatingPlayer(checkPiP: false) }
    func testFloatingPlayerStartsPiPOnDevice() { floatingPlayer(checkPiP: true) }

    private func floatingPlayer(checkPiP: Bool) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["study.pip.open"].exists)
        startReading(app, guided: true)
        let open = app.buttons["study.pip.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(app.navigationBars["Floating Player"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Play/Pause controls Activity"].exists)
        XCTAssertTrue(app.buttons["study.pip.start"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Activity floating player preview"; capture.lifetime = .keepAlways; add(capture)
        if checkPiP {
            let start = app.buttons["study.pip.start"]
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in start.isEnabled }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed, app.debugDescription)
            start.tap()
            XCTAssertTrue(app.staticTexts["PiP is open. You can return Home."].waitForExistence(timeout: 10), app.debugDescription)
            XCUIDevice.shared.press(.home)
            let home = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            home.name = "Activity PiP on Home"; home.lifetime = .keepAlways; add(home)
            app.activate()
        }
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["activity.recorder.expand"].exists)
    }

    func testWorkflowChoicesPersistAndAllowPlainTimersOrGuidedFlows() {
        continueAfterFailure = false; XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString; app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30))
        startReading(app, guided: false)
        XCTAssertTrue(app.buttons["Add activity"].isHittable, "Plain Reading stays in Activity")
        XCTAssertTrue(app.buttons["activity.recorder.expand"].label.contains("Reading"))
        finish(app)
        startContemplation(app, guided: false)
        XCTAssertFalse(app.descendants(matching: .any)["meditation.journey.overlay"].exists)
        XCTAssertTrue(app.buttons["Add activity"].isHittable, "Starting contemplation must not also open its history")
        XCTAssertTrue(app.buttons["activity.recorder.expand"].label.contains("Contemplating"))
        finish(app)
        app.buttons["activity.contemplation.history"].tap()
        XCTAssertTrue(app.navigationBars["Scripture Contemplation"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "activity.record.")).count, 1)
        app.navigationBars.buttons["Back"].tap()
        startReading(app, guided: true)
        XCTAssertTrue(app.buttons["reader.book"].isHittable, "Guided Reading routes to Scripture")
        finish(app)
        startContemplation(app, guided: true)
        XCTAssertTrue(app.descendants(matching: .any)["meditation.journey.overlay"].waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Scripture Contemplation guided workflow"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["Exit Scripture Contemplation"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["meditation.journey.overlay"].exists)
        XCTAssertTrue(app.buttons["activity.recorder.expand"].label.contains("Contemplating"), "Exiting the journey keeps the timer active")
        finish(app)
    }
}
