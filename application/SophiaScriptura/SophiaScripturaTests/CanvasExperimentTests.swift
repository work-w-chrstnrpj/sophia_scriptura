import XCTest
import PencilKit
@testable import SophiaScriptura

@MainActor
final class CanvasExperimentTests: XCTestCase {
    func testIndependentMoveDoesNotMoveOrRewriteInk() {
        let before = CanvasSample.make()
        var moved = before
        moved.move([.text], by: CGSize(width: 50, height: 30))
        XCTAssertEqual(moved.object(.text).frame.origin.x, before.object(.text).frame.origin.x + 50)
        XCTAssertEqual(moved.object(.ink), before.object(.ink))
        XCTAssertEqual(moved.drawing, before.drawing)
        XCTAssertEqual(moved.assets, before.assets)
    }

    func testGroupingExpandsSelectionAndPreservesRelativeOffsetsAtBoundary() {
        var document = CanvasSample.make()
        document.group([.text, .ink])
        XCTAssertEqual(document.members(of: [.text]), [.text, .ink])
        let before = document
        document.move([.text], by: CGSize(width: -500, height: 40))
        // Ink starts at x=0, so the entire selection is clamped together horizontally.
        XCTAssertEqual(document.object(.text).frame.minX, before.object(.text).frame.minX)
        XCTAssertEqual(document.object(.ink).frame.minX, before.object(.ink).frame.minX)
        for id in [CanvasFixture.ObjectID.text, .ink] {
            XCTAssertEqual(document.object(id).frame.minY, before.object(id).frame.minY + 40)
        }
        let grouped = document
        document.ungroup([.ink])
        XCTAssertNil(document.object(.text).group)
        XCTAssertNil(document.object(.ink).group)
        XCTAssertEqual(document.object(.ink).frame, grouped.object(.ink).frame)
        XCTAssertEqual(document.drawing, grouped.drawing)
    }

    func testScreenMovementUsesZoomOnce() {
        for zoom: CGFloat in [0.5, 1, 2] {
            var document = CanvasSample.make()
            let screen = CGSize(width: 40 * zoom, height: 30 * zoom)
            document.move([.text], by: CanvasFixture.documentDelta(screen: screen, zoom: zoom))
            XCTAssertEqual(document.object(.text).frame.origin, CGPoint(x: 110, y: 130))
        }
        XCTAssertEqual(CanvasFixture.documentDelta(screen: CGSize(width: 4, height: 6), zoom: 0), .zero)
    }

    func testExpansionDoesNotRepositionOtherContent() {
        var document = CanvasSample.make()
        let text = document.object(.text)
        document.move([.image], by: CGSize(width: 1_000, height: 1_000))
        XCTAssertGreaterThan(document.contentSize.width, 1_400)
        XCTAssertGreaterThan(document.contentSize.height, 1_000)
        XCTAssertEqual(document.object(.text), text)
    }

    func testUndoRedoRestoresGroupingAndGeometryTogether() {
        var history = CanvasHistory()
        let initial = CanvasSample.make()
        var grouped = initial
        grouped.group([.text, .ink])
        history.record(initial)
        var moved = grouped
        moved.move([.text], by: CGSize(width: 80, height: 20))
        history.record(grouped)
        XCTAssertEqual(history.undo(moved), grouped)
        XCTAssertEqual(history.undo(grouped), initial)
        XCTAssertEqual(history.redo(initial), grouped)
        history.record(grouped)
        XCTAssertNil(history.redo(grouped))
    }

    func testValidationRejectsDuplicateObjectsAndNonfiniteGeometry() {
        var fixture = CanvasSample.make()
        fixture.objects[1].id = .text
        XCTAssertThrowsError(try fixture.validated())
        fixture = CanvasSample.make()
        fixture.objects[0].frame.origin.x = .infinity
        XCTAssertThrowsError(try fixture.validated())
    }

    func testValidationRejectsDamagedAssetsAndFutureVersion() {
        var fixture = CanvasSample.make()
        fixture.drawing = Data("invalid drawing".utf8)
        XCTAssertThrowsError(try fixture.validated())
        fixture = CanvasSample.make()
        fixture.assets[fixture.imageAssetID] = Data("invalid image".utf8)
        XCTAssertThrowsError(try fixture.validated())
        fixture = CanvasSample.make()
        fixture.schemaVersion = 99
        XCTAssertThrowsError(try fixture.validated())
    }

    func testFixtureRoundTripPreservesActualInkImageTextAndGroups() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CanvasFixtureStore(url: directory.appendingPathComponent("sample.json"))
        var fixture = CanvasSample.make()
        fixture.group([.ink, .text])
        fixture.move([.ink], by: CGSize(width: 31, height: 77))
        fixture.text = "Edited observation\nwith a second line."
        try await store.save(fixture)
        let reopened = try await store.load()
        XCTAssertEqual(reopened, fixture)
        XCTAssertEqual(try PKDrawing(data: XCTUnwrap(reopened).drawing).strokes.count, 1)
    }

    func testDamagedRestoreLeavesExistingFileByteForByteUnchanged() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("sample.json")
        let store = CanvasFixtureStore(url: url)
        let fixture = CanvasSample.make()
        try await store.save(fixture)
        let originalBytes = try Data(contentsOf: url)
        do {
            _ = try await store.restore(Data("{bad json".utf8))
            XCTFail("Corrupt fixture accepted")
        } catch { }
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)
        var future = fixture
        future.schemaVersion = 90
        do {
            _ = try await store.restore(JSONEncoder().encode(future))
            XCTFail("Future fixture accepted")
        } catch { }
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)
    }

    func testLateAutosaveCannotReplaceNewerRevision() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CanvasFixtureStore(url: directory.appendingPathComponent("sample.json"))
        let old = CanvasSample.make()
        var newer = old
        newer.text = "Newer saved revision"
        try await store.save(newer, revision: 2)
        try await store.save(old, revision: 1)
        let reopened = try await store.load()
        XCTAssertEqual(reopened, newer)
    }

    func testCorruptExistingFixtureIsNotSilentlyReplacedOnOpen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("sample.json")
        let badBytes = Data("{broken".utf8)
        try badBytes.write(to: url)
        let session = CanvasExperimentSession(store: CanvasFixtureStore(url: url))
        await session.open()
        XCTAssertNil(session.document)
        XCTAssertNotNil(session.loadError)
        XCTAssertEqual(try Data(contentsOf: url), badBytes)
    }

    func testSessionSaveReopenKeepsEditsAndClearsHistory() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = CanvasExperimentSession(store: CanvasFixtureStore(url: directory.appendingPathComponent("sample.json")))
        await session.open()
        session.selection = [.text, .ink]
        session.group()
        session.nudge(CGSize(width: 40, height: 50))
        session.updateText("A saved observation")
        let before = session.document
        await session.saveAndReopen()
        XCTAssertEqual(session.document, before)
        XCTAssertFalse(session.canUndo)
        XCTAssertEqual(session.document?.text, "A saved observation")
    }

    func testDelayedPencilUpdateRefinesSingleUndoTransaction() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = CanvasExperimentSession(store: CanvasFixtureStore(url: directory.appendingPathComponent("sample.json")))
        await session.open()
        let initial = try XCTUnwrap(session.document)
        let original = try PKDrawing(data: initial.drawing)
        let first = original.transformed(using: CGAffineTransform(translationX: 5, y: 0)).dataRepresentation()
        let final = original.transformed(using: CGAffineTransform(translationX: 10, y: 0)).dataRepresentation()
        session.updateInk(first, newTransaction: true)
        session.updateInk(final, newTransaction: false)
        session.undo()
        XCTAssertEqual(session.document, initial)
        XCTAssertFalse(session.canUndo)
        await session.saveAndReopen()
    }
}
