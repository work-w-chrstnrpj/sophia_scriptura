import XCTest
@testable import SophiaScriptura

final class SystemControlsRoutingTests: XCTestCase {
    func testValidActivityDeepLinkOpensTab() {
        var opened = false
        let handled = SystemControlsRouting.openActivityTab(from: StudyActivityDeepLink.activityURL) { opened = true }
        XCTAssertTrue(handled)
        XCTAssertTrue(opened)
    }

    func testUnknownURLIsRejected() {
        var opened = false
        let handled = SystemControlsRouting.openActivityTab(from: URL(string: "https://example.com")!) { opened = true }
        XCTAssertFalse(handled)
        XCTAssertFalse(opened)
    }
}
