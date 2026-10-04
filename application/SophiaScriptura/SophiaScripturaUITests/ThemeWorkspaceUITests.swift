import XCTest

final class ThemeWorkspaceUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launchEnvironment["SP013_FINGER_INK"] = "1"
        app.launchEnvironment["SP013_NEUTRAL_INK"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 30))
        return app
    }
    private func tab(_ name: String, _ app: XCUIApplication) {
        if !app.buttons["tab." + name].isHittable {
            let reveal = app.buttons["navigation.showTabs"]
            XCTAssertTrue(reveal.waitForExistence(timeout: 10)); reveal.tap()
        }
        app.buttons["tab." + name].tap()
    }
    private func appearance(_ value: String, _ app: XCUIApplication, choosePreset: Bool = false) {
        tab("settings", app)
        let form = app.descendants(matching: .any).matching(identifier: "settings.content").firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        if choosePreset {
            let preset = app.buttons["preset.springLeaf"]
            for _ in 0..<4 where !preset.isHittable { form.swipeUp() }
            XCTAssertTrue(preset.isHittable); preset.tap()
        }
        let picker = app.segmentedControls["settings.theme"]
        for _ in 0..<4 where !picker.isHittable { form.swipeUp() }
        XCTAssertTrue(picker.isHittable, app.debugDescription)
        picker.buttons[value].tap()
    }
    private func capture(_ app: XCUIApplication, _ name: String) -> UIImage {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        return shot.image
    }
    private func pixels(_ image: UIImage, rect: CGRect) -> [UInt8] {
        let cg = image.cgImage!
        let clipped = rect.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        let crop = cg.cropping(to: clipped)!
        var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let context = CGContext(data: &pixels, width: crop.width, height: crop.height, bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        return pixels
    }
    private func assertThemeBackground(_ app: XCUIApplication, name: String) {
        let image = capture(app, name), width = CGFloat(image.cgImage!.width), height = CGFloat(image.cgImage!.height)
        // Empty status-bar center and bottom corner must use the same green-tinted paper.
        for point in [CGPoint(x: width * 0.5, y: 8), CGPoint(x: 8, y: height - 8)] {
            let values = pixels(image, rect: CGRect(origin: point, size: CGSize(width: 2, height: 2)))
            for (channel, expected) in [32, 37, 34].enumerated() { XCTAssertEqual(Double(values[channel]), Double(expected), accuracy: 8, name) }
        }
    }
    func testSpringLeafThemeAcrossAllTabsAndScreenEdges() {
        let app = launch(); appearance("Dark", app, choosePreset: true)
        for name in ["settings", "scripture", "collections", "notes", "companion", "activity"] {
            tab(name, app); assertThemeBackground(app, name: "Spring Leaf dark — " + name)
        }
    }
    private func inkCycle(_ kind: String) {
        let app = launch(); appearance("Dark", app, choosePreset: true); tab("notes", app)
        XCTAssertTrue(app.buttons["notes.newNotes"].waitForExistence(timeout: 10))
        app.buttons["notes.newNotes"].tap()
        let choice = app.buttons["notes.new." + kind]
        if !choice.waitForExistence(timeout: 3) { app.buttons["notes.newNotes"].tap() }
        XCTAssertTrue(choice.waitForExistence(timeout: 5)); choice.tap()
        let createNote = app.buttons["notes.new.create"]
        XCTAssertTrue(createNote.waitForExistence(timeout: 5)); createNote.tap()
        let viewport = app.scrollViews["notes.viewport"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 10))
        if app.buttons["notes.scripture.toggle"].label == "Hide Scripture" { app.buttons["notes.scripture.toggle"].tap() }
        XCTAssertEqual(viewport.frame.maxY, app.frame.maxY, accuracy: 2, "Writing area must reach the bottom edge")
        viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.25)).press(forDuration: 0.1, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.45)))
        if app.buttons["notes.tools"].label == "Hide Pencil tools" { app.buttons["notes.tools"].tap() }
        for value in ["Dark", "Light", "Dark"] {
            appearance(value, app); tab("notes", app)
            XCTAssertTrue(viewport.waitForExistence(timeout: 5))
            let image = capture(app, kind + " ink cycle — " + value)
            let scale = CGFloat(image.cgImage!.width) / app.frame.width
            let rect = CGRect(x: viewport.frame.minX + viewport.frame.width * 0.25, y: viewport.frame.minY + viewport.frame.height * 0.2, width: viewport.frame.width * 0.45, height: viewport.frame.height * 0.3).applying(CGAffineTransform(scaleX: scale, y: scale))
            let rgba = pixels(image, rect: rect)
            let channels = stride(from: 0, to: rgba.count, by: 4).map { Int(rgba[$0]) }
            if value == "Dark" { XCTAssertGreaterThan(channels.max() ?? 0, 220, "Ink must be light in dark mode") }
            else { XCTAssertLessThan(channels.min() ?? 255, 50, "Ink must be dark in light mode") }
        }
    }
    func testCanvasInkDarkLightDark() { inkCycle("canvas") }
    func testPageInkDarkLightDark() { inkCycle("page") }
}
