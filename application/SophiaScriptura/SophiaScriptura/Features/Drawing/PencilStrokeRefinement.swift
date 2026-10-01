import UIKit
import PencilKit

/// Shared production drawing behavior for Notes and Scripture annotations.
/// Persistence remains an ordinary `PKDrawing`; this type only refines the last
/// completed Pencil stroke when the owner deliberately pauses at its endpoint.
@MainActor final class PencilStrokeRefiner: NSObject, UIGestureRecognizerDelegate {
    private weak var canvas: PKCanvasView?
    private let hold = PencilEndpointHoldGestureRecognizer()
    private var strokeCount = 0
    private var held = false
    private(set) var lastKind: PencilStrokeRefinement.Kind?
    private(set) var lastDwell: TimeInterval = 0

    #if DEBUG
    static var simulatesPencil: Bool { ProcessInfo.processInfo.environment["SP014_SIMULATED_PENCIL"] == "1" }
    #else
    static var simulatesPencil: Bool { false }
    #endif

    init(canvas: PKCanvasView) {
        self.canvas = canvas
        super.init()
        hold.cancelsTouchesInView = false
        hold.delegate = self
        hold.onHold = { [weak self] in self?.held = true }
        canvas.addGestureRecognizer(hold)
    }

    /// Notes delivers Pencil through a recognizer on the editor, because the ink
    /// canvas declines hits. Annotations keep the recognizer on the canvas.
    func trackHold(on view: UIView) {
        guard hold.view !== view else { return }
        hold.view?.removeGestureRecognizer(hold)
        view.addGestureRecognizer(hold)
    }

    func beginStroke() {
        strokeCount = canvas?.drawing.strokes.count ?? 0
        held = false
        lastKind = nil
    }

    /// Returns the refined drawing, or `nil` when the gesture or geometry did not
    /// express a deliberate line. Callers own undo and persistence transactions.
    func finishStroke() -> PKDrawing? {
        lastKind = nil
        lastDwell = 0
        guard let drawing = canvas?.drawing, drawing.strokes.count == strokeCount + 1 else { return nil }
        let stroke = drawing.strokes[drawing.strokes.count - 1]
        lastDwell = PencilStrokeRefinement.endpointDwell(stroke)
        guard held || lastDwell >= 0.45,
              let refined = PencilStrokeRefinement.refined(stroke) else { return nil }
        lastKind = refined.kind
        var strokes = drawing.strokes
        strokes[strokes.count - 1] = refined.stroke
        return PKDrawing(strokes: strokes)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
}

@MainActor private final class PencilEndpointHoldGestureRecognizer: UIGestureRecognizer {
    var onHold: (() -> Void)?
    private let delay: TimeInterval = 0.5
    private let tolerance: CGFloat = 10
    private var anchor = CGPoint.zero
    private var work: DispatchWorkItem?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first else { state = .failed; return }
        let simulatedFinger = PencilStrokeRefiner.simulatesPencil && touch.type == .direct
        guard touch.type == .stylus || simulatedFinger else { state = .failed; return }
        anchor = touch.location(in: view)
        schedule()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: view)
        if hypot(point.x - anchor.x, point.y - anchor.y) > tolerance {
            anchor = point
            if state == .possible { schedule() }
            else if state == .began || state == .changed { state = .changed }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        work?.cancel()
        state = state == .began || state == .changed ? .ended : .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        work?.cancel(); state = .cancelled
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func reset() { work?.cancel(); work = nil; anchor = .zero }

    private func schedule() {
        work?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.state == .possible else { return }
            self.onHold?()
            self.state = .began
        }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}

enum PencilStrokeRefinement {
    enum Kind: Hashable {
        case line, arrow, ellipse, rectangle, polygon(Int), star
        var label: String {
            switch self {
            case .line: "line"
            case .arrow: "arrow"
            case .ellipse: "ellipse"
            case .rectangle: "rectangle"
            case .polygon(let sides): "polygon \(sides)"
            case .star: "star"
            }
        }
    }

    /// A pause at the finished stroke's endpoint. PencilKit often cancels a parallel
    /// hold gesture, so the stroke's own sample times are the durable signal.
    static func endpointDwell(_ stroke: PKStroke) -> TimeInterval {
        let points = Array(stroke.path)
        guard let end = points.last else { return 0 }
        var earliest = end.timeOffset
        for point in points.reversed() {
            guard hypot(point.location.x - end.location.x, point.location.y - end.location.y) <= 14 else { break }
            earliest = point.timeOffset
        }
        return max(0, end.timeOffset - earliest)
    }

    static func pausedAtEndpoint(_ stroke: PKStroke) -> Bool { endpointDwell(stroke) >= 0.45 }

    static func straighteningLastStroke(in drawing: PKDrawing) -> PKDrawing? {
        guard let stroke = drawing.strokes.last,
              let replacement = refined(stroke)?.stroke else { return nil }
        var strokes = drawing.strokes
        strokes[strokes.count - 1] = replacement
        return PKDrawing(strokes: strokes)
    }

    static func straightened(_ stroke: PKStroke) -> PKStroke? { refined(stroke, allowed: [.line])?.stroke }

    static func refined(_ stroke: PKStroke) -> (kind: Kind, stroke: PKStroke)? {
        refined(stroke, allowed: nil)
    }

    private static func refined(_ stroke: PKStroke, allowed: Set<Kind>?) -> (kind: Kind, stroke: PKStroke)? {
        let source = Array(stroke.path)
        guard source.count >= 2 else { return nil }
        let rendered = source.map { $0.location.applying(stroke.transform) }
        guard let start = rendered.first, let end = rendered.last,
              let inverse = stroke.transform.invertedIfPossible else { return nil }
        let bounds = rendered.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
        let diagonal = hypot(bounds.width, bounds.height)
        guard diagonal >= 24 else { return nil }

        let closed = hypot(end.x - start.x, end.y - start.y) <= max(18, diagonal * 0.22)
        let result: (Kind, [CGPoint])?
        if closed {
            result = closedShape(rendered, bounds: bounds)
        } else if let arrow = arrow(rendered) {
            result = (.arrow, arrow)
        } else if let line = line(rendered) {
            result = (.line, line)
        } else {
            result = nil
        }
        guard let (kind, output) = result, allowed == nil || allowed!.contains(kind) else { return nil }
        let local = output.map { $0.applying(inverse) }
        return (kind, replacementStroke(from: stroke, source: source, locations: local))
    }

    private static func line(_ points: [CGPoint]) -> [CGPoint]? {
        guard let start = points.first, let end = points.last else { return nil }
        let chord = hypot(end.x - start.x, end.y - start.y)
        guard chord >= 24 else { return nil }

        var length: CGFloat = 0
        for index in 1..<points.count {
            length += hypot(points[index].x - points[index - 1].x,
                            points[index].y - points[index - 1].y)
        }
        let allowedDeviation = max(12, chord * 0.14)
        let maximumDeviation = points.map { distance($0, fromLineStart: start, end: end) }.max() ?? .infinity
        guard length <= chord * 1.45, maximumDeviation <= allowedDeviation else { return nil }
        return evenlySpacedLine(from: start, to: end, count: max(4, min(12, points.count)))
    }

    private static func closedShape(_ points: [CGPoint], bounds: CGRect) -> (Kind, [CGPoint])? {
        guard bounds.width >= 20, bounds.height >= 20 else { return nil }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radii = points.map { point in
            hypot((point.x - center.x) / (bounds.width / 2), (point.y - center.y) / (bounds.height / 2))
        }
        let radialError = radii.map { abs($0 - 1) }.reduce(0, +) / CGFloat(radii.count)
        if points.count >= 10, radialError <= 0.15 {
            return (.ellipse, ellipse(in: bounds, startingNear: points[0], clockwise: signedArea(points) >= 0))
        }

        if let star = star(points, bounds: bounds) { return (.star, star) }

        let edgeTolerance = max(9, min(bounds.width, bounds.height) * 0.16)
        let edgeDistances = points.map { point in
            min(min(abs(point.x - bounds.minX), abs(point.x - bounds.maxX)),
                min(abs(point.y - bounds.minY), abs(point.y - bounds.maxY)))
        }
        let cornerCoverage = [
            CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.maxY), CGPoint(x: bounds.minX, y: bounds.maxY)
        ].allSatisfy { corner in
            points.contains { distance($0, to: corner) <= edgeTolerance * 1.25 }
        }
        let averageEdgeDistance = edgeDistances.reduce(0, +) / CGFloat(edgeDistances.count)
        if cornerCoverage, averageEdgeDistance <= max(4, min(bounds.width, bounds.height) * 0.06) {
            return (.rectangle, orientedRectangle(bounds, startingNear: points[0], clockwise: signedArea(points) >= 0))
        }
        let corners = polygonCorners(points)
        if (3...6).contains(corners.count) {
            return (.polygon(corners.count), close(corners, startingNear: points[0], clockwise: signedArea(points) >= 0))
        }
        return nil
    }

    private static func arrow(_ points: [CGPoint]) -> [CGPoint]? {
        guard let tail = points.first else { return nil }
        let indexed = points.enumerated().map { ($0.offset, hypot($0.element.x - tail.x, $0.element.y - tail.y)) }
        guard let farthest = indexed.max(by: { $0.1 < $1.1 }), farthest.1 >= 36,
              farthest.0 > 0, farthest.0 < points.count - 2 else { return nil }
        let tip = points[farthest.0]
        let after = points[(farthest.0 + 1)...]
        guard after.contains(where: { hypot($0.x - tip.x, $0.y - tip.y) <= max(14, farthest.1 * 0.18) }) else { return nil }
        let angle = atan2(tip.y - tail.y, tip.x - tail.x)
        let head = min(48, farthest.1 * 0.32)
        let left = CGPoint(x: tip.x - cos(angle - .pi / 6) * head, y: tip.y - sin(angle - .pi / 6) * head)
        let right = CGPoint(x: tip.x - cos(angle + .pi / 6) * head, y: tip.y - sin(angle + .pi / 6) * head)
        return evenlySpacedLine(from: tail, to: tip, count: 8) + [left, tip, right]
    }

    private static func star(_ points: [CGPoint], bounds: CGRect) -> [CGPoint]? {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radial = points.map { hypot($0.x - center.x, $0.y - center.y) }
        guard let minimum = radial.min(), let maximum = radial.max(), minimum < maximum * 0.62 else { return nil }
        let signs = points.indices.dropFirst().dropLast().compactMap { index -> Int? in
            let a = points[index - 1], b = points[index], c = points[index + 1]
            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            return abs(cross) < 1 ? nil : (cross > 0 ? 1 : -1)
        }
        let changes = zip(signs, signs.dropFirst()).filter { $0 != $1 }.count
        guard (6...14).contains(changes) else { return nil }
        let firstAngle = atan2(points[0].y - center.y, points[0].x - center.x)
        let clockwise = signedArea(points) >= 0
        let result = (0..<10).map { index -> CGPoint in
            let radius: CGFloat = index.isMultiple(of: 2) ? 1 : 0.44
            let direction: CGFloat = clockwise ? 1 : -1
            let angle = firstAngle + direction * CGFloat(index) * .pi / 5
            return CGPoint(x: center.x + cos(angle) * bounds.width / 2 * radius,
                           y: center.y + sin(angle) * bounds.height / 2 * radius)
        }
        return close(result, startingNear: points[0], clockwise: clockwise)
    }

    private static func polygonCorners(_ points: [CGPoint], toleranceScale: CGFloat = 0.065) -> [CGPoint] {
        var corners = convexHull(Array(points.dropLast()))
        guard corners.count > 2 else { return corners }
        let bounds = corners.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
        let tolerance = max(6, hypot(bounds.width, bounds.height) * toleranceScale)
        var changed = true
        while changed, corners.count > 3 {
            changed = false
            for index in corners.indices {
                let previous = corners[(index - 1 + corners.count) % corners.count]
                let next = corners[(index + 1) % corners.count]
                if distance(corners[index], fromLineStart: previous, end: next) <= tolerance {
                    corners.remove(at: index); changed = true; break
                }
            }
        }
        return corners
    }

    private static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        guard sorted.count > 2 else { return sorted }
        func cross(_ origin: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - origin.x) * (b.y - origin.y) - (a.y - origin.y) * (b.x - origin.x)
        }
        var lower: [CGPoint] = []
        for point in sorted {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 { lower.removeLast() }
            lower.append(point)
        }
        var upper: [CGPoint] = []
        for point in sorted.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 { upper.removeLast() }
            upper.append(point)
        }
        return Array(lower.dropLast()) + Array(upper.dropLast())
    }

    private static func orientedRectangle(_ bounds: CGRect, startingNear start: CGPoint, clockwise: Bool) -> [CGPoint] {
        close([CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY),
               CGPoint(x: bounds.maxX, y: bounds.maxY), CGPoint(x: bounds.minX, y: bounds.maxY)],
              startingNear: start, clockwise: clockwise)
    }

    private static func ellipse(in bounds: CGRect, startingNear start: CGPoint, clockwise: Bool) -> [CGPoint] {
        let initial = atan2((start.y - bounds.midY) / (bounds.height / 2), (start.x - bounds.midX) / (bounds.width / 2))
        let direction: CGFloat = clockwise ? 1 : -1
        return (0...40).map { index in
            let angle = initial + direction * 2 * .pi * CGFloat(index) / 40
            return CGPoint(x: bounds.midX + cos(angle) * bounds.width / 2,
                           y: bounds.midY + sin(angle) * bounds.height / 2)
        }
    }

    private static func close(_ vertices: [CGPoint], startingNear start: CGPoint, clockwise: Bool) -> [CGPoint] {
        guard !vertices.isEmpty else { return [] }
        let hasClockwiseOrder = signedArea(vertices) >= 0
        var ordered: [CGPoint] = hasClockwiseOrder == clockwise ? vertices : Array(vertices.reversed())
        let first = ordered.indices.min { distance(ordered[$0], to: start) < distance(ordered[$1], to: start) } ?? 0
        ordered = Array(ordered[first...]) + Array(ordered[..<first])
        var output: [CGPoint] = []
        for vertex in ordered { output.append(contentsOf: [vertex, vertex, vertex]) }
        if let first = ordered.first { output.append(contentsOf: [first, first, first]) }
        return output
    }

    private static func replacementStroke(from stroke: PKStroke, source: [PKStrokePoint], locations: [CGPoint]) -> PKStroke {
        let first = source[0], last = source[source.count - 1]
        let points = locations.enumerated().map { index, location -> PKStrokePoint in
            let fraction = locations.count == 1 ? 0 : CGFloat(index) / CGFloat(locations.count - 1)
            return styledPoint(location: location, fraction: fraction, first: first, last: last)
        }
        let path = PKStrokePath(controlPoints: points, creationDate: stroke.path.creationDate)
        return PKStroke(ink: stroke.ink, path: path, transform: stroke.transform,
                        mask: stroke.mask, randomSeed: stroke.randomSeed)
    }

    private static func styledPoint(location: CGPoint, fraction: CGFloat,
                                    first: PKStrokePoint, last: PKStrokePoint) -> PKStrokePoint {
        PKStrokePoint(
            location: location,
            timeOffset: first.timeOffset + (last.timeOffset - first.timeOffset) * Double(fraction),
            size: CGSize(width: first.size.width + (last.size.width - first.size.width) * fraction,
                         height: first.size.height + (last.size.height - first.size.height) * fraction),
            opacity: first.opacity + (last.opacity - first.opacity) * fraction,
            force: first.force + (last.force - first.force) * fraction,
            azimuth: first.azimuth + (last.azimuth - first.azimuth) * fraction,
            altitude: first.altitude + (last.altitude - first.altitude) * fraction
        )
    }

    private static func evenlySpacedLine(from start: CGPoint, to end: CGPoint, count: Int) -> [CGPoint] {
        (0..<count).map { index in
            let fraction = CGFloat(index) / CGFloat(count - 1)
            return CGPoint(x: start.x + (end.x - start.x) * fraction,
                           y: start.y + (end.y - start.y) * fraction)
        }
    }

    private static func signedArea(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 2 else { return 0 }
        return points.indices.reduce(0) { value, index in
            let next = points[(index + 1) % points.count]
            return value + points[index].x * next.y - next.x * points[index].y
        } / 2
    }

    private static func distance(_ a: CGPoint, to b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private static func distance(_ point: CGPoint, fromLineStart start: CGPoint, end: CGPoint) -> CGFloat {
        let dx = end.x - start.x, dy = end.y - start.y
        let denominator = hypot(dx, dy)
        guard denominator > 0 else { return .infinity }
        return abs(dy * point.x - dx * point.y + end.x * start.y - end.y * start.x) / denominator
    }
}

private extension CGAffineTransform {
    var invertedIfPossible: CGAffineTransform? { abs(a * d - b * c) > .ulpOfOne ? inverted() : nil }
}
