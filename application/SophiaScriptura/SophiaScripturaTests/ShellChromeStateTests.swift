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
