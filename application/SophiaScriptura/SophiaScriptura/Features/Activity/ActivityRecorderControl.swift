import SwiftUI

/// Keeps high-frequency drag updates inside the control instead of redrawing all mounted tabs.
struct ActivityFloatingRecorder: View {
    let draft: ActivityDraft
    @Binding var fabEngagedUntil: Date
    let pauseOrResume: () -> Void
    let finish: () -> Void
    @State private var expanded = false
    @State private var position = CGPoint(x: 0.78, y: 0.68)
    @State private var translation = CGSize.zero
    @State private var bounds = CGSize.zero

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { bounds = geometry.size }
                        .onChange(of: geometry.size) { _, size in bounds = size }
                }
                .allowsHitTesting(false)
            }
            .overlay {
                if bounds.width > 0, bounds.height > 0 {
                    ActivityRecorderControl(
                        draft: draft,
                        expanded: $expanded,
                        fabEngagedUntil: $fabEngagedUntil,
                        pauseOrResume: pauseOrResume,
                        finish: finish
                    )
                        .position(
                            x: clamped(position.x * bounds.width + translation.width,
                                       size: bounds.width, inset: expanded ? 155 : 100),
                            y: clamped(position.y * bounds.height + translation.height,
                                       size: bounds.height, inset: 38))
                        .highPriorityGesture(DragGesture(minimumDistance: 1)
                            .onChanged { value in translation = value.translation }
                            .onEnded { value in
                                let x = clamped(position.x * bounds.width + value.translation.width,
                                                size: bounds.width, inset: expanded ? 155 : 100)
                                let y = clamped(position.y * bounds.height + value.translation.height,
                                                size: bounds.height, inset: 38)
                                position = CGPoint(x: x / max(1, bounds.width), y: y / max(1, bounds.height))
                                translation = .zero
                            })
                        .transaction { $0.disablesAnimations = true }
                }
            }
    }

    private func clamped(_ value: CGFloat, size: CGFloat, inset: CGFloat) -> CGFloat {
        min(max(value, min(inset, size / 2)), max(inset, size - inset))
    }
}

/// A movable cross-tab control for the single active Activity draft.
struct ActivityRecorderControl: View {
    @Environment(\.appTheme) private var theme
    let draft: ActivityDraft
    @Binding var expanded: Bool
    @Binding var fabEngagedUntil: Date
    let pauseOrResume: () -> Void
    let finish: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                ShellFABEngagementOpacity.touch(&fabEngagedUntil)
                expanded.toggle()
            } label: {
                HStack(spacing: 9) {
                    Text(draft.modeLabel)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if expanded {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(ActivityDuration.text(draft.activeSeconds(at: context.date)))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    } else {
                        ActivityRecorderClockIcon(draft: draft)
                            .accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(expanded ? "Minimize \(draft.modeLabel) recorder" : "Expand \(draft.modeLabel) recorder")
            .accessibilityIdentifier("activity.recorder.expand")

            if expanded {
                Button {
                    ShellFABEngagementOpacity.touch(&fabEngagedUntil)
                    pauseOrResume()
                } label: {
                    Image(systemName: draft.runningSince == nil ? "play.fill" : "pause.fill")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel(draft.runningSince == nil ? "Resume activity" : "Pause activity")
                .accessibilityIdentifier("activity.recorder.pause")
                Button {
                    ShellFABEngagementOpacity.touch(&fabEngagedUntil)
                    finish()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Finish activity")
                .accessibilityIdentifier("activity.recorder.finish")
            }
        }
        .foregroundStyle(Color(theme.palette.ink))
        .padding(.leading, 16)
        .padding(.trailing, expanded ? 10 : 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color(theme.palette.rule), lineWidth: 1))
        .shadow(color: Color(theme.palette.ink).opacity(0.12), radius: 14, y: 5)
        .fixedSize()
        .accessibilityElement(children: .contain)
    }
}

/// Analog clock with moving hands while the activity timer runs.
private struct ActivityRecorderClockIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let draft: ActivityDraft

    var body: some View {
        Group {
            if reduceMotion {
                clockFace(elapsed: draft.activeSeconds(at: Date()))
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
                    clockFace(elapsed: draft.activeSeconds(at: timeline.date))
                }
            }
        }
        .frame(width: 22, height: 22)
    }

    private func clockFace(elapsed: TimeInterval) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 0.5
            let dial = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            context.stroke(dial, with: .color(.primary.opacity(0.35)), lineWidth: 1.2)

            let minuteAngle = Angle.degrees((elapsed.truncatingRemainder(dividingBy: 3600)) / 3600 * 360 - 90)
            let secondAngle = Angle.degrees((elapsed.truncatingRemainder(dividingBy: 60)) / 60 * 360 - 90)
            drawHand(context: &context, center: center, length: radius * 0.55, width: 1.6, angle: minuteAngle, opacity: 0.85)
            drawHand(context: &context, center: center, length: radius * 0.78, width: 1.1, angle: secondAngle, opacity: 0.95)

            let hub = Path(ellipseIn: CGRect(x: center.x - 1.6, y: center.y - 1.6, width: 3.2, height: 3.2))
            context.fill(hub, with: .color(.primary.opacity(0.9)))
        }
    }

    private func drawHand(context: inout GraphicsContext, center: CGPoint, length: CGFloat, width: CGFloat, angle: Angle, opacity: Double) {
        let end = CGPoint(
            x: center.x + cos(angle.radians) * length,
            y: center.y + sin(angle.radians) * length
        )
        var path = Path()
        path.move(to: center)
        path.addLine(to: end)
        context.stroke(path, with: .color(.primary.opacity(opacity)), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}
