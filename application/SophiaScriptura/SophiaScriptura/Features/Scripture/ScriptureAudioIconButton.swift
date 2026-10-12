import SwiftUI

/// Opens Scripture narration when the active translation supports AO audio (BSB today).
struct ScriptureAudioIconButton: View {
    @Bindable var narration: ScriptureNarrationSession
    let editionID: String?
    let palette: ReaderPalette
    var isEnabled: Bool
    var onOpen: () -> Void

    private var isAvailable: Bool {
        guard let editionID else { return false }
        return ScriptureNarrationCatalog.supportsNarration(editionID: editionID)
    }

    var body: some View {
        if isAvailable {
            Button {
                onOpen()
            } label: {
                Image(systemName: symbolName)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(palette.accent))
                    .frame(width: 44, height: 44)
                    .background(Color(palette.paper), in: Circle())
                    .overlay(Circle().stroke(Color(palette.rule), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("reader.audio")
            .accessibilityLabel("Scripture audio")
            .accessibilityHint("Opens the audio player for this chapter")
            .disabled(!isEnabled)
        }
    }

    private var symbolName: String {
        narration.isNarrationActive ? "waveform.circle.fill" : "headphones.circle.fill"
    }
}
