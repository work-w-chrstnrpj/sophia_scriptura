import XCTest

final class ShellNavigationUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.textViews["scripture.text"].waitForExistence(timeout:20))
        return app
    }
    private func waitForVisible(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let expectation = XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == true AND hittable == true"), object:element)
        XCTAssertEqual(XCTWaiter.wait(for:[expectation], timeout:timeout), .completed)
    }
    private func reveal(_ app: XCUIApplication) {
        if app.buttons["tab.scripture"].isHittable {
            app.buttons["tab.scripture"].tap()
            waitForVisible(app.buttons["tab.scripture"])
            return
        }
        let handle = app.buttons["navigation.showTabs"]
        XCTAssertTrue(handle.waitForExistence(timeout: 8))
        handle.tap()
        waitForVisible(app.buttons["tab.scripture"])
    }
    private func createCollection(_ name: String, in app: XCUIApplication) {
        let create = app.buttons["collections.newCollection"]
        waitForVisible(create)
        create.tap()
        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout:5))
        field.tap(); field.typeText(name)
        app.buttons["Create"].tap()
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
    func testThreeSecondHideManualRevealAndStableReaderGeometry() {
        let app = launch()
        reveal(app)
        let text = app.textViews["scripture.text"]
        let frame = text.frame
        let handle = app.buttons["navigation.showTabs"]
        waitForVisible(handle, timeout:4)
        XCTAssertTrue(handle.isHittable, "Only the reveal handle should be reachable while the dock is hidden")
        XCTAssertEqual(text.frame,frame)
        capture(app,"Dock hidden with reveal handle")
        handle.tap()
        waitForVisible(app.buttons["tab.settings"])
        XCTAssertEqual(text.frame,frame,"Chrome visibility must not resize the reader")
        capture(app,"Dock restored from reveal handle")
        waitForVisible(handle,timeout:4)
        handle.tap()
        waitForVisible(app.buttons["tab.settings"])
        XCTAssertEqual(text.frame,frame)
    }
    func testTabSwitchRetainsCollectionNavigationAndPlaceholderCanRevealMenu() {
        let app = launch()
        reveal(app)
        app.buttons["tab.collections"].tap()
        createCollection("Assurance", in: app)
        let folder = app.buttons["collections.folder.Assurance"]
        waitForVisible(folder)
        folder.tap()
        let counts = app.descendants(matching:.any)["collections.detail.counts"]
        XCTAssertTrue(counts.waitForExistence(timeout:5))
        reveal(app); app.buttons["tab.notes"].tap()
        waitForVisible(app.buttons["notes.new"])
        reveal(app); app.buttons["tab.collections"].tap()
        XCTAssertTrue(counts.waitForExistence(timeout:5))
        capture(app,"Collection detail preserved through tab slide")
        reveal(app); app.buttons["tab.companion"].tap()
        waitForVisible(app.buttons["navigation.showTabs"],timeout:8)
        app.buttons["navigation.showTabs"].tap()
        waitForVisible(app.buttons["tab.scripture"])
        app.buttons["tab.scripture"].tap()
        waitForVisible(app.textViews["scripture.text"])
    }
    func testSettingsFinalExperimentRowIsFullyAboveDockInBothOrientations() {
        let app = launch()
        reveal(app); app.buttons["tab.settings"].tap()
        let form = app.descendants(matching:.any).matching(identifier:"settings.content").firstMatch
        XCTAssertTrue(form.waitForExistence(timeout:5))
        let experiment = app.buttons["settings.pencilValidation"]
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            for _ in 0..<4 { form.swipeUp() }
            reveal(app)
            waitForVisible(experiment)
            let footer = app.buttons["tab.settings"]
            XCTAssertLessThan(experiment.frame.maxY, footer.frame.minY - 12,
                              "The complete last row must clear the footer")
            capture(app,"Settings last experiment row — \(orientation == .portrait ? "portrait" : "landscape")")
        }
        experiment.tap()
        XCTAssertTrue(app.staticTexts["SP-008 · Pencil geometry experiment"].waitForExistence(timeout:5))
        XCUIDevice.shared.orientation = .portrait
    }
    func testCollectionsAndNotesContentClearsFooterInLandscape() {
        let app = launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        reveal(app); app.buttons["tab.collections"].tap()
        let library = app.descendants(matching:.any).matching(identifier:"collections.content").firstMatch
        XCTAssertTrue(library.waitForExistence(timeout:5))
        createCollection("Prayer", in: app)
        library.swipeUp()
        let prayer = app.buttons["collections.folder.Prayer"]
        if !app.buttons["tab.collections"].isHittable { reveal(app) }
        waitForVisible(prayer)
        XCTAssertLessThan(prayer.frame.maxY,app.buttons["tab.collections"].frame.minY - 12)
        prayer.tap()
        let detail = app.descendants(matching:.any).matching(identifier:"collections.detailContent").firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout:5))
        for _ in 0..<3 { detail.swipeUp() }
        if !app.buttons["tab.collections"].isHittable { reveal(app) }
        let lastAction = app.buttons["collections.addMaterialEmpty"]
        waitForVisible(lastAction)
        XCTAssertLessThan(lastAction.frame.maxY + 14,app.buttons["tab.collections"].frame.minY - 12)
        capture(app,"Collection final card above dock")
        app.buttons["tab.notes"].tap()
        let noteNotice = app.buttons["notes.new"]
        waitForVisible(noteNotice)
        if !app.buttons["tab.notes"].isHittable { reveal(app) }
        XCTAssertLessThan(noteNotice.frame.maxY,app.buttons["tab.notes"].frame.minY - 12)
        capture(app,"Notes last content above dock")
    }
    func testLibraryHeadersUsePresetTitleAndExpandableSearch() {
        let app = launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let landscape = XCTNSPredicateExpectation(predicate:NSPredicate { _, _ in
            app.frame.width > app.frame.height
        }, object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[landscape],timeout:10),.completed)

        reveal(app); app.buttons["tab.collections"].tap()
        let collectionTitle = app.staticTexts["collections.title"]
        let collectionSearchButton = app.buttons["collections.searchButton"]
        for element in [collectionTitle, collectionSearchButton] { waitForVisible(element) }
        XCTAssertLessThan(collectionTitle.frame.maxX, collectionSearchButton.frame.minX)
        capture(app,"Collections minimal collapsed header")
        collectionSearchButton.tap()
        let collectionSearch = app.textFields["collections.search"]
        let collectionSort = app.buttons["collections.sort"]
        let newCollection = app.buttons["collections.newCollection"]
        for element in [collectionSearch, collectionSort, newCollection] { waitForVisible(element) }
        XCTAssertFalse(app.navigationBars["Collections"].exists)
        XCTAssertLessThan(collectionTitle.frame.maxX, collectionSearch.frame.minX)
        XCTAssertLessThan(abs(collectionSearch.frame.midY - collectionSort.frame.midY), 2)
        XCTAssertLessThan(abs(collectionSort.frame.midY - newCollection.frame.midY), 2)
        XCTAssertLessThanOrEqual(collectionSearch.frame.maxX, collectionSort.frame.minX)
        XCTAssertLessThanOrEqual(collectionSort.frame.maxX, newCollection.frame.minX)
        capture(app,"Collections minimal expanded search header")
        app.buttons["Close search"].tap()
        waitForVisible(collectionSearchButton)

        reveal(app); app.buttons["tab.notes"].tap()
        let noteTitle = app.staticTexts["notes.title"]
        let noteSearchButton = app.buttons["notes.searchButton"]
        for element in [noteTitle, noteSearchButton] { waitForVisible(element) }
        XCTAssertLessThan(noteTitle.frame.maxX, noteSearchButton.frame.minX)
        capture(app,"Notes minimal collapsed header")
        noteSearchButton.tap()
        let noteSearch = app.textFields["notes.search"]
        let noteOptions = app.buttons["notes.viewOptions"]
        let backups = app.buttons["notes.backups"]
        let newNote = app.buttons["notes.new"]
        for element in [noteSearch, noteOptions, backups, newNote] { waitForVisible(element) }
        XCTAssertFalse(app.navigationBars["Notes"].exists)
        XCTAssertLessThan(noteTitle.frame.maxX, noteSearch.frame.minX)
        XCTAssertLessThan(abs(noteSearch.frame.midY - noteOptions.frame.midY), 2)
        XCTAssertLessThan(abs(noteOptions.frame.midY - backups.frame.midY), 2)
        XCTAssertLessThan(abs(backups.frame.midY - newNote.frame.midY), 2)
        XCTAssertLessThanOrEqual(noteSearch.frame.maxX, noteOptions.frame.minX)
        XCTAssertLessThanOrEqual(noteOptions.frame.maxX, backups.frame.minX)
        XCTAssertLessThanOrEqual(backups.frame.maxX, newNote.frame.minX)
        capture(app,"Notes minimal expanded search header")
        app.buttons["Close search"].tap()
        waitForVisible(noteSearchButton)
    }
    func testDarkPresetAndLandscapeDockFit() {
        let app = launch()
        reveal(app); app.buttons["tab.settings"].tap()
        let night = app.buttons["preset.midnightLibrary"]
        waitForVisible(night); night.tap()
        reveal(app); app.buttons["tab.scripture"].tap()
        waitForVisible(app.textViews["scripture.text"])
        capture(app,"Midnight Library selected tab glow")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let orientation = XCTNSPredicateExpectation(predicate:NSPredicate { _, _ in
            app.frame.width > app.frame.height
        }, object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[orientation],timeout:10),.completed)
        reveal(app)
        let tab = app.buttons["tab.settings"]
        XCTAssertLessThanOrEqual(tab.frame.maxX,app.frame.width)
        XCTAssertGreaterThan(tab.frame.minY,app.frame.height * 0.75)
        capture(app,"Landscape dock and reader")
    }
}
