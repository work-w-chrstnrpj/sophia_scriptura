import SwiftUI

/// Compact play/pause controls for Settings when the shell music FAB is hidden.
struct BackgroundMusicInlineControls: View {
    @ObservedObject var session: MusicSession
    var openLibrary: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Button { session.handle(.togglePlayPause) } label: {
                Image(systemName: session.snapshot.phase == .playing ? "pause.fill" : "play.fill")
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(session.snapshot.phase == .playing ? "Pause music" : "Play music")

            VStack(alignment: .leading, spacing: 2) {
                Text(session.currentTrack?.title ?? "No track selected")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Button("Choose track", action: openLibrary)
                    .font(.caption)
            }
            .foregroundStyle(Color(theme.palette.ink))
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { session.handle(.next) } label: {
                Image(systemName: "forward.fill")
            }
            .accessibilityLabel("Next track")
            .disabled(session.currentTrack == nil)
        }
        .foregroundStyle(Color(theme.palette.ink))
        .padding(.vertical, 4)
        .accessibilityIdentifier("settings.musicInlineControls")
    }
}
