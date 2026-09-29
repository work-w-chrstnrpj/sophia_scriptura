import UIKit
import PencilKit

@MainActor
enum CanvasSample {
    static func make() -> CanvasFixture {
        let points = (0...60).map { index -> PKStrokePoint in
            let angle = CGFloat(index) / 60 * 2 * .pi
            return PKStrokePoint(location: CGPoint(x: 220 + cos(angle) * 153, y: 153 + sin(angle) * 31),
                                 timeOffset: Double(index) / 60, size: CGSize(width: 3, height: 3),
                                 opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = PKStroke(ink: PKInk(.pen, color: .systemBlue),
                              path: PKStrokePath(controlPoints: points, creationDate: .distantPast))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 480, height: 280))
        let image = renderer.pngData { context in
            UIColor(red: 0.91, green: 0.85, blue: 0.67, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 480, height: 280))
            UIColor(red: 1, green: 0.96, blue: 0.80, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 100, y: 40, width: 68, height: 68)).fill()
            UIColor(red: 0.39, green: 0.51, blue: 0.37, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: -70, y: 140, width: 600, height: 360)).fill()
            UIColor(red: 0.25, green: 0.40, blue: 0.30, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 210, y: 120, width: 520, height: 380)).fill()
        }
        return CanvasFixture(objects: [
            .init(id: .text, frame: CGRect(x: 70, y: 100, width: 320, height: 210)),
            .init(id: .ink, frame: CGRect(x: 0, y: 0, width: 1_100, height: 800)),
            .init(id: .image, frame: CGRect(x: 465, y: 115, width: 250, height: 160))
        ], text: "Love takes initiative.\n\nThe verse begins with what God gives, before our response.",
           drawing: PKDrawing(strokes: [stroke]).dataRepresentation(),
           imageAssetID: "sample-image", assets: ["sample-image": image])
    }
}
