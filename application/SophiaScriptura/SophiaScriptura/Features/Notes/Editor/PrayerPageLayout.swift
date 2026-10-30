import CoreGraphics

/// Shared document-space region for the compact Prayer board and full-page guides.
/// Stored text/ink keep their original coordinates; only the viewport changes.
enum PrayerPageLayout {
    static let textTop: CGFloat = 64
    static let writingMargin: CGFloat = 16
    static let boardPadding: CGFloat = 16
    static let minimumHeight: CGFloat = 360
    static let maximumHeight: CGFloat = 960

    static func writingBounds(pageWidth: CGFloat, bottom: CGFloat) -> CGRect {
        CGRect(x: (pageWidth - NotePage.columnWidth) / 2 - writingMargin,
               y: textTop - writingMargin,
               width: NotePage.columnWidth + writingMargin * 2,
               height: max(120, bottom - textTop + writingMargin * 2))
    }
    static func scale(for boardWidth: CGFloat) -> CGFloat {
        max(0.01, (boardWidth - boardPadding * 2) / (NotePage.columnWidth + writingMargin * 2))
    }
    static func offset(pageWidth: CGFloat, scale: CGFloat) -> CGPoint {
        let region = writingBounds(pageWidth: pageWidth, bottom: textTop)
        return CGPoint(x: region.minX * scale - boardPadding, y: region.minY * scale - boardPadding)
    }
    static func boardHeight(width: CGFloat, contentBottom: CGFloat) -> CGFloat {
        let region = writingBounds(pageWidth: NotePage.width, bottom: contentBottom)
        return min(maximumHeight, max(minimumHeight, region.height * scale(for: width) + boardPadding * 2))
    }
    static func outerMargin(for width: CGFloat) -> CGFloat {
        min(108, max(24, (width - 480) / 2))
    }
}
