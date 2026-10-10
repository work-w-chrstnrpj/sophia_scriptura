import SwiftUI

struct StudyCompanionCharacterView: View {
    let poseName: String
    let character: StudyCompanionCharacter
    let edge: String
    let quote: StudyCompanionIdleQuote?
    let quoteVisible: Bool
    let reduceMotion: Bool
    let sceneActive: Bool
    let onTap: () -> Void
    let onMoveOppositeEdge: () -> Void
    let onResetPosition: () -> Void
    @Environment(\.appTheme) private var theme

    private var isLeading: Bool { edge == "leading" }

    var body: some View {
        VStack(alignment: isLeading ? .leading : .trailing, spacing: 0) {
            if quoteVisible, let quote {
                quoteBubble(quote)
                    .transition(.scale(scale: 0.92, anchor: isLeading ? .bottomLeading : .bottomTrailing).combined(with: .opacity))
                    .padding(.bottom, 8)
            }
            characterButton
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82), value: quoteVisible)
    }

    private var characterButton: some View {
        Button(action: onTap) {
            TimelineView(.animation(minimumInterval: reduceMotion || !sceneActive ? 60 : 1 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let bob = reduceMotion || !sceneActive ? 0 : sin(t * 2.1) * 4
                let sway = reduceMotion || !sceneActive ? 0 : sin(t * 1.3) * 2
                let scale = reduceMotion || !sceneActive ? 1 : 1 + sin(t * 1.7) * 0.045
                Image(poseName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 96)
                    .id("\(character.id)-\(poseName)")
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(sway * 0.35))
                    .offset(y: bob)
                    .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
                    .accessibilityHidden(true)
            }
            .frame(width: 72, height: 96)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(character.displayName)")
        .accessibilityHint(character.accessibilityHint)
        .accessibilityIdentifier("sophy.character")
        .accessibilityAction(named: "Move \(character.displayName) to the other edge", onMoveOppositeEdge)
        .accessibilityAction(named: "Reset \(character.displayName) position", onResetPosition)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: poseName)
    }

    private func quoteBubble(_ quote: StudyCompanionIdleQuote) -> some View {
        let tailOnTrailing = !isLeading
        return VStack(alignment: .leading, spacing: 4) {
            Text(quote.text)
                .font(.caption)
                .foregroundStyle(Color(theme.palette.ink))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(quote.reference)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(theme.palette.secondary))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: 260, alignment: .leading)
        .background {
            SpeechBalloonShape(tailOnTrailing: tailOnTrailing)
                .fill(Color(theme.palette.paper))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
        }
        .overlay {
            SpeechBalloonShape(tailOnTrailing: tailOnTrailing)
                .stroke(Color(theme.palette.soft), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(quote.reference). \(quote.text)")
    }
}

private struct SpeechBalloonShape: Shape {
    var tailOnTrailing: Bool
    private let cornerRadius: CGFloat = 18
    private let tailWidth: CGFloat = 18
    private let tailHeight: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let bodyHeight = rect.height - tailHeight
        let body = CGRect(x: 0, y: 0, width: rect.width, height: bodyHeight)
        var path = Path(roundedRect: body, cornerRadius: cornerRadius, style: .continuous)
        let tailCenterX = tailOnTrailing ? rect.width - 28 : 28
        path.move(to: CGPoint(x: tailCenterX - tailWidth / 2, y: bodyHeight - 1))
        path.addQuadCurve(
            to: CGPoint(x: tailCenterX, y: rect.maxY),
            control: CGPoint(x: tailCenterX - tailWidth * 0.15, y: bodyHeight + tailHeight * 0.55)
        )
        path.addQuadCurve(
            to: CGPoint(x: tailCenterX + tailWidth / 2, y: bodyHeight - 1),
            control: CGPoint(x: tailCenterX + tailWidth * 0.15, y: bodyHeight + tailHeight * 0.55)
        )
        path.closeSubpath()
        return path
    }
}
