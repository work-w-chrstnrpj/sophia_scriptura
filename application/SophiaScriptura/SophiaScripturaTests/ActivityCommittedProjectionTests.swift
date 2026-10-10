import XCTest
@testable import SophiaScriptura

@MainActor
final class ActivityCommittedProjectionTests: XCTestCase {
    func testCommittedProjectionUpdatesAfterSuccessfulSave() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActivityStore(repository: ActivityFileRepository(directory: directory))
        await store.load()
        XCTAssertNil(store.committedProjection)
        store.start(mode: ActivityMode(id: ActivityModeID.reading.id, name: "Reading", isBuiltIn: true), title: "Morning")
        await store.flush()
        XCTAssertNotNil(store.committedProjection)
        XCTAssertEqual(store.committedProjection?.draftID, store.draft?.id)
        XCTAssertTrue(store.committedRevision > 0)
    }
}
