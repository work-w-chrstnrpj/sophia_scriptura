import SwiftUI

/// Activity tab. Phase 7 adds the reading habit timer, manual session entry, and local
/// analytics (streaks, weekly minutes, per-book time).
struct ActivityView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Activity",
                systemImage: "chart.bar",
                description: Text("The reading habit timer and analytics arrive in Phase 7.")
            )
            .appSurface()
            .navigationTitle("Activity")
        }
    }
}

#Preview {
    ActivityView()
}
