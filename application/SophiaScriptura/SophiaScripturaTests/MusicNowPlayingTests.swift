import XCTest
@testable import SophiaScriptura

@MainActor
final class MusicNowPlayingTests: XCTestCase {
    func testRemoteHandlerDispatchesPlayCommand() {
        final class Handler: MusicNowPlayingCommandHandling {
            var received: MusicCommand?
            func handleNowPlayingCommand(_ command: MusicCommand) { received = command }
        }
        let handler = Handler()
        handler.handleNowPlayingCommand(.pause)
        XCTAssertEqual(handler.received, .pause)
    }
}
