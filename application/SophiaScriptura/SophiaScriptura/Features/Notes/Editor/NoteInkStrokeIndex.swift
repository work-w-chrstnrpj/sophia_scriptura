import PencilKit
import CryptoKit

struct NoteStrokeReference: Hashable, Sendable {
    let objectID: UUID
    let strokeID: UUID
}

/// Legacy identities are deterministic without rewriting the original drawing or frame.
enum NoteStrokeIdentity {
    static func ids(for object: NoteObject, count: Int) throws -> [UUID] {
        if let ids = object.strokeIDs {
            guard ids.count == count, Set(ids).count == count else { throw NotesError.invalid }
            return ids
        }
        return (0..<count).map { index in
            let digest = Array(SHA256.hash(data: Data("\(object.id.uuidString):\(index)".utf8)))
            return UUID(uuid: (digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
                               digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]))
        }
    }
}

/// Fixed grid over document-space bounds. Geometry is sampled only for candidate strokes.
struct NoteInkStrokeIndex {
    struct Entry {
        let reference: NoteStrokeReference
        let stroke: PKStroke
    }
    private struct Cell: Hashable { let x: Int; let y: Int }
    let entries: [Entry]
    private var cells: [Cell: Set<Int>] = [:]
    private var large = Set<Int>()
    private let cellSize: CGFloat = 128
    init(entries: [Entry]) {
        self.entries = entries
        for (index, entry) in entries.enumerated() {
            let keys = keys(for: entry.stroke.renderBounds)
            if keys.isEmpty { large.insert(index) }
            else { for key in keys { cells[key, default: []].insert(index) } }
        }
    }
    private func keys(for rect: CGRect) -> [Cell] {
        guard !rect.isNull, [rect.minX, rect.minY, rect.maxX, rect.maxY].allSatisfy({ $0.isFinite && abs($0) <= 1_000_000 }) else { return [] }
        let x0 = Int(floor(rect.minX / cellSize)), x1 = Int(floor(rect.maxX / cellSize))
        let y0 = Int(floor(rect.minY / cellSize)), y1 = Int(floor(rect.maxY / cellSize))
        guard x1 >= x0, y1 >= y0, x1 - x0 < 256, y1 - y0 < 256,
              (x1 - x0 + 1) * (y1 - y0 + 1) <= 1024 else { return [] }
        return (x0...x1).flatMap { x in (y0...y1).map { Cell(x: x, y: $0) } }
    }
    func candidates(in rect: CGRect) -> [Int] {
        let keys = keys(for: rect)
        var found = large
        if keys.isEmpty { found.formUnion(entries.indices) }
        else { for key in keys { found.formUnion(cells[key] ?? []) } }
        return found.filter { entries[$0].stroke.renderBounds.intersects(rect) }.sorted()
    }
    func hit(at point: CGPoint, tolerance: CGFloat = 6) -> NoteStrokeReference? {
        let rect = CGRect(x: point.x - tolerance, y: point.y - tolerance, width: max(1, tolerance * 2), height: max(1, tolerance * 2))
        return candidates(in: rect).reversed().first { Self.hits(entries[$0].stroke, at: point, tolerance: tolerance) }.map { entries[$0].reference }
    }
    func selected(inside points: [CGPoint]) -> Set<NoteStrokeReference> {
        guard points.count >= 3 else { return [] }
        let path = CGMutablePath(); path.addLines(between: points); path.closeSubpath()
        // Full containment of sampled visible centerline: touching only the bounds is insufficient.
        return Set(candidates(in: path.boundingBoxOfPath).compactMap { index in
            let entry = entries[index]
            let samples = Self.visiblePoints(entry.stroke)
            guard !samples.isEmpty, samples.allSatisfy({ path.contains($0) }) else { return nil }
            return entry.reference
        })
    }
    func bounds(of selection: Set<NoteStrokeReference>) -> CGRect {
        entries.filter { selection.contains($0.reference) }.map { $0.stroke.renderBounds }.reduce(.null) { $0.union($1) }
    }
    static func visiblePoints(_ stroke: PKStroke) -> [CGPoint] {
        stroke.path.interpolatedPoints(by: .distance(3)).compactMap { sample in
            guard stroke.mask?.contains(sample.location) != false else { return nil }
            return sample.location.applying(stroke.transform)
        }
    }
    static func hits(_ stroke: PKStroke, at point: CGPoint, tolerance: CGFloat) -> Bool {
        let determinant = stroke.transform.a * stroke.transform.d - stroke.transform.b * stroke.transform.c
        guard abs(determinant) > 0.000001 else { return false }
        let local = point.applying(stroke.transform.inverted())
        // A mask clips visible ink; an erased hole must not hit even within renderBounds.
        guard stroke.mask?.contains(local) != false else { return false }
        let scale = max(0.001, min(hypot(stroke.transform.a, stroke.transform.b), hypot(stroke.transform.c, stroke.transform.d)))
        let padding = tolerance / scale
        let samples = Array(stroke.path.interpolatedPoints(by: .distance(3)))
        for (index, sample) in samples.enumerated() {
            let end = index + 1 < samples.count ? samples[index + 1] : sample
            let dx = end.location.x - sample.location.x, dy = end.location.y - sample.location.y
            let length = dx * dx + dy * dy
            let t = length > 0 ? max(0, min(1, ((local.x - sample.location.x) * dx + (local.y - sample.location.y) * dy) / length)) : 0
            let center = CGPoint(x: sample.location.x + t * dx, y: sample.location.y + t * dy)
            let rx = max(0.5, (sample.size.width + t * (end.size.width - sample.size.width)) / 2) + padding
            let ry = max(0.5, (sample.size.height + t * (end.size.height - sample.size.height)) / 2) + padding
            let x = (local.x - center.x) / rx, y = (local.y - center.y) / ry
            if x * x + y * y <= 1 { return true }
        }
        return false
    }
}
