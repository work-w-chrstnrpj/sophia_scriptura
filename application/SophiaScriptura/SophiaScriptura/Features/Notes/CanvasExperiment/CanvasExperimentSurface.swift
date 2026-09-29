import SwiftUI
import UIKit
import PencilKit

struct CanvasExperimentSurface: UIViewControllerRepresentable {
    @ObservedObject var session: CanvasExperimentSession

    func makeUIViewController(context: Context) -> CanvasSurfaceController {
        CanvasSurfaceController(session: session)
    }

    func updateUIViewController(_ controller: CanvasSurfaceController, context: Context) {
        controller.scheduleSessionApplication()
    }
}

/// One zooming UIView contains every object. UIKit transforms the viewport; the model
/// stores unscaled document points. The single ink object is deliberately a spike limit.
@MainActor
final class CanvasSurfaceController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate, PKCanvasViewDelegate {
    private let session: CanvasExperimentSession
    private let scroll = UIScrollView()
    private let paper = UIView()
    private let text = UILabel()
    private let image = UIImageView()
    private let ink = ExperimentInkView()
    private let caption = UILabel()
    private let drawingOutline = CAShapeLayer()
    private var selectionLayers: [CAShapeLayer] = []
    private var moveGesture: UIPanGestureRecognizer!
    private var tapGesture: UITapGestureRecognizer!
    private var dragStart: CanvasFixture?
    private var dragSelection: Set<CanvasFixture.ObjectID> = []
    private var presentedDrawing: Data?
    private var lastCanvasData: Data?
    private var presentedImage: Data?
    private var usingTool = false
    private var inkHistoryRecorded = false
    private var lastViewportRequest: UUID?
    private var lastSize = CGSize.zero
    private var isApplying = false
    private var appliedEraser: Bool?
    private var sessionApplicationScheduled = false

    init(session: CanvasExperimentSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use init(session:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        scroll.delegate = self
        scroll.minimumZoomScale = 0.5
        scroll.maximumZoomScale = 2
        scroll.bouncesZoom = false
        scroll.alwaysBounceHorizontal = true
        scroll.alwaysBounceVertical = true
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        view.addSubview(scroll)
        paper.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 0.15, green: 0.19, blue: 0.16, alpha: 1)
                : UIColor(red: 1, green: 0.985, blue: 0.95, alpha: 1)
        }
        scroll.addSubview(paper)

        text.numberOfLines = 0
        text.font = .systemFont(ofSize: 24, weight: .regular)
        text.textColor = .label
        text.isAccessibilityElement = true
        text.accessibilityLabel = "Observation text"
        text.accessibilityIdentifier = "canvas.observation"
        text.accessibilityTraits = [.staticText]
        paper.addSubview(text)
        image.contentMode = .scaleAspectFit
        image.isAccessibilityElement = true
        image.accessibilityLabel = "Morning reflection, illustrated landscape"
        paper.addSubview(image)
        ink.backgroundColor = .clear
        ink.isOpaque = false
        ink.isScrollEnabled = false
        ink.bounces = false
        ink.delegate = self
        ink.contentInset = .zero
        ink.drawingPolicy = .pencilOnly
        ink.isAccessibilityElement = true
        ink.accessibilityLabel = "Handwriting layer"
        ink.accessibilityIdentifier = "canvas.ink"
        ink.overrideUserInterfaceStyle = .unspecified
        paper.addSubview(ink)
        ink.layer.addSublayer(drawingOutline)
        drawingOutline.fillColor = UIColor.clear.cgColor
        drawingOutline.lineDashPattern = [6, 5]
        drawingOutline.lineWidth = 1

        caption.text = "John 3:16 · Study sample\nLove → gave → believe → life."
        caption.numberOfLines = 2
        caption.textColor = .secondaryLabel
        caption.font = .systemFont(ofSize: 20)
        caption.frame = CGRect(x: 70, y: 365, width: 500, height: 70)
        paper.addSubview(caption)
        caption.isUserInteractionEnabled = false

        moveGesture = UIPanGestureRecognizer(target: self, action: #selector(moveObject(_:)))
        moveGesture.minimumNumberOfTouches = 1
        moveGesture.maximumNumberOfTouches = 1
        moveGesture.delegate = self
        paper.addGestureRecognizer(moveGesture)
        scroll.panGestureRecognizer.require(toFail: moveGesture)
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(selectObject(_:)))
        tapGesture.delegate = self
        paper.addGestureRecognizer(tapGesture)
        session.flushInk = { [weak self] in self?.publishInk() }
        applySession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let old = lastSize
        let center = CGPoint(x: (scroll.contentOffset.x + old.width / 2) / scroll.zoomScale,
                             y: (scroll.contentOffset.y + old.height / 2) / scroll.zoomScale)
        scroll.frame = view.bounds
        if old != .zero, old != view.bounds.size {
            setOffset(CGPoint(x: center.x * scroll.zoomScale - view.bounds.width / 2,
                              y: center.y * scroll.zoomScale - view.bounds.height / 2))
        }
        lastSize = view.bounds.size
    }

    override func viewWillDisappear(_ animated: Bool) {
        publishInk()
        super.viewWillDisappear(animated)
    }

    func scheduleSessionApplication() {
        guard !sessionApplicationScheduled else { return }
        sessionApplicationScheduled = true
        // Disabling PencilKit may resign first responder and update SwiftUI's
        // responder graph. Do that after updateUIViewController returns to avoid
        // re-entering the graph while SwiftUI is already evaluating it.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.sessionApplicationScheduled = false
            self.applySession()
        }
    }

    func applySession() {
        guard isViewLoaded, let document = session.document else { return }
        isApplying = true
        defer { isApplying = false }
        if dragStart == nil { present(document) }
        let drawing = session.mode == .draw && !session.busy
        ink.isUserInteractionEnabled = drawing
        ink.drawingPolicy = session.fingerDrawing ? .anyInput : .pencilOnly
        if appliedEraser != session.erasing {
            ink.tool = session.erasing ? PKEraserTool(.vector) : PKInkingTool(.pen, color: .systemBlue, width: 3)
            appliedEraser = session.erasing
        }
        // Two direct touches navigate when one-finger drawing is explicitly enabled.
        scroll.panGestureRecognizer.minimumNumberOfTouches = drawing && session.fingerDrawing ? 2 : 1
        moveGesture.isEnabled = session.mode == .select && !session.busy
        tapGesture.isEnabled = session.mode == .select && !session.busy
        scroll.isScrollEnabled = !session.busy
        drawingOutline.isHidden = !drawing
        drawingOutline.strokeColor = UIColor.systemBlue.withAlphaComponent(0.5).cgColor
        drawingOutline.path = UIBezierPath(rect: ink.bounds.insetBy(dx: 2, dy: 2)).cgPath

        if lastViewportRequest != session.viewportRequest {
            lastViewportRequest = session.viewportRequest
            if let zoom = session.requestedZoom {
                let center = CGPoint(x: (scroll.contentOffset.x + scroll.bounds.width / 2) / scroll.zoomScale,
                                     y: (scroll.contentOffset.y + scroll.bounds.height / 2) / scroll.zoomScale)
                scroll.setZoomScale(zoom, animated: false)
                setOffset(CGPoint(x: center.x * zoom - scroll.bounds.width / 2,
                                  y: center.y * zoom - scroll.bounds.height / 2))
                DispatchQueue.main.async { [weak self] in self?.session.zoom = zoom }
            } else if let object = session.requestedObject {
                let frame = visualFrame(object, document: document)
                setOffset(CGPoint(x: frame.midX * scroll.zoomScale - scroll.bounds.width / 2,
                                  y: frame.midY * scroll.zoomScale - scroll.bounds.height / 2))
            }
        }
    }

    private func present(_ document: CanvasFixture) {
        let size = document.contentSize
        if paper.bounds.size != size {
            paper.bounds = CGRect(origin: .zero, size: size)
            paper.center = CGPoint(x: size.width * scroll.zoomScale / 2, y: size.height * scroll.zoomScale / 2)
            scroll.contentSize = CGSize(width: size.width * scroll.zoomScale, height: size.height * scroll.zoomScale)
        }
        text.frame = document.object(.text).frame
        text.text = document.text
        text.accessibilityValue = document.text
        image.frame = document.object(.image).frame
        let bytes = document.assets[document.imageAssetID]
        if bytes != presentedImage {
            image.image = bytes.flatMap(UIImage.init(data:))
            presentedImage = bytes
        }
        ink.frame = document.object(.ink).frame
        if document.drawing != presentedDrawing, !usingTool {
            if let drawing = try? PKDrawing(data: document.drawing) {
                ink.drawing = drawing
                presentedDrawing = document.drawing
                lastCanvasData = ink.drawing.dataRepresentation()
            }
        }
        updateSelection(document)
        ink.accessibilityValue = "\(ink.drawing.strokes.count) strokes"
    }

    private func visualFrame(_ id: CanvasFixture.ObjectID, document: CanvasFixture) -> CGRect {
        let frame = document.object(id).frame
        if id == .ink, !ink.drawing.bounds.isNull {
            return ink.drawing.bounds.offsetBy(dx: frame.minX, dy: frame.minY)
        }
        return frame
    }

    private func updateSelection(_ document: CanvasFixture) {
        selectionLayers.forEach { $0.removeFromSuperlayer() }
        selectionLayers.removeAll()
        let selected = document.members(of: session.selection)
        guard !selected.isEmpty else { return }
        var bounds = CGRect.null
        for id in selected {
            let frame = visualFrame(id, document: document).insetBy(dx: -7, dy: -7)
            bounds = bounds.union(frame)
            let layer = CAShapeLayer()
            layer.path = UIBezierPath(roundedRect: frame, cornerRadius: 5).cgPath
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = UIColor.systemBlue.cgColor
            layer.lineWidth = 1.5 / scroll.zoomScale
            paper.layer.addSublayer(layer)
            selectionLayers.append(layer)
        }
        let groups = Set(document.objects.filter { selected.contains($0.id) }.compactMap(\.group))
        if groups.count == 1, selected.count > 1 {
            let layer = CAShapeLayer()
            layer.path = UIBezierPath(roundedRect: bounds.insetBy(dx: -5, dy: -5), cornerRadius: 8).cgPath
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = UIColor.systemGreen.cgColor
            layer.lineDashPattern = [6, 4]
            paper.layer.addSublayer(layer)
            selectionLayers.append(layer)
        }
    }

    private func hitObject(at point: CGPoint) -> CanvasFixture.ObjectID? {
        guard let document = session.document else { return nil }
        let inkFrame = document.object(.ink).frame
        let local = CGPoint(x: point.x - inkFrame.minX, y: point.y - inkFrame.minY)
        // Test samples on visible strokes, not the entire transparent ink rectangle.
        for stroke in ink.drawing.strokes.reversed() where stroke.renderBounds.insetBy(dx: -14, dy: -14).contains(local) {
            for sample in stroke.path.interpolatedPoints(by: .distance(5)) {
                let transformed = sample.location.applying(stroke.transform)
                if hypot(transformed.x - local.x, transformed.y - local.y) <= max(12 / scroll.zoomScale, sample.size.width) {
                    return .ink
                }
            }
        }
        if document.object(.image).frame.contains(point) { return .image }
        if document.object(.text).frame.contains(point) { return .text }
        return nil
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard session.mode == .select, !session.busy else { return false }
        if gestureRecognizer == moveGesture {
            return hitObject(at: gestureRecognizer.location(in: paper)) != nil
        }
        return true
    }

    @objc private func selectObject(_ recognizer: UITapGestureRecognizer) {
        if let id = hitObject(at: recognizer.location(in: paper)) { session.select(id, add: false) }
        else { session.selection.removeAll() }
    }

    @objc private func moveObject(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            guard let id = hitObject(at: recognizer.location(in: paper)), let document = session.document else { return }
            if !session.selection.contains(id) { session.select(id, add: false) }
            dragStart = document
            dragSelection = document.members(of: session.selection)
            session.interacting = true
        case .changed:
            guard var candidate = dragStart else { return }
            let screen = recognizer.translation(in: view)
            candidate.move(dragSelection, by: CanvasFixture.documentDelta(screen: CGSize(width: screen.x, height: screen.y), zoom: scroll.zoomScale))
            present(candidate)
        case .ended:
            guard var candidate = dragStart else { return }
            let screen = recognizer.translation(in: view)
            candidate.move(dragSelection, by: CanvasFixture.documentDelta(screen: CGSize(width: screen.x, height: screen.y), zoom: scroll.zoomScale))
            dragStart = nil
            session.interacting = false
            session.commit(candidate)
            applySession()
        case .cancelled, .failed:
            dragStart = nil
            session.interacting = false
            applySession()
        default: break
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { paper }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if let document = session.document { updateSelection(document) }
        guard !isApplying else { return }
        let zoom = scrollView.zoomScale
        DispatchQueue.main.async { [weak self] in self?.session.zoom = zoom }
    }

    private func setOffset(_ point: CGPoint) {
        let maximumX = max(0, scroll.contentSize.width - scroll.bounds.width)
        let maximumY = max(0, scroll.contentSize.height - scroll.bounds.height)
        scroll.setContentOffset(CGPoint(x: min(maximumX, max(0, point.x)), y: min(maximumY, max(0, point.y))), animated: false)
    }

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        usingTool = true
        inkHistoryRecorded = false
        session.interacting = true
    }

    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        usingTool = false
        session.interacting = false
        publishInk()
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        // PencilKit can finish rendering AFTER the tool-ended callback. Subsequent
        // final updates refine the same transaction instead of adding another undo step.
        if !usingTool, !isApplying { publishInk() }
    }

    private func publishInk() {
        guard isViewLoaded else { return }
        let data = ink.drawing.dataRepresentation()
        guard data != lastCanvasData else { return }
        lastCanvasData = data
        presentedDrawing = data
        if session.updateInk(data, newTransaction: !inkHistoryRecorded) { inkHistoryRecorded = true }
    }
}

/// Document-level toolbar undo owns committed strokes. Avoid a second responder-chain
/// history competing with it; text editing has a separate draft until Done.
private final class ExperimentInkView: PKCanvasView {
    override var undoManager: UndoManager? { nil }
}
