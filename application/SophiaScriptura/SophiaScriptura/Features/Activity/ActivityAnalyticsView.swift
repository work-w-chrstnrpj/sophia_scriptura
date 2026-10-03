import SwiftUI
import Charts

struct ActivityAnalyticsView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: ActivityStore
    @Binding var period: ActivityAnalyticsPeriod
    @Binding var anchor: Date
    @Binding var modeID: String
    var exporting = false
    var onExport: (() -> Void)? = nil
    var onShowDistribution: (() -> Void)? = nil
    @State private var showingDatePicker = false

    private var selectedModeID: String? { modeID == "all" ? nil : modeID }
    private var buckets: [ActivityChartBucket] {
        ActivityAnalytics.buckets(period: period, at: anchor, records: store.records, modeID: selectedModeID)
    }
    private var modeChoices: [ActivityMode] {
        var result = store.modes
        for record in store.records where !result.contains(where: { $0.id == record.modeID }) {
            result.append(ActivityMode(id: record.modeID, name: record.modeLabel, archived: true))
        }
        return result
    }
    private var totals: [ActivityModeTotal] {
        ActivityAnalytics.modeTotals(period: period, at: anchor, records: store.records,
                                     modes: modeChoices, filterID: selectedModeID)
    }
    private var totalMinutes: Double { totals.reduce(0) { $0 + $1.minutes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Analytics")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
                Spacer()
                Text("\(Int(totalMinutes.rounded())) min")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color(theme.palette.secondary))
                if !exporting, let onExport {
                    Button(action: onExport) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Print Analytics")
                        .accessibilityIdentifier("activity.analytics.export")
                }
            }
            if exporting {
                Text(period.title + " Analytics")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
            } else {
                Picker("Period", selection: $period) {
                    ForEach(ActivityAnalyticsPeriod.allCases) { choice in Text(choice.title).tag(choice) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("activity.analytics.period")
            }
            HStack {
                if exporting {
                    Label(periodLabel, systemImage: "calendar")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(theme.palette.ink))
                } else {
                    Button { showingDatePicker = true } label: {
                        Label(periodLabel, systemImage: "calendar")
                            .font(.subheadline.weight(.medium))
                    }
                    .accessibilityIdentifier("activity.analytics.date")
                }
                Spacer()
                if exporting {
                    Label(modeChoices.first(where: { $0.id == modeID })?.name ?? "All activities",
                          systemImage: "line.3.horizontal.decrease")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(theme.palette.ink))
                } else {
                    Menu {
                        Button("All activities") { modeID = "all" }
                        ForEach(modeChoices) { mode in
                            Button(mode.name) { modeID = mode.id }
                        }
                    } label: {
                        Label(modeChoices.first(where: { $0.id == modeID })?.name ?? "All activities", systemImage: "line.3.horizontal.decrease")
                    }
                    .accessibilityIdentifier("activity.analytics.modeFilter")
                }
            }
            GeometryReader { area in
                HStack(spacing: 16) {
                    Group {
                        if exporting { distributionCard }
                        else {
                            Button { onShowDistribution?() } label: { distributionCard }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Activity distribution details")
                                .accessibilityIdentifier("activity.analytics.distribution")
                        }
                    }
                    .frame(width: (area.size.width - 16) * 0.4)
                    timeCard
                        .frame(width: (area.size.width - 16) * 0.6)
                }
            }
            .frame(height: cardsHeight)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color(theme.palette.rule), lineWidth: 1))
        .frame(width: exporting ? exportWidth : nil)
        .background(exporting ? Color(theme.palette.paper) : Color.clear)
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                Form {
                    periodDatePicker
                    Text(dateHelp).foregroundStyle(Color(theme.palette.secondary))
                    Text("Selected: \(periodLabel)").font(.subheadline.weight(.semibold))
                }
                .appSurface()
                .navigationTitle(datePickerTitle)
                .toolbar { ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingDatePicker = false }
                } }
            }
        }
    }

    private var distributionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity distribution").font(.headline).foregroundStyle(Color(theme.palette.ink))
            if totals.isEmpty {
                emptyChart
            } else {
                Chart(Array(totals.enumerated()), id: \.element.id) { index, item in
                    SectorMark(angle: .value("Minutes", item.minutes), innerRadius: .ratio(0.55), angularInset: 2)
                        .foregroundStyle(color(for: index))
                        .accessibilityLabel("\(item.name), \(Int(item.minutes.rounded())) minutes")
                }
                .frame(height: 210)
                .overlay { Text("\(Int(totalMinutes.rounded())) min").font(.headline).monospacedDigit() }
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8, alignment: .leading),
                        GridItem(.flexible(), spacing: 8, alignment: .leading),
                        GridItem(.flexible(), spacing: 8, alignment: .leading)
                    ],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(Array(totals.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 6) {
                            Circle().fill(color(for: index)).frame(width: 9, height: 9)
                            Text(item.name)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.caption)
                        .foregroundStyle(Color(theme.palette.secondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .background(Color(theme.palette.paper), in: RoundedRectangle(cornerRadius: 16))
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity over time").font(.headline).foregroundStyle(Color(theme.palette.ink))
            Text("Time · total minutes").font(.caption).foregroundStyle(Color(theme.palette.secondary))
            if buckets.allSatisfy({ $0.seconds == 0 }) {
                emptyChart
            } else {
                Group {
                    if exporting { timeChart }
                    else { ScrollView(.horizontal) { timeChart } }
                }
                if period == .day && buckets.last?.seconds ?? 0 > 0 {
                    Text("No time holds records saved without clock times.")
                        .font(.caption).foregroundStyle(Color(theme.palette.secondary))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .background(Color(theme.palette.paper), in: RoundedRectangle(cornerRadius: 16))
    }

    private var timeChart: some View {
                    Chart(buckets) { bucket in
                        BarMark(x: .value("Time", bucket.label), y: .value("Minutes", bucket.minutes))
                            .foregroundStyle(Color(theme.palette.accent))
                            .cornerRadius(4)
                            .accessibilityLabel("\(bucket.label), \(Int(bucket.minutes.rounded())) minutes")
                    }
                    .chartYAxis { AxisMarks(position: .leading) }
                    .chartXAxis {
                        AxisMarks(values: chartAxisLabels) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label == "No time" ? "N/T" : label)
                                }
                            }
                        }
                    }
                    .chartXScale(range: .plotDimension(padding: 26))
                    .frame(width: chartWidth, height: 235)
    }

    private var emptyChart: some View {
        ContentUnavailableView("No activity in this period", systemImage: "chart.bar",
                               description: Text("Saved sessions appear here after you finish them."))
            .frame(maxWidth: .infinity, minHeight: 210)
    }
    private var chartWidth: CGFloat {
        switch period {
        case .day: 850
        case .week: 430
        case .month: 760
        case .year: 540
        }
    }
    private var cardsHeight: CGFloat {
        let legendRows = max(1, (totals.count + 2) / 3)
        return max(320, 260 + CGFloat(legendRows) * 28)
    }
    private var chartAxisLabels: [String] {
        switch period {
        case .day: return buckets.enumerated().compactMap { index, bucket in
            index.isMultiple(of: 3) || bucket.label == "No time" ? bucket.label : nil
        }
        case .week, .year: return buckets.map(\.label)
        case .month: return buckets.enumerated().compactMap { index, bucket in
            index.isMultiple(of: 5) || index == buckets.count - 1 ? bucket.label : nil
        }
        }
    }
    private var exportWidth: CGFloat { max(1280, (chartWidth + 48) / 0.6 + 52) }
    @ViewBuilder
    private var periodDatePicker: some View {
        switch period {
        case .day, .week:
            DatePicker("Date", selection: $anchor, displayedComponents: .date)
                .datePickerStyle(.graphical)
        case .month:
            ActivityMonthYearPicker(selection: $anchor)
        case .year:
            ActivityYearPicker(selection: $anchor)
        }
    }

    private var datePickerTitle: String {
        switch period {
        case .day: "Choose Day"
        case .week: "Choose Week"
        case .month: "Choose Month"
        case .year: "Choose Year"
        }
    }

    private var dateHelp: String {
        switch period {
        case .day: "Choose the day to analyze."
        case .week: "Choose any date. Sophia automatically selects its full calendar week."
        case .month: "Choose the month and year to analyze."
        case .year: "Choose the year to analyze."
        }
    }
    var periodLabel: String {
        guard let span = ActivityAnalytics.interval(for: period, at: anchor) else { return period.title }
        switch period {
        case .day: return span.start.formatted(date: .complete, time: .omitted)
        case .week: return "\(span.start.formatted(date: .abbreviated, time: .omitted)) – \(span.end.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted))"
        case .month: return span.start.formatted(.dateTime.month(.wide).year())
        case .year: return span.start.formatted(.dateTime.year())
        }
    }
    private func color(for index: Int) -> Color {
        ActivityDistributionColor.color(index: index, dark: theme.dark)
    }
}

private struct ActivityMonthYearPicker: View {
    @Binding var selection: Date
    @State private var month: Int
    @State private var year: Int

    private static var monthSymbols: [String] {
        Calendar.current.monthSymbols
    }

    init(selection: Binding<Date>) {
        _selection = selection
        let calendar = Calendar.current
        let value = selection.wrappedValue
        _month = State(initialValue: calendar.component(.month, from: value))
        _year = State(initialValue: calendar.component(.year, from: value))
    }

    var body: some View {
        HStack {
            Picker("Month", selection: $month) {
                ForEach(1...12, id: \.self) { index in
                    Text(Self.monthSymbols[index - 1]).tag(index)
                }
            }
            .pickerStyle(.wheel)
            Picker("Year", selection: $year) {
                ForEach(yearRange, id: \.self) { value in
                    Text(String(value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: month) { _, _ in syncSelection() }
        .onChange(of: year) { _, _ in syncSelection() }
        .onAppear { syncSelection() }
    }

    private var yearRange: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 30)...current)
    }

    private func syncSelection() {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        if let date = Calendar.current.date(from: components) {
            selection = date
        }
    }
}

private struct ActivityYearPicker: View {
    @Binding var selection: Date
    @State private var year: Int

    init(selection: Binding<Date>) {
        _selection = selection
        _year = State(initialValue: Calendar.current.component(.year, from: selection.wrappedValue))
    }

    var body: some View {
        Picker("Year", selection: $year) {
            ForEach(yearRange, id: \.self) { value in
                Text(String(value)).tag(value)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .onChange(of: year) { _, _ in syncSelection() }
        .onAppear { syncSelection() }
    }

    private var yearRange: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 30)...current)
    }

    private func syncSelection() {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        if let date = Calendar.current.date(from: components) {
            selection = date
        }
    }
}

enum ActivityDistributionColor {
    static func color(index: Int, dark: Bool) -> Color {
        let hues: [Double] = [0.59, 0.40, 0.09, 0.76, 0.96, 0.23, 0.51, 0.16]
        return Color(hue: hues[index % hues.count], saturation: dark ? 0.47 : 0.57,
                     brightness: dark ? 0.87 : 0.66)
    }
}
