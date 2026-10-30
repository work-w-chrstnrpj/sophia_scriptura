import XCTest
import UIKit
import PencilKit
@testable import SophiaScriptura

@MainActor final class PrayerLayoutTests: XCTestCase {
    private func find(_ identifier: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == identifier { return view }
        for child in view.subviews { if let found = find(identifier, in: child) { return found } }
        return nil
    }
    private func drawing() -> PKDrawing {
        let points = [CGPoint(x: 300, y: 1800), CGPoint(x: 850, y: 1840)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))])
    }
    private func fixture(_ directory: URL, text: String, ink: Data = Data()) async throws -> NotesSession {
        let session = NotesSession(repository: NotesFileRepository(directory: directory)); await session.load()
        XCTAssertNotNil(session.create(kind: .prayer, title: "Layout fixture"))
        session.edit { $0.page?.body = text; $0.page?.ink = ink }
        await session.save()
        return session
    }
    func testPreviewNativeTextHasBalancedInsetsAcrossPortraitLandscapeAndNarrowWidths() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let text = "Prayer beginning.\n" + String(repeating: "A complete line remains inside the writing area and can be read without horizontal clipping.\n", count: 24) + "Prayer ending."
        let session = try await fixture(directory, text: text)
        let controller = NotePageController(session: session, openCitation: { _ in })
        controller.prayerPreviewFitsContent = true
        controller.loadViewIfNeeded(); defer { controller.close() }
        for width: CGFloat in [528, 1124, 320, 744, 528] {
            controller.view.frame = CGRect(x: 0, y: 0, width: width, height: 500)
            controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
            let textView = try XCTUnwrap(find("notes.body", in: controller.view) as? UITextView)
            let scroll = try XCTUnwrap(find("notes.viewport", in: controller.view) as? UIScrollView)
            let textFrame = textView.convert(textView.bounds, to: controller.view)
            let left = textFrame.minX, right = width - textFrame.maxX
            XCTAssertGreaterThan(left, 16); XCTAssertEqual(left, right, accuracy: 1)
            XCTAssertEqual(textFrame.minY, left, accuracy: 1, "Top and side text insets must be balanced")
            XCTAssertEqual(textView.text, text)
            let glyphs = textView.layoutManager.glyphRange(forCharacterRange: NSRange(location: text.utf16.count - 14, length: 14), actualCharacterRange: nil)
            let end = textView.layoutManager.boundingRect(forGlyphRange: glyphs, in: textView.textContainer)
            let lastLineInPaper = textView.convert(end, to: textView.superview!)
            let visibleEnd = lastLineInPaper.maxY * scroll.zoomScale
            XCTAssertLessThanOrEqual(visibleEnd, scroll.contentSize.height - 8, "Last line must be reachable")
        }
        XCTAssertEqual(session.note?.page?.body, text)
    }
    func testLongPreviewCanScrollToLastLineAndRotatesWithoutLosingItsAnchor() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let text = String(repeating: "A long prayer paragraph with words to wrap safely across the fixed writing column.\n", count: 50) + "END MARKER"
        let session = try await fixture(directory, text: text)
        let controller = NotePageController(session: session, openCitation: { _ in }); controller.prayerPreviewFitsContent = true
        controller.loadViewIfNeeded(); defer { controller.close() }
        for width: CGFloat in [528, 1124] {
            controller.view.frame = CGRect(x: 0, y: 0, width: width, height: 420)
            controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
            let scroll = try XCTUnwrap(find("notes.viewport", in: controller.view) as? UIScrollView)
            let textView = try XCTUnwrap(find("notes.body", in: controller.view) as? UITextView)
            scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: scroll.contentSize.height - scroll.bounds.height), animated: false)
            let glyphs = textView.layoutManager.glyphRange(forCharacterRange: NSRange(location: text.utf16.count - 10, length: 10), actualCharacterRange: nil)
            let rect = textView.convert(textView.layoutManager.boundingRect(forGlyphRange: glyphs, in: textView.textContainer), to: controller.view)
            XCTAssertGreaterThanOrEqual(rect.minY, 0); XCTAssertLessThanOrEqual(rect.maxY, 420)
            XCTAssertGreaterThan(rect.minX, 0); XCTAssertLessThan(rect.maxX, width)
        }
    }
    func testGuidesMatchPreviewSafeRegionAndInkBytesSurviveMaximizeRotationMinimize() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let ink = drawing().dataRepresentation()
        let session = try await fixture(directory, text: "Keep text and annotations.", ink: ink)
        let controller = NotePageController(session: session, openCitation: { _ in }); controller.showsPrayerBoundaries = true
        controller.loadViewIfNeeded(); defer { controller.close() }
        for preview in [false, true, false, true] {
            controller.prayerPreviewFitsContent = preview; controller.apply()
            for size in [CGSize(width: 820, height: 900), CGSize(width: 1180, height: 650)] {
                controller.view.frame = CGRect(origin: .zero, size: size); controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
                let guide = try XCTUnwrap(find("notes.prayer.boundaries", in: controller.view))
                XCTAssertEqual(guide.isHidden, preview)
                if preview {
                    let rect = guide.convert(guide.bounds, to: controller.view)
                    XCTAssertEqual(rect.minX, 16, accuracy: 1); XCTAssertEqual(size.width - rect.maxX, 16, accuracy: 1)
                } else {
                    let scroll = try XCTUnwrap(find("notes.viewport", in: controller.view) as? UIScrollView)
                    XCTAssertEqual(scroll.contentInset.top, 0)
                }
                XCTAssertEqual(session.note?.page?.ink, ink)
            }
        }
        let bottom = NotePageTypography.prayerBoardContentHeight(for: try XCTUnwrap(session.note?.page), includesInkPadding: true)
        XCTAssertGreaterThan(bottom, drawing().bounds.maxY)
        await session.save()
        let reopened = NotesSession(repository: NotesFileRepository(directory: directory)); await reopened.load()
        XCTAssertEqual(reopened.snapshot.notes.first?.page?.ink, ink)
    }
}
