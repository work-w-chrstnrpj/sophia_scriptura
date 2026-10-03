import SwiftUI

/// Bottom-leading FAB that expands into a horizontal now-playing bar.
struct BackgroundMusicFloatingControl: View {
    @ObservedObject var session: MusicSession
    @Binding var showLibrary: Bool
    @Binding var fabEngagedUntil: Date
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    private var controlAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 0.86)
    }

    private var fabAnchor: UnitPoint { UnitPoint(x: 0.12, y: 0.5) }

    var body: some View {
        ZStack(alignment: .leading) {
            if expanded {
                expandedBar
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .scale(scale: 0.35, anchor: fabAnchor).combined(with: .opacity)
                    ))
            } else {
                collapsedFAB
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.35, anchor: fabAnchor).combined(with: .opacity),
                        removal: .scale(scale: 0.88, anchor: fabAnchor).combined(with: .opacity)
                    ))
            }
        }
        .animation(controlAnimation, value: expanded)
    }

    private var collapsedFAB: some View {
        Button {
            ShellFABEngagementOpacity.touch(&fabEngagedUntil)
            withAnimation(controlAnimation) { expanded = true }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(theme.palette.accent))
                    .frame(width: 56, height: 56)
                    .shadow(color: Color(theme.palette.ink).opacity(0.18), radius: 12, y: 5)
                Image(systemName: session.snapshot.phase == .playing ? "waveform" : "music.note")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.paper))
                    .symbolEffect(.variableColor.iterative, isActive: session.snapshot.phase == .playing && !reduceMotion)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Expand background music")
        .accessibilityIdentifier("music.fab")
    }

    private var expandedBar: some View {
        HStack(spacing: 12) {
            Button {
                ShellFABEngagementOpacity.touch(&fabEngagedUntil)
                withAnimation(controlAnimation) { expanded = false }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Minimize music controls")

            MusicPlayingIndicator(isPlaying: session.snapshot.phase == .playing)
                .frame(width: 22, height: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.currentTrack?.title ?? "Background music")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(Color(theme.palette.secondary))
            }
            .frame(maxWidth: 160, alignment: .leading)
            .onTapGesture {
                ShellFABEngagementOpacity.touch(&fabEngagedUntil)
                showLibrary = true
            }

            Button {
                ShellFABEngagementOpacity.touch(&fabEngagedUntil)
                session.handle(.togglePlayPause)
            } label: {
                Image(systemName: session.snapshot.phase == .playing ? "pause.fill" : "play.fill")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(session.snapshot.phase == .playing ? "Pause music" : "Play music")
            .accessibilityIdentifier("music.nowActive.playPause")

            Button {
                ShellFABEngagementOpacity.touch(&fabEngagedUntil)
                session.handle(.next)
            } label: {
                Image(systemName: "forward.fill")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Next track")
            .accessibilityIdentifier("music.nowActive.next")

            Button {
                ShellFABEngagementOpacity.touch(&fabEngagedUntil)
                session.handle(.setLoopAll(!session.snapshot.loopAll))
            } label: {
                Image(systemName: "repeat")
                    .frame(width: 32, height: 32)
                    .foregroundStyle(session.snapshot.loopAll ? Color(theme.palette.accent) : Color(theme.palette.ink))
            }
            .accessibilityLabel(session.snapshot.loopAll ? "Loop all tracks on" : "Loop all tracks off")

            Button {
                ShellFABEngagementOpacity.touch(&fabEngagedUntil)
                showLibrary = true
            } label: {
                Image(systemName: "music.note.list")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Choose track")
            .accessibilityIdentifier("music.library")
        }
        .foregroundStyle(Color(theme.palette.ink))
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color(theme.palette.rule), lineWidth: 1))
        .shadow(color: Color(theme.palette.ink).opacity(0.12), radius: 14, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("music.expandedBar")
    }

    private var statusLabel: String {
        switch session.snapshot.phase {
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .interrupted: return "Paused — tap Play"
        case .idle:
            return session.currentTrack == nil ? "Tap title to choose a track" : "Ready"
        }
    }
}

private struct MusicPlayingIndicator: View {
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            bar(height: 0.55)
            bar(height: 0.85)
            bar(height: 0.45)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private func bar(height: CGFloat) -> some View {
        if isPlaying, !reduceMotion {
            TimelineView(.animation(minimumInterval: 0.12)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Capsule()
                    .fill(Color.primary.opacity(0.75))
                    .frame(width: 4, height: 6 + 10 * abs(sin(t * 3.2 + height * 6)))
            }
        } else {
            Capsule()
                .fill(Color.primary.opacity(isPlaying ? 0.75 : 0.25))
                .frame(width: 4, height: 6 + 10 * height)
        }
    }
}
