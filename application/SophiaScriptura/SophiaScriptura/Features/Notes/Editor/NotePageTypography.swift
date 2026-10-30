import UIKit
import PencilKit

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

    /// Canonical document bottom, including real saved ink bounds rather than a fixed guess.
    static func prayerBoardContentHeight(for page: NotePage, includesInkPadding: Bool) -> CGFloat {
        var bottom = PrayerPageLayout.textTop + max(ceil(height(of: page)), 36) + 16
        if includesInkPadding, let drawing = try? PKDrawing(data: page.ink), !drawing.bounds.isNull {
            bottom = max(bottom, drawing.bounds.maxY + 16)
        }
        return bottom
    }
}
