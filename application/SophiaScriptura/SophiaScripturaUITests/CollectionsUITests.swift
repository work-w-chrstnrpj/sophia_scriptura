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
        let editorBack = app.buttons["collections.note.back"]
        if editorBack.exists && editorBack.isHittable { editorBack.tap() }
        else { app.navigationBars.buttons.element(boundBy: 0).tap() }
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

    private func itemMenu(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "collections.artifact.menu.")).firstMatch
    }

    private func saveBookmarkFromFirstVerse(_ app: XCUIApplication) {
        let verse = app.links.firstMatch
        XCTAssertTrue(verse.waitForExistence(timeout: 10))
        verse.tap()
        XCTAssertTrue(app.navigationBars["Verse hub"].waitForExistence(timeout: 5))
        app.buttons["scripture.bookmark"].tap()
        XCTAssertTrue(app.navigationBars["New Bookmark"].waitForExistence(timeout: 5))
        app.buttons["collections.save.confirm"].tap()
    }

    private func snap(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    private func confirmCenteredDelete(_ app: XCUIApplication) {
        let confirm = app.buttons["collections.delete.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Delete must show the confirmation")
        confirm.tap()
    }

    func testPointToPonderExploreCancelAndCreatePrefilledNote() {
        let app = launch(); openCollections(app)
        app.buttons["collections.folder.No Folder"].tap()
        let addMaterial = app.buttons["collections.addMaterial"]
        XCTAssertTrue(addMaterial.waitForExistence(timeout: 5)); addMaterial.tap()
        XCTAssertTrue(app.buttons["collections.newPoint"].waitForExistence(timeout: 5))
        app.buttons["collections.newPoint"].tap()
        let question = "How can I love my neighbour?"
        let field = app.textViews["ponder.question"].exists ? app.textViews["ponder.question"] : app.textFields["ponder.question"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(question)
        app.buttons["ponder.create"].tap()
        app.buttons["Done"].tap()
        let point = item(question, in: app)
        XCTAssertTrue(point.waitForExistence(timeout: 5)); point.tap()
        XCTAssertTrue(app.staticTexts["ponder.card.question"].waitForExistence(timeout: 5))
        let deleteButton = app.buttons["ponder.delete"]
        let exploreButton = app.buttons["ponder.explore"]
        XCTAssertTrue(deleteButton.exists)
        XCTAssertEqual(deleteButton.frame.width, exploreButton.frame.width, accuracy: 1)
        XCTAssertEqual(deleteButton.frame.height, exploreButton.frame.height, accuracy: 1)
        let card = app.descendants(matching: .any)["ponder.card"].firstMatch
        XCTAssertLessThanOrEqual(card.frame.maxY - deleteButton.frame.maxY, 40)
        snap("Point question", app)
        deleteButton.tap()
        XCTAssertTrue(app.alerts["Move this question to Trash?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        app.buttons["ponder.explore"].tap()
        XCTAssertTrue(app.buttons["ponder.note"].waitForExistence(timeout: 5))
        app.buttons["ponder.note"].tap()
        XCTAssertTrue(app.textFields["notes.new.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["notes.new.title"].value as? String, question)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(point.waitForExistence(timeout: 5)); point.tap()
        app.buttons["ponder.explore"].tap()
        XCTAssertTrue(app.buttons["ponder.note"].waitForExistence(timeout: 5))
        app.buttons["ponder.note"].tap()
        XCTAssertTrue(app.buttons["notes.new.create"].waitForExistence(timeout: 5))
        snap("Prefilled question note", app)
        app.buttons["notes.new.create"].tap()
        XCTAssertTrue(app.scrollViews["notes.viewport"].waitForExistence(timeout: 10))
        back(app)
        XCTAssertTrue(point.waitForExistence(timeout: 5))
    }

    func testBookmarkTurnsIntoGleaningAndPrefillsNoteTitle() {
        let app = launch()
        saveBookmarkFromFirstVerse(app)
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        openCollections(app)
        app.buttons["collections.folder.No Folder"].tap()
        let saved = item("Genesis 1:1", in: app)
        XCTAssertTrue(saved.waitForExistence(timeout: 5)); saved.tap()
        let chapterButton = app.buttons["collections.seeChapter"]
        let gleaningButton = app.buttons["collections.bookmark.toGleaning"]
        XCTAssertTrue(gleaningButton.waitForExistence(timeout: 5))
        XCTAssertEqual(gleaningButton.label, "Turn into a Gleaning")
        XCTAssertGreaterThan(gleaningButton.frame.minY, chapterButton.frame.maxY)
        XCTAssertEqual(gleaningButton.frame.width, chapterButton.frame.width, accuracy: 1)
        XCTAssertEqual(gleaningButton.frame.height, chapterButton.frame.height, accuracy: 1)
        snap("Bookmark action order and sizing", app)
        gleaningButton.tap()
        let insight = app.textViews["collections.insight.field"].exists ? app.textViews["collections.insight.field"] : app.textFields["collections.insight.field"]
        XCTAssertTrue(insight.waitForExistence(timeout: 5)); insight.tap(); insight.typeText("God is the Creator.")
        app.buttons["collections.insight.save"].tap()
        let reference = app.staticTexts["collections.card.reference"].label
        let noteButton = app.buttons["collections.gleaning.toNote"]
        XCTAssertTrue(noteButton.waitForExistence(timeout: 5))
        XCTAssertEqual(noteButton.label, "Turn into a Note")
        XCTAssertGreaterThan(noteButton.frame.minY, chapterButton.frame.maxY)
        XCTAssertEqual(noteButton.frame.width, chapterButton.frame.width, accuracy: 1)
        XCTAssertEqual(noteButton.frame.height, chapterButton.frame.height, accuracy: 1)
        snap("Gleaning action order and sizing", app)
        noteButton.tap()
        XCTAssertTrue(app.textFields["notes.new.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["notes.new.title"].value as? String, "Gleaning from \"\(reference)\"")
        app.buttons["notes.new.create"].tap()
        XCTAssertTrue(app.scrollViews["notes.viewport"].waitForExistence(timeout: 10))
        XCTAssertTrue((app.textViews["notes.body"].value as? String ?? "").contains("God is the Creator."))
        XCTAssertTrue((app.textViews["notes.body"].value as? String ?? "").contains(reference))
        snap("Converted gleaning note", app)
    }

    func testDeletedCollectionIsAbsentWhenSavingBookmark() {
        let app = launch(); openCollections(app)
        createCollection("Removed destination", in: app)
        app.buttons["collections.folder.Removed destination"].tap()
        app.buttons["Collection actions"].tap()
        app.buttons["Delete Collection"].tap()
        let confirm = app.buttons["Delete Collection"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        XCTAssertTrue(app.buttons["collections.folder.No Folder"].waitForExistence(timeout: 5))
        showTab("tab.scripture", in: app)
        let verse = app.links.firstMatch
        XCTAssertTrue(verse.waitForExistence(timeout: 10)); verse.tap()
        XCTAssertTrue(app.buttons["scripture.bookmark"].waitForExistence(timeout: 5))
        app.buttons["scripture.bookmark"].tap()
        XCTAssertTrue(app.navigationBars["New Bookmark"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["collections.choose.Removed destination"].exists)
        snap("Deleted folder excluded from save choices", app)
        app.buttons["collections.save.confirm"].tap()
    }

    func testEditLinkAndDragItIntoSubfolderPersists() {
        let app = launch(); openCollections(app)
        createCollection("Link parent", in: app)
        app.buttons["collections.folder.Link parent"].tap()
        app.buttons["collections.newSubfolder"].tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Link child")
        app.buttons["Create"].tap()
        app.buttons["collections.addMaterial"].tap()
        app.buttons["collections.newLink"].tap()
        let title = app.textFields["collections.newLink.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Original link")
        let url = app.textFields["collections.newLink.url"]
        url.tap(); url.typeText("example.com")
        app.buttons["collections.newLink.create"].tap()
        app.buttons["Done"].tap()
        let original = item("Original link", in: app)
        XCTAssertTrue(original.waitForExistence(timeout: 5)); original.tap()
        app.buttons["collections.link.edit"].tap()
        let editTitle = app.textFields["collections.editLink.title"]
        XCTAssertTrue(editTitle.waitForExistence(timeout: 5)); editTitle.tap()
        editTitle.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Original link".count) + "Edited link")
        let editURL = app.textFields["collections.editLink.url"]
        editURL.tap(); editURL.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "https://example.com".count) + "https://example.org/revised")
        app.buttons["collections.editLink.save"].tap()
        XCTAssertTrue(app.buttons["collections.link.edit"].waitForExistence(timeout: 5))
        snap("Edited saved link", app)
        app.buttons["Done"].tap()
        let material = item("Edited link", in: app)
        let target = app.buttons["collections.folder.Link child"]
        XCTAssertTrue(material.waitForExistence(timeout: 5)); XCTAssertTrue(target.exists)
        material.press(forDuration: 1.2, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.5)
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !material.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 5), .completed)
        target.tap()
        XCTAssertTrue(material.waitForExistence(timeout: 5))
        app.terminate(); app.launch(); openCollections(app)
        app.buttons["collections.folder.Link parent"].tap()
        app.buttons["collections.folder.Link child"].tap()
        XCTAssertTrue(material.waitForExistence(timeout: 5)); material.tap()
        XCTAssertTrue(app.staticTexts["https://example.org/revised"].waitForExistence(timeout: 5))
    }

    func testDragRootAndNestedFoldersPersists() {
        let app = launch()
        openCollections(app)
        for name in ["Drag A", "Drag B", "Drag C"] { createCollection(name, in: app) }
        let a = app.buttons["collections.folder.Drag A"]
        let b = app.buttons["collections.folder.Drag B"]
        let c = app.buttons["collections.folder.Drag C"]
        XCTAssertTrue(a.waitForExistence(timeout: 5))
        a.press(forDuration: 1.2, thenDragTo: b, withVelocity: .slow, thenHoldForDuration: 0.5)
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !a.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 5), .completed)
        c.press(forDuration: 1.2, thenDragTo: b, withVelocity: .slow, thenHoldForDuration: 0.5)
        b.tap()
        XCTAssertTrue(a.waitForExistence(timeout: 5))
        XCTAssertTrue(c.waitForExistence(timeout: 5))
        a.press(forDuration: 1.2, thenDragTo: c, withVelocity: .slow, thenHoldForDuration: 0.5)
        let nested = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !a.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [nested], timeout: 5), .completed)
        c.tap()
        XCTAssertTrue(a.waitForExistence(timeout: 5))
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Nested folder after drag"; capture.lifetime = .keepAlways; add(capture)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20))
        openCollections(app)
        b.tap(); c.tap()
        XCTAssertTrue(a.waitForExistence(timeout: 5))
    }

    func testAddMaterialCreatesNoteInCollection() {
        let app = launch()
        openCollections(app)
        createCollection("New material", in: app)
        app.buttons["collections.folder.New material"].tap()
        app.buttons["collections.addMaterialEmpty"].tap()
        XCTAssertTrue(app.buttons["collections.newConversation"].waitForExistence(timeout: 5))
        app.buttons["collections.newNote"].tap()
        XCTAssertTrue(app.buttons["notes.new.page"].waitForExistence(timeout: 5))
        let title = app.textFields["notes.new.title"]
        title.tap(); title.typeText("Created in collection")
        app.buttons["notes.new.create"].tap()
        XCTAssertTrue(app.scrollViews["notes.viewport"].waitForExistence(timeout: 10))
        back(app)
        let material = app.buttons["collections.open.Created in collection"]
        XCTAssertTrue(material.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["collections.filter"].tap(); app.buttons["Card View"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["collections.material.cards"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(material.frame.height, 176, accuracy: 1)
        XCTAssertTrue(material.isHittable)
        material.press(forDuration: 1)
        app.buttons["Page Status"].tap(); app.buttons["Closed"].tap()
        XCTAssertTrue(material.exists)
        material.tap()
        XCTAssertTrue(app.scrollViews["notes.viewport"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["notes.page.status"].value as? String, "Closed")
        back(app)
        XCTAssertTrue(material.waitForExistence(timeout: 5), "Closing a collection note must return to its folder")
        XCTAssertEqual(material.frame.height, 176, accuracy: 1)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Uniform collection card layout"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["collections.filter"].tap(); app.buttons["List View"].tap()
        XCTAssertEqual(material.frame.height, 80, accuracy: 1)
    }

    func testDuplicateCollectionModalCreatesIndependentFolders() {
        let app = launch(); openCollections(app)
        createCollection("Duplicate Source", in: app)
        app.buttons["collections.folder.Duplicate Source"].press(forDuration: 1)
        app.buttons["collections.duplicate"].tap()
        XCTAssertTrue(app.switches["collections.duplicate.contents"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons["collections.folder.Duplicate Source (Copy)"].exists)
        app.buttons["collections.folder.Duplicate Source"].tap()
        app.buttons["Collection actions"].tap(); app.buttons["collections.duplicate"].tap()
        XCTAssertTrue(app.buttons["collections.duplicate.confirm"].waitForExistence(timeout: 5))
        app.buttons["collections.duplicate.confirm"].tap()
        back(app)
        XCTAssertTrue(app.buttons["collections.folder.Duplicate Source (Copy)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["collections.folder.Duplicate Source"].exists)
    }

    func testSubfolderPreviewCountsOnlyDirectChildFolders() {
        let app = launch(); openCollections(app)
        createCollection("Count Parent", in: app)
        app.buttons["collections.folder.Count Parent"].tap()
        func addSubfolder(_ name: String) {
            app.buttons["collections.newSubfolder"].tap()
            let field = app.textFields["Name"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap(); field.typeText(name + "\n")
            app.buttons["Create"].tap()
            XCTAssertTrue(app.buttons["collections.folder." + name].waitForExistence(timeout: 5))
        }
        addSubfolder("Preview")
        app.buttons["collections.folder.Preview"].tap()
        addSubfolder("Direct")
        app.buttons["collections.folder.Direct"].tap()
        addSubfolder("Deep")
        back(app)
        XCTAssertEqual(app.staticTexts["collections.subfolder.counts.Direct"].label, "0 items · 1 subfolder")
        back(app)
        XCTAssertEqual(app.staticTexts["collections.subfolder.counts.Preview"].label, "0 items · 1 subfolder", "Deeper descendants must not increase the direct-folder count")
        app.buttons["collections.subfolder.arrange"].tap()
        XCTAssertTrue(app.buttons["collections.subfolder.arrange.name"].waitForExistence(timeout: 5))
        app.buttons["collections.subfolder.arrange.name"].tap()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Plain Arrange and direct subfolder count"; shot.lifetime = .keepAlways; add(shot)
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
        childName.typeText("Study Child\n")
        let plum = app.buttons["collections.color.plum"]
        let sheetBar = app.navigationBars["New Subfolder"]
        for _ in 0..<8 where !(plum.exists && plum.isHittable) {
            sheetBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 8))
                .press(forDuration: 0.05, thenDragTo: sheetBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 3)))
        }
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
        let editColor = app.buttons["Edit No Folder Color…"]
        XCTAssertTrue(editColor.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Delete Collection"].exists)
        editColor.tap()
        XCTAssertTrue(app.navigationBars["No Folder Color"].waitForExistence(timeout: 5))
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
        let confirmDelete = app.buttons["Delete Collection"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
        snap("grace confirm", app)
        confirmDelete.tap()
        snap("grace after confirm", app)
        XCTAssertTrue(app.buttons["collections.folder.No Folder"].waitForExistence(timeout: 5))
        let grace = app.buttons["collections.folder.Grace"]
        let graceGone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !grace.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [graceGone], timeout: 5), .completed, "Delete Collection must remove the folder")
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
        let menu = itemMenu(in: app)
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        menu.tap()
        app.buttons["collections.artifact.move"].tap()
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

    func testDeleteBookmarkFromNoFolderUsingSwipe() {
        let app = launch()
        saveBookmarkFromFirstVerse(app)
        openCollections(app)
        app.buttons["collections.folder.No Folder"].tap()
        let bookmark = item("Genesis 1:1", in: app)
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))

        XCTAssertFalse(itemMenu(in: app).exists, "List records must not display an ellipsis")
        app.buttons["collections.filter"].tap(); app.buttons["Card View"].tap()
        XCTAssertFalse(itemMenu(in: app).exists, "Cards must not display an ellipsis either")
        bookmark.press(forDuration: 1)
        XCTAssertTrue(app.buttons["collections.artifact.delete"].waitForExistence(timeout: 3), "Card hold menu remains available")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.55)).tap()
        app.buttons["collections.filter"].tap(); app.buttons["List View"].tap()
        bookmark.swipeLeft()
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.lifetime = .keepAlways; capture.name = "Revealed Collection actions"; add(capture)
        app.buttons["collections.swipe.more"].tap()
        let delete = app.buttons["collections.artifact.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        confirmCenteredDelete(app)
        XCTAssertFalse(bookmark.waitForExistence(timeout: 3))

        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20))
        openCollections(app)
        app.buttons["collections.folder.No Folder"].tap()
        XCTAssertFalse(item("Genesis 1:1", in: app).waitForExistence(timeout: 3), "Deletion must persist across relaunch")
    }

    func testDeleteBookmarkInsideFolderUsingLongPress() {
        let app = launch()
        saveBookmarkFromFirstVerse(app)
        openCollections(app)
        createCollection("Hold Delete", in: app)
        app.buttons["collections.folder.No Folder"].tap()
        let bookmark = item("Genesis 1:1", in: app)
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
        back(app)

        app.buttons["collections.folder.Hold Delete"].tap()
        app.buttons["collections.addMaterial"].tap()
        let pick = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "collections.pick.Genesis 1:1")).firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))

        bookmark.press(forDuration: 1.2)
        let delete = app.buttons["collections.artifact.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3), "Long-press must offer Delete")
        delete.tap()
        confirmCenteredDelete(app)
        XCTAssertFalse(bookmark.waitForExistence(timeout: 3))
        back(app)
        app.buttons["collections.folder.No Folder"].tap()
        XCTAssertFalse(item("Genesis 1:1", in: app).waitForExistence(timeout: 2), "A deleted bookmark must not fall back to No Folder")
    }

    func testDeleteNoteFromNoFolderMovesItToTrash() {
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
        let note = item("Untitled Note", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.press(forDuration: 1)
        app.buttons["collections.artifact.delete"].tap()
        confirmCenteredDelete(app)
        XCTAssertFalse(note.waitForExistence(timeout: 3))
    }

    func testDeleteFolderFromLibraryUsingLongPress() {
        let app = launch()
        openCollections(app)
        createCollection("Remove Me", in: app)
        let folder = app.buttons["collections.folder.Remove Me"]
        XCTAssertTrue(folder.waitForExistence(timeout: 5))
        folder.press(forDuration: 1.2)
        let delete = app.buttons["Delete Collection"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3), "Long-press on a folder must offer Delete Collection")
        snap("library menu", app)
        delete.tap()
        let confirm = app.buttons["Delete Collection"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        snap("library confirm", app)
        confirm.tap()
        snap("library after confirm", app)
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !folder.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed)

        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20))
        openCollections(app)
        XCTAssertFalse(folder.waitForExistence(timeout: 2), "Folder deletion must persist")
    }
}
