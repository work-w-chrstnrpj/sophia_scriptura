import UIKit

@MainActor enum NotePageAttachments {
    static func attributed(_ page: NotePage, palette: ReaderPalette? = nil) -> NSAttributedString {
        let value = NSMutableAttributedString(string: page.body, attributes: NotePageTypography.attributes(ink: palette?.ink ?? .label))
        NoteTextFormatting.apply(page.formatting, to: value)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for match in detector.matches(in: page.body, range: NSRange(location: 0, length: value.length)) {
                if let url = match.url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    value.addAttribute(.link, value: url, range: match.range)
                }
            }
        }
        for citation in page.citations { value.addAttribute(.link, value: "sophia-citation:\(citation.id)", range: NSRange(location: citation.location, length: citation.length)) }
        for item in page.attachments {
            let attachment = NSTextAttachment()
            let object = item.object
            let width = min(NotePage.columnWidth, object.frame.width)
            let height = object.kind == .image ? width * object.frame.height / max(object.frame.width, 1) : object.kind == .audio ? 72 : CGFloat(max(1, object.cells.count)) * 64
            attachment.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            if object.kind == .image { attachment.image = UIImage(data: object.payload) }
            else if object.kind == .audio { attachment.image = audioCard(object, size: attachment.bounds.size, palette: palette) }
            else {
                attachment.image = UIGraphicsImageRenderer(size: attachment.bounds.size).image { context in
                    (palette?.paper ?? .secondarySystemBackground).setFill(); context.fill(attachment.bounds)
                    let columns = max(1, object.cells.map(\.count).max() ?? 1), cellWidth = width / CGFloat(columns)
                    for (row, cells) in object.cells.enumerated() {
                        for (column, text) in cells.enumerated() {
                            let rect = CGRect(x: CGFloat(column) * cellWidth, y: CGFloat(row) * 64, width: cellWidth, height: 64)
                            (palette?.rule ?? .separator).setStroke(); context.stroke(rect)
                            (text.isEmpty ? "—" : text as NSString).draw(in: rect.insetBy(dx: 8, dy: 8), withAttributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: palette?.ink ?? UIColor.label])
                        }
                    }
                }
            }
            value.addAttribute(.attachment, value: attachment, range: NSRange(location: item.location, length: 1))
        }
        return value
    }

    private static func audioCard(_ object: NoteObject, size: CGSize, palette: ReaderPalette?) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 6)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
            (palette?.soft ?? UIColor.secondarySystemBackground).setFill()
            path.fill()
            (palette?.rule ?? UIColor.separator).setStroke()
            path.lineWidth = 1
            path.stroke()
            let symbol = UIImage(systemName: "waveform")?.withTintColor(palette?.accent ?? .label, renderingMode: .alwaysOriginal)
            symbol?.draw(in: CGRect(x: 18, y: (size.height - 28) / 2, width: 28, height: 28))
            let title = object.text.isEmpty ? "Audio" : object.text
            (title as NSString).draw(in: CGRect(x: 56, y: (size.height - 24) / 2, width: size.width - 72, height: 24), withAttributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: palette?.ink ?? UIColor.label
            ])
        }
    }
}
