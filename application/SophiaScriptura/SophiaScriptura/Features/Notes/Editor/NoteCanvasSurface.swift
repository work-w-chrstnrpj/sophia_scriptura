import SwiftUI
import PencilKit

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
    var openCitation: (NoteQuote) -> Void
    func makeUIViewController(context: Context) -> NotePageController { NotePageController(session: session, openCitation: openCitation) }
    func updateUIViewController(_ controller: NotePageController, context: Context) {
        let theme = theme
        DispatchQueue.main.async { [weak controller] in controller?.setTheme(theme); controller?.apply() }
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
        overrideUserInterfaceStyle = next.dark ? .dark : .light
        acceptsInkChanges = false; represented = [:]; renderedPage = nil; loadedPageInk = nil
    }
    private var canvasScene: NoteCanvasInk?
    private let session: NotesSession
    private let openCitation: (NoteQuote) -> Void
    private let scroll = UIScrollView(), paper = NotePaperView(), bodyText = UITextView()
    private let ink = NoteInkCanvas()
    private let placeholder = UILabel()
    private let picker: PKToolPicker
    private lazy var strokeRefiner = PencilStrokeRefiner(canvas: ink)
    private var objects: [UUID: UIView] = [:]
    private var represented: [UUID: NoteObject] = [:]
    private var noteID: UUID?, generation: UUID?, focus: UUID?, toolsRequest: UUID?
    private var applying = false, usingPencil = false, fitted = false, wasActive = false
    private var acceptsInkChanges = false
    private var refinementStatus = "rough"
    private var lastInk = Data()
    private var loadedPageInk: Data?
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
        scroll.delegate = self; scroll.minimumZoomScale = 0.2; scroll.maximumZoomScale = 2
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
        paper.addSubview(bodyText)
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
        flush(); acceptsInkChanges = false; represented = [:]; renderedPage = nil; loadedPageInk = nil
        apply()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if scroll.frame != view.bounds { scroll.frame = view.bounds; fitIfNeeded(); centerPage(); updateViewport() }
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); apply(); showTools() }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { paper }
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // PKCanvasView is also a UIScrollView. Its synchronized viewport must never
        // drive the document viewport back through this delegate.
        guard scrollView === scroll else { return }
        session.zoom = scrollView.zoomScale; centerPage(); updateViewport()
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // See scrollViewDidZoom(_:). Without this identity check, setting the live
        // ink viewport's contentOffset recurses through UIScrollView callbacks.
        guard scrollView === scroll else { return }
        updateViewport()
    }
    private func updateViewport() {
        let visible = scroll.convert(scroll.bounds, to: paper)
        session.insertionPoint = CGPoint(x: visible.midX, y: visible.minY + min(visible.height * 0.4, 400))
        paper.visibleRect = visible
        updateInkViewport()
        positionPalette()
    }
    private func updateInkViewport() {
        guard scroll.bounds.width > 0, scroll.bounds.height > 0 else { return }
        ink.frame = scroll.frame
        if ink.zoomScale != scroll.zoomScale { ink.setZoomScale(scroll.zoomScale, animated: false) }
        ink.contentSize = scroll.contentSize
        ink.contentInset = scroll.contentInset
        if ink.contentOffset != scroll.contentOffset { ink.contentOffset = scroll.contentOffset }
        #if DEBUG
        if ink.testingFinger && !PencilStrokeRefiner.simulatesPencil {
            scroll.accessibilityValue = "Ink viewport \(Int(ink.bounds.width)) × \(Int(ink.bounds.height)); \(ink.drawing.strokes.count) strokes"
        }
        #endif
    }
    private func centerPage() {
        scroll.contentInset.left = max(0, (scroll.bounds.width - paper.bounds.width * scroll.zoomScale) / 2)
    }
    private func fitIfNeeded() {
        guard !fitted, scroll.bounds.width > 0, let note = session.note else { return }
        fitted = true
        if isCanvas {
            zoomToContent()
        } else {
            scroll.setZoomScale(max(0.2, min(1, (scroll.bounds.width - 24) / (NotePage.columnWidth + 32))), animated: false)
            scroll.contentOffset.x = max(0, (note.page!.width * scroll.zoomScale - scroll.bounds.width) / 2)
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
        flush(); hideTools(); picker.removeObserver(ink); picker.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
    private func flush() {
        guard acceptsInkChanges, generation == session.surfaceGeneration, noteID == session.selectedNoteID else { return }
        let bytes = ink.drawing.dataRepresentation()
        if !ink.drawing.strokes.isEmpty || !lastInk.isEmpty {
            if bytes != lastInk {
                if isCanvas, let scene = canvasScene {
                    session.edit { $0.objects = scene.objects(after: ink.drawing, replacing: $0.objects, extending: session.selection.count == 1 ? session.selection.first : nil) }
                    // Rebuild ownership after every committed gesture, including newly created ink.
                    canvasScene = try? NoteCanvasInk(objects: session.note?.objects ?? [], traits: traitCollection)
                } else { session.updatePageInk(bytes); loadedPageInk = session.note?.page?.ink }
                lastInk = bytes
            }
        }
    }
    private func hideTools() {
        if #available(iOS 26.0, *) { ink.pencilKitResponderState.toolPickerVisibility = .inactive }
        picker.setVisible(false, forFirstResponder: ink); ink.resignFirstResponder()
        if #available(iOS 18.0, *) { ink.isDrawingEnabled = session.active }
    }
    private func showTools() {
        guard session.active, session.toolsVisible, view.window != nil else { return }
        view.endEditing(true); ink.becomeFirstResponder()
        if #available(iOS 26.0, *) {
            ink.pencilKitResponderState.activeToolPicker = picker
            ink.pencilKitResponderState.toolPickerVisibility = .visible
        } else { picker.setVisible(true, forFirstResponder: ink) }
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
    }
    @available(iOS 18.0, *)
    func toolPickerSelectedToolItemDidChange(_ toolPicker: PKToolPicker) { toolPickerSelectedToolDidChange(toolPicker) }
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
        paper.backgroundColor = noteColor(note.color); paper.ruleColor = theme.palette.rule
        palette.backgroundColor = theme.palette.paper; palette.layer.borderWidth = 0.5
        palette.layer.borderColor = theme.palette.rule.cgColor
        bodyText.textColor = theme.palette.ink; bodyText.linkTextAttributes = [.foregroundColor: theme.palette.accent]
        placeholder.textColor = theme.palette.secondary
        bodyText.typingAttributes = NotePageTypography.attributes(ink: theme.palette.ink)
        applying = true; defer { applying = false }
        bodyText.isHidden = isCanvas; placeholder.isHidden = isCanvas || !page.body.isEmpty
        let restoringSurface = noteID != note.id || generation != session.surfaceGeneration
        if restoringSurface {
            acceptsInkChanges = false; usingPencil = false; view.endEditing(true)
            if noteID != note.id { fitted = false }
            noteID = note.id; generation = session.surfaceGeneration
            objects.values.forEach { $0.removeFromSuperview() }; objects = [:]; represented = [:]
            renderedPage = nil; loadedPageInk = nil
            lastInk = Data([0]) // Force restoration, including an empty drawing after undo.
        }
        session.flushSurface = { [weak self] in self?.flush() }
        session.setZoom = { [weak self] scale in
            guard let self else { return }
            if let scale { self.scroll.setZoomScale(scale, animated: false) } else { self.zoomToContent() }
            self.updateViewport()
        }
        session.endTyping = { [weak self] in self?.view.endEditing(true); self?.showTools() }
        paper.paper = note.paper
        if renderedPage?.body != page.body || renderedPage?.citations != page.citations || renderedPage?.attachments != page.attachments {
            let attributed = attributedBody(page)
            if bodyText.text == page.body {
                // Keep UIKit's cursor, marked text and text-editing state while typing.
                let range = NSRange(location: 0, length: bodyText.textStorage.length)
                bodyText.textStorage.beginEditing()
                bodyText.textStorage.removeAttribute(.link, range: range)
                bodyText.textStorage.removeAttribute(.attachment, range: range)
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
                do {
                    let scene = try NoteCanvasInk(objects: note.objects, traits: traitCollection)
                    if !NoteCanvasInk.equivalent(ink.drawing, scene.drawing) { ink.drawing = scene.drawing }
                    canvasScene = scene; lastInk = ink.drawing.dataRepresentation()
                } catch { session.report(error) }
            } else if loadedPageInk != page.ink {
                ink.drawing = NoteInkAppearance.canonicalDrawing(page.ink.isEmpty ? PKDrawing() : (try? PKDrawing(data: page.ink)) ?? PKDrawing())
                loadedPageInk = page.ink; lastInk = ink.drawing.dataRepresentation()
            }
        }
        if restoringSurface { ink.undoManager?.removeAllActions() }
        publishRefinementAccessibility()
        let ids = Set(note.objects.map(\.id))
        for id in Array(objects.keys) where !ids.contains(id) { objects.removeValue(forKey: id)?.removeFromSuperview(); represented[id] = nil }
        for object in note.objects where isCanvas || object.kind != .ink {
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
                text.font = .systemFont(ofSize: object.fontSize)
                if !text.isFirstResponder, text.text != object.text { text.text = object.text }
            } else if represented[object.id] != object { render(object, in: item) }
            item.viewWithTag(701)?.removeFromSuperview()
            if selected, object.group == nil {
                let size = min(min(item.bounds.width, item.bounds.height), max(10, 12 / scroll.zoomScale))
                let handle = UIView(frame: CGRect(x: item.bounds.width - size, y: item.bounds.height - size, width: size, height: size))
                handle.tag = 701; handle.backgroundColor = .systemBlue; handle.layer.cornerRadius = size / 2
                handle.isUserInteractionEnabled = false; item.addSubview(handle)
            }
            represented[object.id] = object; paper.bringSubviewToFront(item)
        }
        view.bringSubviewToFront(ink); view.bringSubviewToFront(palette)
        ink.isUserInteractionEnabled = session.active; bodyText.isEditable = session.active
        ink.drawingGestureRecognizer.isEnabled = session.active
        if isCanvas { ink.layer.opacity = usingPencil ? 1 : 0 }
        ink.accessibilityLabel = isCanvas ? "Canvas drawings" : "Page annotations"
        if !session.active { flush(); hideTools(); view.endEditing(true) }
        if session.active && !wasActive { showTools() }; wasActive = session.active
        if toolsRequest != session.toolsRequest { toolsRequest = session.toolsRequest; if session.toolsVisible { showTools() } else { hideTools() } }
        fitIfNeeded(); centerPage(); updatePalette(); updateViewport()
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

    private func noteColor(_ color: NoteDocument.Color) -> UIColor {
        switch color {
        case .neutral: return theme.palette.paper
        case .rose: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.22, green: 0.15, blue: 0.16, alpha: 1) : UIColor(red: 0.98, green: 0.91, blue: 0.92, alpha: 1) }
        case .amber: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.22, green: 0.18, blue: 0.10, alpha: 1) : UIColor(red: 0.98, green: 0.94, blue: 0.82, alpha: 1) }
        case .sage: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.13, green: 0.20, blue: 0.15, alpha: 1) : UIColor(red: 0.89, green: 0.95, blue: 0.88, alpha: 1) }
        case .blue: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.12, green: 0.18, blue: 0.23, alpha: 1) : UIColor(red: 0.88, green: 0.94, blue: 0.98, alpha: 1) }
        case .lavender: return UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.18, green: 0.15, blue: 0.23, alpha: 1) : UIColor(red: 0.94, green: 0.91, blue: 0.98, alpha: 1) }
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
    private func render(_ object: NoteObject, in item: UIView) {
        item.subviews.forEach { $0.removeFromSuperview() }
        if object.kind == .ink {
            item.backgroundColor = .clear
            if let drawing = try? PKDrawing(data: object.payload), !drawing.strokes.isEmpty {
                let scaleX = object.frame.width / (object.inkSize?.width ?? object.frame.width)
                let scaleY = object.frame.height / (object.inkSize?.height ?? object.frame.height)
                let scaled = NoteInkAppearance.canonicalDrawing(drawing).transformed(using: CGAffineTransform(scaleX: scaleX, y: scaleY))
                let rasterScale = min(2, 2048 / max(1, max(scaled.bounds.width, scaled.bounds.height)))
                let image = UIImageView(image: NoteInkAppearance.image(scaled, from: scaled.bounds, scale: rasterScale, traits: theme.traits))
                image.frame = scaled.bounds; item.addSubview(image)
            }
        } else if object.kind == .image {
            let image = UIImageView(image: UIImage(data: object.payload)); image.contentMode = .scaleAspectFit
            image.frame = item.bounds; image.autoresizingMask = [.flexibleWidth, .flexibleHeight]; item.addSubview(image)
        } else if object.kind == .shape {
            item.backgroundColor = .clear
            let image = UIImageView(image: UIImage(systemName: (object.shape ?? .roundedRectangle).symbol))
            image.tintColor = (object.tint ?? .teal).color; image.contentMode = .scaleToFill
            image.frame = item.bounds; image.autoresizingMask = [.flexibleWidth, .flexibleHeight]; item.addSubview(image)
        } else if object.kind == .link {
            item.backgroundColor = theme.palette.paper; item.layer.cornerRadius = 12; item.clipsToBounds = true
            let image = UIImageView(image: UIImage(data: object.payload) ?? UIImage(systemName: "link"))
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
        guard let note = session.note, let id = session.selection.first, let object = note.objects.first(where: { $0.id == id }) else { palette.isHidden = true; paletteKey = ""; return }
        let key = "\(session.selection.sorted { $0.uuidString < $1.uuidString })|\(session.renderRevision)|\(session.selectingMultiple)"
        if key != paletteKey {
            paletteKey = key
            palette.arrangedSubviews.forEach { palette.removeArrangedSubview($0); $0.removeFromSuperview() }
            func action(_ title: String, _ symbol: String, _ handler: @escaping () -> Void) -> UIAction {
                UIAction(title: title, image: UIImage(systemName: symbol)) { [weak self] _ in handler(); self?.paletteKey = ""; self?.apply() }
            }
            func button(_ title: String, _ symbol: String, _ handler: @escaping () -> Void) {
                let b = UIButton(type: .system); b.setImage(UIImage(systemName: symbol), for: .normal)
                b.accessibilityLabel = title; b.accessibilityIdentifier = "notes.action." + title.lowercased()
                b.addAction(action(title, symbol, handler), for: .touchUpInside)
                b.widthAnchor.constraint(equalToConstant: 42).isActive = true; b.heightAnchor.constraint(equalToConstant: 40).isActive = true
                palette.addArrangedSubview(b)
            }
            if session.selection.count == 1, object.kind != .ink {
                button("Edit", "pencil") { [weak self] in
                    guard let self else { return }
                    if [.text, .bullets, .numbered].contains(object.kind) { self.session.mode = .text; self.session.focusRequest = UUID() }
                    else { self.session.editingObjectID = id }
                }
            }
            button("Duplicate", "plus.square.on.square") { [weak self] in self?.session.duplicateSelection() }
            button("Delete", "trash") { [weak self] in self?.session.remove() }
            let more = UIButton(type: .system); more.setImage(UIImage(systemName: "ellipsis"), for: .normal)
            more.accessibilityLabel = "Object options"; more.accessibilityIdentifier = "notes.action.more"
            var actions: [UIMenuElement] = []
            if [.shape, .text, .bullets, .numbered].contains(object.kind) {
                actions.append(UIMenu(title: "Color", children: NoteTint.allCases.map { tint in action(tint.rawValue.capitalized, "circle.fill") { [weak self] in self?.session.update(id) { $0.tint = tint } } }))
            }
            if object.kind == .shape {
                actions.append(UIMenu(title: "Change shape", children: NoteShape.allCases.map { shape in action(shape.title, shape.symbol) { [weak self] in self?.session.update(id) { $0.shape = shape } } }))
            }
            if object.kind == .link {
                actions.append(action("Open link", "arrow.up.right") { if let url = URL(string: object.url) { UIApplication.shared.open(url) } })
                actions.append(action("Refresh preview", "arrow.clockwise") { [weak self] in self?.session.refreshLink(id) })
            }
            actions += [action("Bring to front", "square.3.layers.3d.top.filled") { [weak self] in self?.session.reorder(id, front: true) },
                        action("Send to back", "square.3.layers.3d.bottom.filled") { [weak self] in self?.session.reorder(id, front: false) },
                        action(session.selectingMultiple ? "Finish selecting" : "Select multiple", "checkmark.circle") { [weak self] in self?.session.selectingMultiple.toggle() }]
            if note.members(session.selection).count > 1 { actions.append(action("Group", "square.on.square") { [weak self] in self?.session.group(); self?.session.selectingMultiple = false }) }
            if object.group != nil { actions.append(action("Ungroup", "square.dashed") { [weak self] in self?.session.ungroup() }) }
            more.menu = UIMenu(children: actions); more.showsMenuAsPrimaryAction = true
            more.widthAnchor.constraint(equalToConstant: 42).isActive = true; more.heightAnchor.constraint(equalToConstant: 40).isActive = true
            palette.addArrangedSubview(more)
        }
        palette.isHidden = usingPencil || bodyText.isFirstResponder || objects.values.contains { $0.isFirstResponder } || !session.active
        positionPalette()
    }
    private func positionPalette() {
        guard !palette.isHidden, let note = session.note else { return }
        let rect = note.objects.filter { session.selection.contains($0.id) }.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        guard !rect.isNull else { return }
        let target = paper.convert(rect, to: view)
        let size = palette.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let y = target.minY >= size.height + 12 ? target.minY - size.height - 8 : target.maxY + 8
        palette.frame = CGRect(x: max(8, min(view.bounds.width - size.width - 8, target.midX - size.width / 2)), y: max(8, min(view.bounds.height - size.height - 100, y)), width: size.width, height: size.height)
    }
    private func objectID(_ view: UIView) -> UUID? { objects.first { $0.value === view }?.key }
    private func hit(_ point: CGPoint) -> NoteObject? { session.note?.objects.reversed().first { (isCanvas || $0.kind != .ink) && $0.frame.contains(point) } }
    @objc private func selectObject(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: paper)
        // The keyboard may scroll the page before this recognizer ends.
        // Resolve the target captured at touch-down, not its shifted final position.
        if let offset = bodyTapOffset {
            if let attachment = session.note?.page?.attachments.first(where: { $0.location == offset }) {
                view.endEditing(true); session.editingObjectID = attachment.id
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
        guard let object = hit(point), session.selection.contains(object.id) else { return false }
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
            if let object = hit(dragStart), object.group == nil, dragStart.x > object.frame.maxX - max(30, 36 / scroll.zoomScale), dragStart.y > object.frame.maxY - max(30, 36 / scroll.zoomScale) {
                resizeID = object.id; originalSize = object.frame.size
            } else { resizeID = nil }
        case .changed:
            if let id = resizeID, let item = objects[id] {
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
    func textViewDidChangeSelection(_ textView: UITextView) { if textView === bodyText { session.bodySelection = textView.selectedRange } }
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
        acceptsInkChanges = true; usingPencil = true; palette.isHidden = true
        // End text editing without resigning the active PencilKit responder mid-stroke.
        if bodyText.isFirstResponder { bodyText.resignFirstResponder() }
        for object in objects.values where object.isFirstResponder { object.resignFirstResponder() }
        if isCanvas { ink.layer.opacity = 1; for object in session.note?.objects ?? [] where object.kind == .ink { objects[object.id]?.isHidden = true } }
        // Do not reconfigure the tool picker or responder during an in-flight stroke.
    }
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        usingPencil = false
        if let refined = strokeRefiner.finishStroke() {
            let original = ink.drawing
            let previous = refinementStatus
            refinementStatus = strokeRefiner.lastKind.map { "refined \($0.label)" } ?? "rough"
            ink.undoManager?.registerUndo(withTarget: self) { target in target.replaceInkDrawing(original, status: previous) }
            ink.drawing = refined
        } else if PencilStrokeRefiner.simulatesPencil {
            refinementStatus = "rough"
        }
        flush(); apply()
    }
    private func replaceInkDrawing(_ drawing: PKDrawing, status: String) {
        let current = ink.drawing
        let previous = refinementStatus
        ink.undoManager?.registerUndo(withTarget: self) { target in target.replaceInkDrawing(current, status: previous) }
        refinementStatus = status
        ink.drawing = drawing; flush(); apply()
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
