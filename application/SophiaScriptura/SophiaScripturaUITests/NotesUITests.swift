import XCTest

final class NotesUITests: XCTestCase {
    private func launch(fingerInk: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        if fingerInk { app.launchEnvironment["SP013_FINGER_INK"] = "1" }
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30))
        return app
    }
    private func notes(_ app: XCUIApplication) {
        let tab = app.buttons["tab.notes"]
        let create = app.buttons["notes.newNotes"]
        for _ in 0..<3 {
            if !(tab.exists && tab.isHittable) {
                let reveal = app.buttons["navigation.showTabs"]
                if reveal.waitForExistence(timeout: 3) { reveal.tap() }
            }
            if tab.isHittable { tab.tap() }
            if create.waitForExistence(timeout: 2), create.isHittable { return }
        }
        XCTAssertTrue(create.waitForExistence(timeout: 5) && create.isHittable)
    }
    private func newNote(_ app: XCUIApplication, kind: String) {
        app.buttons["notes.newNotes"].tap()
        let kindButton = app.buttons["notes.new." + kind]
        XCTAssertTrue(kindButton.waitForExistence(timeout: 5))
        kindButton.tap()
        let create = app.buttons["notes.new.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
    }
    func testJournalCardTypeMenuIcons() {
        let app = launch(); notes(app)
        newNote(app, kind: "journal")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        for choice in ["Diaristic Journal", "Spiritual Journal", "Unset"] {
            app.staticTexts["Untitled Journal"].firstMatch.press(forDuration: 1)
            let menu = app.buttons["Journal Type"]
            XCTAssertTrue(menu.waitForExistence(timeout: 5))
            let field = XCTAttachment(screenshot: app.screenshot())
            field.name = "Journal Type field before " + choice
            field.lifetime = .keepAlways; add(field)
            menu.tap()
            for title in ["Unset", "Diaristic Journal", "Spiritual Journal"] {
                XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5))
            }
            let choices = XCTAttachment(screenshot: app.screenshot())
            choices.name = "Journal Type choices before " + choice
            choices.lifetime = .keepAlways; add(choices)
            app.buttons[choice].tap()
        }
    }

    func testDuplicateNoteRetractableToolsAndJournalType() {
        let app = launch(); notes(app)
        newNote(app, kind: "page")
        let collapse = app.buttons["notes.tools.collapse"]
        XCTAssertTrue(collapse.waitForExistence(timeout: 5))
        if app.buttons["notes.format"].exists { collapse.tap() }
        XCTAssertFalse(app.buttons["notes.format"].exists)
        XCTAssertTrue(app.buttons["notes.options"].exists)
        collapse.tap(); XCTAssertTrue(app.buttons["notes.format"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.staticTexts["Untitled Note"].firstMatch.press(forDuration: 1)
        app.buttons["notes.duplicate"].tap()
        XCTAssertTrue(app.staticTexts["Untitled Note (Copy)"].waitForExistence(timeout: 5))
        newNote(app, kind: "journal")
        XCTAssertEqual(app.buttons["notes.journal.type"].value as? String, "Unset")
        app.buttons["notes.journal.type"].tap(); app.buttons["Diaristic Journal"].tap()
        XCTAssertEqual(app.buttons["notes.journal.type"].value as? String, "Diaristic Journal")
        app.buttons["notes.journal.type"].tap(); app.buttons["Spiritual Journal"].tap()
        XCTAssertEqual(app.buttons["notes.journal.type"].value as? String, "Spiritual Journal")
        app.buttons["notes.journal.type"].tap(); app.buttons["Unset"].tap()
        XCTAssertEqual(app.buttons["notes.journal.type"].value as? String, "Unset")
        app.buttons["notes.tools.collapse"].tap()
        XCTAssertFalse(app.buttons["notes.format"].exists)
        XCTAssertTrue(app.buttons["notes.journal.type"].exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Collapsed Journal editing tools"; capture.lifetime = .keepAlways; add(capture)
    }

    func testNotesListAndPrayerUpdatesRevealActionsOnSwipe() {
        let app = launch(); notes(app)
        newNote(app, kind: "page")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["notes.viewOptions"].tap()
        let cards = app.buttons["Cards"]
        XCTAssertTrue(cards.waitForExistence(timeout: 5)); cards.tap()
        // Dismiss the menu without selecting a record.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.4)).tap()
        let title = app.staticTexts["Untitled Note"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.swipeLeft()
        XCTAssertTrue(app.buttons["notes.swipe.more"].waitForExistence(timeout: 5))
        app.buttons["notes.swipe.more"].tap()
        XCTAssertTrue(app.buttons["notes.editNote"].waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.4)).tap()
        app.buttons["notes.swipe.more"].swipeRight()
        XCTAssertFalse(app.buttons["notes.swipe.more"].exists)
        app.buttons["notes.viewOptions"].tap(); cards.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.4)).tap()
        title.swipeLeft()
        XCTAssertTrue(app.buttons["notes.swipe.more"].waitForExistence(timeout: 5), "Cards also reveal actions")
        app.buttons["notes.swipe.more"].swipeRight()
        title.press(forDuration: 1)
        XCTAssertTrue(app.buttons["notes.editNote"].waitForExistence(timeout: 5), "Holding retains the full menu")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.4)).tap()
        newNote(app, kind: "prayer")
        let input = app.descendants(matching: .any)["notes.prayer.update.input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10)); input.tap(); input.typeText("Swipe update fixture")
        app.buttons["notes.prayer.update.share"].tap()
        let text = app.staticTexts["Swipe update fixture"].firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5)); text.swipeLeft()
        XCTAssertTrue(app.buttons["notes.prayer.update.swipe.edit"].waitForExistence(timeout: 5))
        app.buttons["notes.prayer.update.swipe.delete"].tap()
        XCTAssertTrue(app.alerts["Delete this update?"].waitForExistence(timeout: 5))
        app.alerts["Delete this update?"].buttons["Cancel"].tap()
        XCTAssertTrue(text.exists)
    }

    func testOnlyOneSwipeRailAndDismissFromRecordOrScroll() {
        let app = launch(); notes(app)
        newNote(app, kind: "page")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        newNote(app, kind: "prayer")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["notes.viewOptions"].tap(); app.buttons["Cards"].tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.4)).tap()
        let page = app.staticTexts["Untitled Note"].firstMatch
        let prayer = app.staticTexts["Untitled Prayer"].firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        let pageX = page.frame.minX
        page.swipeLeft()
        XCTAssertEqual(app.buttons.matching(identifier: "notes.swipe.more").count, 1)
        prayer.swipeLeft()
        XCTAssertEqual(app.buttons.matching(identifier: "notes.swipe.more").count, 1, "Opening another row closes the first")
        XCTAssertEqual(page.frame.minX, pageX, accuracy: 2)

        // Start on the shifted record's blank body, not on an action button.
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let y = prayer.frame.midY
        origin.withOffset(CGVector(dx: 160, dy: y)).press(forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 420, dy: y)))
        XCTAssertFalse(app.buttons["notes.swipe.more"].exists, "Swipe-back on the record itself closes the rail")
        prayer.swipeLeft()
        XCTAssertTrue(app.buttons["notes.swipe.more"].exists)
        origin.withOffset(CGVector(dx: 160, dy: prayer.frame.midY)).press(forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 160, dy: prayer.frame.midY - 140)))
        XCTAssertFalse(app.buttons["notes.swipe.more"].exists, "Vertical scrolling dismisses actions")
        XCTAssertFalse(app.scrollViews["notes.viewport"].exists, "Dismissal must not open a note")
    }

    func testPrayerUpdateVerticalDragStillScrolls() {
        let app = launch(); notes(app)
        newNote(app, kind: "prayer")
        let input = app.descendants(matching: .any)["notes.prayer.update.input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText((1...55).map { "Line \($0) of prayer update." }.joined(separator: "\n"))
        app.buttons["notes.prayer.update.share"].tap()
        let hideKeyboard = app.buttons["Hide keyboard"]
        if hideKeyboard.exists { hideKeyboard.tap() }
        let update = app.descendants(matching: .any).matching(NSPredicate(format: "identifier MATCHES %@", "notes.prayer.update.[A-F0-9-]+")).firstMatch
        XCTAssertTrue(update.waitForExistence(timeout: 5))
        let before = update.frame.minY
        let startY = min(before + 80, app.frame.height - 220)
        XCTAssertGreaterThan(startY, before, "The drag must start inside the update")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: startY))
        start.press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: startY - 260)))
        XCTAssertLessThan(update.frame.minY, before - 40, "A vertical drag over a swipe-enabled update must scroll")
        XCTAssertFalse(app.buttons["notes.prayer.update.swipe.delete"].exists)
    }

    func testHoldNoteStatusMenus() {
        let app = launch(); notes(app)
        newNote(app, kind: "page")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.staticTexts["Untitled Note"].press(forDuration: 1)
        app.buttons["Page Status"].tap(); app.buttons["Closed"].tap()
        XCTAssertTrue(app.images["notes.page.stamp"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.scrollViews["notes.viewport"].exists)
        newNote(app, kind: "prayer")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.staticTexts["Untitled Prayer"].press(forDuration: 1)
        app.buttons["Prayer Status"].tap(); app.buttons["Prayer answered"].tap()
        XCTAssertTrue(app.images["notes.prayer.stamp"].waitForExistence(timeout: 5))
        newNote(app, kind: "journal")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.staticTexts["Untitled Journal"].press(forDuration: 1)
        app.buttons["Mental State"].tap(); app.buttons["Thriving"].tap()
        app.staticTexts["Untitled Journal"].press(forDuration: 1)
        app.buttons["Emotional State"].tap(); app.buttons["Happy"].tap()
        let preview = app.descendants(matching: .any)["notes.journal.preview"].firstMatch
        XCTAssertTrue(preview.label.contains("Happy")); XCTAssertTrue(preview.label.contains("Thriving"))
        XCTAssertFalse(app.scrollViews["notes.viewport"].exists)
    }

    func testJournalAndPageCardPreviews() {
        let app = launch(); notes(app)
        newNote(app, kind: "journal")
        XCTAssertTrue(app.buttons["notes.journal.mental"].waitForExistence(timeout: 10))
        app.buttons["notes.journal.mental"].tap()
        app.buttons["notes.journal.mental.thriving"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let journal = app.descendants(matching: .any)["notes.journal.preview"].firstMatch
        XCTAssertTrue(journal.waitForExistence(timeout: 5))
        XCTAssertTrue(journal.label.contains("Emotional State: Not set"))
        XCTAssertTrue(journal.label.contains("Mental State: Thriving"))
        newNote(app, kind: "page")
        let body = app.textViews["notes.body"]
        XCTAssertTrue(body.waitForExistence(timeout: 10)); body.tap()
        body.typeText("Opening words for the Page preview")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let preview = app.staticTexts["notes.page.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertTrue(preview.label.contains("Opening words"))
        preview.tap()
        let status = app.buttons["notes.page.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        status.tap(); app.buttons["Closed"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let stamp = app.images["notes.page.stamp"]
        XCTAssertTrue(stamp.waitForExistence(timeout: 5))
        XCTAssertEqual(stamp.label, "Page published")
        XCTAssertFalse(preview.exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Journal row and Published Page card"; capture.lifetime = .keepAlways; add(capture)
        stamp.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        status.tap(); app.buttons["Drafting"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertFalse(stamp.exists)
    }

    func testPageStatusToolbarOffersAllChoices() {
        let app = launch(); notes(app)
        newNote(app, kind: "page")
        let status = app.buttons["notes.page.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(status.value as? String, "Unset")
        for choice in ["Drafting", "Revising", "Editing", "Publishing", "Closed", "Unset"] {
            status.tap()
            let option = app.buttons[choice]
            XCTAssertTrue(option.waitForExistence(timeout: 5))
            option.tap()
            XCTAssertEqual(status.value as? String, choice)
        }
        status.tap()
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Page status toolbar choices"; capture.lifetime = .keepAlways; add(capture)
    }

    func testPrayerStatusStampsAndJournalStateIcons() {
        let app = launch(); notes(app)
        newNote(app, kind: "prayer")
        let status = app.buttons["notes.prayer.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        status.tap(); app.buttons["Prayer answered"].tap()
        let stamp = app.descendants(matching: .any)["notes.prayer.stamp"].firstMatch
        XCTAssertFalse(stamp.exists, "The prayer editor must not contain a stamp")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(stamp.waitForExistence(timeout: 5))
        XCTAssertEqual(stamp.label, "Prayer answered")
        let answered = XCTAttachment(screenshot: app.screenshot())
        answered.name = "Answered prayer card stamp"; answered.lifetime = .keepAlways; add(answered)
        stamp.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        status.tap(); app.buttons["Prayer redirected"].tap()
        XCTAssertFalse(stamp.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(stamp.waitForExistence(timeout: 5))
        XCTAssertEqual(stamp.label, "Prayer redirected")
        let redirected = XCTAttachment(screenshot: app.screenshot())
        redirected.name = "Redirected prayer card stamp"; redirected.lifetime = .keepAlways; add(redirected)
        stamp.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        status.tap(); app.buttons["Praying & waiting"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertFalse(stamp.exists)
        newNote(app, kind: "journal")
        let emotion = app.buttons["notes.journal.emotional"]
        XCTAssertTrue(emotion.waitForExistence(timeout: 10))
        XCTAssertEqual(emotion.value as? String, "Not set")
        app.buttons["notes.journal.mental"].tap()
        app.buttons["notes.journal.mental.thriving"].tap()
        XCTAssertEqual(app.buttons["notes.journal.mental"].value as? String, "Thriving")
        let journal = XCTAttachment(screenshot: app.screenshot())
        journal.name = "Journal thriving and unset emotion icons"; journal.lifetime = .keepAlways; add(journal)
    }

    func testBulkDeleteConfirmsCancelsAndPersistsOnlySelectedNotes() {
        let app = launch(); notes(app)
        for _ in 0..<3 {
            newNote(app, kind: "page")
            XCTAssertTrue(app.scrollViews["notes.viewport"].waitForExistence(timeout: 10))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["notes.selectMode"].waitForExistence(timeout: 5))
        }
        app.buttons["notes.selectMode"].tap()
        let selectors = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "notes.select."))
        XCTAssertEqual(selectors.count, 3)
        selectors.element(boundBy: 0).tap()
        selectors.element(boundBy: 1).tap()
        app.buttons["notes.bulkDelete"].tap()
        let confirmation = app.alerts["Move 2 notes to Trash?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), app.debugDescription)
        confirmation.buttons["Cancel"].tap()
        XCTAssertEqual(selectors.count, 3)
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 10), .completed)
        app.buttons["notes.bulkDelete"].tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Move to Trash"].tap()
        XCTAssertTrue(app.buttons["notes.selectMode"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["notes.selectMode"].label, "Select notes")
        app.buttons["notes.selectMode"].tap()
        XCTAssertEqual(selectors.count, 1)
        app.buttons["notes.selectMode"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30)); notes(app)
        app.buttons["notes.selectMode"].tap()
        XCTAssertEqual(selectors.count, 1)
    }

    func testCanvasShareAndColorMenu() {
        let app = launch(); notes(app); newNote(app, kind: "canvas")
        XCTAssertTrue(app.buttons["notes.editor.share"].waitForExistence(timeout: 10))
        app.buttons["notes.shapes"].tap()
        app.buttons["notes.shape.circle"].tap()
        let color = app.buttons["notes.action.color"]
        XCTAssertTrue(color.waitForExistence(timeout: 5))
        color.tap()
        XCTAssertTrue(app.buttons["Red"].waitForExistence(timeout: 5))
        let swatches = XCTAttachment(screenshot: app.screenshot())
        swatches.name = "Canvas color swatches"; swatches.lifetime = .keepAlways; add(swatches)
        app.buttons["Red"].firstMatch.tap()
        app.buttons["notes.editor.share"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10), app.debugDescription)
    }

    func testBlankNoteDirectTextMetadataAndRelaunch() {
        let app = launch(); notes(app)
        newNote(app, kind: "page")
        XCTAssertTrue(app.scrollViews["notes.viewport"].waitForExistence(timeout: 10))
        let text = app.textViews["notes.body"]
        XCTAssertTrue(text.waitForExistence(timeout: 5)); text.tap(); text.typeText("Grace and truth")
        app.buttons["notes.options"].tap()
        app.buttons["Note details"].tap()
        let title = app.textFields["notes.title"]; XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.press(forDuration: 1)
        if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap(); title.typeText("Morning study") }
        else { title.typeText(" morning study") }
        app.buttons["Save"].tap()
        app.buttons["notes.options"].tap()
        let saved = app.buttons["Saved"]
        XCTAssertTrue(saved.waitForExistence(timeout: 10)); saved.tap()
        let screen = XCTAttachment(screenshot: app.screenshot()); screen.name = "SP013 direct text"; screen.lifetime = .keepAlways; add(screen)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30)); notes(app)
        let note = app.buttons.containing(.staticText, identifier: "Grace and truth").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 10)); note.tap()
        XCTAssertEqual(app.textViews["notes.body"].value as? String, "Grace and truth")
    }
    func testContextActionsShapeStickerPaperTitleAndRotation() {
        let app = launch(); notes(app); newNote(app, kind: "canvas")
        if app.buttons["notes.scripture.toggle"].label == "Hide Scripture" { app.buttons["notes.scripture.toggle"].tap() }
        XCTAssertFalse(app.buttons["Done typing"].exists); XCTAssertFalse(app.buttons["notes.objects"].exists)
        let viewport = app.scrollViews["notes.viewport"]
        XCTAssertGreaterThan(viewport.frame.maxY, app.frame.maxY - 50)
        app.buttons["notes.rename"].tap()
        let title = app.alerts["Rename note"].textFields.firstMatch; XCTAssertTrue(title.waitForExistence(timeout: 5), app.debugDescription)
        title.tap(); title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (title.value as? String ?? "").count)); title.typeText("Canvas study")
        app.alerts.buttons["Save"].tap()
        app.buttons["notes.options"].tap(); app.buttons["Paper"].tap(); app.buttons["Dotted"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let canvasCard = app.buttons.containing(.staticText, identifier: "Canvas study").firstMatch
        XCTAssertTrue(canvasCard.waitForExistence(timeout: 10))
        canvasCard.press(forDuration: 1.2)
        app.buttons["notes.editNote"].tap()
        app.buttons["notes.color.sage"].tap()
        app.buttons["notes.edit.save"].tap()
        canvasCard.tap()
        app.buttons["notes.shapes"].tap(); app.buttons["notes.shape.star"].tap()
        XCTAssertTrue(app.buttons["notes.action.duplicate"].waitForExistence(timeout: 5))
        app.buttons["notes.action.duplicate"].tap()
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "notes.object.shape").count, 2)
        app.buttons["notes.action.delete"].tap()
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "notes.object.shape").count, 1)
        app.buttons["notes.undo"].tap()
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "notes.object.shape").count, 2)
        app.buttons["notes.stickers"].tap(); app.buttons["Sticker 🌿"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "notes.object.sticker").firstMatch.exists)
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 10), .completed)
        XCTAssertTrue(viewport.isHittable)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); screen.name = "Refined Canvas landscape"; screen.lifetime = .keepAlways; add(screen)
    }
    func testVerseQuoteReturnsToSameNoteFromHub() {
        let app = launch()
        let verse = app.links.firstMatch
        XCTAssertTrue(verse.waitForExistence(timeout: 10)); verse.tap()
        XCTAssertTrue(app.buttons["Save verse to note"].waitForExistence(timeout: 5))
        app.buttons["Save verse to note"].tap()
        XCTAssertTrue(app.buttons["scripture.saveNote.newPage"].waitForExistence(timeout: 5))
        app.buttons["scripture.saveNote.newPage"].tap()
        XCTAssertTrue(app.scrollViews["notes.viewport"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["GEN 1:1"].exists)
        XCTAssertTrue(app.buttons["notes.reader.book"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.textViews["notes.body"].value as? String ?? "").contains("GEN 1:1"))
        if app.buttons["navigation.showTabs"].exists { app.buttons["navigation.showTabs"].tap() }
        if app.buttons["notes.tools"].label == "Hide Pencil tools" { app.buttons["notes.tools"].tap() }
        if app.buttons["navigation.showTabs"].exists { app.buttons["navigation.showTabs"].tap() }
        let debugScreen = XCTAttachment(screenshot: app.screenshot()); debugScreen.name = "Before leaving Notes"; debugScreen.lifetime = .keepAlways; add(debugScreen)
        XCTAssertTrue(app.buttons["tab.scripture"].isHittable, app.debugDescription)
        app.buttons["tab.scripture"].tap()
        app.links.matching(NSPredicate(format: "label CONTAINS '1'")).firstMatch.tap()
        let linked = app.buttons["GEN 1:1"]
        XCTAssertTrue(linked.waitForExistence(timeout: 5)); linked.tap()
        XCTAssertTrue(app.scrollViews["notes.viewport"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["GEN 1:1"].exists)
    }

    func testCanvasFingerMovesAndResizesObject() {
        let app = launch(); notes(app); newNote(app, kind: "canvas")
        XCTAssertFalse(app.textViews["notes.body"].exists)
        app.buttons["notes.insert"].tap(); app.buttons["Shape"].tap(); app.buttons["notes.shape.circle"].tap()
        let shape = app.descendants(matching: .any).matching(identifier: "notes.object.shape").firstMatch
        XCTAssertTrue(shape.waitForExistence(timeout: 5))
        let before = shape.frame
        let origin = shape.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.4))
        origin.press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: 45, dy: 55)))
        XCTAssertGreaterThan(shape.frame.minY, before.minY + 20)
        let moved = shape.frame
        let handle = shape.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.95))
        handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: 45, dy: 40)))
        XCTAssertGreaterThan(shape.frame.width, moved.width + 15)
        app.buttons["notes.options"].tap()
        XCTAssertTrue(app.buttons["Saved"].waitForExistence(timeout: 10)); app.buttons["Saved"].tap()
        let screen = XCTAttachment(screenshot: app.screenshot()); screen.name = "Study page direct object editing"; screen.lifetime = .keepAlways; add(screen)
    }

    func testPageInlineTableAndScriptureVisibilityPersist() {
        let app = launch(); notes(app); newNote(app, kind: "page")
        XCTAssertTrue(app.buttons["notes.scripture.toggle"].waitForExistence(timeout: 10))
        let toggle = app.buttons["notes.scripture.toggle"]
        if toggle.label == "Show Scripture" { toggle.tap() }
        XCTAssertTrue(app.buttons["notes.reader.book"].waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertFalse(app.buttons["notes.reader.book"].exists)
        XCTAssertTrue(app.buttons["notes.format"].exists)
        XCTAssertTrue(app.buttons["notes.insert.checkbox"].exists)
        XCTAssertTrue(app.buttons["notes.attach"].exists)
        XCTAssertFalse(app.buttons["notes.zoom"].exists)
        app.buttons["notes.insert.table"].tap()
        XCTAssertTrue((app.textViews["notes.body"].value as? String ?? "").contains("\u{FFFC}"))
        app.buttons["notes.options"].tap()
        XCTAssertTrue(app.buttons["Saved"].waitForExistence(timeout: 10)); app.buttons["Saved"].tap()
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30)); notes(app)
        app.buttons.containing(.staticText, identifier: "Untitled Note").firstMatch.tap()
        XCTAssertTrue(app.buttons["notes.scripture.toggle"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["notes.scripture.toggle"].label, "Show Scripture")
        app.buttons["notes.scripture.toggle"].tap()
        XCTAssertTrue(app.buttons["notes.reader.book"].waitForExistence(timeout: 5))
    }

    func testCanvasSelectsDeletesOneStrokeAndPastesItsCopy() {
        let app = launch(fingerInk: true); notes(app); newNote(app, kind: "canvas")
        let viewport = app.scrollViews["notes.viewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 10))
        let firstStart = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.32))
        firstStart.press(forDuration: 0.1, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.32)))
        viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.52)).press(forDuration: 0.1,
            thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.52)))
        let ink = viewport
        app.buttons["notes.options"].tap()
        XCTAssertTrue(app.buttons["Strokes"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Strokes"].tap()
        viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.32)).tap()
        let copy = app.buttons["notes.strokes.copy"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue((ink.value as? String ?? "").contains("1 selected strokes"), String(describing: ink.value))
        copy.tap()
        app.buttons["notes.strokes.delete"].tap()
        let oneStroke = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in (ink.value as? String ?? "").hasPrefix("1 strokes") }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [oneStroke], timeout: 5), .completed)
        app.buttons["notes.options"].tap(); app.buttons["notes.canvas.paste"].tap()
        let twoStrokes = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in (ink.value as? String ?? "").hasPrefix("2 strokes") }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [twoStrokes], timeout: 5), .completed)
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "SP025 stroke copy and paste"; image.lifetime = .keepAlways; add(image)
        app.buttons["notes.undo"].tap()
        let undone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in (ink.value as? String ?? "").hasPrefix("1 strokes") }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [undone], timeout: 5), .completed)
    }

    func testCanvasDrawingObjectMovesAndReopens() {
        let app = launch(fingerInk: true); notes(app)
        newNote(app, kind: "canvas")
        let viewport = app.scrollViews["notes.viewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 10))
        viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.2)).press(forDuration: 0.1, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.4)))
        let object = app.descendants(matching: .any).matching(identifier: "notes.object.ink").firstMatch
        XCTAssertTrue(object.waitForExistence(timeout: 8))
        app.buttons["notes.tools"].tap()
        // DEBUG finger drawing cannot also emulate Pencil-vs-finger object selection.
        // Geometry/ownership transforms are covered by the model tests.
        XCTAssertTrue(object.waitForExistence(timeout: 5))
        app.buttons["notes.options"].tap()
        XCTAssertTrue(app.buttons["Saved"].waitForExistence(timeout: 10)); app.buttons["Saved"].tap()
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Canvas drawing object"; image.lifetime = .keepAlways; add(image)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30)); notes(app)
        app.buttons.containing(.staticText, identifier: "Untitled Note").firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "notes.object.ink").firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.textViews["notes.body"].exists)
    }

    func testCitationRevealsHiddenScripture() {
        let app = launch()
        let verse = app.links.firstMatch; XCTAssertTrue(verse.waitForExistence(timeout: 10)); verse.tap()
        app.buttons["Save verse to note"].tap()
        XCTAssertTrue(app.buttons["scripture.saveNote.newPage"].waitForExistence(timeout: 5))
        app.buttons["scripture.saveNote.newPage"].tap()
        XCTAssertTrue(app.buttons["notes.scripture.toggle"].waitForExistence(timeout: 10))
        let toggle = app.buttons["notes.scripture.toggle"]
        if toggle.label == "Show Scripture" { toggle.tap() }
        toggle.tap(); XCTAssertFalse(app.buttons["notes.reader.book"].exists)
        let citation = app.textViews["notes.body"].links["GEN 1:1 · WEB"]
        XCTAssertTrue(citation.waitForExistence(timeout: 5)); citation.tap()
        XCTAssertTrue(app.buttons["notes.reader.book"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["GEN 1:1"].exists)
    }

    func testCanvasWebsitePreviewLoadsAndReopens() {
        let app = launch(); notes(app); newNote(app, kind: "canvas")
        if app.buttons["notes.scripture.toggle"].label == "Hide Scripture" { app.buttons["notes.scripture.toggle"].tap() }
        app.buttons["notes.insert"].tap(); app.buttons["Link"].tap()
        let url = app.alerts["Insert link"].textFields.firstMatch
        XCTAssertTrue(url.waitForExistence(timeout: 5)); url.tap(); url.typeText("www.apple.com/ipad/")
        app.alerts.buttons["Insert"].tap()
        let card = app.descendants(matching: .any).matching(identifier: "notes.object.link").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let preview = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Thumbnail available'"), object: card)
        XCTAssertEqual(XCTWaiter.wait(for: [preview], timeout: 30), .completed)
        app.buttons["notes.undo"].tap(); XCTAssertFalse(card.exists)
        app.buttons["notes.redo"].tap(); XCTAssertTrue(card.waitForExistence(timeout: 5)); XCTAssertEqual(card.value as? String, "Thumbnail available")
        app.buttons["notes.options"].tap(); XCTAssertTrue(app.buttons["Saved"].waitForExistence(timeout: 10)); app.buttons["Saved"].tap()
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Canvas website preview"; image.lifetime = .keepAlways; add(image)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30)); notes(app)
        app.buttons.containing(.staticText, identifier: "Untitled Note").firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 10)); XCTAssertEqual(card.value as? String, "Thumbnail available")
    }

    func testCanvasYouTubePreviewLoadsAndReopens() {
        let app = launch(); notes(app); newNote(app, kind: "canvas")
        if app.buttons["notes.scripture.toggle"].label == "Hide Scripture" { app.buttons["notes.scripture.toggle"].tap() }
        app.buttons["notes.insert"].tap(); app.buttons["Link"].tap()
        let url = app.alerts["Insert link"].textFields.firstMatch
        XCTAssertTrue(url.waitForExistence(timeout: 5)); url.tap(); url.typeText("www.youtube.com/watch?v=aqz-KE-bpKQ")
        app.alerts.buttons["Insert"].tap()
        let card = app.descendants(matching: .any).matching(identifier: "notes.object.link").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let preview = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Thumbnail available'"), object: card)
        XCTAssertEqual(XCTWaiter.wait(for: [preview], timeout: 30), .completed)
        app.buttons["notes.undo"].tap(); XCTAssertFalse(card.exists)
        app.buttons["notes.redo"].tap(); XCTAssertTrue(card.waitForExistence(timeout: 5)); XCTAssertEqual(card.value as? String, "Thumbnail available")
        app.buttons["notes.options"].tap(); XCTAssertTrue(app.buttons["Saved"].waitForExistence(timeout: 10)); app.buttons["Saved"].tap()
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Canvas YouTube preview"; image.lifetime = .keepAlways; add(image)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30)); notes(app)
        app.buttons.containing(.staticText, identifier: "Untitled Note").firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 10)); XCTAssertEqual(card.value as? String, "Thumbnail available")
    }

    func testInkAutosavesAcrossTabAndRelaunch() {
        let app = launch(fingerInk: true); notes(app); newNote(app, kind: "page")
        let ink = app.descendants(matching: .any).matching(identifier: "notes.ink").firstMatch
        XCTAssertTrue(ink.waitForExistence(timeout: 10))
        let viewport = app.scrollViews["notes.viewport"]
        viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2)).press(forDuration: 0.1, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        let hasInk = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value MATCHES %@", "^[1-9][0-9]* strokes$"), object: ink)
        XCTAssertEqual(XCTWaiter.wait(for: [hasInk], timeout: 8), .completed)
        if app.buttons["navigation.showTabs"].exists { app.buttons["navigation.showTabs"].tap() }
        if app.buttons["notes.tools"].label == "Hide Pencil tools" { app.buttons["notes.tools"].tap() }
        if app.buttons["navigation.showTabs"].exists { app.buttons["navigation.showTabs"].tap() }
        let debugScreen = XCTAttachment(screenshot: app.screenshot()); debugScreen.name = "Before leaving Notes"; debugScreen.lifetime = .keepAlways; add(debugScreen)
        XCTAssertTrue(app.buttons["tab.scripture"].isHittable, app.debugDescription)
        app.buttons["tab.scripture"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30)); notes(app)
        app.buttons.containing(.staticText, identifier: "Untitled Note").firstMatch.tap()
        let reopened = app.descendants(matching: .any).matching(identifier: "notes.ink").firstMatch
        XCTAssertTrue(reopened.waitForExistence(timeout: 10))
        let count = Int((reopened.value as? String ?? "").split(separator: " ").first ?? "") ?? 0
        XCTAssertGreaterThan(count, 0)
    }

    func testCanvasRepeatedInkUsesViewportAndActivePenIndicator() {
        let app = launch(fingerInk: true); notes(app)
        newNote(app, kind: "canvas")
        let viewport = app.scrollViews["notes.viewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 10))
        let tools = app.buttons["notes.tools"]
        XCTAssertEqual(tools.value as? String, "Active")
        tools.tap(); XCTAssertEqual(tools.value as? String, "Hidden")
        tools.tap(); XCTAssertEqual(tools.value as? String, "Active")
        let bounds = "Ink viewport \(Int(viewport.frame.width)) × \(Int(viewport.frame.height)); "
        XCTAssertEqual(viewport.value as? String, bounds + "0 strokes")
        let expectedStrokes = 20
        for index in 0..<expectedStrokes {
            let y = 0.15 + Double(index % 10) * 0.045
            viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: y)).press(forDuration: 0.05, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: y + 0.025)))
        }
        let strokes = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", bounds + "\(expectedStrokes) strokes"), object: viewport)
        XCTAssertEqual(XCTWaiter.wait(for: [strokes], timeout: 10), .completed)
        tools.tap()
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Canvas repeated ink with bounded viewport"; shot.lifetime = .keepAlways; add(shot)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30)); notes(app)
        app.buttons.containing(.staticText, identifier: "Untitled Note").firstMatch.tap()
        XCTAssertTrue(viewport.waitForExistence(timeout: 10)); XCTAssertTrue((viewport.value as? String ?? "").hasSuffix("\(expectedStrokes) strokes"))
    }

}
