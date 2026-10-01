#if DEBUG
import XCTest
import PencilKit
@testable import SophiaScriptura

@MainActor
final class InkValidationTests: XCTestCase {
    private func stroke() -> PKDrawing {
        let points = [CGPoint(x: 42, y: 58), CGPoint(x: 142, y: 58)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 2, height: 2),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))])
    }
    func testSaveReopenKeepsIndependentLayersAndReturnsToVisible() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = InkValidationSession(url: dir.appendingPathComponent("ink.json"))
        session.signature = "layout-a"; session.drawings[0] = stroke(); session.save()
        session.drawings = [PKDrawing(), stroke()]; session.mode = .draw
        session.reopen()
        XCTAssertEqual(session.drawings[0].strokes.count, 1)
        XCTAssertEqual(session.drawings[0].strokes[0].path[0].location, CGPoint(x: 42, y: 58))
        XCTAssertTrue(session.drawings[1].strokes.isEmpty)
        XCTAssertEqual(session.mode, .visible)
    }
    func testMismatchRetainsInkAndSuppressesBackground() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = InkValidationSession(url: dir.appendingPathComponent("ink.json"))
        session.signature = "old-layout"; session.drawings[0] = stroke(); session.save()
        session.signature = "new-layout"; session.reopen()
        XCTAssertTrue(session.layoutMismatch)
        XCTAssertEqual(session.drawings[0].strokes.count, 1)
        session.save()
        let saved = try JSONDecoder().decode(InkValidationSession.Snapshot.self, from: Data(contentsOf: session.url))
        XCTAssertEqual(saved.signature, "old-layout", "Do not bless old ink as the new layout")
    }
    func testCorruptReopenDoesNotReplaceInkOrFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let bytes = Data("invalid".utf8); try bytes.write(to: url)
        let session = InkValidationSession(url: url); session.drawings[0] = stroke(); session.reopen()
        XCTAssertEqual(session.drawings[0].strokes.count, 1)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
    func testViewportResizePreservesTextFramesAndStrokeCoordinates() async throws {
        let document = try await BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self))
            .chapter(book: "JHN", number: 3)
        let session = InkValidationSession(); session.drawings[0] = stroke()
        let controller = InkValidationController(session: session, document: document)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 820, height: 1000)
        controller.viewDidLayoutSubviews()
        let scroll = try XCTUnwrap(controller.view.subviews.first as? UIScrollView)
        let paper = try XCTUnwrap(scroll.subviews.first)
        let text = try XCTUnwrap(paper.viewWithTag(8) as? UITextView)
        let frame = text.frame
        let signature = session.signature
        let bytes = session.drawings[0].dataRepresentation()
        scroll.zoomScale = 1.4
        controller.view.frame = CGRect(x: 0, y: 0, width: 400, height: 700)
        controller.viewDidLayoutSubviews()
        session.rules = false; controller.apply()
        XCTAssertEqual(text.frame, frame)
        XCTAssertEqual(session.signature, signature)
        XCTAssertEqual(session.drawings[0].dataRepresentation(), bytes)
        session.mode = .draw; controller.apply()
        let canvas = try XCTUnwrap(paper.subviews.compactMap { $0 as? PKCanvasView }.first)
        XCTAssertTrue(canvas.isUserInteractionEnabled)
        session.unavailable = true; controller.apply()
        XCTAssertTrue(text.isHidden)
        XCTAssertTrue(canvas.isHidden)
        XCTAssertFalse(canvas.isUserInteractionEnabled)
    }
    func testSaveAndReopenAreBlockedDuringStroke() {
        let session = InkValidationSession(url: URL(fileURLWithPath: "/nonexistent/sp008-test"))
        session.usingTool = true
        let notice = session.notice
        session.save(); session.reopen()
        XCTAssertEqual(session.notice, notice)
        XCTAssertEqual(session.generation, 0)
    }
}
#endif
