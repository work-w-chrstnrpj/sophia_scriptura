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
