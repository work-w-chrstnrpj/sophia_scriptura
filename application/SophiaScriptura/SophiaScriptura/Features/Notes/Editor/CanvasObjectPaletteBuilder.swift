import UIKit

/// Builds the Freeform-style floating palette for Canvas object selection.
@MainActor enum CanvasObjectPaletteBuilder {
    typealias Handler = () -> Void

    struct Context {
        weak var presenter: UIViewController?
        let session: NotesSession
        let object: NoteObject
        let note: NoteDocument
        let refresh: Handler
    }

    static func fill(
        _ palette: UIStackView,
        context: Context,
        action: @escaping (String, String, @escaping Handler) -> UIAction,
        button: @escaping (String, String?, String?, Bool, Handler?) -> UIButton,
        menuButton: @escaping (String, String?, String?, UIMenu) -> UIButton
    ) {
        if context.session.selection.count == 1 {
            typeSpecific(palette, context: context, action: action, button: button, menuButton: menuButton)
        }
        if supportsColor(context.object.kind) {
            palette.addArrangedSubview(menuButton("Color", "paintpalette.fill", nil, colorMenu(context, action: action)))
        }
        palette.addArrangedSubview(button("Duplicate", "plus.square.on.square", nil, false) { context.session.duplicateSelection() })
        palette.addArrangedSubview(button("Delete", "trash", nil, true) { context.session.remove() })
        palette.addArrangedSubview(menuButton("More", "ellipsis", nil, moreMenu(context, action: action)))
    }

    private static func typeSpecific(
        _ palette: UIStackView,
        context: Context,
        action: @escaping (String, String, @escaping Handler) -> UIAction,
        button: @escaping (String, String?, String?, Bool, Handler?) -> UIButton,
        menuButton: @escaping (String, String?, String?, UIMenu) -> UIButton
    ) {
        let id = context.object.id
        switch context.object.kind {
        case .text, .bullets, .numbered:
            palette.addArrangedSubview(menuButton("Font", "textformat", nil, fontMenu(context, id: id, action: action)))
            palette.addArrangedSubview(menuButton(
                "Font size",
                "textformat.size",
                "\(Int(context.object.fontSize))",
                fontSizeMenu(context, id: id, action: action)
            ))
        case .link:
            palette.addArrangedSubview(button("Edit link", "link", nil, false) { context.session.editingObjectID = id })
            palette.addArrangedSubview(button("Go to link", "arrow.up.right", nil, false) { openLink(context.object.url) })
            palette.addArrangedSubview(button("Refresh link", "arrow.clockwise", nil, false) { context.session.refreshLink(id) })
        case .shape:
            palette.addArrangedSubview(menuButton("Shape", "square.on.circle", nil, shapeMenu(context, id: id, action: action)))
        case .quote:
            palette.addArrangedSubview(button("Edit quote", "text.quote", nil, false) { context.session.editingObjectID = id })
        case .table:
            palette.addArrangedSubview(button("Edit table", "tablecells", nil, false) { context.session.editingObjectID = id })
        case .image:
            palette.addArrangedSubview(button("Replace image", "photo", nil, false) { context.session.editingObjectID = id })
        case .sticker:
            palette.addArrangedSubview(menuButton("Sticker", "face.smiling", nil, stickerMenu(context, id: id, action: action)))
        case .audio:
            palette.addArrangedSubview(button("Edit audio", "waveform", nil, false) { context.session.editingObjectID = id })
        case .ink:
            break
        }
    }

    private static func colorMenu(_ context: Context, action: @escaping (String, String, @escaping Handler) -> UIAction) -> UIMenu {
        let id = context.object.id
        return UIMenu(title: "Color", children: NoteTint.allCases.map { tint in
            action(tint.rawValue.capitalized, "circle.fill") { context.session.update(id) { $0.tint = tint } }
        })
    }

    private static func fontMenu(_ context: Context, id: UUID, action: @escaping (String, String, @escaping Handler) -> UIAction) -> UIMenu {
        UIMenu(children: [
            action("Body", "text.alignleft") { context.session.update(id) { $0.monospaced = false; $0.fontSize = 22 } },
            action("Title", "textformat.size.larger") { context.session.update(id) { $0.monospaced = false; $0.fontSize = 34 } },
            action("Heading", "textformat") { context.session.update(id) { $0.monospaced = false; $0.fontSize = 28 } },
            action("Caption", "textformat.size.smaller") { context.session.update(id) { $0.monospaced = false; $0.fontSize = 17 } },
            action("Monospaced", "chevron.left.forwardslash.chevron.right") { context.session.update(id) { $0.monospaced = true; $0.fontSize = 20 } },
        ])
    }

    private static func fontSizeMenu(_ context: Context, id: UUID, action: @escaping (String, String, @escaping Handler) -> UIAction) -> UIMenu {
        UIMenu(children: [12, 14, 17, 20, 22, 28, 34, 48, 64].map { size in
            action("\(size) pt", "textformat.size") { context.session.update(id) { $0.fontSize = Double(size) } }
        })
    }

    private static func shapeMenu(_ context: Context, id: UUID, action: @escaping (String, String, @escaping Handler) -> UIAction) -> UIMenu {
        UIMenu(children: NoteShape.allCases.map { shape in
            action(shape.title, shape.symbol) { context.session.update(id) { $0.shape = shape } }
        })
    }

    private static func stickerMenu(_ context: Context, id: UUID, action: @escaping (String, String, @escaping Handler) -> UIAction) -> UIMenu {
        UIMenu(children: ["🌿", "✨", "🙏", "📖", "❤️", "⭐️"].map { emoji in
            action(emoji, "face.smiling") { context.session.update(id) { $0.text = emoji } }
        })
    }

    private static func moreMenu(_ context: Context, action: @escaping (String, String, @escaping Handler) -> UIAction) -> UIMenu {
        let id = context.object.id
        var items: [UIMenuElement] = [
            action("Bring to front", "square.3.layers.3d.top.filled") { context.session.reorderSelection(front: true) },
            action("Send to back", "square.3.layers.3d.bottom.filled") { context.session.reorderSelection(front: false) },
            action("Cut", "scissors") { context.session.cutSelection() },
            action("Copy", "doc.on.doc") { context.session.copySelection() },
            action("Duplicate", "plus.square.on.square") { context.session.duplicateSelection() },
            action(context.object.positionLocked ? "Unlock position" : "Lock position", context.object.positionLocked ? "lock.open" : "lock") {
                context.session.togglePositionLock()
            },
        ]
        if context.note.members(context.session.selection).count > 1 {
            items.append(action("Group", "square.on.square") {
                context.session.group()
                context.session.selectingMultiple = false
            })
        }
        if context.object.group != nil {
            items.append(action("Ungroup", "square.dashed") { context.session.ungroup() })
        }
        items.append(action(context.session.selectingMultiple ? "Finish selecting" : "Select multiple", "checkmark.circle") {
            context.session.selectingMultiple.toggle()
        })
        items.append(UIMenu(title: "", options: .displayInline, children: [
            action("Description", "text.bubble") { presentDescription(context, id: id) },
        ]))
        items.append(UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                context.session.remove()
                context.refresh()
            },
        ]))
        return UIMenu(children: items)
    }

    private static func presentDescription(_ context: Context, id: UUID) {
        guard let presenter = context.presenter else { return }
        let alert = UIAlertController(title: "Description", message: "Optional note about this object.", preferredStyle: .alert)
        alert.addTextField { field in
            field.text = context.object.details
            field.placeholder = "Description"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let text = String((alert.textFields?.first?.text ?? "").prefix(500))
            context.session.update(id) { $0.details = text }
            context.refresh()
        })
        presenter.present(alert, animated: true)
    }

    private static func openLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private static func supportsColor(_ kind: NoteObject.Kind) -> Bool {
        [.shape, .text, .bullets, .numbered, .sticker, .table].contains(kind)
    }
}
