import SwiftUI
import Charts

struct ActivityDistributionDetailView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ActivityStore
    let period: ActivityAnalyticsPeriod
    let anchor: Date
    let modeID: String

    private var modes: [ActivityMode] {
        var result = store.modes
        for record in store.records where !result.contains(where: { $0.id == record.modeID }) {
            result.append(ActivityMode(id: record.modeID, name: record.modeLabel, archived: true))
        }
        return result
    }
    private var totals: [ActivityModeTotal] {
        ActivityAnalytics.modeTotals(period: period, at: anchor, records: store.records,
            modes: modes, filterID: modeID == "all" ? nil : modeID)
    }
    private var seconds: TimeInterval { totals.reduce(0) { $0 + $1.seconds } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(period.title) activity breakdown")
                        .font(.subheadline).foregroundStyle(Color(theme.palette.secondary))
                    if totals.isEmpty {
                        ContentUnavailableView("No activity in this period", systemImage: "chart.pie",
                            description: Text("Saved sessions appear here after you finish them."))
                    } else {
                        ActivityAnimatedDistributionChart(
                            totals: totals,
                            totalMinutes: seconds / 60,
                            height: 170
                        )
                        ForEach(Array(totals.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 12) {
                                Circle().fill(ActivityDistributionColor.color(index: index, dark: theme.dark))
                                    .frame(width: 12, height: 12)
                                Text(item.name).font(.headline)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(ActivityDuration.text(item.seconds)).monospacedDigit().font(.subheadline.weight(.semibold))
                                    Text("\(Int((item.seconds / seconds * 100).rounded()))%")
                                        .font(.caption).foregroundStyle(Color(theme.palette.secondary))
                                }
                            }
                            .padding(14)
                            .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .frame(maxWidth: 640)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .appSurface()
            .navigationTitle("Activity Distribution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.height(400), .large])
    }
}
