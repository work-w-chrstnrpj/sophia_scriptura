import XCTest

final class CollectionsUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20))
        return app
    }

    private func showTab(_ id: String, in app: XCUIApplication) {
        let tab = app.buttons[id]
        let show = app.buttons["navigation.showTabs"]
        if show.waitForExistence(timeout: 2) { show.tap() }
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
    }

    private func openCollections(_ app: XCUIApplication) {
        showTab("tab.collections", in: app)
        XCTAssertTrue(app.buttons["collections.folder.No Folder"].waitForExistence(timeout: 10))
    }

    private func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func createCollection(_ name: String, in app: XCUIApplication) {
        app.buttons["collections.newCollection"].tap()
        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["Create"].tap()
    }

    private func item(_ prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "collections.open.\(prefix)")).firstMatch
    }

    func testFolderColorNestingAndDeletionReturnsItemsToNoFolder() {
        let app = launch()
        openCollections(app)
        createCollection("Study Review", in: app)
        let created = app.buttons["collections.folder.Study Review"]
        XCTAssertTrue(created.waitForExistence(timeout: 5))
        created.tap()
        XCTAssertTrue(app.descendants(matching: .any)["collections.detail.counts"].waitForExistence(timeout: 3))

        app.buttons["collections.newSubfolder"].tap()
        let childName = app.textFields["Name"]
        XCTAssertTrue(childName.waitForExistence(timeout: 5))
        childName.tap()
        childName.typeText("Study Child")
        let plum = app.buttons["collections.color.plum"]
        for _ in 0..<6 where !plum.isHittable { app.swipeUp() }
        XCTAssertTrue(plum.waitForExistence(timeout: 5))
        plum.tap()
        app.buttons["Create"].tap()
        XCTAssertTrue(app.buttons["collections.folder.Study Child"].waitForExistence(timeout: 5))
        let detail = XCTAttachment(screenshot: app.screenshot())
        detail.name = "Collection detail with subfolder"; detail.lifetime = .keepAlways; add(detail)

        app.buttons["Collection actions"].tap()
        app.buttons["Delete Collection"].tap()
        let confirmDelete = app.buttons["Delete Collection"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        confirmDelete.tap()
        XCTAssertTrue(app.buttons["collections.folder.Study Child"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["collections.folder.No Folder"].exists)
        XCTAssertFalse(app.buttons["collections.folder.Study Review"].exists)
        let library = XCTAttachment(screenshot: app.screenshot())
        library.name = "Collections library"; library.lifetime = .keepAlways; add(library)

        app.buttons["collections.folder.No Folder"].tap()
        app.buttons["Collection actions"].tap()
        XCTAssertTrue(app.buttons["Change Color"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Delete Collection"].exists)
    }

    func testUnfiledNoteCanBeFiledAndReturnsWhenItsFolderIsDeleted() {
        let app = launch()
        showTab("tab.notes", in: app)
        XCTAssertTrue(app.buttons["notes.newNotes"].waitForExistence(timeout: 10))
        app.buttons["notes.newNotes"].tap()
        app.buttons["notes.new.page"].tap()
        app.buttons["notes.new.create"].tap()
        let close = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()

        openCollections(app)
        app.buttons["collections.folder.No Folder"].tap()
        XCTAssertTrue(item("Untitled Note", in: app).waitForExistence(timeout: 5))
        back(app)

        createCollection("Grace", in: app)
        app.buttons["collections.folder.Grace"].tap()
        app.buttons["collections.addMaterial"].tap()
        let pick = app.buttons["collections.pick.Untitled Note"]
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(item("Untitled Note", in: app).waitForExistence(timeout: 5))

        back(app)
        app.buttons["collections.folder.No Folder"].tap()
        XCTAssertFalse(item("Untitled Note", in: app).waitForExistence(timeout: 2))
        back(app)
        app.buttons["collections.folder.Grace"].tap()
        app.buttons["Collection actions"].tap()
        app.buttons["Delete Collection"].tap()
        app.alerts.buttons["Delete Collection"].tap()
        app.buttons["collections.folder.No Folder"].tap()
        XCTAssertTrue(item("Untitled Note", in: app).waitForExistence(timeout: 5))
    }

    func testBookmarkIsSavedToNewCollectionMovedAndOpenedAsCenteredCard() {
        let app = launch()
        let verse = app.links.firstMatch
        XCTAssertTrue(verse.waitForExistence(timeout: 10))
        verse.tap()
        XCTAssertTrue(app.navigationBars["Verse hub"].waitForExistence(timeout: 5))
        app.buttons["scripture.bookmark"].tap()

        XCTAssertTrue(app.navigationBars["New Bookmark"].waitForExistence(timeout: 5))
        app.buttons["collections.chooser.new"].tap()
        let name = app.textFields["collections.chooser.newName"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.typeText("Creation")
        app.buttons["collections.chooser.create"].tap()
        XCTAssertEqual(app.buttons["collections.choose.Creation"].value as? String, "Selected")
        let save = XCTAttachment(screenshot: app.screenshot())
        save.name = "Save bookmark to a collection"; save.lifetime = .keepAlways; add(save)
        app.buttons["collections.save.confirm"].tap()

        openCollections(app)
        app.buttons["collections.folder.Creation"].tap()
        let bookmark = item("Genesis 1:1", in: app)
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
        bookmark.swipeLeft()
        app.buttons["Move"].tap()
        XCTAssertTrue(app.navigationBars["Move"].waitForExistence(timeout: 5))
        app.buttons["collections.chooser.new"].tap()
        let moveName = app.textFields["collections.chooser.newName"]
        XCTAssertTrue(moveName.waitForExistence(timeout: 3))
        moveName.typeText("Beginnings")
        app.buttons["collections.chooser.create"].tap()
        app.buttons["collections.destination.confirm"].tap()
        XCTAssertFalse(bookmark.waitForExistence(timeout: 2))

        back(app)
        app.buttons["collections.folder.Beginnings"].tap()
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
        bookmark.tap()
        let reference = app.staticTexts["collections.card.reference"]
        XCTAssertTrue(reference.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["collections.seeChapter"].exists)
        let center = reference.frame.midY
        XCTAssertLessThan(center, app.frame.height * 0.7, "The card should present as a centered sheet, not a bottom drawer.")
        let card = XCTAttachment(screenshot: app.screenshot())
        card.name = "Bookmark card"; card.lifetime = .keepAlways; add(card)
    }

    func testGleaningInsightEditsSavesAndClearsFromItsCard() {
        let app = launch()
        let verse = app.links.firstMatch
        XCTAssertTrue(verse.waitForExistence(timeout: 10))
        verse.tap()
        XCTAssertTrue(app.navigationBars["Verse hub"].waitForExistence(timeout: 5))
        app.buttons["scripture.gleaning"].tap()
        XCTAssertTrue(app.navigationBars["New Gleaning"].waitForExistence(timeout: 5))
        let insight = app.textFields["collections.save.insight"]
        XCTAssertTrue(insight.waitForExistence(timeout: 3))
        insight.tap()
        insight.typeText("God speaks order into chaos.")
        app.buttons["collections.save.confirm"].tap()

        openCollections(app)
        app.buttons["collections.folder.No Folder"].tap()
        let gleaning = item("Genesis 1:1", in: app)
        XCTAssertTrue(gleaning.waitForExistence(timeout: 5))
        gleaning.tap()
        XCTAssertEqual(app.staticTexts["collections.insight.text"].label, "God speaks order into chaos.")
        XCTAssertTrue(app.buttons["collections.insight.clear"].exists)
        let reading = XCTAttachment(screenshot: app.screenshot())
        reading.name = "Gleaning card"; reading.lifetime = .keepAlways; add(reading)

        app.buttons["collections.insight.edit"].tap()
        let field = app.textFields["collections.insight.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["collections.insight.save"].exists)
        app.buttons["collections.insight.clear"].tap()
        field.typeText("Light comes first.")
        let editing = XCTAttachment(screenshot: app.screenshot())
        editing.name = "Gleaning card editing"; editing.lifetime = .keepAlways; add(editing)
        app.buttons["collections.insight.save"].tap()
        XCTAssertEqual(app.staticTexts["collections.insight.text"].label, "Light comes first.")
        XCTAssertTrue(app.buttons["collections.insight.edit"].exists)
    }
}
