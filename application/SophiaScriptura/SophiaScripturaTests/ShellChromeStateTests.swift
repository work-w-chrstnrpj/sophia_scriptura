import XCTest
@testable import SophiaScriptura

@MainActor
final class ShellChromeStateTests: XCTestCase {
    func testDefaultVisibilityDelayIsThreeSeconds() {
        XCTAssertEqual(ShellChromeState.visibilityDelay, .seconds(3))
    }

    func testNewActivityExtendsDeadlineAndRepeatedRevealsStillExpire() async throws {
        let chrome = ShellChromeState(delay: .milliseconds(250))
        chrome.reveal()
        try await Task.sleep(for: .milliseconds(80))
        chrome.reveal()
        try await Task.sleep(for: .milliseconds(190))
        XCTAssertTrue(chrome.isVisible, "The original deadline must not hide newly revealed navigation")
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertFalse(chrome.isVisible)
        chrome.reveal()
        XCTAssertTrue(chrome.isVisible)
        chrome.stop()
    }
    func testHideImmediatelyDismissesVisibleDock() {
        let chrome = ShellChromeState()
        chrome.reveal()
        XCTAssertTrue(chrome.isVisible)
        chrome.hideImmediately()
        XCTAssertFalse(chrome.isVisible)
    }

    func testShellTabActionPreferencePersists() {
        let key = "shell.showTabActionButtons"
        let defaults = UserDefaults.standard
        let prior = defaults.object(forKey: key) as? Bool
        defer {
            if let prior { defaults.set(prior, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
        ShellPreferencesStore.save(ShellPreferences(showTabActionButtons: false))
        XCTAssertFalse(ShellPreferencesStore.load().showTabActionButtons)
        let session = ShellPreferencesSession()
        session.load()
        XCTAssertFalse(session.preferences.showTabActionButtons)
        session.setShowTabActionButtons(true)
        XCTAssertTrue(ShellPreferencesStore.load().showTabActionButtons)
    }

    func testStoppingBackgroundTimerPreventsStaleHideAfterResume() async throws {
        let chrome = ShellChromeState(delay: .milliseconds(100))
        chrome.reveal(); chrome.stop()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(chrome.isVisible)
        chrome.reveal()
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertFalse(chrome.isVisible, "A new active timer must run after cancellation")
    }
}
