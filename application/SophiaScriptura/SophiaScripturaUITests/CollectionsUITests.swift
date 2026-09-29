import XCTest

final class CollectionsUITests: XCTestCase {
    private func openCollections() -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launch()
        let tab = app.buttons["Collections"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(app.staticTexts["collections.demoNotice"].waitForExistence(timeout: 5))
        return app
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMembershipRemovalPreservesDescendantAndFiltersWork() {
        let app = openCollections()
        app.buttons["collections.folder.Assurance"].tap()
        XCTAssertTrue(app.staticTexts["Romans 8:1"].waitForExistence(timeout: 5))
        app.buttons["collections.itemActions.Romans 8:1"].tap()
        let removeButton = app.buttons["Remove from This Collection"].firstMatch
        let removeMenuItem = app.menuItems["Remove from This Collection"].firstMatch
        if removeButton.waitForExistence(timeout: 5) {
            removeButton.tap()
        } else {
            XCTAssertTrue(removeMenuItem.waitForExistence(timeout: 5))
            removeMenuItem.tap()
        }
        XCTAssertFalse(app.staticTexts["Romans 8:1"].exists)
        app.buttons["Study material view options"].tap()
        app.buttons["Include child folders"].tap()
        XCTAssertTrue(app.staticTexts["Romans 8:1"].waitForExistence(timeout: 5))
        app.buttons["collections.itemActions.Romans 8:1"].tap()
        // Native menus can expose informational Text as a disabled button.
        let childFolderHint = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Open the child folder to manage this item."))
            .firstMatch
        XCTAssertTrue(childFolderHint.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Remove from This Collection"].exists)
        XCTAssertFalse(app.menuItems["Remove from This Collection"].exists)
        app.tap()
        app.buttons["collections.filter"].tap()
        app.buttons["Links"].tap()
        XCTAssertTrue(app.staticTexts["Historical context article"].exists)
        XCTAssertFalse(app.staticTexts["Romans 8:1"].exists)
        capture(app, name: "Collections — filtered detail")
    }

    func testCreateAddDeletePromotesChildAndSearchFindsIt() {
        let app = openCollections()
        app.buttons["collections.newCollection"].tap()
        XCTAssertFalse(app.buttons["Create"].isEnabled)
        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Study Review")
        app.buttons["Create"].tap()
        let created = app.buttons["collections.folder.Study Review"]
        XCTAssertTrue(created.waitForExistence(timeout: 5))
        created.tap()
        app.buttons["Add Study Material"].tap()
        app.buttons["collections.pick.Romans 8:1"].tap()
        XCTAssertEqual(app.buttons["collections.pick.Romans 8:1"].value as? String, "Included")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Romans 8:1"].waitForExistence(timeout: 5))
        app.buttons["Collection actions"].tap()
        app.buttons["Create Child Folder"].tap()
        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Study Child")
        app.buttons["Create"].tap()
        XCTAssertTrue(app.buttons["collections.folder.Study Child"].waitForExistence(timeout: 5))
        app.buttons["collections.folder.Study Child"].tap()
        XCTAssertTrue(app.navigationBars["Study Child"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Study Review"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        capture(app, name: "Collections — landscape with child")
        XCUIDevice.shared.orientation = .portrait
        app.buttons["Collection actions"].tap()
        app.buttons["Delete Collection"].tap()
        app.alerts.buttons["Delete Folder"].tap()
        XCTAssertTrue(app.buttons["collections.folder.Study Child"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["collections.folder.Study Review"].exists)
        app.buttons["Sort collections"].tap()
        app.buttons["Name"].tap()
        let assurance = app.buttons["collections.folder.Assurance"].frame
        let studyChild = app.buttons["collections.folder.Study Child"].frame
        XCTAssertTrue(assurance.minY < studyChild.minY ||
                      (abs(assurance.minY - studyChild.minY) < 1 && assurance.minX < studyChild.minX))
        // iPadOS 26 exposes searchable as a toolbar button until opened.
        let searchButton = app.buttons["Search"].firstMatch
        if searchButton.waitForExistence(timeout: 5) {
            searchButton.tap()
        }
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Study Child")
        XCTAssertTrue(app.buttons["collections.folder.Study Child"].exists)
        XCTAssertFalse(app.buttons["collections.folder.Assurance"].exists)
        capture(app, name: "Collections — search after promotion")
    }
}
