import SwiftUI

/// Transparent scenery bands in the same coordinates as the traveler.
struct PlanTravelerScenery {
    let ink: Color
    private static let crescent = Path(ellipseIn: CGRect(x: -12, y: 9, width: 24, height: 24))
        .subtracting(Path(ellipseIn: CGRect(x: -4, y: 4, width: 23, height: 23)))

    func draw(_ backdrop: PlanTravelerBackdrop, in context: GraphicsContext, width: CGFloat, time: Double) {
        switch backdrop {
        case .mountains:
            mountains(in: context, width: width, time: time)
        case .library:
            library(in: context, width: width, time: time)
            return
        case .sunny:
            clouds(in: context, width: width, time: time, sparse: true)
            sun(in: context, x: width * 0.78, time: time)
        case .moon:
            clouds(in: context, width: width, time: time, sparse: true)
            moon(in: context, width: width, time: time)
        case .rainy:
            clouds(in: context, width: width, time: time)
            rain(in: context, width: width, time: time)
        case .automatic, .cloudy:
            clouds(in: context, width: width, time: time)
        }
        grass(in: context, width: width, time: time)
    }

    private func clouds(in context: GraphicsContext, width: CGFloat, time: Double, sparse: Bool = false) {
        let period = sparse ? max(Double(width) * 0.8, 144) : 136
        let speed = sparse ? 4.0 : 7.0
        let scale = sparse ? 0.68 : 1.0
        let cloudOffset = (time * speed).truncatingRemainder(dividingBy: period)
        for tile in stride(from: -period, through: Double(width) + period, by: period) {
            var sky = context
            sky.translateBy(x: tile - cloudOffset + 27, y: sparse ? 12 : 0)
            sky.scaleBy(x: scale, y: scale)
            var cloud = Path()
            cloud.addRoundedRect(in: CGRect(x: 0, y: 19, width: 37, height: 8), cornerSize: CGSize(width: 4, height: 4))
            cloud.addEllipse(in: CGRect(x: 6, y: 12, width: 16, height: 14))
            cloud.addEllipse(in: CGRect(x: 18, y: 15, width: 13, height: 11))
            sky.fill(cloud, with: .color(ink.opacity(sparse ? 0.10 : 0.16)))
            let wisp = Path(roundedRect: CGRect(x: 80, y: 32, width: 19, height: 4), cornerRadius: 2)
            sky.fill(wisp, with: .color(ink.opacity(sparse ? 0.07 : 0.11)))
        }
    }

    private func grass(in context: GraphicsContext, width: CGFloat, time: Double) {
        let grassOffset = (time * 34).truncatingRemainder(dividingBy: 88)
        let grass = Color(red: 0.40, green: 0.52, blue: 0.35)
        for tile in stride(from: -88.0, through: Double(width) + 88, by: 88) {
            for (offset, baseline, height) in [(12.0, 91.0, 9.0), (53.0, 93.0, 6.0)] {
                let x = tile - grassOffset + offset
                var tuft = Path()
                tuft.move(to: CGPoint(x: x - 7, y: baseline - height * 0.62))
                tuft.addQuadCurve(to: CGPoint(x: x, y: baseline), control: CGPoint(x: x - 2, y: baseline - height / 2))
                tuft.addQuadCurve(to: CGPoint(x: x + 7, y: baseline - height * 0.78), control: CGPoint(x: x + 1, y: baseline - height / 2))
                tuft.move(to: CGPoint(x: x, y: baseline))
                tuft.addQuadCurve(to: CGPoint(x: x - 1, y: baseline - height), control: CGPoint(x: x + 2, y: baseline - height / 2))
                context.stroke(tuft, with: .color(grass.opacity(0.58)), style: StrokeStyle(lineWidth: 1.35, lineCap: .round))
            }
        }
    }

    private func mountains(in context: GraphicsContext, width: CGFloat, time: Double) {
        let period = 142.0
        let offset = (time * 8).truncatingRemainder(dividingBy: period)
        for tile in stride(from: -period, through: Double(width) + period, by: period) {
            let x = tile - offset
            var ridge = Path()
            ridge.addLines([CGPoint(x: x, y: 72), CGPoint(x: x + 38, y: 35), CGPoint(x: x + 54, y: 46),
                            CGPoint(x: x + 83, y: 14), CGPoint(x: x + period, y: 72)])
            ridge.closeSubpath()
            context.fill(ridge, with: .color(Color(red: 0.32, green: 0.48, blue: 0.51).opacity(0.24)))

            var snow = Path()
            snow.addLines([CGPoint(x: x + 66, y: 32), CGPoint(x: x + 83, y: 14), CGPoint(x: x + 103, y: 34),
                           CGPoint(x: x + 88, y: 29), CGPoint(x: x + 82, y: 34), CGPoint(x: x + 76, y: 28)])
            snow.closeSubpath()
            context.fill(snow, with: .color(.white.opacity(0.57)))
        }
    }

    private func library(in context: GraphicsContext, width: CGFloat, time: Double) {
        let period = 94.0
        let offset = (time * 17).truncatingRemainder(dividingBy: period)
        let bookColors: [Color] = [.brown, .teal, .orange, .indigo]
        for tile in stride(from: -period, through: Double(width) + period, by: period) {
            let x = tile - offset
            let post = Path(CGRect(x: x + 8, y: 15, width: 2, height: 64))
            context.fill(post, with: .color(.brown.opacity(0.33)))
            for y in [36.0, 58.0, 79.0] {
                let shelf = Path(roundedRect: CGRect(x: x + 8, y: y, width: period, height: 2), cornerRadius: 1)
                context.fill(shelf, with: .color(.brown.opacity(0.4)))
                for (index, height) in [12.0, 16, 10, 14, 13, 9, 15, 12, 14].enumerated() {
                    let bookX = x + 13 + Double(index) * 9
                    let book = Path(roundedRect: CGRect(x: bookX, y: y - height, width: 6.5, height: height), cornerRadius: 1)
                    context.fill(book, with: .color(bookColors[index % bookColors.count].opacity(0.33)))
                }
            }
        }
        stroke(in: context, color: ink.opacity(0.14), points: [CGPoint(x: 0, y: 92), CGPoint(x: width, y: 92)])
    }

    private func sun(in context: GraphicsContext, x: CGFloat, time: Double) {
        let amber = Color(red: 0.89, green: 0.59, blue: 0.19)
        halo(in: context, center: CGPoint(x: x, y: 21), color: amber)
        context.fill(Path(ellipseIn: CGRect(x: x - 8, y: 13, width: 16, height: 16)), with: .color(amber.opacity(0.83)))
        for ray in 0..<8 {
            let angle = Double(ray) * .pi / 4
            let pulse = 0.5 + 0.5 * sin(time * 2.2 + Double(ray) * .pi / 2)
            let reach = 13.5 + pulse * 3
            let start = CGPoint(x: x + cos(angle) * 11, y: 21 + sin(angle) * 11)
            let end = CGPoint(x: x + cos(angle) * reach, y: 21 + sin(angle) * reach)
            stroke(in: context, color: amber.opacity(0.48 + pulse * 0.37), points: [start, end])
        }
    }

    private func moon(in context: GraphicsContext, width: CGFloat, time: Double) {
        let x = width * 0.78
        let gold = Color(red: 0.84, green: 0.65, blue: 0.32)
        halo(in: context, center: CGPoint(x: x, y: 21), color: Color(red: 0.61, green: 0.72, blue: 0.94))
        var moon = context
        moon.translateBy(x: x, y: 0)
        moon.fill(Self.crescent, with: .color(gold))
        let stars = [(0.13, 19.0), (0.27, 32.0), (0.35, 12.0), (0.63, 12.0), (0.91, 30.0)]
        for (index, (fraction, y)) in stars.enumerated() {
            let starX = width * fraction
            let twinkle = 0.5 + 0.5 * sin(time * 1.8 + Double(index) * 1.7)
            let reach = 1.4 + twinkle * 1.8
            let light = gold.opacity(0.38 + twinkle * 0.52)
            stroke(in: context, color: light, points: [CGPoint(x: starX - reach * 0.8, y: y), CGPoint(x: starX + reach * 0.8, y: y)])
            stroke(in: context, color: light, points: [CGPoint(x: starX, y: y - reach), CGPoint(x: starX, y: y + reach)])
        }
    }

    private func halo(in context: GraphicsContext, center: CGPoint, color: Color) {
        let radius: CGFloat = 22
        let glow = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        context.fill(glow, with: .radialGradient(
            Gradient(stops: [
                .init(color: color.opacity(0.34), location: 0),
                .init(color: color.opacity(0.18), location: 0.45),
                .init(color: color.opacity(0), location: 1)
            ]),
            center: center, startRadius: 0, endRadius: radius
        ))
    }

    private func rain(in context: GraphicsContext, width: CGFloat, time: Double) {
        let offset = (time * 55).truncatingRemainder(dividingBy: 68)
        let blue = Color(red: 0.37, green: 0.57, blue: 0.70)
        for (index, x) in stride(from: 5.0, to: Double(width) + 6, by: 13).enumerated() {
            for row in 0..<2 {
                let y = 19 + (Double(index * 19 + row * 34) + offset).truncatingRemainder(dividingBy: 68)
                stroke(in: context, color: blue.opacity(0.44), points: [CGPoint(x: x, y: y), CGPoint(x: x - 3, y: y + 5)])
            }
        }
    }

    private func stroke(in context: GraphicsContext, color: Color, points: [CGPoint]) {
        var path = Path()
        path.addLines(points)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
    }
}
