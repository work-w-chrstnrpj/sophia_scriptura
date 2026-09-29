import SwiftUI
import UIKit

/// A chapter is one continuous, selectable TextKit stream.
/// The renderer is replaceable; no persistence or content access occurs here.
struct ReaderTextSurface: UIViewRepresentable {
    let document: ChapterDocument
    let preferences: ReaderPreferences
    let targetVerse: Int
    let navigationID: UUID
    let restorationLocation: ReadingLocation?
    let onVerse: (Int) -> Void
    let onVisibleLocation: (Int, String?, Int?) -> Void
    let onChapterSwipe: (Int) -> Void
    var authorizeQuote: ((ChapterTextMap.Selection) async -> String?)? = nil

    func makeUIView(context: Context) -> ContinuousReaderTextView {
        let view = ContinuousReaderTextView()
        view.delegate = context.coordinator
        view.isEditable = false
        view.isSelectable = true
        view.backgroundColor = .clear
        view.adjustsFontForContentSizeCategory = true
        view.accessibilityIdentifier = "scripture.text"
        view.onLayout = { [weak view] in
            context.coordinator.restoreIfNeeded(view)
        }
        return view
    }
    static func dismantleUIView(_ view: ContinuousReaderTextView, coordinator: Coordinator) {
        view.onLayout = nil; view.authorizeQuote = nil; view.map = nil
        view.clearFocus(); view.attributedText = NSAttributedString(string:"")
        coordinator.map = nil
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func updateUIView(_ view: ContinuousReaderTextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        view.onChapterSwipe = onChapterSwipe
        view.authorizeQuote = authorizeQuote
        view.textDragInteraction?.isEnabled = !document.isLicensed
        let appearance = preferences.appearance
        let dark = appearance == .midnightLibrary || preferences.theme == "dark" ||
            (preferences.theme == "system" && view.traitCollection.userInterfaceStyle == .dark)
        let palette = appearance.palette(dark:dark)
        view.tintColor = palette.accent
        view.focusColor = palette.accent.withAlphaComponent(0.18)
        let key = "\(document.editionID).\(document.book).\(document.chapter).\(document.contentRevision).\(preferences.appearancePreset ?? "legacy").\(preferences.typeface).\(preferences.sizeStep).\(view.traitCollection.preferredContentSizeCategory.rawValue).\(view.traitCollection.userInterfaceStyle.rawValue)"
        if coordinator.renderKey != key {
            coordinator.renderKey = key
            let map = ChapterTextMap(document: document)
            coordinator.map = map; view.map = map
            let family = preferences.appearancePreset == nil ? preferences.typeface : appearance.readingFamily
            let font = ScriptureFonts.font(family, size:CGFloat(19 + preferences.sizeStep * 2))
            let scaled = UIFontMetrics(forTextStyle: .body).scaledFont(for: font)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 6
            paragraph.paragraphSpacing = 12
            let result = NSMutableAttributedString(string: map.text, attributes: [.font:scaled, .foregroundColor:palette.ink, .paragraphStyle:paragraph])
            for run in map.runs where run.range.length > 0 {
                switch run.block.kind {
                case "label":
                    if let verse = run.block.verses.first {
                        result.addAttributes([.link:URL(string:"sophia-verse:\(verse)")!, .font:UIFontMetrics(forTextStyle:.caption1).scaledFont(for:.systemFont(ofSize:15,weight:.semibold))], range:run.range)
                    }
                case "note":
                    result.addAttributes([.link:URL(string:"sophia-note:\(run.range.location)")!, .font:UIFont.systemFont(ofSize:14)], range:run.range)
                case "heading":
                    result.addAttributes([.font:UIFontMetrics(forTextStyle:.headline).scaledFont(for:.systemFont(ofSize:17,weight:.semibold)), .foregroundColor:palette.secondary], range:run.range)
                default: break
                }
                if ["q1", "q2", "pi1", "li1"].contains(run.block.style), run.block.kind == "body" {
                    let poetry = paragraph.mutableCopy() as! NSMutableParagraphStyle
                    poetry.headIndent = run.block.style == "q2" ? 36 : 18
                    poetry.firstLineHeadIndent = poetry.headIndent
                    result.addAttribute(.paragraphStyle,value:poetry,range:run.range)
                }
            }
            view.linkTextAttributes = [.foregroundColor:palette.accent]
            view.clearFocus()
            view.attributedText = result
            coordinator.pendingVerse = targetVerse
        }
        if coordinator.navigationID != navigationID {
            coordinator.navigationID = navigationID
            coordinator.pendingVerse = targetVerse
        }
        view.setNeedsLayout()
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ReaderTextSurface
        var map: ChapterTextMap?
        var renderKey = ""
        var navigationID: UUID?
        var pendingVerse: Int?
        init(_ parent: ReaderTextSurface) { self.parent = parent }
        func restoreIfNeeded(_ view: ContinuousReaderTextView?) {
            guard let view, let verse = pendingVerse, let range = map?.range(for:verse) else { return }
            pendingVerse = nil
            if let location = parent.restorationLocation, let id = location.blockID,
               let run = map?.runs.first(where: { $0.block.id == id }), let offset = location.utf16Offset {
                view.reveal(NSRange(location:run.range.location + min(offset,max(0,run.range.length - 1)),length:1))
            } else { view.reveal(range) }
            view.focus(verse:verse)
        }
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            if URL.scheme == "sophia-verse", let verse = Int(URL.absoluteString.replacingOccurrences(of:"sophia-verse:",with:"")) {
                (textView as? ContinuousReaderTextView)?.focus(verse:verse)
                parent.onVerse(verse)
            }
            if URL.scheme == "sophia-note", let run = map?.runs.first(where: { $0.range == characterRange }) {
                let alert = UIAlertController(title:"Source note", message:run.block.text, preferredStyle:.alert)
                alert.addAction(UIAlertAction(title:"Done",style:.cancel))
                textView.window?.rootViewController?.presentedViewControllerOrSelf.present(alert, animated:true)
            }
            return false
        }
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { record(scrollView) }
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate { record(scrollView) }
        }
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Never resize reader chrome in response to offsets: rubber-banding and
            // layout-induced offset changes must not create another layout transition.
            guard scrollView.isDragging || scrollView.isDecelerating else { return }
            record(scrollView)
        }
        private func record(_ scrollView: UIScrollView) {
            guard let view = scrollView as? UITextView else { return }
            let point = CGPoint(x:10,y:max(0,view.contentOffset.y - view.textContainerInset.top + 20))
            let glyph = view.layoutManager.glyphIndex(for:point,in:view.textContainer)
            guard glyph < view.layoutManager.numberOfGlyphs else { return }
            let offset = view.layoutManager.characterIndexForGlyph(at:glyph)
            if let verse = map?.verse(at:offset) {
                let run = map?.runs.first { $0.block.kind == "body" && NSLocationInRange(offset,$0.range) }
                parent.onVisibleLocation(verse,run?.block.id,run.map { max(0,offset - $0.range.location) })
            }
        }
        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard let view = textView as? ContinuousReaderTextView, let selection = map?.selection(in:range), !selection.text.isEmpty else { return nil }
            let copy = UIAction(title:"Copy",image:UIImage(systemName:"doc.on.doc")) { _ in view.copySelection(range) }
            let share = UIAction(title:"Share",image:UIImage(systemName:"square.and.arrow.up")) { _ in view.shareSelection(range) }
            return UIMenu(children:[copy,share])
        }
    }
}

final class ContinuousReaderTextView: UITextView, UIGestureRecognizerDelegate {
    var map: ChapterTextMap?
    var authorizeQuote: ((ChapterTextMap.Selection) async -> String?)?
    var onLayout: (() -> Void)?
    var focusColor = UIColor.label.withAlphaComponent(0.18)
    private var focusID = UUID()
    private var focusedRanges: [NSRange] = []
    private var chapterPan: UIPanGestureRecognizer?
    var onChapterSwipe: ((Int) -> Void)?
    init() {
        let storage = NSTextStorage()
        let manager = NSLayoutManager()
        let container = NSTextContainer(size:CGSize(width:600,height:CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(manager); manager.addTextContainer(container)
        super.init(frame:.zero,textContainer:container)
        textContainerInset = UIEdgeInsets(top:28,left:28,bottom:40,right:28)
        let chapterPan = UIPanGestureRecognizer(target:self,action:#selector(chapterPanned(_:)))
        self.chapterPan = chapterPan
        chapterPan.maximumNumberOfTouches = 1
        chapterPan.delegate = self
        addGestureRecognizer(chapterPan)
        // Vertical motion immediately fails the chapter gesture and remains native scrolling.
        panGestureRecognizer.require(toFail:chapterPan)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === chapterPan, let pan = chapterPan else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let velocity = pan.velocity(in:self)
        return selectedRange.length == 0 && abs(velocity.x) > 80 && abs(velocity.x) > abs(velocity.y) * 1.8
    }
    @objc private func chapterPanned(_ pan: UIPanGestureRecognizer) {
        guard pan.state == .ended else { return }
        let translation = pan.translation(in:self)
        if let step = Self.chapterStep(translation:translation,selection:selectedRange) { onChapterSwipe?(step) }
    }
    static func chapterStep(translation: CGPoint, selection: NSRange) -> Int? {
        guard selection.length == 0, abs(translation.x) >= 80,
              abs(translation.x) > abs(translation.y) * 1.8 else { return nil }
        return translation.x < 0 ? 1 : -1
    }
    func reveal(_ range: NSRange) {
        layoutManager.ensureLayout(for:textContainer)
        let glyphs = layoutManager.glyphRange(forCharacterRange:range,actualCharacterRange:nil)
        let rect = layoutManager.boundingRect(forGlyphRange:glyphs,in:textContainer)
        let maximum = max(0,contentSize.height - bounds.height + adjustedContentInset.bottom)
        let y = min(maximum,max(0,rect.minY + textContainerInset.top - 20))
        setContentOffset(CGPoint(x:0,y:y),animated:false)
    }
    func clearFocus() {
        focusID = UUID()
        for range in focusedRanges where NSMaxRange(range) <= textStorage.length {
            textStorage.removeAttribute(.backgroundColor,range:range)
        }
        focusedRanges = []
    }
    func focus(verse: Int) {
        clearFocus()
        focusedRanges = map?.focusRanges(for:verse) ?? []
        for range in focusedRanges where NSMaxRange(range) <= textStorage.length {
            textStorage.addAttribute(.backgroundColor,value:focusColor,range:range)
        }
        let focus = focusID
        DispatchQueue.main.asyncAfter(deadline:.now() + 1.5) { [weak self] in
            guard let self, self.focusID == focus else { return }
            self.clearFocus()
        }
    }
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if map?.document.isLicensed == true { return action == #selector(copy(_:)) && selectedRange.length > 0 }
        return super.canPerformAction(action,withSender:sender)
    }
    override func copy(_ sender: Any?) { copySelection(selectedRange) }
    func copySelection(_ range: NSRange) {
        guard let selection = map?.selection(in:range), !selection.text.isEmpty else { return }
        if map?.document.isLicensed != true { UIPasteboard.general.string = selection.text; return }
        Task { @MainActor [weak self] in
            guard let self, let text = await self.authorizeQuote?(selection) else { return }
            UIPasteboard.general.string = text
        }
    }
    func shareSelection(_ range: NSRange) {
        guard let selection = map?.selection(in:range), !selection.text.isEmpty else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let text: String?
            if self.map?.document.isLicensed == true { text = await self.authorizeQuote?(selection) }
            else { text = selection.text }
            guard let text else { return }
            let controller = UIActivityViewController(activityItems:[text],applicationActivities:nil)
            controller.popoverPresentationController?.sourceView = self
            controller.popoverPresentationController?.sourceRect = CGRect(x:bounds.midX,y:contentOffset.y + 60,width:1,height:1)
            window?.rootViewController?.presentedViewControllerOrSelf.present(controller,animated:true)
        }
    }

}

private extension UIViewController {
    var presentedViewControllerOrSelf: UIViewController { presentedViewController?.presentedViewControllerOrSelf ?? self }
}
