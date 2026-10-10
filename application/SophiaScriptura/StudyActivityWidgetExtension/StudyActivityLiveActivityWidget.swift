import ActivityKit
import SwiftUI
import WidgetKit

struct StudyActivityLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivityLiveActivityAttributes.self) { context in
            StudyActivityLockScreenView(state: context.state)
                .activityBackgroundTint(Color(.systemBackground))
                .widgetURL(StudyActivityDeepLink.activityURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Study activity", systemImage: "timer")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.runningSince == nil ? "Paused" : "Running")
                        .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    StudyActivityElapsedText(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                StudyActivityElapsedText(state: context.state)
            } minimal: {
                Image(systemName: "timer")
            }
            .widgetURL(StudyActivityDeepLink.activityURL)
        }
    }
}

private struct StudyActivityLockScreenView: View {
    let state: StudyActivityLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Study activity", systemImage: "timer")
                    .font(.headline)
                Spacer()
                Text(state.runningSince == nil ? "Paused" : "Running")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            StudyActivityElapsedText(state: state)
        }
        .padding(.vertical, 4)
    }
}

private struct StudyActivityElapsedText: View {
    let state: StudyActivityLiveActivityAttributes.ContentState

    var body: some View {
        if let runningSince = state.runningSince {
            let origin = runningSince.addingTimeInterval(-state.accumulatedSeconds)
            Text(timerInterval: origin...Date.distantFuture, countsDown: false)
                .font(.system(.title3, design: .monospaced))
                .monospacedDigit()
        } else {
            Text(formatElapsed(state.accumulatedSeconds))
                .font(.system(.title3, design: .monospaced))
                .monospacedDigit()
        }
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }
}
