import UIKit

/// Shared measurement keeps the saved body within the rendered growing page.
@MainActor enum NotePageTypography {
    static var attributes: [NSAttributedString.Key: Any] { attributes(ink: .label) }
    static func attributes(ink: UIColor) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 7; paragraph.paragraphSpacing = 10
        return [.font: UIFont.systemFont(ofSize: 22), .foregroundColor: ink, .paragraphStyle: paragraph]
    }
    static func height(of page: NotePage) -> CGFloat {
        NotePageAttachments.attributed(page).boundingRect(with: CGSize(width: NotePage.columnWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height
    }
    static func height(of body: String) -> CGFloat {
        NSAttributedString(string: body.isEmpty ? " " : body, attributes: attributes)
            .boundingRect(with: CGSize(width: NotePage.columnWidth, height: .greatestFiniteMagnitude),
                          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height
    }

    /// Top rule through text (and optional ink) used to size the Prayer card board.
    static func prayerBoardContentHeight(for page: NotePage, includesInkPadding: Bool) -> CGFloat {
        let textBlock = height(of: page)
        var maxY = 64 + max(textBlock, 36) + 32
        if includesInkPadding, !page.ink.isEmpty { maxY += 96 }
        return max(maxY, 120)
    }
}
