import XCTest
@testable import SophiaScriptura

final class ActivitySystemProjectionTests: XCTestCase {
    func testElapsedMatchesCanonicalDraftMath() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let pauseAt = start.addingTimeInterval(120)
        var draft = ActivityDraft(
            id: UUID(), title: "Study", modeID: "reading", modeLabel: "Reading",
            startedAt: start, runningSince: nil,
            intervals: [ActivityInterval(start: start, end: pauseAt)],
            description: "", readingStart: nil, editionID: nil
        )
        let projection = ActivitySystemProjection.from(draft: draft, revision: 1)!
        XCTAssertEqual(projection.elapsed(at: pauseAt), 120, accuracy: 0.001)

        draft.runningSince = pauseAt.addingTimeInterval(300)
        let resumed = ActivitySystemProjection.from(draft: draft, revision: 2)!
        let at = pauseAt.addingTimeInterval(360)
        XCTAssertEqual(resumed.elapsed(at: at), 180, accuracy: 0.001)
    }

    func testNilDraftProducesNilProjection() {
        XCTAssertNil(ActivitySystemProjection.from(draft: nil, revision: 1))
    }
}
