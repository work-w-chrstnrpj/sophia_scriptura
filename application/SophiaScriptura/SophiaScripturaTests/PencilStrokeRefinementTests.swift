import XCTest
import PencilKit
@testable import SophiaScriptura

final class PencilStrokeRefinementTests: XCTestCase {
    func testStraightensLineLikeStrokeAndPreservesAppearance() throws {
        let stroke = makeStroke([CGPoint(x: 10, y: 20), CGPoint(x: 40, y: 27), CGPoint(x: 70, y: 17), CGPoint(x: 110, y: 20)])
        let refined = try XCTUnwrap(PencilStrokeRefinement.straightened(stroke))

        XCTAssertEqual(refined.ink.inkType, stroke.ink.inkType)
        XCTAssertEqual(refined.transform, stroke.transform)
        XCTAssertEqual(refined.path[0].location, CGPoint(x: 10, y: 20))
        XCTAssertEqual(refined.path[refined.path.count - 1].location, CGPoint(x: 110, y: 20))
        for point in refined.path { XCTAssertEqual(point.location.y, 20, accuracy: 0.001) }
    }

    func testRejectsShortAndClearlyCurvedStrokes() {
        XCTAssertNil(PencilStrokeRefinement.straightened(makeStroke([CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 2)])))
        XCTAssertNil(PencilStrokeRefinement.straightened(makeStroke([
            CGPoint(x: 0, y: 0), CGPoint(x: 20, y: 45), CGPoint(x: 50, y: 60), CGPoint(x: 80, y: 45), CGPoint(x: 100, y: 0)
        ])))
    }

    func testOnlyReplacesLastStroke() throws {
        let first = makeStroke([CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0)])
        let second = makeStroke([CGPoint(x: 10, y: 20), CGPoint(x: 60, y: 25), CGPoint(x: 110, y: 20)])
        let drawing = PKDrawing(strokes: [first, second])
        let refined = try XCTUnwrap(PencilStrokeRefinement.straighteningLastStroke(in: drawing))

        XCTAssertEqual(refined.strokes.count, 2)
        XCTAssertEqual(refined.strokes[0].path[0].location, first.path[0].location)
        for point in refined.strokes[1].path { XCTAssertEqual(point.location.y, 20, accuracy: 0.001) }
    }

    func testRecognizesEllipseAndRectangle() throws {
        let ellipse = stride(from: 0.0, through: Double.pi * 2, by: Double.pi / 12).map {
            CGPoint(x: 100 + cos($0) * 60, y: 90 + sin($0) * 35)
        }
        XCTAssertEqual(try XCTUnwrap(PencilStrokeRefinement.refined(makeStroke(ellipse))).kind, .ellipse)

        let box = [CGPoint(x: 10, y: 10), CGPoint(x: 55, y: 8), CGPoint(x: 100, y: 12),
                   CGPoint(x: 102, y: 50), CGPoint(x: 98, y: 90), CGPoint(x: 55, y: 92),
                   CGPoint(x: 9, y: 88), CGPoint(x: 7, y: 50), CGPoint(x: 10, y: 10)]
        XCTAssertEqual(try XCTUnwrap(PencilStrokeRefinement.refined(makeStroke(box))).kind, .rectangle)
    }

    func testRecognizesTriangleDiamondHexagonAndStar() throws {
        let triangle = [CGPoint(x: 50, y: 5), CGPoint(x: 95, y: 90), CGPoint(x: 5, y: 90), CGPoint(x: 50, y: 5)]
        XCTAssertEqual(try XCTUnwrap(PencilStrokeRefinement.refined(makeStroke(triangle))).kind, .polygon(3))

        let diamond = [CGPoint(x: 50, y: 5), CGPoint(x: 95, y: 50), CGPoint(x: 50, y: 95), CGPoint(x: 5, y: 50), CGPoint(x: 50, y: 5)]
        XCTAssertEqual(try XCTUnwrap(PencilStrokeRefinement.refined(makeStroke(diamond))).kind, .polygon(4))

        let hexagon = polygon(sides: 6, outer: 50, inner: 50)
        XCTAssertEqual(try XCTUnwrap(PencilStrokeRefinement.refined(makeStroke(hexagon))).kind, .polygon(6))

        let pentagon = polygon(sides: 5, outer: 50, inner: 50)
        XCTAssertEqual(try XCTUnwrap(PencilStrokeRefinement.refined(makeStroke(pentagon))).kind, .polygon(5))

        let star = polygon(sides: 10, outer: 52, inner: 22)
        XCTAssertEqual(try XCTUnwrap(PencilStrokeRefinement.refined(makeStroke(star))).kind, .star)
    }

    func testEndpointPauseIsDistinctFromAMovingStroke() {
        let moving = timedStroke([(0, CGPoint(x: 10, y: 20)), (0.1, CGPoint(x: 40, y: 22)),
                                  (0.2, CGPoint(x: 80, y: 18)), (0.3, CGPoint(x: 120, y: 20))])
        XCTAssertFalse(PencilStrokeRefinement.pausedAtEndpoint(moving))
        let paused = timedStroke([(0, CGPoint(x: 10, y: 20)), (0.15, CGPoint(x: 70, y: 24)),
                                  (0.3, CGPoint(x: 120, y: 20)), (0.9, CGPoint(x: 121, y: 20)),
                                  (1.1, CGPoint(x: 120, y: 21))])
        let samples = Array(paused.path).map { "\(String(format: "%.3f", $0.timeOffset))@(\(Int($0.location.x)),\(Int($0.location.y)))" }.joined(separator: " ")
        XCTAssertTrue(PencilStrokeRefinement.pausedAtEndpoint(paused), samples)
    }

    func testRecognizesSingleStrokeArrow() throws {
        let arrow = [CGPoint(x: 5, y: 50), CGPoint(x: 80, y: 50), CGPoint(x: 58, y: 28),
                     CGPoint(x: 80, y: 50), CGPoint(x: 58, y: 72)]
        XCTAssertEqual(try XCTUnwrap(PencilStrokeRefinement.refined(makeStroke(arrow))).kind, .arrow)
    }

    private func timedStroke(_ samples: [(TimeInterval, CGPoint)]) -> PKStroke {
        let points = samples.map { sample in
            PKStrokePoint(location: sample.1, timeOffset: sample.0,
                          size: CGSize(width: 3, height: 3), opacity: 0.8,
                          force: 0.7, azimuth: 0.2, altitude: .pi / 3)
        }
        return PKStroke(ink: PKInk(.pen, color: .systemBlue),
                        path: PKStrokePath(controlPoints: points, creationDate: .distantPast))
    }

    private func makeStroke(_ locations: [CGPoint]) -> PKStroke {
        let points = locations.enumerated().map { index, location in
            PKStrokePoint(location: location, timeOffset: Double(index) * 0.1,
                          size: CGSize(width: 3, height: 3), opacity: 0.8,
                          force: 0.7, azimuth: 0.2, altitude: .pi / 3)
        }
        return PKStroke(ink: PKInk(.pen, color: .systemBlue),
                        path: PKStrokePath(controlPoints: points, creationDate: .distantPast))
    }

    private func polygon(sides: Int, outer: CGFloat, inner: CGFloat) -> [CGPoint] {
        let points = (0..<sides).map { index -> CGPoint in
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = -.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(sides)
            return CGPoint(x: 70 + cos(angle) * radius, y: 70 + sin(angle) * radius)
        }
        return points + [points[0]]
    }
}
