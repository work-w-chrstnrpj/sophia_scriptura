import SwiftUI

struct ScriptureNarrationAccessorySheet: View {
    @Bindable var session: ScriptureNarrationSession
    let accessory: ScriptureNarrationPlayerAccessory
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch accessory {
                    case .speed:
                        speedContent
                    case .settings:
                        settingsContent
                    case .timer:
                        timerContent
                    }
                }
                .padding(24)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(accessory.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var speedContent: some View {
        VStack(spacing: 10) {
            ForEach(Array(ScriptureNarrationPlaybackSpeed.speedRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(row) { speed in
                        Button {
                            session.setPlaybackSpeed(speed)
                        } label: {
                            Text(speed.label)
                                .font(.subheadline.weight(session.playbackSpeed == speed ? .semibold : .regular))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    session.playbackSpeed == speed
                                        ? Color.accentColor.opacity(0.18)
                                        : Color.primary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(speed.accessibilityLabel)
                        .accessibilityAddTraits(session.playbackSpeed == speed ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Continuous chapters", isOn: Binding(
                get: { session.preferences.continuousChapters },
                set: { session.setContinuousChapters($0) }
            ))
            Toggle("Follow audio", isOn: Binding(
                get: { session.preferences.followAudio },
                set: { session.setFollowAudio($0) }
            ))
            if let reason = session.followSuspendedReason {
                Text(reason).font(.caption).foregroundStyle(.secondary)
                Button("Return to audio") { session.returnToAudioChapter() }
                    .font(.caption)
            }
        }
    }

    private var timerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if session.sleepTimerIsActive, let remaining = session.sleepTimerRemainingSeconds {
                Label(
                    "Stops in \(ScriptureNarrationSleepTimerFormatting.countdownLabel(remainingSeconds: remaining))",
                    systemImage: "moon.zzz.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            }
            Text("Turns off audio after the selected time. The countdown pauses when playback is paused.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            ForEach(ScriptureNarrationSleepTimer.allCases) { option in
                Button {
                    session.setSleepTimer(option)
                } label: {
                    HStack {
                        Text(option.label)
                        Spacer()
                        if session.sleepTimerSelection == option {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .font(.body)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(session.sleepTimerSelection == option ? .isSelected : [])
            }
        }
    }
}
