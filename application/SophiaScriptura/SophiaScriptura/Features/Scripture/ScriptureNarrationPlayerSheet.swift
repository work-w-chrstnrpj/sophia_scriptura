import SwiftUI

struct ScriptureNarrationPlayerSheet: View {
    @Bindable var session: ScriptureNarrationSession
    let chapterTitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var isLandscape = false
    @State private var presentedAccessory: ScriptureNarrationPlayerAccessory?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: isLandscape ? 16 : 20) {
                        header
                        if case .failed(let message) = session.snapshot.phase {
                            Text(message).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                        }
                        if let status = session.snapshot.highlightingStatusMessage {
                            Label(status, systemImage: "text.line.first.and.arrowtriangle.forward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        progressSection
                        unifiedTransportRow
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, isLandscape ? 4 : 8)
                    .padding(.bottom, 12)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)

                bottomIconBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .padding(.top, 4)
            }
            .navigationTitle(chapterTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Stop") { session.stop() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $presentedAccessory) { accessory in
            ScriptureNarrationAccessorySheet(session: session, accessory: accessory)
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { isLandscape = geometry.size.width > geometry.size.height }
                    .onChange(of: geometry.size) { _, size in
                        isLandscape = size.width > size.height
                    }
            }
        }
        .task {
            session.prepareCurrentChapter()
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Scripture Audio")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(session.snapshot.editionDisplayName.isEmpty ? ScriptureNarrationCatalog.bsbDisplayName : session.snapshot.editionDisplayName)
                .font(.subheadline)
            Text(session.snapshot.narratorDisplayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            if session.snapshot.usesLocalAudio {
                Label("Saved on this iPad", systemImage: "arrow.down.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if session.preferences.deliveryMode == .streaming {
                Label("Streaming", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { session.snapshot.duration > 0 ? session.snapshot.elapsed / session.snapshot.duration : 0 },
                    set: { session.seek(to: $0) }
                )
            )
            .disabled(session.snapshot.duration <= 0 || session.snapshot.phase == .loading)
            HStack {
                Text(format(session.snapshot.elapsed))
                Spacer()
                Text(format(session.snapshot.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var unifiedTransportRow: some View {
        let loading = session.snapshot.phase == .loading
        return HStack(spacing: 0) {
            transportIcon("backward.end.fill", label: "Previous chapter") {
                session.previousChapter()
            }
            .disabled(!session.canGoToPreviousChapter || loading)

            transportIcon("chevron.left.circle.fill", label: "Previous verse") {
                session.previousVerse()
            }
            .disabled(!session.canGoToPreviousVerse || loading)

            Button { session.togglePlayPause() } label: {
                Image(systemName: playPauseSymbol)
                    .font(.system(size: isLandscape ? 44 : 52))
            }
            .accessibilityLabel("Play or pause")
            .frame(minWidth: 72)

            transportIcon("chevron.right.circle.fill", label: "Next verse") {
                session.nextVerse()
            }
            .disabled(!session.canGoToNextVerse || loading)

            transportIcon("forward.end.fill", label: "Next chapter") {
                session.nextChapter()
            }
            .disabled(!session.canGoToNextChapter || loading)
        }
        .buttonStyle(.plain)
        .font(.title3)
        .frame(maxWidth: .infinity)
    }

    private var bottomIconBar: some View {
        HStack {
            panelIcon(
                symbol: "speedometer",
                label: "Playback speed",
                subtitle: session.playbackSpeed.label
            ) {
                presentedAccessory = .speed
            }
            Spacer(minLength: 16)
            panelIcon(
                symbol: "gearshape.fill",
                label: "Audio settings",
                subtitle: nil
            ) {
                presentedAccessory = .settings
            }
            Spacer(minLength: 16)
            timerIcon
        }
    }

    private var timerIcon: some View {
        let subtitle: String? = {
            guard session.sleepTimerIsActive, let remaining = session.sleepTimerRemainingSeconds else { return nil }
            return ScriptureNarrationSleepTimerFormatting.countdownLabel(remainingSeconds: remaining)
        }()
        return panelIcon(
            symbol: session.sleepTimerIsActive ? "timer.circle.fill" : "timer",
            label: "Sleep timer",
            subtitle: subtitle
        ) {
            presentedAccessory = .timer
        }
    }

    private func panelIcon(
        symbol: String,
        label: String,
        subtitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.title2)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: 72, height: 52)
            .foregroundStyle(Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(subtitle ?? "")
    }

    private func transportIcon(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .accessibilityLabel(label)
    }

    private var playPauseSymbol: String {
        switch session.snapshot.phase {
        case .playing: "pause.circle.fill"
        case .loading: "hourglass.circle.fill"
        default: "play.circle.fill"
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        guard interval.isFinite, interval >= 0 else { return "0:00" }
        let total = Int(interval.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
