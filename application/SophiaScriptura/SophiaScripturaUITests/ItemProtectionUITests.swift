import XCTest

final class ItemProtectionUITests: XCTestCase {
    private let password = "Sophia UI test password 42"
    private func tab(_ name: String, app: XCUIApplication) {
        let button = app.buttons["tab." + name]
        let target: XCUIElement = name == "settings" ? app.scrollViews["settings.content"] : app.buttons[name == "notes" ? "notes.newNotes" : name == "collections" ? "collections.newCollection" : "settings.title"]
        for _ in 0..<3 {
            if target.exists && target.isHittable { return }
            if !(button.exists && button.isHittable) {
                let reveal = app.buttons["navigation.showTabs"]
                if reveal.waitForExistence(timeout: 3) { reveal.tap() }
            }
            if button.isHittable { button.tap() }
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in target.exists && target.isHittable }, object: nil)
            if XCTWaiter.wait(for: [ready], timeout: 2) == .completed { return }
        }
        XCTAssertTrue(target.exists && target.isHittable, app.debugDescription)
    }
    private func reveal(_ identifier: String, app: XCUIApplication) {
        let control = app.buttons[identifier]
        let scroll = app.scrollViews["settings.content"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            if control.exists && control.isHittable { return }
            scroll.swipeUp()
        }
        XCTAssertTrue(control.exists && control.isHittable, app.debugDescription)
    }
    private func enterPassword(_ app: XCUIApplication, setup: Bool = false, value: String? = nil) {
        let field = app.secureTextFields["protection.password"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), app.debugDescription)
        field.tap(); field.typeText(value ?? password)
        if setup {
            let confirm = app.secureTextFields["protection.confirmPassword"]
            confirm.tap(); confirm.typeText(value ?? password)
        }
        app.buttons["protection.submit"].tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !field.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed)
    }
    func testProtectedNoteAndCollectionCategoryAndCombinedControlsPersistAcrossRelaunch() {
        continueAfterFailure = false; XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString; app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30)); tab("notes", app: app)
        app.buttons["notes.newNotes"].tap(); app.buttons["notes.new.page"].tap()
        let title = app.textFields["notes.new.title"]; title.tap(); title.typeText("Private Note")
        app.buttons["notes.new.create"].tap()
        let body = app.textViews["notes.body"]; XCTAssertTrue(body.waitForExistence(timeout: 10)); body.tap(); body.typeText("Private content is concealed")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let note = app.buttons.containing(.staticText, identifier: "Private Note").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5)); note.press(forDuration: 1)
        app.buttons["Protect Note"].tap(); enterPassword(app, setup: true)
        app.buttons["protection.notes.toggle"].tap()
        XCTAssertFalse(app.staticTexts["Private content is concealed"].exists)
        note.press(forDuration: 1); XCTAssertFalse(app.buttons["notes.editNote"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.8)).tap()
        tab("collections", app: app); app.buttons["collections.newCollection"].tap()
        let name = app.textFields["Name"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Private Collection")
        app.buttons["Create"].tap()
        let folder = app.buttons["collections.folder.Private Collection"]; XCTAssertTrue(folder.waitForExistence(timeout: 5))
        folder.press(forDuration: 1); app.buttons["Protect Collection"].tap(); enterPassword(app)
        app.buttons["protection.collections.toggle"].tap()
        folder.tap(); enterPassword(app)
        XCTAssertTrue(app.otherElements["collections.detailContent"].exists || app.scrollViews["collections.detailContent"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tab("notes", app: app); XCTAssertFalse(app.staticTexts["Private content is concealed"].exists)
        tab("settings", app: app)
        reveal("protection.all.lock", app: app)
        let lock = app.buttons["protection.all.lock"]; XCTAssertTrue(lock.waitForExistence(timeout: 5)); lock.tap()
        app.buttons["protection.all.unlock"].tap(); enterPassword(app)
        tab("notes", app: app); XCTAssertTrue(app.staticTexts["Private content is concealed"].waitForExistence(timeout: 5))
        let screen = XCTAttachment(screenshot: app.screenshot()); screen.name = "Protected note unlocked"; screen.lifetime = .keepAlways; add(screen)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30)); tab("notes", app: app)
        XCTAssertFalse(app.staticTexts["Private content is concealed"].exists)
        app.buttons.containing(.staticText, identifier: "Private Note").firstMatch.tap(); enterPassword(app)
        XCTAssertEqual(app.textViews["notes.body"].value as? String, "Private content is concealed")
        app.navigationBars.buttons.element(boundBy: 0).tap(); tab("settings", app: app)
        reveal("protection.password.change", app: app)
        app.buttons["protection.password.change"].tap()
        let oldPassword = app.secureTextFields["protection.password"]
        XCTAssertTrue(oldPassword.waitForExistence(timeout: 10)); oldPassword.tap(); oldPassword.typeText(password)
        app.buttons["protection.submit"].tap()
        XCTAssertTrue(app.secureTextFields["protection.confirmPassword"].waitForExistence(timeout: 10))
        let replacement = "Replacement UI password 99"
        enterPassword(app, setup: true, value: replacement)
        tab("notes", app: app); XCTAssertFalse(app.staticTexts["Private content is concealed"].exists)
        app.buttons.containing(.staticText, identifier: "Private Note").firstMatch.tap()
        enterPassword(app, value: replacement)
        XCTAssertEqual(app.textViews["notes.body"].value as? String, "Private content is concealed")
    }
    func testSharedNoteOpensFromPlainCollectionAndFilingRetainsLockedMembership() {
        continueAfterFailure = false; XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString; app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30)); tab("notes", app: app)
        app.buttons["notes.newNotes"].tap(); app.buttons["notes.new.page"].tap()
        let title = app.textFields["notes.new.title"]; title.tap(); title.typeText("Shared review note")
        app.buttons["notes.new.create"].tap()
        let body = app.textViews["notes.body"]; XCTAssertTrue(body.waitForExistence(timeout: 10))
        body.tap(); body.typeText("Shared content remains editable")
        func openFiling() {
            app.buttons["notes.options"].tap(); app.buttons["notes.options.addToCollection"].tap()
            XCTAssertTrue(app.buttons["collections.destination.confirm"].waitForExistence(timeout: 5))
        }
        func createFolder(_ name: String) {
            app.buttons["collections.chooser.new"].tap()
            let field = app.textFields["collections.chooser.newName"]
            XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(name)
            app.buttons["collections.chooser.create"].tap()
        }
        openFiling(); createFolder("Private review"); createFolder("Open review")
        app.buttons["collections.destination.confirm"].tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tab("collections", app: app)
        let privateFolder = app.buttons["collections.folder.Private review"]
        XCTAssertTrue(privateFolder.waitForExistence(timeout: 5)); privateFolder.press(forDuration: 1)
        app.buttons["Protect Collection"].tap(); enterPassword(app, setup: true)
        app.buttons["protection.collections.toggle"].tap()
        tab("notes", app: app)
        XCTAssertFalse(app.buttons.containing(.staticText, identifier: "Shared review note").firstMatch.exists)
        tab("collections", app: app); app.buttons["collections.folder.Open review"].tap()
        let shared = app.buttons["collections.open.Shared review note"]
        XCTAssertTrue(shared.waitForExistence(timeout: 5)); shared.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 10)); XCTAssertEqual(body.value as? String, "Shared content remains editable")
        openFiling(); createFolder("Added review")
        app.buttons["collections.destination.confirm"].tap()
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        openFiling()
        XCTAssertEqual(app.buttons["collections.choose.Private review"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["collections.choose.Added review"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["collections.choose.Open review"].value as? String, "Selected")
        app.buttons["Cancel"].tap()
    }

}
