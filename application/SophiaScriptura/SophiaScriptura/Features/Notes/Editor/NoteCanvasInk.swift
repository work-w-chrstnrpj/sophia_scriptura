import PencilKit

/// Keeps framed ink in document coordinates while PencilKit edits the combined scene.
/// Stroke creation dates survive PencilKit transforms and split erasure.
struct NoteCanvasInk {
    var drawing = PKDrawing()
    private var owners: [Date: NoteStrokeReference] = [:]
    private(set) var strokeIndex = NoteInkStrokeIndex(entries: [])
    private var originals: [UUID: PKDrawing] = [:]
    private var sourceObjects: [UUID: NoteObject] = [:]
    private let canonical: Bool
    init(objects: [NoteObject], traits: UITraitCollection? = nil, previous: NoteCanvasInk? = nil) throws {
        canonical = traits != nil
        var strokes: [PKStroke] = []
        var nextCollisionToken: TimeInterval = 0
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
            let ids = try NoteStrokeIdentity.ids(for: object, count: positioned.strokes.count)
            let owned = try positioned.strokes.enumerated().map { index, value -> PKStroke in
                var stroke = value
                var date = stroke.path.creationDate
                // A legacy archive can legitimately contain copies of the same drawing.
                guard date.timeIntervalSinceReferenceDate.isFinite else { throw NotesError.invalid }
                while owners[date] != nil {
                    date = Date(timeIntervalSinceReferenceDate: nextCollisionToken)
                    nextCollisionToken += 1
                }
                if date != stroke.path.creationDate { stroke.path = PKStrokePath(controlPoints: stroke.path, creationDate: date) }
                owners[date] = NoteStrokeReference(objectID: object.id, strokeID: ids[index])
                return stroke
            }
            originals[object.id] = PKDrawing(strokes: owned)
            strokes += owned
        }
        drawing = PKDrawing(strokes: strokes)
        strokeIndex = NoteInkStrokeIndex(entries: strokes.compactMap { stroke in
            owners[stroke.path.creationDate].map { NoteInkStrokeIndex.Entry(reference: $0, stroke: stroke) }
        })
    }
    static func extensionOwner(in objects: [NoteObject], selection: Set<UUID>) -> UUID? {
        if selection.count == 1, let selected = objects.first(where: { selection.contains($0.id) && $0.kind == .ink && !$0.positionLocked }) { return selected.id }
        // Continue only the topmost ink region. Inserting another object establishes a new
        // z-order boundary; explicit selection can extend an older region deliberately.
        guard let recent = objects.last, recent.kind == .ink, !recent.positionLocked, recent.group == nil else { return nil }
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
        var assigned = Set<NoteStrokeReference>()
        let identified = edited.strokes.map { stroke -> (PKStroke, NoteStrokeReference) in
            let previous = owners[stroke.path.creationDate]
            var ref = previous ?? NoteStrokeReference(objectID: newID, strokeID: UUID())
            // Partial erasure can produce several fragments with one source creation date.
            // The first survives under the parent ID; subsequent fragments get fresh IDs.
            if !assigned.insert(ref).inserted { ref = NoteStrokeReference(objectID: ref.objectID, strokeID: UUID()) }
            return (stroke, ref)
        }
        var groups = Dictionary(grouping: identified) { $0.1.objectID }
        var follows: [UUID: UUID] = [:]
        // Safety-bound transitions preserve the new ink; they are not arbitrary batching.
        for (id, values) in groups {
            guard values.count > 10_000 || PKDrawing(strokes: values.map { $0.0 }).dataRepresentation().count > 16 * 1024 * 1024 else { continue }
            var remaining = values
            var regionID = id
            while !remaining.isEmpty {
                var count = min(10_000, remaining.count)
                while count > 1, PKDrawing(strokes: remaining.prefix(count).map { $0.0 }).dataRepresentation().count > 16 * 1024 * 1024 { count /= 2 }
                groups[regionID] = Array(remaining.prefix(count)).map { ($0.0, NoteStrokeReference(objectID: regionID, strokeID: $0.1.strokeID)) }
                remaining.removeFirst(count)
                if !remaining.isEmpty {
                    let next = UUID(); follows[next] = regionID; regionID = next
                }
            }
        }
        var result = objects.filter { $0.kind != .ink || groups[$0.id] != nil }
        for (id, values) in groups {
            let drawing = PKDrawing(strokes: values.map { $0.0 })
            if let original = originals[id], Self.equivalent(original, drawing) { continue }
            let bounds = drawing.bounds
            guard !bounds.isNull, !bounds.isEmpty else { continue }
            let origin = CGPoint(x: max(0, bounds.minX), y: max(0, bounds.minY))
            let size = CGSize(width: max(40, bounds.maxX - origin.x), height: max(40, bounds.maxY - origin.y))
            var object = result.first { $0.id == id } ?? NoteObject(kind: .ink)
            object.id = id; object.frame = CGRect(origin: origin, size: size); object.inkSize = size
            object.strokeIDs = values.map { $0.1.strokeID }
            object.payload = drawing.transformed(using: CGAffineTransform(translationX: -origin.x, y: -origin.y)).dataRepresentation()
            if let index = result.firstIndex(where: { $0.id == id }) { result[index] = object } else { result.append(object) }
        }
        // Spill regions remain adjacent to their source, including ink below text/images.
        var pending = follows
        while !pending.isEmpty {
            var progressed = false
            for (child, parent) in pending where pending[parent] == nil {
                if let childIndex = result.firstIndex(where: { $0.id == child }) {
                    let object = result.remove(at: childIndex)
                    if let parentIndex = result.firstIndex(where: { $0.id == parent }) { result.insert(object, at: parentIndex + 1) }
                    else { result.append(object) }
                }
                pending.removeValue(forKey: child); progressed = true
            }
            if !progressed { break }
        }
        for index in result.indices {
            if let group = result[index].group, result.filter({ $0.group == group }).count < 2 { result[index].group = nil }
        }
        return result
    }
    func localBounds(for object: NoteObject) -> CGRect? {
        originals[object.id]?.bounds.offsetBy(dx: -object.frame.minX, dy: -object.frame.minY)
    }
    func localDrawing(for object: NoteObject) -> PKDrawing? {
        originals[object.id]?.transformed(using: CGAffineTransform(translationX: -object.frame.minX, y: -object.frame.minY))
    }
    enum StrokeEdit { case move(CGSize), delete, color(UIColor) }
    func editing(_ selection: Set<NoteStrokeReference>, in objects: [NoteObject], operation: StrokeEdit) -> [NoteObject] {
        let editable: Set<NoteStrokeReference>
        if case .move = operation { editable = Set(selection.filter { sourceObjects[$0.objectID]?.positionLocked == false }) }
        else { editable = selection }
        let strokes = drawing.strokes.compactMap { value -> PKStroke? in
            guard let ref = owners[value.path.creationDate], editable.contains(ref) else { return value }
            var stroke = value
            switch operation {
            case .delete: return nil
            case .move(let delta):
                stroke.transform = stroke.transform.concatenating(CGAffineTransform(translationX: delta.width, y: delta.height))
            case .color(let color): stroke.ink = PKInk(stroke.ink.inkType, color: color)
            }
            return stroke
        }
        return self.objects(after: PKDrawing(strokes: strokes), replacing: objects)
    }
    func copying(_ selection: Set<NoteStrokeReference>) -> [NoteObject] {
        let selected = drawing.strokes.filter { stroke in owners[stroke.path.creationDate].map { selection.contains($0) } ?? false }
        let groups = Dictionary(grouping: selected) { owners[$0.path.creationDate]!.objectID }
        // Keep source-region order and geometry; copies acquire independent stroke IDs.
        return sourceObjects.values.filter { groups[$0.id] != nil }.sorted { lhs, rhs in
            let a = strokeIndex.entries.firstIndex { $0.reference.objectID == lhs.id } ?? 0
            let b = strokeIndex.entries.firstIndex { $0.reference.objectID == rhs.id } ?? 0
            return a < b
        }.compactMap { source in
            guard let strokes = groups[source.id] else { return nil }
            let drawing = PKDrawing(strokes: strokes)
            let origin = CGPoint(x: max(0, drawing.bounds.minX), y: max(0, drawing.bounds.minY))
            var object = NoteObject(kind: .ink)
            object.frame = CGRect(origin: origin, size: CGSize(width: max(40, drawing.bounds.maxX - origin.x), height: max(40, drawing.bounds.maxY - origin.y)))
            object.inkSize = object.frame.size
            object.strokeIDs = strokes.map { _ in UUID() }
            object.payload = drawing.transformed(using: CGAffineTransform(translationX: -origin.x, y: -origin.y)).dataRepresentation()
            return object
        }
    }

}
