import PencilKit

/// Keeps framed ink in document coordinates while PencilKit edits the combined scene.
/// Stroke creation dates survive PencilKit transforms and split erasure.
struct NoteCanvasInk {
    var drawing = PKDrawing()
    private var owners: [Date: UUID] = [:]
    private var originals: [UUID: PKDrawing] = [:]
    private var sourceObjects: [UUID: NoteObject] = [:]
    private let canonical: Bool
    init(objects: [NoteObject], traits: UITraitCollection? = nil, previous: NoteCanvasInk? = nil) throws {
        canonical = traits != nil
        var strokes: [PKStroke] = []
        for object in objects where object.kind == .ink {
            let positioned: PKDrawing
            if previous?.canonical == canonical, previous?.sourceObjects[object.id] == object,
               let cached = previous?.originals[object.id] {
                positioned = cached
            } else {
                var local = try PKDrawing(data: object.payload)
                if canonical { local = NoteInkAppearance.canonicalDrawing(local) }
                if let size = object.inkSize {
                    local = local.transformed(using: CGAffineTransform(scaleX: object.frame.width / size.width, y: object.frame.height / size.height))
                }
                positioned = local.transformed(using: CGAffineTransform(translationX: object.frame.minX, y: object.frame.minY))
            }
            sourceObjects[object.id] = object
            let owned = positioned.strokes.map { value -> PKStroke in
                var stroke = value
                var date = stroke.path.creationDate
                // A legacy archive can legitimately contain copies of the same drawing.
                while let owner = owners[date], owner != object.id { date = date.addingTimeInterval(0.000001) }
                if date != stroke.path.creationDate { stroke.path = PKStrokePath(controlPoints: stroke.path, creationDate: date) }
                owners[date] = object.id
                return stroke
            }
            originals[object.id] = PKDrawing(strokes: owned)
            strokes += owned
        }
        drawing = PKDrawing(strokes: strokes)
    }
    static func extensionOwner(in objects: [NoteObject], selection: Set<UUID>) -> UUID? {
        if selection.count == 1, let selected = objects.first(where: { selection.contains($0.id) && $0.kind == .ink && !$0.positionLocked }) { return selected.id }
        guard let recent = objects.last(where: { $0.kind == .ink && !$0.positionLocked && $0.group == nil }),
              let count = try? PKDrawing(data: recent.payload).strokes.count, count < 64 else { return nil }
        return recent.id
    }

    static func equivalent(_ lhs: PKDrawing, _ rhs: PKDrawing) -> Bool {
        guard lhs.strokes.count == rhs.strokes.count else { return false }
        return zip(lhs.strokes, rhs.strokes).allSatisfy { a, b in
            guard a.transform == b.transform, a.ink.inkType == b.ink.inkType, a.ink.color == b.ink.color, a.randomSeed == b.randomSeed,
                  a.mask?.cgPath == b.mask?.cgPath, a.path.creationDate == b.path.creationDate,
                  a.path.count == b.path.count else { return false }
            return zip(a.path, b.path).allSatisfy { x, y in
                return x.location == y.location && x.timeOffset == y.timeOffset && x.size == y.size &&
                    x.opacity == y.opacity && x.force == y.force && x.azimuth == y.azimuth &&
                    x.altitude == y.altitude && x.secondaryScale == y.secondaryScale
            }
        }
    }
    func objects(after edited: PKDrawing, replacing objects: [NoteObject], extending selectedID: UUID? = nil) -> [NoteObject] {
        let newID = selectedID.flatMap { id in objects.first { $0.id == id && $0.kind == .ink }?.id } ?? UUID()
        let groups = Dictionary(grouping: edited.strokes) { owners[$0.path.creationDate] ?? newID }
        var result = objects.filter { $0.kind != .ink || groups[$0.id] != nil }
        for (id, strokes) in groups {
            let drawing = PKDrawing(strokes: strokes)
            if let original = originals[id], Self.equivalent(original, drawing) { continue }
            let bounds = drawing.bounds
            guard !bounds.isNull, !bounds.isEmpty else { continue }
            let origin = CGPoint(x: max(0, bounds.minX), y: max(0, bounds.minY))
            let size = CGSize(width: max(40, bounds.maxX - origin.x), height: max(40, bounds.maxY - origin.y))
            var object = result.first { $0.id == id } ?? NoteObject(kind: .ink)
            object.id = id; object.frame = CGRect(origin: origin, size: size); object.inkSize = size
            object.payload = drawing.transformed(using: CGAffineTransform(translationX: -origin.x, y: -origin.y)).dataRepresentation()
            if let index = result.firstIndex(where: { $0.id == id }) { result[index] = object } else { result.append(object) }
        }
        for index in result.indices {
            if let group = result[index].group, result.filter({ $0.group == group }).count < 2 { result[index].group = nil }
        }
        return result
    }
}
