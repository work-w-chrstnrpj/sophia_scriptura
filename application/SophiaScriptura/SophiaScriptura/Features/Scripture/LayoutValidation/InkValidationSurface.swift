#if DEBUG
import SwiftUI
import PencilKit
import CryptoKit

struct InkValidationSurface: UIViewControllerRepresentable {
    @ObservedObject var session: InkValidationSession
    let document: ChapterDocument
    func makeUIViewController(context: Context) -> InkValidationController {
        InkValidationController(session: session, document: document)
    }
    func updateUIViewController(_ controller: InkValidationController, context: Context) {
        DispatchQueue.main.async { [weak controller] in controller?.apply() }
    }
}

/// One fixed continuous chapter; resizing affects the viewport, never its text container.
/// This experiment deliberately does not share production reader gesture ownership yet.
@MainActor
final class InkValidationController: UIViewController, UIScrollViewDelegate, PKCanvasViewDelegate {
    private let session: InkValidationSession
    private let document: ChapterDocument
    private let viewport = UIScrollView()
    private let paper = UIView()
    private let canvas = PKCanvasView()
    private let rules = CAShapeLayer()
    private let unavailable = UILabel()
    private let picker = PKToolPicker()
    private var appliedLayer = -1
    private var appliedGeneration = -1
    private var applying = false
    private var pickerVisible = false
    init(session: InkValidationSession, document: ChapterDocument) {
        self.session = session; self.document = document
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use init(session:document:)") }
    override func viewDidLoad() {
        super.viewDidLoad()
        viewport.delegate = self
        viewport.minimumZoomScale = 0.35; viewport.maximumZoomScale = 2.5
        viewport.contentInsetAdjustmentBehavior = .never
        viewport.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        view.addSubview(viewport); viewport.addSubview(paper)
        paper.backgroundColor = UIColor(red: 1, green: 0.98, blue: 0.92, alpha: 1)
        // Explicit TextKit 1, matching the current reader family.
        let storage = NSTextStorage()
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 540, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(manager); manager.addTextContainer(container)
        let chapter = UITextView(frame: .zero, textContainer: container)
        // Keep a single selectable text view under the canvas.
        chapter.isEditable = false; chapter.isScrollEnabled = false
        chapter.backgroundColor = .clear; chapter.textColor = .black
        chapter.textContainerInset = .zero; chapter.textContainer.lineFragmentPadding = 0
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 6; paragraph.paragraphSpacing = 12
        chapter.attributedText = NSAttributedString(string: ChapterTextMap(document: document).text,
            attributes: [.font: UIFont(name: "Georgia", size: 23) ?? UIFont.systemFont(ofSize: 23),
                         .foregroundColor: UIColor.black, .paragraphStyle: paragraph])
        chapter.frame = CGRect(x: 32, y: 32, width: 540, height: 1)
        let height = chapter.sizeThatFits(CGSize(width: 540, height: CGFloat.greatestFiniteMagnitude)).height
        chapter.frame.size.height = height
        paper.frame = CGRect(x: 0, y: 0, width: 800, height: height + 64)
        paper.addSubview(chapter)
        chapter.tag = 8
        manager.ensureLayout(for: container)
        var geometry = "sp008-v1|\(document.contentRevision)|\(paper.bounds)|Georgia23"
        manager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs)) { rect, used, _, range, _ in
            geometry += "|\(range):\(rect):\(used)"
        }
        session.signature = SHA256.hash(data: Data(geometry.utf8)).map { String(format: "%02x", $0) }.joined()
        let path = UIBezierPath()
        for y in stride(from: CGFloat(56), to: paper.bounds.height, by: 32) {
            path.move(to: CGPoint(x: 600, y: y)); path.addLine(to: CGPoint(x: 776, y: y))
        }
        rules.path = path.cgPath; rules.strokeColor = UIColor.gray.withAlphaComponent(0.35).cgColor
        rules.lineWidth = 0.5; paper.layer.addSublayer(rules)
        canvas.frame = paper.bounds; canvas.backgroundColor = .clear; canvas.isOpaque = false
        canvas.isScrollEnabled = false; canvas.drawingPolicy = .pencilOnly; canvas.delegate = self
        canvas.tool = PKInkingTool(.pen, color: .black, width: 2)
        canvas.overrideUserInterfaceStyle = .light
        paper.addSubview(canvas)
        unavailable.text = "Background unavailable — retained ink is not overlaid on changed text."
        unavailable.numberOfLines = 0; unavailable.textAlignment = .center
        unavailable.frame = CGRect(x: 32, y: 32, width: 740, height: 120)
        unavailable.textColor = .black; paper.addSubview(unavailable)
        viewport.contentSize = paper.bounds.size
        picker.addObserver(canvas)
        session.flush = { [weak self] in self?.publish() }
        session.undo = { [weak self] in self?.canvas.undoManager?.undo() }
        session.redo = { [weak self] in self?.canvas.undoManager?.redo() }
        apply()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        viewport.frame = view.bounds
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); apply() }
    override func viewWillDisappear(_ animated: Bool) {
        publish()
        picker.setVisible(false, forFirstResponder: canvas)
        canvas.resignFirstResponder(); pickerVisible = false
        super.viewWillDisappear(animated)
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { paper }
    func apply() {
        guard isViewLoaded, !session.usingTool else { return }
        if appliedLayer != session.layer || appliedGeneration != session.generation {
            // A reopen replaces the model; never flush the stale surface over it.
            if appliedLayer >= 0 && appliedGeneration == session.generation { publish() }
            applying = true
            canvas.drawing = session.drawings[session.layer]
            canvas.undoManager?.removeAllActions()
            appliedLayer = session.layer; appliedGeneration = session.generation
            applying = false
        }
        let blocked = session.unavailable || session.layoutMismatch
        let draw = session.mode == .draw && !blocked
        canvas.isHidden = session.mode == .hidden || blocked
        canvas.isUserInteractionEnabled = draw
        paper.viewWithTag(8)?.isHidden = blocked
        paper.viewWithTag(8)?.isUserInteractionEnabled = !draw
        rules.isHidden = !session.rules || blocked
        unavailable.isHidden = !blocked
        if view.window != nil, pickerVisible != draw {
            pickerVisible = draw
            if draw { canvas.becomeFirstResponder() }
            picker.setVisible(draw, forFirstResponder: canvas)
            if !draw { canvas.resignFirstResponder() }
        }
    }
    private func publish() {
        guard !applying, appliedLayer >= 0 else { return }
        session.drawings[appliedLayer] = canvas.drawing
    }
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { publish() }
    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) { session.usingTool = true }
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        publish(); session.usingTool = false
    }
}
#endif
