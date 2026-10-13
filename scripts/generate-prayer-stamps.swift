// Run from repository root: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift scripts/generate-prayer-stamps.swift /path/to/RUBBERSTAMP.otf
// Produces vector wordmarks only; the source font is never copied into the app.
import Foundation
import CoreText
import CoreGraphics
guard CommandLine.arguments.count == 2 else {
    fatalError("Pass the locally licensed RUBBERSTAMP.otf path; see docs/design/stamp-font-provenance.md")
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let provider = CGDataProvider(url: url as CFURL)!
let graphicsFont = CGFont(provider)!
let font = CTFontCreateWithGraphicsFont(graphicsFont, 64, nil, nil)
print("Rendering", CTFontCopyPostScriptName(font))
for (text, asset) in [("ANSWERED", "PrayerAnsweredStamp"), ("REDIRECTED", "PrayerRedirectedStamp"), ("PUBLISHED", "PagePublishedStamp")] {
    let attributed = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
    let line = CTLineCreateWithAttributedString(attributed)
    let combined = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for index in 0..<count {
            if let path = CTFontCreatePathForGlyph(font, glyphs[index], nil) {
                combined.addPath(path, transform: CGAffineTransform(translationX: positions[index].x, y: positions[index].y))
            }
        }
    }
    let bounds = combined.boundingBoxOfPath
    let directory = URL(fileURLWithPath: "application/SophiaScriptura/SophiaScriptura/Assets.xcassets/\(asset).imageset")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var mediaBox = CGRect(origin: .zero, size: bounds.size)
    let context = CGContext(directory.appendingPathComponent("\(asset).pdf") as CFURL, mediaBox: &mediaBox, nil)!
    context.beginPDFPage(nil)
    context.translateBy(x: -bounds.minX, y: -bounds.minY)
    context.addPath(combined); context.fillPath()
    context.endPDFPage(); context.closePDF()
    let json = """
    {"images":[{"filename":"\(asset).pdf","idiom":"universal"}],"info":{"author":"xcode","version":1},"properties":{"preserves-vector-representation":true,"template-rendering-intent":"template"}}
    """
    try json.write(to: directory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}
