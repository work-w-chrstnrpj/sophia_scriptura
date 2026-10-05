import XCTest

final class AnnotationUITests: XCTestCase {
    private func layerItem(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", name, "annotation.layers")).firstMatch
    }
    private func showTabs(_ app: XCUIApplication) {
        if app.buttons["navigation.showTabs"].exists { app.buttons["navigation.showTabs"].tap() }
    }
    func testLayerManagementModesAndReopen() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString; app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20))
        let layers = app.buttons["annotation.layers"]
        XCTAssertTrue(layers.waitForExistence(timeout: 10)); layers.tap(); app.buttons["New layer"].tap()
        XCTAssertTrue(app.scrollViews["annotation.viewport"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["annotation.paletteMinimized"].exists)
        XCTAssertFalse(app.buttons["annotation.tools"].exists)
        app.buttons["annotation.paletteCollapse"].tap()
        XCTAssertTrue(app.buttons["annotation.paletteCollapsed"].exists)
        app.buttons["annotation.paletteCollapsed"].tap()
        XCTAssertTrue(app.buttons["annotation.paletteMinimized"].exists)
        app.buttons["annotation.paletteMinimized"].tap()
        XCTAssertFalse(app.buttons["annotation.paletteMinimized"].exists)
        app.buttons["annotation.mode"].tap(); app.buttons["Read Visible"].tap()
        layers.tap(); app.buttons["Rename layer"].tap()
        let name = app.alerts.textFields.firstMatch; name.tap()
        name.typeText("Morning study")
        app.alerts.buttons["Save"].tap()
        layers.tap(); app.buttons["New layer"].tap()
        app.buttons["annotation.mode"].tap(); app.buttons["Read Hidden"].tap()
        layers.tap(); app.buttons["Delete layer"].tap()
        let deleteConfirm = app.buttons["Delete Layer"]
        XCTAssertTrue(deleteConfirm.waitForExistence(timeout: 5))
        deleteConfirm.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: deleteConfirm)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        layers.tap(); XCTAssertTrue(app.buttons["Recently Deleted"].waitForExistence(timeout: 5)); app.buttons["Recently Deleted"].tap(); app.buttons["Restore Study 2"].tap()
        XCTAssertEqual(app.buttons["annotation.mode"].label, "Read Visible")
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rotation], timeout: 10), .completed)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); screen.name = "SP012 preserved layer landscape"; screen.lifetime = .keepAlways; add(screen)
        showTabs(app); app.buttons["tab.settings"].tap()
        showTabs(app); app.buttons["tab.scripture"].tap()
        XCTAssertTrue(app.scrollViews["annotation.viewport"].waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["annotation.layers"].waitForExistence(timeout: 20))
        layers.tap(); XCTAssertTrue(app.buttons["Morning study"].exists); XCTAssertTrue(app.buttons["Study 2"].exists)
    }
    func testHiddenReturnsNormalReaderAndControlsStayCentered() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString; app.launch()
        XCTAssertTrue(app.buttons["annotation.layers"].waitForExistence(timeout: 20))
        let text = app.textViews.matching(identifier: "scripture.text").firstMatch
        let before = text.frame, content = text.value as? String
        app.buttons["annotation.layers"].tap(); app.buttons["New layer"].tap()
        XCTAssertTrue(app.scrollViews["annotation.viewport"].waitForExistence(timeout: 10))
        app.buttons["annotation.margin"].tap()
        XCTAssertEqual(app.buttons["annotation.margin"].value as? String, "On")
        let expanded = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); expanded.name = "SP012 blank surrounding margin"; expanded.lifetime = .keepAlways; add(expanded)
        app.buttons["annotation.mode"].tap(); app.buttons["Read Hidden"].tap()
        XCTAssertEqual(app.buttons["annotation.mode"].label, "Read Hidden")
        XCTAssertFalse(app.buttons["annotation.margin"].exists)
        let hiddenShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); hiddenShot.name = "SP012 hidden verification"; hiddenShot.lifetime = .keepAlways; add(hiddenShot)
        let normal = app.textViews.matching(identifier: "scripture.text").allElementsBoundByIndex.first { $0.isHittable }
        let visible = try! XCTUnwrap(normal)
        XCTAssertEqual(visible.frame.width, before.width, accuracy: 1)
        XCTAssertEqual(visible.frame.midX, before.midX, accuracy: 1)
        XCTAssertEqual(visible.value as? String, content)
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in orientation == .portrait ? app.frame.height > app.frame.width : app.frame.width > app.frame.height }, object: nil)
            guard XCTWaiter.wait(for: [settled], timeout: 10) == .completed else {
                throw XCTSkip("The simulator kept the app window fixed after the orientation change.")
            }
            let left = app.buttons["annotation.layers"].frame.minX, right = app.buttons["annotation.backup"].frame.maxX
            XCTAssertEqual((left + right) / 2, app.frame.midX, accuracy: 24)
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "SP012 normal hidden reader \(orientation.rawValue)"; shot.lifetime = .keepAlways; add(shot)
        }
    }
    func testVerseHubOpensAfterHidingNewLayer() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString; app.launch()
        XCTAssertTrue(app.buttons["annotation.layers"].waitForExistence(timeout: 20))
        app.buttons["annotation.layers"].tap(); app.buttons["New layer"].tap()
        XCTAssertTrue(app.scrollViews["annotation.viewport"].waitForExistence(timeout: 10))
        app.buttons["annotation.mode"].tap(); app.buttons["Read Hidden"].tap()
        XCTAssertTrue(app.textViews["scripture.text"].waitForExistence(timeout: 5))
        let verse = app.links.firstMatch
        XCTAssertTrue(verse.waitForExistence(timeout: 5), app.debugDescription)
        let start = Date()
        verse.tap()
        XCTAssertTrue(app.navigationBars["Verse hub"].waitForExistence(timeout: 3))
        let timing = XCTAttachment(string: "Verse Hub visible \(Date().timeIntervalSince(start)) seconds after tapping a verse in Read Hidden")
        timing.name = "SP012 hidden Verse Hub response"; timing.lifetime = .keepAlways; add(timing)
    }
    func testFontChangeUpdatesSelectedLayerAndSelectionRestoresAppearance() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString; app.launch()
        XCTAssertTrue(app.buttons["annotation.layers"].waitForExistence(timeout: 20))
        app.buttons["annotation.layers"].tap(); app.buttons["New layer"].tap()
        XCTAssertTrue(app.scrollViews["annotation.viewport"].waitForExistence(timeout: 10))
        app.buttons["annotation.layers"].tap(); app.buttons["New layer"].tap()
        showTabs(app); app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.buttons["preset.quietSage"].waitForExistence(timeout: 10)); app.buttons["preset.quietSage"].tap()
        showTabs(app); app.buttons["tab.scripture"].tap()
        XCTAssertTrue(app.scrollViews["annotation.viewport"].waitForExistence(timeout: 10))
        app.buttons["annotation.layers"].tap()
        let appearanceShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        appearanceShot.name = "SP012 selected layer appearance"
        appearanceShot.lifetime = .keepAlways; add(appearanceShot)
        XCTAssertFalse(app.buttons["Preserved layouts"].exists)
        XCTAssertTrue(layerItem(app, "Study 2").exists)
        XCTAssertTrue((layerItem(app, "Study 2").value as? String)?.contains("Quiet Sage") == true)
        XCTAssertTrue(layerItem(app, "Study 2").isSelected)
        layerItem(app, "Study 1").tap()
        app.buttons["annotation.layers"].tap()
        XCTAssertTrue(layerItem(app, "Study 1").isSelected)
        XCTAssertTrue((layerItem(app, "Study 1").value as? String)?.contains("Old Paper") == true)
        app.buttons["annotation.layers"].tap()
        showTabs(app); app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.buttons["preset.oldPaper"].isSelected)
    }
}
