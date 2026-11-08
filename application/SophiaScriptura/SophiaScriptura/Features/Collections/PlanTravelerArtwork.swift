import SwiftUI

struct PlanTravelerWalk: Equatable {
    let from: Double
    let to: Double
    let startedAt: Date

    init?(from: Double, to: Double, startedAt: Date) {
        guard to > from else { return nil }
        self.from = from
        self.to = to
        self.startedAt = startedAt
    }

    var duration: TimeInterval { 0.75 + (to - from) * 0.75 }

    func fraction(after elapsed: TimeInterval) -> Double {
        let time = min(max(elapsed / duration, 0), 1)
        return time * time * (3 - 2 * time)
    }
}

/// Paper-cut traveler drawn directly over the card surface.
struct PlanTravelerArtwork: View {
    @Environment(\.appTheme) private var theme
    let character: StudyCompanionCharacter
    let ink: Color
    let outfitColor: CollectionAccent?
    let backdrop: PlanTravelerBackdrop
    let equipment: PlanTravelerEquipment
    let progress: Double
    let walk: PlanTravelerWalk?
    let animated: Bool

    var body: some View {
        PlanTravelerScene(character: character, ink: ink,
            outfitColor: outfitColor?.color, backdrop: backdrop.resolved(dark: theme.dark),
            equipment: equipment, progress: progress, walk: walk, animated: animated)
    }
}

private struct PlanTravelerScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let character: StudyCompanionCharacter
    let ink: Color
    let outfitColor: Color?
    let backdrop: PlanTravelerBackdrop
    let equipment: PlanTravelerEquipment
    let progress: Double
    let walk: PlanTravelerWalk?
    let animated: Bool

    var body: some View {
        let moving = animated && !reduceMotion && scenePhase == .active
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !moving)) { timeline in
            Canvas { context, size in
                drawScene(in: context, size: size, time: moving ? timeline.date.timeIntervalSinceReferenceDate : nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func drawScene(in context: GraphicsContext, size: CGSize, time: Double?) {
        let scale = min(size.width / 108, size.height / 96)
        guard scale > 0 else { return }
        var landscape = context
        landscape.clip(to: Path(CGRect(origin: .zero, size: size)))
        landscape.translateBy(x: 0, y: (size.height - 96 * scale) / 2)
        landscape.scaleBy(x: scale, y: scale)
        let width = size.width / scale
        PlanTravelerScenery(ink: ink).draw(backdrop, in: landscape, width: width, time: time ?? 0)

        // Position the torso on the progress mark, leaving room for the sword and lamp.
        let torsoX: CGFloat = 50
        func position(_ progress: Double) -> CGFloat {
            min(max(width * progress, 30), width - 54)
        }
        let center: CGFloat
        if let walk, let time {
            let from = position(walk.from)
            let distance = position(walk.to) - from
            center = from + distance * walk.fraction(after: time - walk.startedAt.timeIntervalSinceReferenceDate)
        } else {
            center = position(progress)
        }
        var traveler = landscape
        traveler.translateBy(x: center - torsoX, y: 0)
        let phase = time.map { $0.truncatingRemainder(dividingBy: 1.28) * 2 * .pi / 1.28 }
        let flicker = time.map { sin($0 * 19) * 0.65 + sin($0 * 31) * 0.35 } ?? 0
        drawTraveler(in: traveler, phase: phase, flicker: flicker)
    }

    private func drawTraveler(in context: GraphicsContext, phase: Double?, flicker: Double) {
        let stride = phase.map { sin($0) } ?? 0
        let rise = phase.map { abs(sin($0)) * 1.6 } ?? 0
        let armored = equipment == .armorOfGod
        if equipment == .lamp {
            drawLampLight(in: context, flicker: flicker)
        }
        var upper = context
        upper.translateBy(x: 0, y: -rise)

        func leg(direction: CGFloat, color: Color) {
            let swing = stride * direction
            let lift = max(0, swing) * 6
            let hip = CGPoint(x: 49 + direction * 4, y: 61 - rise)
            let knee = CGPoint(x: 51 + direction * (armored ? 6 : 4) + swing * 7, y: 76 - lift / 2)
            let ankle = CGPoint(x: 50 + direction * (armored ? 8 : 5) + swing * 14, y: 88 - lift)
            stroke(context, color, width: 6, points: [hip, knee, ankle])
            stroke(context, color, width: 4, points: [ankle, CGPoint(x: ankle.x + 7, y: ankle.y + 1)])
            if armored {
                stroke(context, armorGold, width: 1.6, points: [CGPoint(x: ankle.x - 2, y: ankle.y - 2),
                    CGPoint(x: ankle.x + 1, y: ankle.y - 5), CGPoint(x: ankle.x + 4, y: ankle.y)])
            }
        }

        leg(direction: -1, color: ink.opacity(0.66))
        leg(direction: 1, color: ink)

        // The far arm emerges from behind the breastplate and braces the shield.
        let shieldGrip = CGPoint(x: 74 + stride * 2, y: 41 - stride)
        if armored {
            drawShieldArm(in: upper, grip: shieldGrip)
        }
        if character == .sophy {
            drawBraid(in: upper)
        }
        if !armored {
            drawFreeArm(in: upper, stride: stride)
        }

        let hem: CGFloat = character == .sophy ? 79 : character == .sabinus ? 74 : 69
        fill(upper, cloak) { path in
            path.move(to: CGPoint(x: 44, y: 31))
            path.addQuadCurve(to: CGPoint(x: 58, y: 35), control: CGPoint(x: 51, y: 29))
            path.addQuadCurve(to: CGPoint(x: 59, y: 53), control: CGPoint(x: 57, y: 47))
            path.addLine(to: CGPoint(x: 64 + stride * 2, y: hem))
            path.addQuadCurve(to: CGPoint(x: 36 + stride * 2, y: hem), control: CGPoint(x: 49, y: hem + 4))
            path.addQuadCurve(to: CGPoint(x: 44, y: 31), control: CGPoint(x: 42, y: 51))
        }
        stroke(upper, ink.opacity(0.45), width: 1.8,
               points: [CGPoint(x: 42, y: 53), CGPoint(x: 58, y: 54)])

        if character == .sophy {
            stroke(upper, Color(red: 0.80, green: 0.61, blue: 0.32), width: 4,
                   points: [CGPoint(x: 44, y: 33), CGPoint(x: 49, y: 42), CGPoint(x: 55, y: 45)])
        }

        drawFace(in: upper)
        switch equipment {
        case .candle:
            drawCarryingArm(in: upper)
            drawCandle(in: upper, flicker: flicker)
        case .lamp:
            drawCarryingArm(in: upper)
            drawLamp(in: upper, flicker: flicker)
        case .armorOfGod:
            drawArmor(in: upper)
            drawSwordArm(in: upper, stride: stride)
            drawShield(in: upper, grip: shieldGrip)
        }
    }

    private func drawFreeArm(in context: GraphicsContext, stride: CGFloat) {
        let hand = CGPoint(x: 36 - stride * 7, y: 61)
        let elbow = CGPoint(x: 38 - stride * 3, y: 52)
        stroke(context, cloak.opacity(0.75), width: 7,
               points: [CGPoint(x: 43, y: 40), elbow, hand])
        context.fill(Path(ellipseIn: CGRect(x: hand.x - 2.6, y: hand.y - 2, width: 5.2, height: 6)),
                     with: .color(skin))
    }

    private func drawFace(in upper: GraphicsContext) {
        upper.fill(Path(roundedRect: CGRect(x: 47, y: 24, width: 7, height: 12), cornerRadius: 2), with: .color(skin))
        fill(upper, skin) { path in
            path.move(to: CGPoint(x: 43, y: 16))
            path.addQuadCurve(to: CGPoint(x: 58, y: 16), control: CGPoint(x: 52, y: 9))
            path.addLine(to: CGPoint(x: 59, y: 21))
            path.addLine(to: CGPoint(x: 62, y: 25))
            path.addLine(to: CGPoint(x: 59, y: 26))
            path.addQuadCurve(to: CGPoint(x: 48, y: 31), control: CGPoint(x: 59, y: 33))
            path.addQuadCurve(to: CGPoint(x: 43, y: 16), control: CGPoint(x: 41, y: 28))
        }
        fill(upper, hair) { path in
            path.move(to: CGPoint(x: 44, y: 27))
            path.addQuadCurve(to: CGPoint(x: 43, y: 13), control: CGPoint(x: 39, y: 23))
            path.addQuadCurve(to: CGPoint(x: 59, y: 15), control: CGPoint(x: 51, y: 6))
            path.addQuadCurve(to: CGPoint(x: 48, y: 17), control: CGPoint(x: 55, y: 17))
            path.addQuadCurve(to: CGPoint(x: 44, y: 27), control: CGPoint(x: 47, y: 23))
        }
        switch character {
        case .sabinus:
            fill(upper, hair) { path in
                path.move(to: CGPoint(x: 46, y: 22))
                path.addQuadCurve(to: CGPoint(x: 59, y: 26), control: CGPoint(x: 50, y: 28))
                path.addQuadCurve(to: CGPoint(x: 53, y: 38), control: CGPoint(x: 61, y: 33))
                path.addQuadCurve(to: CGPoint(x: 46, y: 22), control: CGPoint(x: 46, y: 35))
            }
        case .sol:
            stroke(upper, Color(red: 0.56, green: 0.49, blue: 0.41), width: 1.2,
                   points: [CGPoint(x: 43.5, y: 21), CGPoint(x: 46, y: 17.5)])
        case .sophy:
            break
        }
        upper.fill(Path(ellipseIn: CGRect(x: 55, y: 20, width: 1.7, height: 1.7)), with: .color(hair))
    }

    private func drawBraid(in context: GraphicsContext) {
        let braid = [CGPoint(x: 44, y: 16), CGPoint(x: 41, y: 26), CGPoint(x: 40, y: 34), CGPoint(x: 37, y: 43)]
        stroke(context, hair, width: 6, points: braid)
        stroke(context, Color(red: 0.76, green: 0.59, blue: 0.33), width: 2,
               points: [CGPoint(x: 35.5, y: 41), CGPoint(x: 39.5, y: 42)])
    }

    private func drawCarryingArm(in context: GraphicsContext) {
        stroke(context, cloak, width: 8, points: [CGPoint(x: 53, y: 38), CGPoint(x: 61, y: 49), CGPoint(x: 72, y: 43)])
        stroke(context, skin, width: 5, points: [CGPoint(x: 71, y: 44), CGPoint(x: 77, y: 41)])
    }

    private func drawCandle(in upper: GraphicsContext, flicker: Double) {
        upper.fill(Path(roundedRect: CGRect(x: 75, y: 30, width: 6, height: 13), cornerRadius: 1.5),
                   with: .color(Color(red: 0.93, green: 0.77, blue: 0.52)))
        stroke(upper, ink, width: 1, points: [CGPoint(x: 78, y: 30), CGPoint(x: 78, y: 27)])
        drawFlame(in: upper, x: 78, base: 28, flicker: flicker)
    }

    private func drawLampLight(in context: GraphicsContext, flicker: Double) {
        var ground = context
        ground.translateBy(x: 63, y: 88.5)
        ground.scaleBy(x: 1, y: 0.18)
        let light = Color(red: 0.98, green: 0.72, blue: 0.26)
        let pool = Path(ellipseIn: CGRect(x: -39, y: -39, width: 78, height: 78))
        ground.fill(pool, with: .radialGradient(
            Gradient(stops: [
                .init(color: light.opacity(0.58 + flicker * 0.07), location: 0),
                .init(color: light.opacity(0.24), location: 0.50),
                .init(color: light.opacity(0), location: 1)
            ]),
            center: .zero, startRadius: 0, endRadius: 39
        ))
    }

    private func drawLamp(in context: GraphicsContext, flicker: Double) {
        let brass = Color(red: 0.76, green: 0.50, blue: 0.20)
        let bronze = Color(red: 0.39, green: 0.24, blue: 0.11)
        let warmGlass = Color(red: 1, green: 0.76, blue: 0.32)
        let glowCenter = CGPoint(x: 79, y: 57)
        let halo = Path(ellipseIn: CGRect(x: 63, y: 41, width: 32, height: 32))
        context.fill(halo, with: .radialGradient(
            Gradient(colors: [warmGlass.opacity(0.44 + flicker * 0.08), warmGlass.opacity(0)]),
            center: glowCenter, startRadius: 0, endRadius: 16
        ))

        // Loop handle rises to the traveler’s hand. The glass hangs beneath it.
        var handle = Path()
        handle.move(to: CGPoint(x: 71, y: 51))
        handle.addCurve(to: CGPoint(x: 87, y: 51), control1: CGPoint(x: 65, y: 39),
                        control2: CGPoint(x: 88, y: 35))
        context.stroke(handle, with: .color(bronze), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        fill(context, warmGlass) { path in
            path.move(to: CGPoint(x: 75, y: 50))
            path.addLine(to: CGPoint(x: 83, y: 50))
            path.addQuadCurve(to: CGPoint(x: 83, y: 65), control: CGPoint(x: 90, y: 63))
            path.addQuadCurve(to: CGPoint(x: 75, y: 65), control: CGPoint(x: 79, y: 66))
            path.addQuadCurve(to: CGPoint(x: 75, y: 50), control: CGPoint(x: 68, y: 63))
        }
        let flameTip = CGPoint(x: 79 + flicker, y: 54 - flicker)
        fill(context, Color(red: 1, green: 0.94, blue: 0.65)) { path in
            path.move(to: flameTip)
            path.addQuadCurve(to: CGPoint(x: 79, y: 63), control: CGPoint(x: 85, y: 62))
            path.addQuadCurve(to: flameTip, control: CGPoint(x: 74, y: 62))
        }
        stroke(context, brass, width: 1.9, points: [CGPoint(x: 72, y: 49), CGPoint(x: 69, y: 63), CGPoint(x: 73, y: 67)])
        stroke(context, brass, width: 1.9, points: [CGPoint(x: 86, y: 49), CGPoint(x: 89, y: 63), CGPoint(x: 85, y: 67)])
        stroke(context, bronze.opacity(0.8), width: 0.9, points: [CGPoint(x: 73, y: 55), CGPoint(x: 85, y: 64)])
        stroke(context, bronze.opacity(0.8), width: 0.9, points: [CGPoint(x: 85, y: 55), CGPoint(x: 73, y: 64)])
        context.fill(Path(roundedRect: CGRect(x: 73, y: 47, width: 12, height: 4), cornerRadius: 1.5),
                     with: .color(bronze))
        context.fill(Path(roundedRect: CGRect(x: 70, y: 66, width: 18, height: 4), cornerRadius: 1.5),
                     with: .color(bronze))
        stroke(context, brass, width: 1.4, points: [CGPoint(x: 72, y: 67), CGPoint(x: 86, y: 67)])
    }

    private func drawFlame(in context: GraphicsContext, x: CGFloat, base: CGFloat, flicker: Double) {
        fill(context, Color(red: 0.89, green: 0.45, blue: 0.15)) { path in
            path.move(to: CGPoint(x: x, y: base))
            path.addQuadCurve(to: CGPoint(x: x + flicker * 2.5, y: base - 13 - flicker * 2),
                              control: CGPoint(x: x - 8, y: base - 2))
            path.addQuadCurve(to: CGPoint(x: x, y: base), control: CGPoint(x: x + 9, y: base - 2))
        }
        context.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: base - 5, width: 3, height: 4)),
                     with: .color(Color(red: 1, green: 0.86, blue: 0.50)))
    }

    private var armorGold: Color { Color(red: 0.81, green: 0.59, blue: 0.28) }
    private var armorSteel: Color { Color(red: 0.43, green: 0.53, blue: 0.59) }
    private var armorShadow: Color { Color(red: 0.27, green: 0.32, blue: 0.35) }

    private func drawArmor(in context: GraphicsContext) {
        // Helmet of salvation and breastplate of righteousness.
        fill(context, armorSteel) { path in
            path.move(to: CGPoint(x: 40, y: 21))
            path.addQuadCurve(to: CGPoint(x: 59, y: 15), control: CGPoint(x: 38, y: 7))
            path.addLines([CGPoint(x: 62, y: 18), CGPoint(x: 47, y: 19), CGPoint(x: 46, y: 27),
                           CGPoint(x: 42, y: 28)])
        }
        stroke(context, armorGold, width: 1.7, points: [CGPoint(x: 41, y: 19), CGPoint(x: 61, y: 17)])
        fill(context, armorShadow) { path in
            path.addLines([CGPoint(x: 42, y: 33), CGPoint(x: 52, y: 36), CGPoint(x: 58, y: 32),
                           CGPoint(x: 63, y: 40), CGPoint(x: 58, y: 52), CGPoint(x: 45, y: 53),
                           CGPoint(x: 40, y: 43)])
        }
        fill(context, armorSteel) { path in
            path.addLines([CGPoint(x: 43, y: 34), CGPoint(x: 52, y: 37), CGPoint(x: 58, y: 34),
                           CGPoint(x: 60, y: 40), CGPoint(x: 56, y: 49), CGPoint(x: 46, y: 50),
                           CGPoint(x: 42, y: 42)])
        }
        stroke(context, armorGold, width: 1.4,
               points: [CGPoint(x: 45, y: 40), CGPoint(x: 53, y: 42), CGPoint(x: 58, y: 39)])
        stroke(context, .white.opacity(0.45), width: 1.2,
               points: [CGPoint(x: 47, y: 45), CGPoint(x: 53, y: 47), CGPoint(x: 57, y: 44)])
        // Belt of truth.
        stroke(context, armorGold, width: 3, points: [CGPoint(x: 41, y: 54), CGPoint(x: 60, y: 54)])
        context.fill(Path(roundedRect: CGRect(x: 49, y: 52, width: 5, height: 4), cornerRadius: 1),
                     with: .color(ink.opacity(0.7)))
    }

    private func drawShieldArm(in context: GraphicsContext, grip: CGPoint) {
        let shoulder = CGPoint(x: 58, y: 36)
        let elbow = CGPoint(x: grip.x - 9, y: grip.y + 6)
        stroke(context, armorShadow, width: 8, points: [shoulder, elbow, grip])
        stroke(context, armorSteel, width: 5.5, points: [elbow, grip])
    }

    private func drawShield(in upper: GraphicsContext, grip: CGPoint) {
        // Draw the curved face in front of the braced forearm, with the near rim in shadow.
        var context = upper
        context.translateBy(x: grip.x, y: grip.y)
        context.fill(Path(ellipseIn: CGRect(x: -3, y: -2, width: 6, height: 5)), with: .color(skin))
        var rim = Path()
        rim.move(to: CGPoint(x: 0, y: -13))
        rim.addQuadCurve(to: CGPoint(x: 15, y: -13), control: CGPoint(x: 7, y: -18))
        rim.addQuadCurve(to: CGPoint(x: 9, y: 27), control: CGPoint(x: 20, y: 12))
        rim.addQuadCurve(to: CGPoint(x: 0, y: -13), control: CGPoint(x: -1, y: 14))
        rim.closeSubpath()
        context.fill(rim, with: .color(armorShadow))
        context.stroke(rim, with: .color(armorGold), lineWidth: 1.5)

        fill(context, armorSteel) { path in
            path.move(to: CGPoint(x: 4, y: -12))
            path.addQuadCurve(to: CGPoint(x: 14, y: -12), control: CGPoint(x: 9, y: -15))
            path.addQuadCurve(to: CGPoint(x: 9, y: 23), control: CGPoint(x: 17, y: 9))
            path.addQuadCurve(to: CGPoint(x: 4, y: -12), control: CGPoint(x: 4, y: 12))
        }
        stroke(context, armorGold, width: 1.8,
               points: [CGPoint(x: 9, y: -7), CGPoint(x: 10, y: 13)])
        stroke(context, armorGold, width: 1.8,
               points: [CGPoint(x: 5, y: 0), CGPoint(x: 14, y: -1)])
    }

    private func drawSwordArm(in context: GraphicsContext, stride: CGFloat) {
        let shoulder = CGPoint(x: 43, y: 37)
        let elbow = CGPoint(x: 36 - stride, y: 48)
        let grip = CGPoint(x: 31 - stride * 3, y: 62 + stride)
        stroke(context, cloak, width: 8, points: [shoulder, elbow, grip])
        stroke(context, armorSteel, width: 6, points: [elbow, grip])
        stroke(context, armorGold, width: 1.5, points: [CGPoint(x: grip.x - 1, y: grip.y - 3),
                                                       CGPoint(x: grip.x + 3, y: grip.y - 1)])
        context.fill(Path(ellipseIn: CGRect(x: 36, y: 32, width: 13, height: 9)), with: .color(armorSteel))
        stroke(context, armorGold, width: 1.4, points: [CGPoint(x: 37, y: 38), CGPoint(x: 42, y: 40),
                                                       CGPoint(x: 47, y: 37)])

        // Keep the hilt and hand on the same pivot as the blade sways across the waist.
        var sword = context
        sword.translateBy(x: grip.x, y: grip.y)
        sword.rotate(by: .degrees(-15 + stride * 2))
        stroke(sword, armorGold, width: 3.5, points: [CGPoint(x: -4, y: 0), CGPoint(x: 7, y: 0)])
        fill(sword, armorSteel) { path in
            path.addLines([CGPoint(x: 7, y: -3), CGPoint(x: 29, y: -2.5), CGPoint(x: 35, y: 0),
                           CGPoint(x: 29, y: 2.5), CGPoint(x: 7, y: 3)])
        }
        stroke(sword, .white.opacity(0.7), width: 1, points: [CGPoint(x: 8, y: -1.5), CGPoint(x: 31, y: -1)])
        stroke(sword, armorGold, width: 2.3, points: [CGPoint(x: 7, y: -4), CGPoint(x: 7, y: 4)])
        sword.fill(Path(ellipseIn: CGRect(x: -2.6, y: -3.2, width: 5.2, height: 6.4)), with: .color(skin))
    }

    private var skin: Color { Color(red: 0.77, green: 0.52, blue: 0.37) }

    private var hair: Color {
        switch character {
        case .sabinus: Color(red: 0.50, green: 0.48, blue: 0.44)
        case .sophy: Color(red: 0.25, green: 0.16, blue: 0.12)
        case .sol: Color(red: 0.30, green: 0.23, blue: 0.17)
        }
    }

    private var cloak: Color { outfitColor ?? character.defaultTravelerOutfit }

    private func fill(_ context: GraphicsContext, _ color: Color, shape: (inout Path) -> Void) {
        var path = Path()
        shape(&path)
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }

    private func stroke(_ context: GraphicsContext, _ color: Color, width: CGFloat, points: [CGPoint]) {
        var path = Path()
        path.addLines(points)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}

extension StudyCompanionCharacter {
    var defaultTravelerOutfit: Color {
        switch self {
        case .sabinus: Color(red: 0.49, green: 0.33, blue: 0.23)
        case .sophy: Color(red: 0.34, green: 0.44, blue: 0.32)
        case .sol: Color(red: 0.29, green: 0.40, blue: 0.55)
        }
    }
}
