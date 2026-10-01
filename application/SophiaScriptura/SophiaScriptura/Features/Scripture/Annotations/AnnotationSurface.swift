import SwiftUI
import PencilKit

struct AnnotationSurface: UIViewControllerRepresentable {
    let document: ChapterDocument
    let preferences: ReaderPreferences
    let reader: ReaderSession
    let session: AnnotationSession
    let stateToken: String
    var saveToNote: ((ChapterTextMap.Selection) -> Void)? = nil
    var saveBookmark: ((NSRange) -> Void)? = nil
    var saveGleaning: ((NSRange) -> Void)? = nil
    func makeUIViewController(context: Context) -> AnnotationController {
        AnnotationController(document: document, preferences: preferences, reader: reader, session: session)
    }
    func updateUIViewController(_ controller: AnnotationController, context: Context) {
        controller.preferences = preferences
        controller.saveToNote = saveToNote
        controller.saveBookmark = saveBookmark
        controller.saveGleaning = saveGleaning
        DispatchQueue.main.async { [weak controller] in controller?.apply() }
    }
    static func dismantleUIViewController(_ controller: AnnotationController, coordinator: ()) { controller.dispose() }
}

@MainActor final class AnnotationCanvas: PKCanvasView {
    private let history = UndoManager()
    override var undoManager: UndoManager? { history }
}

@MainActor final class AnnotationController: UIViewController, UIScrollViewDelegate, PKCanvasViewDelegate {
    let document: ChapterDocument
    var preferences: ReaderPreferences
    private let reader: ReaderSession
    private let session: AnnotationSession
    private let openedGeneration: Int
    private let viewport = UIScrollView()
    private let paper = UIView()
    private let text = ContinuousReaderTextView()
    private let stage = UIView()
    private var expanded: Bool?
    private let picker = PKToolPicker()
    private var coordinator: ReaderTextSurface.Coordinator?
    private var canvases: [UUID: PKCanvasView] = [:]
    private var selectedCanvas: PKCanvasView?
    private var selectedID: UUID?
    private var layoutID: String?
    private var verifiedLayoutID: String?
    private var verifiedSource: AnnotationSource?
    private var drawingTokens: [UUID: Int] = [:]
    private var applying = false
    private var pickerVisible = false
    private var pickerActive = false
    private var navigationID: UUID?
    var saveToNote: ((ChapterTextMap.Selection) -> Void)?
    var saveBookmark: ((NSRange) -> Void)?
    var saveGleaning: ((NSRange) -> Void)?
    private var renderKey = ""
    private var matched = false
    private var lastMode: AnnotationSession.Mode?
    init(document: ChapterDocument, preferences: ReaderPreferences, reader: ReaderSession, session: AnnotationSession) {
        self.document = document; self.preferences = preferences; self.reader = reader; self.session = session; openedGeneration = session.reopenGeneration
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Use document initializer") }
    override func viewDidLoad() {
        super.viewDidLoad()
        viewport.delegate = self; viewport.minimumZoomScale = 0.25; viewport.maximumZoomScale = 3
        viewport.contentInsetAdjustmentBehavior = .never
        viewport.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        viewport.accessibilityIdentifier = "annotation.viewport"
        view.addSubview(viewport); viewport.addSubview(stage); stage.addSubview(paper); stage.clipsToBounds = true
        text.isEditable = false; text.isScrollEnabled = false; text.backgroundColor = .clear
        text.textContainerInset = .zero; text.textContainer.lineFragmentPadding = 0
        text.textContainer.widthTracksTextView = true
        text.accessibilityIdentifier = "scripture.text"
        text.map = ChapterTextMap(document: document); text.authorizeQuote = reader.authorizeQuote
        text.textDragInteraction?.isEnabled = !document.isLicensed
        let parent = ReaderTextSurface(document: document, preferences: preferences, targetVerse: reader.targetVerse,
            navigationID: reader.navigationID, restorationLocation: reader.restorationLocation,
            onVerse: { [weak reader, document] verse in reader?.hubVerse = document.verse(verse) },
            onVisibleLocation: reader.visibleLocation, onChapterSwipe: { _ in }, authorizeQuote: reader.authorizeQuote)
        let delegate = ReaderTextSurface.Coordinator(parent); delegate.map = text.map
        coordinator = delegate; text.delegate = delegate
        text.externalReveal = { [weak self] range in self?.reveal(range) }
        paper.addSubview(text)
        session.flush = { [weak self] in self?.publish() }
        session.undo = { [weak self] in self?.selectedCanvas?.undoManager?.undo() }
        session.redo = { [weak self] in self?.selectedCanvas?.undoManager?.redo() }
        session.clear = { [weak self] in
            guard let self, let canvas = self.selectedCanvas else { return }
            self.replaceDrawing(canvas, with: PKDrawing())
        }
        apply()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews(); viewport.frame = view.bounds
        centerStage()
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); apply() }
    override func viewWillDisappear(_ animated: Bool) { stop(); super.viewWillDisappear(animated) }
    func stop() {
        publish(); picker.setVisible(false, forFirstResponder: selectedCanvas ?? text)
        if #available(iOS 26.0, *) { selectedCanvas?.pencilKitResponderState.toolPickerVisibility = .inactive }
        selectedCanvas?.resignFirstResponder(); pickerVisible = false; pickerActive = false
    }
    func dispose() {
        stop()
        canvases.values.forEach { picker.removeObserver($0); $0.delegate = nil; $0.undoManager?.removeAllActions() }
        text.delegate = nil; text.authorizeQuote = nil; text.externalReveal = nil
    }
    func apply() {
        guard isViewLoaded, session.reopenGeneration == openedGeneration, !session.usingTool,
              let group = session.group, let layout = session.selectedLayout else { return }
        let hidden = session.mode == .hidden
        viewport.isHidden = hidden
        viewport.accessibilityElementsHidden = hidden
        viewport.accessibilityIdentifier = hidden ? nil : "annotation.viewport"
        text.accessibilityIdentifier = hidden ? nil : "scripture.text"
        if hidden {
            if lastMode != .hidden { stop() }
            lastMode = .hidden
            return
        }
        if verifiedLayoutID != layout.signature || verifiedSource != group.source {
            matched = AnnotationRenderer.matches(layout, source: group.source, document: document)
            verifiedLayoutID = layout.signature
            verifiedSource = group.source
        }
        guard matched, let font = UIFont(name: layout.fontName, size: layout.fontSize) else { return }
        let dark = preferences.appearance == .midnightLibrary || preferences.theme == "dark" ||
            (preferences.theme == "system" && traitCollection.userInterfaceStyle == .dark)
        let palette = preferences.appearance.palette(dark: dark)
        if layoutID != layout.signature {
            stop()
            canvases.values.forEach { picker.removeObserver($0); $0.removeFromSuperview() }
            canvases.removeAll(); drawingTokens.removeAll(); selectedCanvas = nil; selectedID = nil
            layoutID = layout.signature
            paper.frame = CGRect(x: 0, y: 0, width: layout.width, height: layout.height)
            text.frame = CGRect(x: layout.inset, y: layout.inset, width: layout.textWidth, height: layout.height - layout.inset * 2)

        }
        // Typography comes exclusively from the captured layout; theme changes only colors.
        let key = "\(layout.signature)|\(preferences.appearance)|\(dark)"
        if key != renderKey {
            renderKey = key
            text.attributedText = AnnotationRenderer.text(document, font: font, palette: palette)
        }
        text.linkTextAttributes = [.foregroundColor: palette.accent]; text.tintColor = palette.accent
        text.focusColor = palette.accent.withAlphaComponent(0.18)
        paper.backgroundColor = palette.paper
        if expanded != session.marginExpanded {
            expanded = session.marginExpanded
            configureStage(layout)
        }
        if selectedID != session.selected?.id {
            publish(); selectedCanvas?.isHidden = true
            picker.setVisible(false, forFirstResponder: selectedCanvas ?? text)
            if #available(iOS 26.0, *) { selectedCanvas?.pencilKitResponderState.toolPickerVisibility = .inactive }
            selectedCanvas?.resignFirstResponder(); pickerVisible = false; pickerActive = false
            selectedID = session.selected?.id
            if let layer = session.selected {
                let canvas = canvases[layer.id] ?? makeCanvas(layer, color: palette.ink)
                canvases[layer.id] = canvas; selectedCanvas = canvas
            } else { selectedCanvas = nil }
        }
        let draw = session.selected != nil && session.mode == .draw && session.active
        text.isSelectable = !draw; text.isUserInteractionEnabled = !draw
        if let layer = session.selected, let canvas = selectedCanvas {
            if drawingTokens[layer.id] != layer.revision {
                applying = true
                if let drawing = try? PKDrawing(data: layer.drawing) { canvas.drawing = drawing }
                applying = false; drawingTokens[layer.id] = layer.revision
            }
            canvas.isHidden = session.mode == .hidden
            canvas.isUserInteractionEnabled = draw
            text.isSelectable = !draw; text.isUserInteractionEnabled = !draw
            let showTools = draw && session.toolsVisible
            if view.window != nil, pickerActive != draw || pickerVisible != showTools {
                pickerActive = draw; pickerVisible = showTools
                if draw {
                    canvas.becomeFirstResponder()
                    if #available(iOS 26.0, *) {
                        canvas.pencilKitResponderState.activeToolPicker = picker
                        canvas.pencilKitResponderState.toolPickerVisibility = showTools ? .visible : .hidden
                    } else { picker.setVisible(showTools, forFirstResponder: canvas) }
                } else {
                    if #available(iOS 26.0, *) { canvas.pencilKitResponderState.toolPickerVisibility = .inactive }
                    picker.setVisible(false, forFirstResponder: canvas)
                    canvas.resignFirstResponder()
                }
            }
        }
        if lastMode == .hidden && session.mode != .hidden, let range = text.map?.range(for: reader.targetVerse) { reveal(range) }
        lastMode = session.mode
        coordinator?.parent.saveToNote = saveToNote
        coordinator?.parent.saveBookmark = saveBookmark
        coordinator?.parent.saveGleaning = saveGleaning
        if navigationID != reader.navigationID {
            navigationID = reader.navigationID
            if let location = reader.restorationLocation, let id = location.blockID,
               let run = text.map?.runs.first(where: { $0.block.id == id }), let offset = location.utf16Offset {
                reveal(NSRange(location: run.range.location + min(offset, max(0, run.range.length - 1)), length: 1), focusAfter: false)
            } else if let range = text.map?.range(for: reader.targetVerse) {
                reveal(range, focusAfter: false)
            }
            if reader.emphasisSpans.isEmpty {
                text.focus(verse: reader.targetVerse)
            } else {
                text.focus(spans: reader.emphasisSpans, holds: true)
            }
        }
    }
    private func makeCanvas(_ layer: AnnotationLayer, color: UIColor) -> PKCanvasView {
        let canvas = AnnotationCanvas(frame: paper.bounds)
        canvas.backgroundColor = .clear; canvas.isOpaque = false; canvas.isScrollEnabled = false
        canvas.drawingPolicy = .pencilOnly; canvas.delegate = self
        canvas.tool = PKInkingTool(.pen, color: color, width: 2)
        applying = true; canvas.drawing = (try? PKDrawing(data: layer.drawing)) ?? PKDrawing(); applying = false
        canvas.accessibilityIdentifier = "annotation.canvas"
        paper.addSubview(canvas)
        if canvases.isEmpty { picker.selectedTool = PKInkingTool(.pen, color: color, width: 2) }
        picker.addObserver(canvas)
        drawingTokens[layer.id] = layer.revision
        return canvas
    }
    private func replaceDrawing(_ canvas: PKCanvasView, with drawing: PKDrawing) {
        let before = canvas.drawing
        canvas.undoManager?.registerUndo(withTarget: self) { target in target.replaceDrawing(canvas, with: before) }
        canvas.drawing = drawing; publish()
    }
    private func publish() {
        guard !applying, session.reopenGeneration == openedGeneration, let id = selectedID, let canvas = selectedCanvas else { return }
        session.updateDrawing(canvas.drawing.dataRepresentation(), layerID: id)
        drawingTokens[id] = session.group?.layers.first { $0.id == id }?.revision
    }
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { if canvasView === selectedCanvas { publish() } }
    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        session.beginStroke()
        if #available(iOS 26.0, *) { canvasView.pencilKitResponderState.toolPickerVisibility = .hidden }
        else { picker.setVisible(false, forFirstResponder: canvasView) }
        pickerVisible = false
        // Keep the picker active and canvas first responder while its UI is minimized.
    }
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        publish(); session.finishStroke(); Task { await session.save() }
    }
    private func configureStage(_ layout: AnnotationLayout) {
        let readingY: CGFloat? = viewport.contentOffset.y > 40 ? viewport.contentOffset.y / viewport.zoomScale - paper.frame.minY : nil
        viewport.setZoomScale(1, animated: false)
        let full = session.marginExpanded
        let crop = full ? 0 : layout.inset - 28
        paper.frame = CGRect(x: -crop, y: -crop, width: layout.width, height: layout.height)
        stage.bounds = CGRect(x: 0, y: 0, width: full ? layout.width : layout.textWidth + 56,
            height: full ? layout.height : layout.height - layout.inset * 2 + 68)
        stage.frame.size = stage.bounds.size
        viewport.contentSize = stage.bounds.size
        if full && viewport.bounds.width > 0 { viewport.setZoomScale(min(1, viewport.bounds.width / stage.bounds.width), animated: false) }
        centerStage()
        let y = readingY.map { max(0, min(viewport.contentSize.height - viewport.bounds.height,
                                      ($0 + paper.frame.minY) * viewport.zoomScale)) } ?? 0
        viewport.setContentOffset(CGPoint(x: 0, y: y), animated: false)
    }
    private func centerStage() {
        let size = stage.bounds.size
        stage.center = CGPoint(x: max(viewport.bounds.width, size.width * viewport.zoomScale) / 2,
                               y: size.height * viewport.zoomScale / 2)
    }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerStage() }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { stage }
    func reveal(_ range: NSRange, focusAfter: Bool = true) {
        text.layoutManager.ensureLayout(for: text.textContainer)
        let glyphs = text.layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = text.layoutManager.boundingRect(forGlyphRange: glyphs, in: text.textContainer)
        viewport.setContentOffset(CGPoint(x: 0, y: max(0, min(viewport.contentSize.height - viewport.bounds.height,
            (rect.minY + text.frame.minY + paper.frame.minY) * viewport.zoomScale - 20))), animated: false)
        if focusAfter { text.focus(verse: text.map?.verse(at: range.location) ?? reader.targetVerse) }
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isDragging || scrollView.isDecelerating, scrollView.zoomScale > 0 else { return }
        let point = CGPoint(x: 10, y: max(0, (scrollView.contentOffset.y + 20) / scrollView.zoomScale - text.frame.minY - paper.frame.minY))
        let glyph = text.layoutManager.glyphIndex(for: point, in: text.textContainer)
        guard glyph < text.layoutManager.numberOfGlyphs else { return }
        let offset = text.layoutManager.characterIndexForGlyph(at: glyph)
        if let verse = text.map?.verse(at: offset) {
            let run = text.map?.runs.first { $0.block.kind == "body" && NSLocationInRange(offset, $0.range) }
            reader.visibleLocation(verse, blockID: run?.block.id, utf16Offset: run.map { max(0, offset - $0.range.location) })
        }
    }
}
