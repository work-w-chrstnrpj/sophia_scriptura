import XCTest

/// Simulator checks that do not require Apple Pencil hardware. XCUITest drag-holds do not
/// produce the stationary Pencil samples PencilKit records on device, so endpoint snap,
/// Undo of that snap, and palm rejection stay on the physical iPad.
final class PencilShapeUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launchEnvironment["SP014_SIMULATED_PENCIL"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30))
        return app
    }

    private func showNotes(_ app: XCUIApplication) {
        let tab = app.buttons["tab.notes"]
        if !tab.isHittable {
            let reveal = app.buttons["navigation.showTabs"]
            XCTAssertTrue(reveal.waitForExistence(timeout: 10)); reveal.tap()
        }
        tab.tap()
        if !app.buttons["notes.newNotes"].waitForExistence(timeout: 3) {
            if app.buttons["navigation.showTabs"].exists { app.buttons["navigation.showTabs"].tap() }
            tab.tap()
        }
        XCTAssertTrue(app.buttons["notes.newNotes"].waitForExistence(timeout: 10))
    }

    func testNotesPencilPaletteKeepsRuler() {
        let app = launch(); showNotes(app)
        app.buttons["notes.newNotes"].tap()
        app.buttons["notes.new.canvas"].tap()
        app.buttons["notes.new.create"].tap()
        XCTAssertTrue(app.scrollViews["notes.viewport"].waitForExistence(timeout: 10))
        let ruler = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'ruler'")).firstMatch
        XCTAssertTrue(ruler.waitForExistence(timeout: 8), "Native ruler should stay in the Notes Pencil palette. \(app.debugDescription)")
    }

    func testInstalledIconAppearsOnHomeScreen() {
        _ = launch()
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons["SophiaScriptura"]
        XCTAssertTrue(icon.waitForExistence(timeout: 15), springboard.debugDescription)
        let shot = XCTAttachment(screenshot: springboard.screenshot())
        shot.name = "SP014 home icon"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
