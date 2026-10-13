import SwiftUI
import Charts

enum ActivityChartAnimation {
    static func reveal(duration: TimeInterval = 0.85, reduceMotion: Bool, update: @escaping (Double) -> Void) {
        if reduceMotion {
            update(1)
            return
        }
        update(0)
        withAnimation(.easeOut(duration: duration)) { update(1) }
    }
}

struct ActivityAnimatedDistributionChart: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let totals: [ActivityModeTotal]
    let totalMinutes: Double
    var height: CGFloat = 210
    var innerRadius: CGFloat = 0.55
    @State private var reveal: Double = 0

    var body: some View {
        Chart(Array(totals.enumerated()), id: \.element.id) { index, item in
            SectorMark(
                angle: .value("Minutes", max(0, item.minutes * reveal)),
                innerRadius: .ratio(innerRadius),
                angularInset: 2
            )
            .foregroundStyle(ActivityDistributionColor.color(index: index, dark: theme.dark))
            .accessibilityLabel("\(item.name), \(Int(item.minutes.rounded())) minutes")
        }
        .frame(height: height)
        .overlay {
            Text("\(Int((totalMinutes * reveal).rounded())) min")
                .font(.headline)
                .monospacedDigit()
        }
        .onAppear { ActivityChartAnimation.reveal(reduceMotion: reduceMotion) { reveal = $0 } }
        .onChange(of: totals.map(\.id)) { _, _ in
            ActivityChartAnimation.reveal(reduceMotion: reduceMotion) { reveal = $0 }
        }
    }
}

struct ActivityAnimatedBarChart: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let buckets: [ActivityChartBucket]
    var width: CGFloat
    var height: CGFloat = 235
    var axisLabels: [String]
    @State private var reveal: Double = 0

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Time", bucket.label),
                y: .value("Minutes", bucket.minutes * reveal)
            )
            .foregroundStyle(Color(theme.palette.accent))
            .cornerRadius(4)
            .accessibilityLabel("\(bucket.label), \(Int(bucket.minutes.rounded())) minutes")
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis {
            AxisMarks(values: axisLabels) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label == "No time" ? "N/T" : label)
                    }
                }
            }
        }
        .chartXScale(range: .plotDimension(padding: 26))
        .frame(width: width, height: height)
        .onAppear { ActivityChartAnimation.reveal(reduceMotion: reduceMotion) { reveal = $0 } }
        .onChange(of: buckets.map(\.id)) { _, _ in
            ActivityChartAnimation.reveal(reduceMotion: reduceMotion) { reveal = $0 }
        }
    }
}
