import SwiftUI
import PencilKit
import AVFoundation

struct NoteCanvasSurface: UIViewControllerRepresentable {
    @Environment(\.appTheme) private var theme
    var session: NotesSession
    var active: Bool
    var stateToken: String
    var openCitation: (NoteQuote) -> Void
    func makeUIViewController(context: Context) -> NoteCanvasController { NoteCanvasController(session: session, openCitation: openCitation) }
    func updateUIViewController(_ controller: NoteCanvasController, context: Context) {
        let theme = theme
        DispatchQueue.main.async { [weak controller] in controller?.setTheme(theme); controller?.apply() }
    }
    static func dismantleUIViewController(_ controller: NoteCanvasController, coordinator: ()) { controller.close() }
}

struct NotePageSurface: UIViewControllerRepresentable {
    @Environment(\.appTheme) private var theme
    var session: NotesSession
    var active: Bool
    var stateToken: String
    var allowsHorizontalPan = false
    /// When true (Prayer card preview), fits the writing column to the board width with modest margins.
    var prayerPreviewFitsContent = false
    var prayerPreviewHorizontalMargin: CGFloat = 16
    var openCitation: (NoteQuote) -> Void
    func makeUIViewController(context: Context) -> NotePageController {
        let controller = NotePageController(session: session, openCitation: openCitation)
        controller.allowsHorizontalPan = allowsHorizontalPan
        controller.prayerPreviewFitsContent = prayerPreviewFitsContent
        controller.prayerPreviewHorizontalMargin = prayerPreviewHorizontalMargin
        return controller
    }
    func updateUIViewController(_ controller: NotePageController, context: Context) {
        let theme = theme
        let allowsHorizontalPan = allowsHorizontalPan
        let prayerPreviewFitsContent = prayerPreviewFitsContent
        let prayerPreviewHorizontalMargin = prayerPreviewHorizontalMargin
        DispatchQueue.main.async { [weak controller] in
            controller?.allowsHorizontalPan = allowsHorizontalPan
            controller?.prayerPreviewFitsContent = prayerPreviewFitsContent
            controller?.prayerPreviewHorizontalMargin = prayerPreviewHorizontalMargin
            controller?.setTheme(theme)
            controller?.apply()
        }
    }
    static func dismantleUIViewController(_ controller: NotePageController, coordinator: ()) { controller.close() }
}

@MainActor final class NotePageController: NoteSurfaceController {}
@MainActor final class NoteCanvasController: NoteSurfaceController { override var isCanvas: Bool { true } }

/// Ink renders above content. Its recognizer is on the common editor ancestor, so
/// Pencil reaches it even over a first-responder UITextView; finger hits pass through.
private final class NoteInkCanvas: PKCanvasView {
    var testingFinger = false
    private let history = UndoManager()
    override var undoManager: UndoManager? { history }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

@MainActor class NoteSurfaceController: UIViewController, UIScrollViewDelegate, UITextViewDelegate, PKCanvasViewDelegate, UIGestureRecognizerDelegate, PKToolPickerObserver, UIScribbleInteractionDelegate {
    var isCanvas: Bool { false }
    private var theme = AppTheme()
    func setTheme(_ next: AppTheme) {
        guard theme != next else { return }
        if isViewLoaded { flush() }
        theme = next
        rasters.removeAllObjects()
        overrideUserInterfaceStyle = next.dark ? .dark : .light
        acceptsInkChanges = false; represented = [:]; representedInkObjects = []; renderedPage = nil; loadedPageInk = nil
    }
    private var canvasScene: NoteCanvasInk?
    private var representedInkObjects: [NoteObject] = []
    private var pencilSelecting = false
    private var pencilSelectionPan: UIPanGestureRecognizer!
    private var pencilSelectionTap: UITapGestureRecognizer!
    private var selectionPoints: [CGPoint] = []
    private var draggingStrokeSelection = false
    private let selectionOutline = CAShapeLayer()
    private let session: NotesSession
    private let openCitation: (NoteQuote) -> Void
    private let scroll = UIScrollView(), paper = NotePaperView(), bodyText = UITextView(), quoteBars = NoteBlockQuoteBarView()
    private let ink = NoteInkCanvas()
    private let placeholder = UILabel()
    private let picker: PKToolPicker
    private lazy var strokeRefiner = PencilStrokeRefiner(canvas: ink)
    private var objects: [UUID: UIView] = [:]
    private var represented: [UUID: NoteObject] = [:]
    private final class RasterEntry: NSObject {
        let object: NoteObject
        let image: UIImage
        let frame: CGRect
        func matches(_ next: NoteObject) -> Bool {
            object.kind == next.kind && object.payload == next.payload &&
                (next.kind != .ink || (object.frame.size == next.frame.size && object.inkSize == next.inkSize))
        }
        init(_ object: NoteObject, image: UIImage, frame: CGRect) {
            self.object = object; self.image = image; self.frame = frame
        }
    }
    private let rasters: NSCache<NSUUID, RasterEntry> = {
        let cache = NSCache<NSUUID, RasterEntry>()
        cache.countLimit = 64; cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()
    private var preparingShare = false
    private var updatingObjects = false
    private var imageTasks: [UUID: Task<Void, Never>] = [:]
    private var noteID: UUID?, generation: UUID?, focus: UUID?, toolsRequest: UUID?
    private var applying = false, usingPencil = false, fitted = false, wasActive = false
    private var acceptsInkChanges = false
    private var refinementStatus = "rough"
    private var lastInk = Data()
    private var loadedPageInk: Data?
    var allowsHorizontalPan = false
    var prayerPreviewFitsContent = false
    var prayerPreviewHorizontalMargin: CGFloat = 16
    private var appliedHorizontalPan: Bool?
    private var audioPlayer: AVAudioPlayer?
    private let palette = UIStackView()
    private var paletteKey = ""
    private var renderedPage: NotePage?
    private var pan: UIPanGestureRecognizer!
    private var resizeID: UUID?
    private var dragStart = CGPoint.zero, originalSize = CGSize.zero
    private var bodyEdit: (NSRange, String)?
    private var bodyTapOffset: Int?
    private var objectTouchPoint = CGPoint.zero
    init(session: NotesSession, openCitation: @escaping (NoteQuote) -> Void) {
        self.session = session; self.openCitation = openCitation
        if #available(iOS 18.0, *) {
            let items = PKToolPicker().toolItems.filter {
                $0 is PKToolPickerInkingItem || $0 is PKToolPickerEraserItem || $0 is PKToolPickerRulerItem ||
                    (session.note?.kind == .canvas && $0 is PKToolPickerLassoItem)
            }
            picker = PKToolPicker(toolItems: items)
        } else { picker = PKToolPicker() }
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use init(session:openCitation:)") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        scroll.delegate = self
        scroll.minimumZoomScale = isCanvas ? 0.2 : 1
        scroll.maximumZoomScale = isCanvas ? 2 : 1
        scroll.pinchGestureRecognizer?.isEnabled = isCanvas
        scroll.bouncesZoom = isCanvas
        scroll.isDirectionalLockEnabled = !isCanvas
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        scroll.pinchGestureRecognizer?.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        scroll.accessibilityIdentifier = "notes.viewport"
        view.addSubview(scroll); scroll.addSubview(paper)
        bodyText.delegate = self; bodyText.isScrollEnabled = false; bodyText.backgroundColor = .clear
        bodyText.textContainerInset = .zero; bodyText.textContainer.lineFragmentPadding = 0
        bodyText.accessibilityIdentifier = "notes.body"; bodyText.accessibilityLabel = "Study note text"
        bodyText.textDragInteraction?.isEnabled = false
        bodyText.attributedText = attributedBody(NotePage())
        bodyText.font = .systemFont(ofSize: 22); bodyText.typingAttributes = NotePageTypography.attributes
        paper.addInteraction(UIScribbleInteraction(delegate: self))
        configureTextInput(bodyText)
        paper.addSubview(quoteBars)
        paper.addSubview(bodyText)
        quoteBars.textView = bodyText
        placeholder.text = "Start your study…"; placeholder.font = .systemFont(ofSize: 22)
        placeholder.textColor = .placeholderText; placeholder.isUserInteractionEnabled = false
        paper.addSubview(placeholder)
        ink.delegate = self; ink.backgroundColor = .clear; ink.isOpaque = false
        ink.isScrollEnabled = false; ink.drawingPolicy = .pencilOnly
        ink.tool = PKInkingTool(.pen, color: .label, width: 3)
        #if DEBUG
        ink.testingFinger = ProcessInfo.processInfo.environment["SP013_FINGER_INK"] == "1" || PencilStrokeRefiner.simulatesPencil
        if ink.testingFinger { ink.drawingPolicy = .anyInput }
        #endif
        ink.accessibilityIdentifier = "notes.ink"; ink.accessibilityLabel = "Page annotations"
        _ = strokeRefiner
        strokeRefiner.trackHold(on: view)
        // PencilKit must own a screen-sized drawable, not a 12,000-point Metal surface.
        view.addSubview(ink)
        ink.minimumZoomScale = scroll.minimumZoomScale; ink.maximumZoomScale = scroll.maximumZoomScale
        ink.contentInsetAdjustmentBehavior = .never
        view.addGestureRecognizer(ink.drawingGestureRecognizer)
        ink.drawingGestureRecognizer.allowedTouchTypes = [NSNumber(value: (ink.testingFinger ? UITouch.TouchType.direct : .pencil).rawValue)]
        picker.addObserver(ink); picker.addObserver(self)
        pencilSelectionPan = UIPanGestureRecognizer(target: self, action: #selector(selectWithPencil(_:)))
        pencilSelectionPan.allowedTouchTypes = [NSNumber(value: (ink.testingFinger ? UITouch.TouchType.direct : .pencil).rawValue)]
        pencilSelectionPan.isEnabled = false
        view.addGestureRecognizer(pencilSelectionPan)
        pencilSelectionTap = UITapGestureRecognizer(target: self, action: #selector(selectObject(_:)))
        pencilSelectionTap.allowedTouchTypes = [NSNumber(value: (ink.testingFinger ? UITouch.TouchType.direct : .pencil).rawValue)]
        pencilSelectionTap.isEnabled = false
        pencilSelectionTap.require(toFail: pencilSelectionPan)
        view.addGestureRecognizer(pencilSelectionTap)
        selectionOutline.fillColor = UIColor.systemBlue.withAlphaComponent(0.08).cgColor
        selectionOutline.strokeColor = UIColor.systemBlue.cgColor
        selectionOutline.lineDashPattern = [5, 4]
        paper.layer.addSublayer(selectionOutline)
        pan = UIPanGestureRecognizer(target: self, action: #selector(moveObjects(_:)))
        pan.delegate = self; pan.maximumNumberOfTouches = 1
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        paper.addGestureRecognizer(pan); scroll.panGestureRecognizer.require(toFail: pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(selectObject(_:)))
        tap.delegate = self; tap.cancelsTouchesInView = false
        tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        paper.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboard(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        palette.axis = .horizontal; palette.spacing = 4; palette.alignment = .center
        palette.backgroundColor = .secondarySystemBackground; palette.layer.cornerRadius = 14
        palette.layer.shadowColor = UIColor.black.cgColor; palette.layer.shadowOpacity = 0.15; palette.layer.shadowRadius = 8
        palette.isLayoutMarginsRelativeArrangement = true; palette.layoutMargins = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        palette.accessibilityIdentifier = "notes.object.actions"
        view.addSubview(palette)
        apply()
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        flush(); acceptsInkChanges = false; represented = [:]; representedInkObjects = []; renderedPage = nil; loadedPageInk = nil
        apply()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let resized = scroll.frame != view.bounds
        if resized { scroll.frame = view.bounds }
        if resized || usesPrayerPreviewFit {
            if usesPrayerPreviewFit, let page = session.note?.page {
                layoutPrayerPreviewFit(page: page)
            } else {
                fitIfNeeded()
                centerPage()
            }
            updateViewport()
        }
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); apply(); showTools() }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { paper }
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // PKCanvasView is also a UIScrollView. Its synchronized viewport must never
        // drive the document viewport back through this delegate.
        guard scrollView === scroll else { return }
        guard isCanvas else {
            if usesPrayerPreviewFit, let page = session.note?.page {
                layoutFixedPagePaperFrame()
                scroll.contentOffset.x = prayerPreviewLockedOffsetX(for: page)
                updateViewport()
                return
            }
            layoutFixedPage(); updateViewport(); return
        }
        session.zoom = scrollView.zoomScale; centerPage(); updateViewport()
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // See scrollViewDidZoom(_:). Without this identity check, setting the live
        // ink viewport's contentOffset recurses through UIScrollView callbacks.
        guard scrollView === scroll else { return }
        if !isCanvas, !allowsHorizontalPan {
            let locked: CGFloat
            if usesPrayerPreviewFit, let page = session.note?.page {
                locked = prayerPreviewLockedOffsetX(for: page)
            } else {
                locked = horizontalRestingOffset()
            }
            if abs(scroll.contentOffset.x - locked) > 0.5 { scroll.contentOffset.x = locked }
        }
        updateViewport()
    }
    private func updateViewport() {
        let visible = scroll.convert(scroll.bounds, to: paper)
        session.insertionPoint = CGPoint(x: visible.midX, y: visible.minY + min(visible.height * 0.4, 400))
        paper.visibleRect = visible
        updateInkViewport()
        positionPalette()
        if !applying, let note = session.note { updateObjectViews(note) }
    }
    private func updateInkViewport() {
        guard scroll.bounds.width > 0, scroll.bounds.height > 0 else { return }
        ink.frame = scroll.frame
        // v0.1.0 scroll sync. Freeze while the Pencil is down so live ink is not stretched mid-stroke.
        guard !usingPencil else { return }
        if ink.zoomScale != scroll.zoomScale { ink.setZoomScale(scroll.zoomScale, animated: false) }
        ink.contentSize = scroll.contentSize
        ink.contentInset = scroll.contentInset
        if ink.contentOffset != scroll.contentOffset { ink.contentOffset = scroll.contentOffset }
        #if DEBUG
        if ink.testingFinger && !PencilStrokeRefiner.simulatesPencil {
            scroll.accessibilityValue = isCanvas
                ? "\(ink.drawing.strokes.count) strokes; \(session.strokeSelection.count) selected strokes"
                : "Ink viewport \(Int(ink.bounds.width)) × \(Int(ink.bounds.height)); \(ink.drawing.strokes.count) strokes"
        }
        #endif
    }
    private func horizontalRestingOffset() -> CGFloat {
        let width = paper.bounds.width * max(scroll.zoomScale, 0.01)
        guard width > scroll.bounds.width else { return 0 }
        return (width - scroll.bounds.width) / 2
    }
    private var usesPrayerPreviewFit: Bool {
        prayerPreviewFitsContent && session.note?.kind == .prayer
    }

    private func prayerContentMaxY(on page: NotePage) -> CGFloat {
        var maxY = NotePageTypography.prayerBoardContentHeight(for: page, includesInkPadding: false)
        if !ink.drawing.bounds.isNull {
            maxY = max(maxY, ink.drawing.bounds.maxY + 32)
        }
        return maxY
    }

    private func prayerPreviewLockedOffsetX(for page: NotePage) -> CGFloat {
        let columnX = (page.width - NotePage.columnWidth) / 2
        return columnX * scroll.zoomScale
    }

    private func layoutPrayerPreviewFit(page: NotePage) {
        scroll.pinchGestureRecognizer?.isEnabled = false
        scroll.bouncesZoom = false
        scroll.isScrollEnabled = true
        scroll.alwaysBounceVertical = true
        scroll.alwaysBounceHorizontal = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = true
        guard scroll.bounds.width > 0, scroll.bounds.height > 0 else { return }
        let margin = prayerPreviewHorizontalMargin
        let scale = max(0.2, (scroll.bounds.width - margin * 2) / NotePage.columnWidth)
        scroll.minimumZoomScale = scale
        scroll.maximumZoomScale = scale
        if abs(scroll.zoomScale - scale) > 0.001 { scroll.setZoomScale(scale, animated: false) }
        ink.minimumZoomScale = scale
        ink.maximumZoomScale = scale
        layoutFixedPagePaperFrame()
        scroll.contentInset = .zero
        let lockedX = prayerPreviewLockedOffsetX(for: page)
        let maxY = max(0, scroll.contentSize.height - scroll.bounds.height)
        let lockedY = min(max(scroll.contentOffset.y, 0), maxY)
        scroll.contentOffset = CGPoint(x: lockedX, y: lockedY)
        session.zoom = scale
        scroll.backgroundColor = theme.palette.paper
        view.backgroundColor = theme.palette.paper
    }

    private func layoutFixedPagePaperFrame() {
        let pageWidth = paper.bounds.width
        let pageHeight = paper.bounds.height
        paper.frame = CGRect(origin: .zero, size: CGSize(width: pageWidth * scroll.zoomScale, height: pageHeight * scroll.zoomScale))
        scroll.contentSize = paper.frame.size
        if usesPrayerPreviewFit {
            scroll.contentInset.left = 0
            scroll.contentInset.right = 0
        } else {
            scroll.contentInset.left = max(0, (scroll.bounds.width - pageWidth * scroll.zoomScale) / 2)
        }
    }

    private func layoutFixedPage() {
        guard !isCanvas else { return }
        if usesPrayerPreviewFit, let page = session.note?.page {
            layoutPrayerPreviewFit(page: page)
            return
        }
        scroll.isScrollEnabled = true
        scroll.alwaysBounceVertical = true
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 1
        scroll.pinchGestureRecognizer?.isEnabled = false
        scroll.bouncesZoom = false
        ink.minimumZoomScale = 1
        ink.maximumZoomScale = 1
        if abs(scroll.zoomScale - 1) > 0.001 { scroll.setZoomScale(1, animated: false) }
        layoutFixedPagePaperFrame()
        let pageWidth = paper.bounds.width
        scroll.alwaysBounceHorizontal = false
        scroll.showsHorizontalScrollIndicator = allowsHorizontalPan && pageWidth > scroll.bounds.width + 1
        scroll.contentInset.left = max(0, (scroll.bounds.width - pageWidth) / 2)
        if allowsHorizontalPan {
            if appliedHorizontalPan != true {
                appliedHorizontalPan = true
                scroll.contentOffset.x = max(-scroll.contentInset.left, (pageWidth - scroll.bounds.width) / 2)
            }
        } else if appliedHorizontalPan != false {
            appliedHorizontalPan = false
            scroll.contentOffset.x = horizontalRestingOffset()
        }
        session.zoom = 1
    }
    private func centerPage() {
        if isCanvas {
            scroll.contentInset.left = max(0, (scroll.bounds.width - paper.bounds.width * scroll.zoomScale) / 2)
        } else {
            layoutFixedPage()
        }
    }
    private func fitIfNeeded() {
        guard scroll.bounds.width > 0, session.note != nil else { return }
        if usesPrayerPreviewFit {
            layoutFixedPage()
            updateViewport()
            return
        }
        guard !fitted else { return }
        fitted = true
        if isCanvas {
            zoomToContent()
        } else {
            scroll.setZoomScale(1, animated: false)
            layoutFixedPage()
        }
        updateViewport()
    }
    private func zoomToContent() {
        guard let note = session.note else { return }
        let rect = note.objects.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        if isCanvas, !rect.isNull {
            scroll.zoom(to: rect.insetBy(dx: -60, dy: -80), animated: false)
        } else {
            let width = isCanvas ? 760 : NotePage.columnWidth + 32
            scroll.setZoomScale(max(0.2, min(1, (scroll.bounds.width - 24) / width)), animated: false)
            let x: CGFloat = isCanvas ? 600 : (note.page?.width ?? 1200) / 2
            scroll.contentOffset = CGPoint(x: max(0, x * scroll.zoomScale - scroll.bounds.width / 2), y: 0)
        }

    }
    @objc private func keyboard(_ notification: Notification) {
        guard let rect = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        scroll.contentInset.bottom = max(0, view.bounds.maxY - view.convert(rect, from: nil).minY)
        if bodyText.isFirstResponder, let range = bodyText.selectedTextRange { reveal(bodyText.convert(bodyText.caretRect(for: range.end), to: paper).insetBy(dx: -20, dy: -30)) }
    }
    func close() {
        imageTasks.values.forEach { $0.cancel() }; imageTasks = [:]
        flush(); hideTools(); picker.removeObserver(ink); picker.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
    private func flush() {
        guard acceptsInkChanges, generation == session.surfaceGeneration, noteID == session.selectedNoteID else { return }
        let bytes = ink.drawing.dataRepresentation()
        if !ink.drawing.strokes.isEmpty || !lastInk.isEmpty {
            if bytes != lastInk {
                if isCanvas, let scene = canvasScene {
                    let owner = session.startsNewInkRegion ? nil : NoteCanvasInk.extensionOwner(in: session.note?.objects ?? [], selection: session.selection)
                    session.edit { $0.objects = scene.objects(after: ink.drawing, replacing: $0.objects, extending: owner) }
                    let savedObjects = session.note?.objects ?? []
                    if NoteCanvasInk.equivalent((try? NoteCanvasInk(objects: savedObjects))?.drawing ?? PKDrawing(), ink.drawing) {
                        session.startsNewInkRegion = false
                    } else {
                        session.retainRejectedInk(bytes)
                        session.notice = "This drawing could not be saved within the note limits. Your saved ink is preserved, and the unsaved drawing is retained for recovery. Use Note options → Recover unsaved drawing."
                    }
                    canvasScene = try? NoteCanvasInk(objects: savedObjects, traits: traitCollection, previous: scene)
                    representedInkObjects = savedObjects.filter { $0.kind == .ink }
                    // A rejected drawing must not be retried on every SwiftUI refresh.
                    if let scene = canvasScene, !NoteCanvasInk.equivalent(scene.drawing, ink.drawing) {
                        applying = true
                        ink.drawing = scene.drawing
                        applying = false
                    }
                } else { session.updatePageInk(bytes); loadedPageInk = session.note?.page?.ink }
                lastInk = ink.drawing.dataRepresentation()
            }
        }
    }
    private func hideTools() {
        picker.setVisible(false, forFirstResponder: ink); ink.resignFirstResponder()
        if #available(iOS 18.0, *) { ink.isDrawingEnabled = session.active }
    }
    private func showTools() {
        guard session.active, session.toolsVisible, view.window != nil else { return }
        if session.startsNewInkRegion, picker.selectedTool is PKLassoTool {
            picker.selectedTool = PKInkingTool(.pen, color: .black, width: 3)
            pencilSelecting = false; updateSelectionGestures()
        }
        view.endEditing(true); ink.becomeFirstResponder()
        picker.setVisible(true, forFirstResponder: ink)
        #if DEBUG
        // Pixel regression must not inherit a previous simulator tool/color selection.
        if ProcessInfo.processInfo.environment["SP013_NEUTRAL_INK"] == "1" {
            ink.tool = PKInkingTool(.pen, color: .black, width: 6)
        }
        #endif
    }
    func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
        // iPadOS 17's standard palette includes lasso. Ink remains fixed in this editor.
        if !isCanvas, toolPicker.selectedTool is PKLassoTool { ink.tool = PKInkingTool(.pen, color: .label, width: 3) }
        pencilSelecting = isCanvas && toolPicker.selectedTool is PKLassoTool
        if pencilSelecting { session.editsStrokes = true }
        pencilSelectionPan?.isEnabled = pencilSelecting && session.active
        pencilSelectionTap?.isEnabled = pencilSelecting && session.active
        updateSelectionGestures()
    }
    @available(iOS 18.0, *)
    func toolPickerSelectedToolItemDidChange(_ toolPicker: PKToolPicker) { toolPickerSelectedToolDidChange(toolPicker) }
    private func updateSelectionGestures() {
        let selecting = pencilSelecting || (ink.testingFinger && session.editsStrokes)
        pencilSelectionPan?.isEnabled = selecting && session.active
        pencilSelectionTap?.isEnabled = selecting && session.active
        ink.drawingGestureRecognizer.isEnabled = session.active && !selecting
        pan?.isEnabled = !(ink.testingFinger && selecting)
    }
    func scribbleInteraction(_ interaction: UIScribbleInteraction, shouldBeginAt location: CGPoint) -> Bool { false }
    private func configureTextInput(_ text: UITextView) {
        text.addInteraction(UIScribbleInteraction(delegate: self))
        for gesture in text.gestureRecognizers ?? [] {
            gesture.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        }
    }
    func apply() {
        guard isViewLoaded, let note = session.note, (note.kind == .canvas) == isCanvas else { hideTools(); return }
        let page = note.page ?? NotePage()
        view.backgroundColor = theme.palette.paper; view.tintColor = theme.palette.accent
        paper.backgroundColor = theme.palette.paper; paper.ruleColor = theme.palette.rule
        palette.backgroundColor = theme.palette.paper; palette.layer.borderWidth = 0.5
        palette.layer.borderColor = theme.palette.rule.cgColor
        bodyText.textColor = theme.palette.ink; bodyText.linkTextAttributes = [.foregroundColor: theme.palette.accent]
        placeholder.textColor = theme.palette.secondary
        bodyText.typingAttributes = NotePageTypography.attributes(ink: theme.palette.ink)
        applying = true; defer { applying = false }
        bodyText.isHidden = isCanvas
        quoteBars.isHidden = isCanvas
        placeholder.isHidden = isCanvas || note.kind == .prayer || !page.body.isEmpty
        let restoringSurface = noteID != note.id || generation != session.surfaceGeneration
        if restoringSurface {
            acceptsInkChanges = false; usingPencil = false; view.endEditing(true)
            if noteID != note.id { fitted = false }
            if noteID != note.id { rasters.removeAllObjects() }
            noteID = note.id; generation = session.surfaceGeneration
            objects.values.forEach { $0.removeFromSuperview() }; objects = [:]; represented = [:]
            renderedPage = nil; loadedPageInk = nil
            lastInk = Data([0]) // Force restoration, including an empty drawing after undo.
        }
        session.flushSurface = { [weak self] in self?.flush() }
        session.shareCanvas = { [weak self] in self?.shareCanvasImage() }
        session.setZoom = { [weak self] scale in
            guard let self, self.isCanvas else { return }
            if let scale { self.scroll.setZoomScale(scale, animated: false) } else { self.zoomToContent() }
            self.updateViewport()
        }
        session.endTyping = { [weak self] in self?.view.endEditing(true); self?.showTools() }
        paper.paper = note.paper
        if renderedPage?.body != page.body || renderedPage?.citations != page.citations || renderedPage?.attachments != page.attachments || renderedPage?.formatting != page.formatting {
            let attributed = attributedBody(page)
            if bodyText.text == page.body {
                // Keep UIKit's cursor, marked text and text-editing state while typing.
                let range = NSRange(location: 0, length: bodyText.textStorage.length)
                bodyText.textStorage.beginEditing()
                bodyText.textStorage.removeAttribute(.link, range: range)
                bodyText.textStorage.removeAttribute(.attachment, range: range)
                bodyText.textStorage.removeAttribute(.font, range: range)
                bodyText.textStorage.removeAttribute(.underlineStyle, range: range)
                bodyText.textStorage.removeAttribute(.strikethroughStyle, range: range)
                bodyText.textStorage.removeAttribute(.foregroundColor, range: range)
                bodyText.textStorage.removeAttribute(.paragraphStyle, range: range)
                attributed.enumerateAttributes(in: range) { attributes, range, _ in
                    bodyText.textStorage.addAttributes(attributes, range: range)
                }
                bodyText.textStorage.endEditing()
            } else {
                let selection = bodyText.selectedRange
                bodyText.attributedText = attributed
                bodyText.selectedRange = NSRange(location: min(selection.location, page.body.utf16.count), length: 0)
            }
            bodyText.typingAttributes = NotePageTypography.attributes(ink: theme.palette.ink)
            renderedPage = page
        }
        let columnX = (page.width - NotePage.columnWidth) / 2
        let textHeight = max(600, bodyText.sizeThatFits(CGSize(width: NotePage.columnWidth, height: .greatestFiniteMagnitude)).height + 80)
        bodyText.frame = CGRect(x: columnX, y: 64, width: NotePage.columnWidth, height: min(NoteDocument.extent - 64, textHeight))
        quoteBars.frame = bodyText.frame
        quoteBars.barColor = theme.palette.rule
        quoteBars.spans = page.formatting
        quoteBars.setNeedsDisplay()
        placeholder.frame = CGRect(x: columnX, y: 64, width: NotePage.columnWidth, height: 36)
        let needed = max(textHeight + 304, max(ink.drawing.bounds.isNull ? 0 : ink.drawing.bounds.maxY + 400, (note.objects.map(\.frame.maxY).max() ?? 0) + 400))
        if !isCanvas, needed > page.height { session.growPage(to: needed) }
        let size = isCanvas ? CGSize(width: NoteDocument.extent, height: NoteDocument.extent) : CGSize(width: page.width, height: max(page.height, min(NoteDocument.extent, ceil(needed / 400) * 400)))
        paper.bounds.size = size
        paper.frame = CGRect(origin: .zero, size: CGSize(width: size.width * scroll.zoomScale, height: size.height * scroll.zoomScale))
        scroll.contentSize = paper.frame.size
        updateInkViewport()
        if !usingPencil {
            if isCanvas {
                let inkObjects = note.objects.filter { $0.kind == .ink }
                if restoringSurface || inkObjects != representedInkObjects {
                do {
                    let scene = try NoteCanvasInk(objects: note.objects, traits: traitCollection, previous: canvasScene)
                    if !NoteCanvasInk.equivalent(ink.drawing, scene.drawing) { ink.drawing = scene.drawing }
                    canvasScene = scene; representedInkObjects = inkObjects; lastInk = ink.drawing.dataRepresentation()
                } catch { session.report(error) }
                }
            } else if loadedPageInk != page.ink {
                ink.drawing = NoteInkAppearance.canonicalDrawing(page.ink.isEmpty ? PKDrawing() : (try? PKDrawing(data: page.ink)) ?? PKDrawing())
                loadedPageInk = page.ink; lastInk = ink.drawing.dataRepresentation()
            }
        }
        if restoringSurface { ink.undoManager?.removeAllActions() }
        publishRefinementAccessibility()
        updateObjectViews(note)
        view.bringSubviewToFront(ink); view.bringSubviewToFront(palette)
        ink.isUserInteractionEnabled = session.active; bodyText.isEditable = session.active
        updateSelectionGestures()
        if isCanvas { ink.layer.opacity = usingPencil ? 1 : 0 }
        ink.accessibilityLabel = isCanvas ? "Canvas drawings" : "Page annotations"
        if !session.active { flush(); hideTools(); view.endEditing(true) }
        if session.active && !wasActive { showTools() }; wasActive = session.active
        if toolsRequest != session.toolsRequest { toolsRequest = session.toolsRequest; if session.toolsVisible { showTools() } else { hideTools() } }
        updateStrokeOutline()
        fitIfNeeded(); centerPage(); updatePalette(); updateViewport(); updateObjectViews(note)
        if focus != session.focusRequest {
            focus = session.focusRequest
            if let id = session.selection.first {
                if let object = objects[id] {
                    reveal(object.frame)
                    if session.mode == .text { (object as? UITextView)?.becomeFirstResponder() }
                } else if let attachment = page.attachments.first(where: { $0.id == id }) {
                    let range = bodyText.layoutManager.glyphRange(forCharacterRange: NSRange(location: attachment.location, length: 1), actualCharacterRange: nil)
                    reveal(bodyText.convert(bodyText.layoutManager.boundingRect(forGlyphRange: range, in: bodyText.textContainer), to: paper))
                }
            }
        }
    }

    private func updateObjectViews(_ note: NoteDocument, includeAll: Bool = false) {
        guard !updatingObjects else { return }
        updatingObjects = true; defer { updatingObjects = false }
        let visible = scroll.convert(scroll.bounds, to: paper).insetBy(dx: -256, dy: -256)
        let mounted = note.objects.filter {
            !isCanvas || includeAll || preparingShare || $0.frame.insetBy(dx: -32, dy: -32).intersects(visible) ||
                session.selection.contains($0.id) || session.editingObjectID == $0.id
        }
        let ids = Set(mounted.map(\.id))
        for id in Array(objects.keys) where !ids.contains(id) {
            imageTasks.removeValue(forKey: id)?.cancel()
            objects.removeValue(forKey: id)?.removeFromSuperview(); represented[id] = nil
        }
        for object in mounted where isCanvas || object.kind != .ink {
            let item = objects[object.id] ?? make(object)
            if objects[object.id] == nil { objects[object.id] = item; paper.insertSubview(item, belowSubview: ink) }
            item.isHidden = false
            item.frame = object.frame
            let selected = session.selection.contains(object.id)
            item.layer.borderColor = (selected ? UIColor.systemBlue : UIColor.separator).cgColor
            item.layer.borderWidth = selected ? 1 / scroll.zoomScale : 0
            item.accessibilityLabel = object.kind == .shape ? (object.shape ?? .roundedRectangle).title : object.label
            item.accessibilityTraits = selected ? [.selected] : []
            if object.kind == .link { item.accessibilityValue = object.payload.isEmpty ? "Website link" : "Thumbnail available" }
            item.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "Select object") { [weak self] _ in
                self?.session.selection = [object.id]; self?.session.mode = .select; self?.apply(); return true
            }]
            if let text = item as? UITextView {
                text.isEditable = selected && session.mode == .text && session.active
                text.isSelectable = text.isEditable; text.isUserInteractionEnabled = text.isEditable
                text.textColor = theme.palette.ink
                text.backgroundColor = object.tint?.color.withAlphaComponent(0.25) ?? .clear
                text.font = object.monospaced
                    ? UIFont.monospacedSystemFont(ofSize: object.fontSize, weight: .regular)
                    : .systemFont(ofSize: object.fontSize)
                if !text.isFirstResponder, text.text != object.text { text.text = object.text }
            } else if object.kind == .ink || represented[object.id] != object { render(object, in: item) }
            item.viewWithTag(701)?.removeFromSuperview()
            if selected, object.group == nil, !object.positionLocked {
                let size = min(min(item.bounds.width, item.bounds.height), max(10, 12 / scroll.zoomScale))
                let handle = UIView(frame: CGRect(x: item.bounds.width - size, y: item.bounds.height - size, width: size, height: size))
                handle.tag = 701; handle.backgroundColor = .systemBlue; handle.layer.cornerRadius = size / 2
                handle.isUserInteractionEnabled = false; item.addSubview(handle)
            }
            item.viewWithTag(702)?.removeFromSuperview()
            if object.positionLocked {
                let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
                lock.tag = 702; lock.tintColor = .secondaryLabel; lock.frame = CGRect(x: 6, y: 6, width: 16, height: 16)
                lock.isUserInteractionEnabled = false; item.addSubview(lock)
            }
            item.viewWithTag(703)?.removeFromSuperview()
            if !object.details.isEmpty {
                let caption = UILabel()
                caption.tag = 703
                caption.text = object.details
                caption.font = .systemFont(ofSize: 12)
                caption.textColor = theme.palette.secondary
                caption.numberOfLines = 2
                caption.frame = CGRect(x: 0, y: item.bounds.height + 2, width: item.bounds.width, height: 28)
                caption.autoresizingMask = [.flexibleWidth]
                item.addSubview(caption)
            }
            represented[object.id] = object; paper.bringSubviewToFront(item)
        }
    }

    private func attributedBody(_ page: NotePage) -> NSAttributedString {
        NotePageAttachments.attributed(page, palette: theme.palette)
    }
    private func reveal(_ rect: CGRect) {
        let z = scroll.zoomScale
        scroll.scrollRectToVisible(CGRect(x: rect.minX * z, y: rect.minY * z, width: min(rect.width * z, scroll.bounds.width), height: min(rect.height * z, scroll.bounds.height - scroll.contentInset.bottom)), animated: true)
    }
    private func make(_ object: NoteObject) -> UIView {
        if [.text, .bullets, .numbered].contains(object.kind) {
            let text = UITextView(); configureTextInput(text); text.delegate = self; text.backgroundColor = .clear
            text.textColor = .label; text.accessibilityIdentifier = "notes.text.\(object.id)"; return text
        }
        let item = UIView(); item.backgroundColor = .clear; item.isAccessibilityElement = true
        item.accessibilityIdentifier = "notes.object.\(object.kind.rawValue)"
        return item
    }
    private func cachedImage(for object: NoteObject, in item: UIView) -> UIImage? {
        if let cached = rasters.object(forKey: object.id as NSUUID), cached.matches(object) { return cached.image }
        guard !object.payload.isEmpty else { return nil }
        imageTasks[object.id]?.cancel()
        imageTasks[object.id] = Task { [weak self, weak item] in
            let decoded = await NoteImagePreparation.decode(object.payload)
            guard !Task.isCancelled, let self, let item, self.objects[object.id] === item,
                  self.represented[object.id] == object, let decoded else { return }
            let image = UIImage(cgImage: decoded.image)
            let cost = decoded.image.bytesPerRow * decoded.image.height + object.payload.count
            self.rasters.setObject(RasterEntry(object, image: image, frame: object.frame), forKey: object.id as NSUUID, cost: cost)
            self.imageTasks[object.id] = nil
            if let imageView = item.subviews.first as? UIImageView { imageView.image = image }
        }
        return nil
    }

    private func renderInk(_ object: NoteObject, in item: UIView) {
        item.backgroundColor = .clear
        guard let bounds = canvasScene?.localBounds(for: object), !bounds.isNull else {
            item.subviews.forEach { $0.removeFromSuperview() }; return
        }
        let visible = scroll.convert(scroll.bounds, to: paper).insetBy(dx: -128, dy: -128)
        let x = floor(visible.minX / 256) * 256, y = floor(visible.minY / 256) * 256
        let crop = CGRect(x: x - object.frame.minX, y: y - object.frame.minY,
                          width: ceil((visible.maxX - x) / 256) * 256,
                          height: ceil((visible.maxY - y) / 256) * 256)
        let rect = preparingShare ? bounds : bounds.intersection(crop)
        guard !rect.isNull, !rect.isEmpty else { item.subviews.forEach { $0.removeFromSuperview() }; return }
        let entry: RasterEntry
        if let cached = rasters.object(forKey: object.id as NSUUID), cached.matches(object), cached.frame == rect {
            if let image = item.subviews.first as? UIImageView, image.image === cached.image, image.frame == rect { return }
            entry = cached
        } else {
            guard let scaled = canvasScene?.localDrawing(for: object) else { return }
            let scale = min(2, 2048 / max(1, max(rect.width, rect.height)))
            let raster = NoteInkAppearance.image(scaled, from: rect, scale: scale, traits: theme.traits)
            entry = RasterEntry(object, image: raster, frame: rect)
            let cost = raster.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            rasters.setObject(entry, forKey: object.id as NSUUID, cost: cost + object.payload.count)
        }
        item.subviews.forEach { $0.removeFromSuperview() }
        let image = UIImageView(image: entry.image); image.frame = entry.frame; item.addSubview(image)
    }
    private func render(_ object: NoteObject, in item: UIView) {
        if object.kind == .ink { renderInk(object, in: item); return }
        item.subviews.forEach { $0.removeFromSuperview() }
        if object.kind == .image {
            let image = UIImageView(image: cachedImage(for: object, in: item)); image.contentMode = .scaleAspectFit
            image.frame = item.bounds; image.autoresizingMask = [.flexibleWidth, .flexibleHeight]; item.addSubview(image)
        } else if object.kind == .shape {
            item.backgroundColor = .clear
            let image = UIImageView(image: UIImage(systemName: (object.shape ?? .roundedRectangle).symbol))
            image.tintColor = (object.tint ?? .teal).color; image.contentMode = .scaleToFill
            image.frame = item.bounds; image.autoresizingMask = [.flexibleWidth, .flexibleHeight]; item.addSubview(image)
        } else if object.kind == .link {
            item.backgroundColor = theme.palette.paper; item.layer.cornerRadius = 12; item.clipsToBounds = true
            let image = UIImageView(image: cachedImage(for: object, in: item) ?? UIImage(systemName: "link"))
            image.tintColor = .tertiaryLabel; image.contentMode = object.payload.isEmpty ? .scaleAspectFit : .scaleAspectFill; image.clipsToBounds = true
            image.frame = CGRect(x: 0, y: 0, width: item.bounds.width, height: max(40, item.bounds.height - 80)); image.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            let label = UILabel(); label.numberOfLines = 2; label.font = .systemFont(ofSize: 17, weight: .semibold); label.textColor = theme.palette.ink
            label.text = object.text == object.url ? URL(string: object.url)?.host : object.text
            label.frame = CGRect(x: 12, y: item.bounds.height - 76, width: item.bounds.width - 24, height: 44); label.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
            let host = UILabel(); host.text = URL(string: object.url)?.host; host.font = .systemFont(ofSize: 13); host.textColor = theme.palette.secondary
            host.frame = CGRect(x: 12, y: item.bounds.height - 28, width: item.bounds.width - 24, height: 20); host.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
            item.addSubview(image); item.addSubview(label); item.addSubview(host)
        } else {
            let label = UILabel(); label.numberOfLines = 0; label.font = .systemFont(ofSize: object.fontSize); label.textColor = theme.palette.ink
            switch object.kind {
            case .quote: label.text = [object.quote?.source, object.quote?.reference, object.quote?.editionLabel, object.text].compactMap { $0 }.joined(separator: "\n\n")
            case .table: label.font = .monospacedSystemFont(ofSize: 18, weight: .regular); label.text = object.cells.map { $0.map { $0.isEmpty ? "—" : $0 }.joined(separator: "  │  ") }.joined(separator: "\n─────────────\n")
            case .link: label.text = "↗ " + object.text + "\n" + object.url; label.textColor = theme.palette.accent
            case .sticker: label.text = object.text; label.textAlignment = .center; label.font = .systemFont(ofSize: min(item.bounds.width, item.bounds.height) * 0.65)
            default: label.text = object.text
            }
            label.frame = item.bounds.insetBy(dx: 12, dy: 12); label.autoresizingMask = [.flexibleWidth, .flexibleHeight]; item.addSubview(label)
        }
    }
    private func updatePalette() {
        if isCanvas, !session.strokeSelection.isEmpty {
            updateStrokePalette(); return
        }
        guard let note = session.note, let id = session.selection.first, let object = note.objects.first(where: { $0.id == id }) else {
            palette.isHidden = true; paletteKey = ""; return
        }
        let key = "\(session.selection.sorted { $0.uuidString < $1.uuidString })|\(session.renderRevision)|\(session.selectingMultiple)|\(object.positionLocked)|\(object.details)|\(Int(object.fontSize))|\(object.monospaced)"
        if key != paletteKey {
            paletteKey = key
            palette.arrangedSubviews.forEach { palette.removeArrangedSubview($0); $0.removeFromSuperview() }
            func action(_ title: String, _ symbol: String, _ handler: @escaping () -> Void) -> UIAction {
                UIAction(title: title, image: UIImage(systemName: symbol)) { [weak self] _ in handler(); self?.paletteKey = ""; self?.apply() }
            }
            func button(_ title: String, _ symbol: String?, _ visibleTitle: String?, _ destructive: Bool, _ handler: (() -> Void)?) -> UIButton {
                let b = UIButton(type: .system)
                if let visibleTitle, !visibleTitle.isEmpty {
                    b.setTitle(visibleTitle, for: .normal)
                    b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
                } else if let symbol {
                    b.setImage(UIImage(systemName: symbol), for: .normal)
                }
                if destructive { b.tintColor = .systemRed }
                b.accessibilityLabel = title
                b.accessibilityIdentifier = "notes.action." + title.lowercased().replacingOccurrences(of: " ", with: ".")
                if let handler, let symbol {
                    b.addAction(action(title, symbol, handler), for: .touchUpInside)
                } else if let handler {
                    b.addAction(UIAction(title: title) { [weak self] _ in handler(); self?.paletteKey = ""; self?.apply() }, for: .touchUpInside)
                }
                b.widthAnchor.constraint(equalToConstant: visibleTitle == nil ? 42 : 48).isActive = true
                b.heightAnchor.constraint(equalToConstant: 40).isActive = true
                return b
            }
            func menuButton(_ title: String, _ symbol: String?, _ visibleTitle: String?, _ menu: UIMenu) -> UIButton {
                let b = button(title, symbol, visibleTitle, false, nil)
                b.menu = menu
                b.showsMenuAsPrimaryAction = true
                return b
            }
            if isCanvas {
                let context = CanvasObjectPaletteBuilder.Context(
                    presenter: self,
                    session: session,
                    object: object,
                    note: note,
                    refresh: { [weak self] in self?.paletteKey = ""; self?.apply() }
                )
                CanvasObjectPaletteBuilder.fill(palette, context: context, action: action, button: button, menuButton: menuButton)
                palette.arrangedSubviews.last?.accessibilityIdentifier = "notes.action.more"
            } else {
                if session.selection.count == 1, object.kind != .ink {
                    palette.addArrangedSubview(button("Edit", "pencil", nil, false) { [weak self] in
                        guard let self else { return }
                        if [.text, .bullets, .numbered].contains(object.kind) { self.session.mode = .text; self.session.focusRequest = UUID() }
                        else { self.session.editingObjectID = id }
                    })
                }
                palette.addArrangedSubview(button("Duplicate", "plus.square.on.square", nil, false) { [weak self] in self?.session.duplicateSelection() })
                palette.addArrangedSubview(button("Delete", "trash", nil, true) { [weak self] in self?.session.remove() })
                let more = menuButton("More", "ellipsis", nil, UIMenu(children: [
                    action("Bring to front", "square.3.layers.3d.top.filled") { [weak self] in self?.session.reorder(id, front: true) },
                    action("Send to back", "square.3.layers.3d.bottom.filled") { [weak self] in self?.session.reorder(id, front: false) },
                ]))
                more.accessibilityIdentifier = "notes.action.more"
                palette.addArrangedSubview(more)
            }
        }
        palette.isHidden = usingPencil || bodyText.isFirstResponder || objects.values.contains { $0.isFirstResponder } || !session.active || session.selection.isEmpty
        positionPalette()
    }
    private func updateStrokeOutline(offset: CGSize = .zero) {
        guard isCanvas, selectionPoints.isEmpty else { return }
        let bounds = canvasScene?.strokeIndex.bounds(of: session.strokeSelection) ?? .null
        selectionOutline.path = bounds.isNull ? nil : UIBezierPath(rect: bounds.offsetBy(dx: offset.width, dy: offset.height).insetBy(dx: -4, dy: -4)).cgPath
        selectionOutline.lineWidth = 1 / max(0.2, scroll.zoomScale)
    }
    private func updateStrokePalette() {
        let key = "strokes|\(session.strokeSelection)|\(session.renderRevision)"
        if paletteKey != key {
            paletteKey = key
            palette.arrangedSubviews.forEach { palette.removeArrangedSubview($0); $0.removeFromSuperview() }
            func button(_ title: String, _ symbol: String, _ handler: @escaping () -> Void) -> UIButton {
                let button = UIButton(type: .system)
                button.setImage(UIImage(systemName: symbol), for: .normal)
                button.accessibilityLabel = title
                button.accessibilityIdentifier = "notes.strokes." + title.lowercased().replacingOccurrences(of: " ", with: ".")
                button.widthAnchor.constraint(equalToConstant: 42).isActive = true
                button.heightAnchor.constraint(equalToConstant: 40).isActive = true
                button.addAction(UIAction { [weak self] _ in handler(); self?.paletteKey = ""; self?.apply() }, for: .touchUpInside)
                return button
            }
            let color = button("Color", "paintpalette.fill") {}
            color.menu = UIMenu(children: NoteTint.allCases.map { tint in
                UIAction(title: tint.rawValue.capitalized) { [weak self] _ in
                    self?.session.colorSelectedStrokes(tint.color); self?.paletteKey = ""; self?.apply()
                }
            }); color.showsMenuAsPrimaryAction = true
            palette.addArrangedSubview(color)
            palette.addArrangedSubview(button("Copy", "doc.on.doc") { [weak self] in self?.session.copySelection() })
            palette.addArrangedSubview(button("Duplicate", "plus.square.on.square") { [weak self] in self?.session.duplicateSelection() })
            let delete = button("Delete", "trash") { [weak self] in self?.session.remove() }
            delete.tintColor = .systemRed; palette.addArrangedSubview(delete)
            palette.addArrangedSubview(button("Select drawing", "square.dashed") { [weak self] in
                guard let self else { return }
                let ids = Set(self.session.strokeSelection.map(\.objectID))
                self.session.editsStrokes = false; self.session.selection = ids
            })
        }
        palette.isHidden = usingPencil || !session.active || session.strokeSelection.isEmpty
        positionPalette()
    }
    private func positionPalette() {
        guard !palette.isHidden, let note = session.note else { return }
        let rect = session.strokeSelection.isEmpty
            ? note.objects.filter { session.selection.contains($0.id) }.map(\.frame).reduce(CGRect.null) { $0.union($1) }
            : canvasScene?.strokeIndex.bounds(of: session.strokeSelection) ?? .null
        guard !rect.isNull else { return }
        let target = paper.convert(rect, to: view)
        let size = palette.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let y = target.minY >= size.height + 12 ? target.minY - size.height - 8 : target.maxY + 8
        palette.frame = CGRect(x: max(8, min(view.bounds.width - size.width - 8, target.midX - size.width / 2)), y: max(8, min(view.bounds.height - size.height - 100, y)), width: size.width, height: size.height)
    }
    private func objectID(_ view: UIView) -> UUID? { objects.first { $0.value === view }?.key }
    private func hit(_ point: CGPoint) -> NoteObject? {
        let strokeHit = isCanvas ? canvasScene?.strokeIndex.hit(at: point, tolerance: 6 / max(0.2, scroll.zoomScale)) : nil
        return session.note?.objects.reversed().first {
            guard isCanvas || $0.kind != .ink else { return false }
            if $0.kind == .ink { return strokeHit?.objectID == $0.id }
            return $0.frame.contains(point)
        }
    }
    @objc private func selectObject(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: paper)
        if isCanvas, session.editsStrokes, hit(point)?.kind == .ink {
            view.endEditing(true); session.selection = []
            if let ref = canvasScene?.strokeIndex.hit(at: point, tolerance: 6 / max(0.2, scroll.zoomScale)) {
                if session.selectingMultiple {
                    if session.strokeSelection.contains(ref) { session.strokeSelection.remove(ref) }
                    else { session.strokeSelection.insert(ref) }
                } else { session.strokeSelection = [ref] }
            }
            session.mode = .select; apply(); return
        }
        session.strokeSelection = []
        // The keyboard may scroll the page before this recognizer ends.
        // Resolve the target captured at touch-down, not its shifted final position.
        if let offset = bodyTapOffset {
            if let attachment = session.note?.page?.attachments.first(where: { $0.location == offset }) {
                view.endEditing(true)
                if attachment.object.kind == .audio { playAudio(attachment.object.payload) }
                else { session.editingObjectID = attachment.id }
            } else if let citation = session.note?.page?.citations.first(where: { NSLocationInRange(offset, NSRange(location: $0.location, length: $0.length)) }) {
                view.endEditing(true); openCitation(citation.quote)
            } else if offset < bodyText.textStorage.length,
                      let link = bodyText.textStorage.attribute(.link, at: offset, effectiveRange: nil),
                      let url = (link as? URL) ?? URL(string: String(describing: link)),
                      ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(url)
            } else {
                hideTools(); bodyText.becomeFirstResponder()
            }
            session.selection = []; return
        }
        if let object = hit(point), session.selection.contains(object.id), !session.selectingMultiple {
            if [.text, .bullets, .numbered].contains(object.kind) {
                session.mode = .text; session.focusRequest = UUID(); apply(); return
            }
            if let quote = object.quote { openCitation(quote); return }
            if object.kind == .link, let url = URL(string: object.url) { UIApplication.shared.open(url); return }
        }
        if let object = hit(point), let text = objects[object.id] as? UITextView, text.isFirstResponder { return }
        view.endEditing(true)
        if let object = hit(point) {
            if session.selectingMultiple { if session.selection.contains(object.id) { session.selection.remove(object.id) } else { session.selection.insert(object.id) } }
            else { session.selection = [object.id] }
            session.mode = .select
        }
        else { session.selection = [] }
        apply()
    }
    @objc private func selectWithPencil(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: paper)
        if gesture.state == .began {
            dragStart = point
            let ref = canvasScene?.strokeIndex.hit(at: point, tolerance: 6 / max(0.2, scroll.zoomScale))
            draggingStrokeSelection = session.editsStrokes && ref.map { session.strokeSelection.contains($0) } == true && hit(point)?.positionLocked == false
            selectionPoints = draggingStrokeSelection ? [] : [point]
        }
        if draggingStrokeSelection {
            let delta = CGSize(width: point.x - dragStart.x, height: point.y - dragStart.y)
            if gesture.state == .ended { session.move(delta); draggingStrokeSelection = false; apply() }
            else if gesture.state == .cancelled || gesture.state == .failed { draggingStrokeSelection = false; apply() }
            else { palette.isHidden = true; updateStrokeOutline(offset: delta) }
            return
        }
        if gesture.state != .began { selectionPoints.append(point) }
        let path = CGMutablePath()
        if let first = selectionPoints.first {
            path.move(to: first)
            for point in selectionPoints.dropFirst() { path.addLine(to: point) }
            path.closeSubpath()
        }
        selectionOutline.path = path
        if gesture.state == .ended {
            if session.editsStrokes {
                session.selection = []
                session.strokeSelection = canvasScene?.strokeIndex.selected(inside: selectionPoints) ?? []
            } else {
                session.strokeSelection = []
                session.selection = session.note?.objectsInside(selectionPoints) ?? []
            }
            session.mode = .select
            selectionOutline.path = nil
            selectionPoints = []
            apply()
        } else if gesture.state == .cancelled || gesture.state == .failed {
            selectionOutline.path = nil
            selectionPoints = []
        }
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === pan { objectTouchPoint = touch.location(in: paper) }
        if gestureRecognizer is UITapGestureRecognizer {
            let point = touch.location(in: paper)
            bodyTapOffset = nil
            if !isCanvas, bodyText.frame.contains(point), hit(point) == nil,
               let position = bodyText.closestPosition(to: touch.location(in: bodyText)) {
                bodyTapOffset = bodyText.offset(from: bodyText.beginningOfDocument, to: position)
            }
        }
        return true
    }
    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard gesture === pan else { return true }
        let point = objectTouchPoint
        if !session.strokeSelection.isEmpty {
            guard let ref = canvasScene?.strokeIndex.hit(at: point, tolerance: 6 / max(0.2, scroll.zoomScale)),
                  session.strokeSelection.contains(ref), let object = hit(point), !object.positionLocked else { return false }
            return true
        }
        guard let object = hit(point), session.selection.contains(object.id), !object.positionLocked else { return false }
        if let text = objects[object.id] as? UITextView, text.isFirstResponder { return false }
        return true
    }
    @objc private func moveObjects(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: paper)
        switch gesture.state {
        case .began:
            palette.isHidden = true
            // A corner drag can leave the object before the pan reaches its threshold.
            // Choose the handle from touch-down rather than the recognition position.
            dragStart = objectTouchPoint
            if session.strokeSelection.isEmpty, let object = hit(dragStart), !object.positionLocked, object.group == nil,
               dragStart.x > object.frame.maxX - max(30, 36 / scroll.zoomScale), dragStart.y > object.frame.maxY - max(30, 36 / scroll.zoomScale) {
                resizeID = object.id; originalSize = object.frame.size
            } else { resizeID = nil }
        case .changed:
            if !session.strokeSelection.isEmpty {
                updateStrokeOutline(offset: CGSize(width: point.x - dragStart.x, height: point.y - dragStart.y))
            } else if let id = resizeID, let item = objects[id] {
                item.frame.size = CGSize(width: max(40, originalSize.width + point.x - dragStart.x), height: max(40, originalSize.height + point.y - dragStart.y))
            } else if var preview = session.note {
                preview.move(session.selection, by: CGSize(width: point.x - dragStart.x, height: point.y - dragStart.y))
                for object in preview.objects { objects[object.id]?.frame = object.frame }
            }
        case .ended:
            if let id = resizeID { session.resize(id, width: originalSize.width + point.x - dragStart.x, height: originalSize.height + point.y - dragStart.y) }
            else { session.move(CGSize(width: point.x - dragStart.x, height: point.y - dragStart.y)) }
            resizeID = nil; apply()
        case .cancelled, .failed: resizeID = nil; apply()
        default: break
        }
    }
    func textViewDidBeginEditing(_ textView: UITextView) { hideTools(); palette.isHidden = true }
    func textViewDidChangeSelection(_ textView: UITextView) {
        if textView === bodyText { session.bodySelection = textView.selectedRange }
        else if let id = objectID(textView) { session.sophyCanvasSelection = (id, textView.selectedRange) }
    }
    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        guard range.length > 0, session.onSophyEnhance != nil else { return UIMenu(children: suggestedActions) }
        let id = textView === bodyText ? nil : objectID(textView)
        guard textView === bodyText || id != nil else { return UIMenu(children: suggestedActions) }
        let enhance = UIAction(title: "Enhance with Sophy", image: UIImage(systemName: "sparkles")) { [weak self] _ in
            guard let self, let selection = self.session.sophySelection(range: range, objectID: id) else { return }
            self.session.onSophyEnhance?(selection)
        }
        return UIMenu(children: suggestedActions + [enhance])
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let limit = textView === bodyText ? 100_000 : 20_000
        guard textView.text.count - range.length + text.count <= limit else { return false }
        if textView === bodyText {
            var candidate = session.note?.page ?? NotePage()
            candidate.replace(range, with: text)
            if NotePageTypography.height(of: candidate) > NoteDocument.extent - 400 {
                session.notice = "This page has reached its length limit. Start another note to keep all text reachable."
                return false
            }
            bodyEdit = (range, text)
        }
        return true
    }
    func textViewDidChange(_ textView: UITextView) {
        guard !applying, noteID == session.selectedNoteID else { return }
        if textView === bodyText {
            if let (range, text) = bodyEdit { session.replaceBody(range, with: text) }
            else if let old = session.note?.page?.body { session.replaceBody(NSRange(location: 0, length: old.utf16.count), with: textView.text) }
            bodyEdit = nil; session.bodySelection = textView.selectedRange
        } else if let id = objectID(textView) { session.update(id) { $0.text = textView.text } }
        apply()
    }
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if let citation = session.note?.page?.citations.first(where: { URL.absoluteString == "sophia-citation:\($0.id)" }) { openCitation(citation.quote) }
        else if ["https", "http"].contains(URL.scheme?.lowercased() ?? "") { UIApplication.shared.open(URL) }
        return false
    }
    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        strokeRefiner.beginStroke()
        updateInkViewport()
        acceptsInkChanges = true; usingPencil = true; palette.isHidden = true
        // End text editing without resigning the active PencilKit responder mid-stroke.
        if bodyText.isFirstResponder { bodyText.resignFirstResponder() }
        for object in objects.values where object.isFirstResponder { object.resignFirstResponder() }
        if isCanvas { ink.layer.opacity = 1; for object in session.note?.objects ?? [] where object.kind == .ink { objects[object.id]?.isHidden = true } }
        if session.note?.kind == .prayer || session.toolsVisible {
            showTools()
        }
    }
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        usingPencil = false
        if let refined = strokeRefiner.finishStroke() {
            let original = ink.drawing
            let previous = refinementStatus
            refinementStatus = strokeRefiner.lastKind.map { "refined \($0.label)" } ?? "rough"
            ink.undoManager?.registerUndo(withTarget: self) { target in target.replaceInkDrawing(original, status: previous) }
            applying = true
            ink.drawing = refined
            applying = false
        } else if PencilStrokeRefiner.simulatesPencil {
            refinementStatus = "rough"
        }
        updateInkViewport()
        flush(); apply()
        if session.note?.kind == .prayer || session.toolsVisible { showTools() }
    }
    private func replaceInkDrawing(_ drawing: PKDrawing, status: String) {
        let current = ink.drawing
        let previous = refinementStatus
        ink.undoManager?.registerUndo(withTarget: self) { target in target.replaceInkDrawing(current, status: previous) }
        refinementStatus = status
        ink.drawing = drawing; flush(); apply()
    }
    private func shareCanvasImage() {
        Task { [weak self] in await self?.prepareCanvasShare() }
    }
    private func prepareCanvasShare() async {
        guard isCanvas, session.active, !preparingShare else { return }
        preparingShare = true
        defer { preparingShare = false; if let current = session.note { updateObjectViews(current) } }
        flush()
        guard let note = session.note else { return }
        updateObjectViews(note, includeAll: true)
        let revision = session.renderRevision
        let pending = Array(imageTasks.values)
        for task in pending { await task.value }
        guard session.note?.id == note.id, session.renderRevision == revision, session.active else { return }
        let content = note.objects.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        let bounds = content.isNull ? CGRect(x: 0, y: 0, width: 760, height: 1000) : content.insetBy(dx: -32, dy: -32).intersection(paper.bounds)
        guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { return }
        let scale = min(1, 2048 / max(bounds.width, bounds.height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: bounds.width * scale, height: bounds.height * scale), format: format).image { renderer in
            theme.palette.paper.setFill()
            renderer.fill(CGRect(origin: .zero, size: CGSize(width: bounds.width * scale, height: bounds.height * scale)))
            renderer.cgContext.scaleBy(x: scale, y: scale)
            renderer.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            let path = selectionOutline.path; selectionOutline.path = nil
            paper.layer.render(in: renderer.cgContext)
            selectionOutline.path = path
        }
        let sheet = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: 20, width: 1, height: 1)
        present(sheet, animated: true)
    }
    private func playAudio(_ data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            session.notice = "That audio could not be played."
        }
    }
    private func publishRefinementAccessibility() {
        let count = "\(ink.drawing.strokes.count) strokes"
        #if DEBUG
        if PencilStrokeRefiner.simulatesPencil {
            ink.isAccessibilityElement = true
            let described = "\(count); \(refinementStatus)"
            ink.accessibilityValue = described
            scroll.accessibilityValue = described
            return
        }
        #endif
        ink.accessibilityValue = count
        if isCanvas, ink.testingFinger {
            ink.isAccessibilityElement = true
            let value = "\(count); \(session.strokeSelection.count) selected strokes"
            ink.accessibilityValue = value; scroll.accessibilityValue = value
        }
    }
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !applying, !usingPencil else { return }
        flush(); if isCanvas { apply() }; publishRefinementAccessibility()
    }
}

private final class NotePaperView: UIView {
    private let grid = CAShapeLayer()
    var ruleColor = UIColor.separator { didSet { if oldValue != ruleColor { updateGrid() } } }
    var visibleRect = CGRect.zero { didSet { if oldValue != visibleRect { updateGrid() } } }
    var paper = NoteDocument.Paper.plain { didSet { if oldValue != paper { updateGrid() } } }
    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = .systemBackground
        grid.lineWidth = 0.5; layer.addSublayer(grid)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) { super.traitCollectionDidChange(previousTraitCollection); updateGrid() }
    private func updateGrid() {
        let color = ruleColor.withAlphaComponent(paper == .dotted ? 0.35 : 0.16).cgColor
        grid.strokeColor = paper == .dotted ? nil : color; grid.fillColor = paper == .dotted ? color : nil
        guard paper != .plain else { grid.path = nil; return }
        // Render only visible marks, even on the 12,000-point Canvas workspace.
        let rect = visibleRect.insetBy(dx: -64, dy: -64).intersection(bounds)
        guard !rect.isNull else { grid.path = nil; return }
        let path = CGMutablePath()
        for y in stride(from: floor(rect.minY / 32) * 32, through: rect.maxY, by: 32) {
            if paper == .dotted {
                for x in stride(from: floor(rect.minX / 32) * 32, through: rect.maxX, by: 32) { path.addEllipse(in: CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)) }
            } else { path.move(to: CGPoint(x: rect.minX, y: y)); path.addLine(to: CGPoint(x: rect.maxX, y: y)) }
        }
        if paper == .grid { for x in stride(from: floor(rect.minX / 32) * 32, through: rect.maxX, by: 32) { path.move(to: CGPoint(x: x, y: rect.minY)); path.addLine(to: CGPoint(x: x, y: rect.maxY)) } }
        CATransaction.begin(); CATransaction.setDisableActions(true); grid.path = path; CATransaction.commit()
    }
}
