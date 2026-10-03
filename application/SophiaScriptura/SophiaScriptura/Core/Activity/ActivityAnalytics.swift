import Foundation

enum ActivityAnalyticsPeriod: String, CaseIterable, Identifiable {
    case day, week, month, year

    var id: Self { self }
    var title: String {
        switch self {
        case .day: "Daily"
        case .week: "Weekly"
        case .month: "Monthly"
        case .year: "Annual"
        }
    }
    var calendarComponent: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }
}

struct ActivityChartBucket: Identifiable {
    let id: Int
    let label: String
    let start: Date?
    let end: Date?
    var seconds: TimeInterval
    var minutes: Double { seconds / 60 }
}

struct ActivityModeTotal: Identifiable {
    let id: String
    let name: String
    let seconds: TimeInterval
    var minutes: Double { seconds / 60 }
}

enum ActivityAnalytics {
    static func interval(for period: ActivityAnalyticsPeriod, at date: Date, calendar: Calendar = .current) -> DateInterval? {
        calendar.dateInterval(of: period.calendarComponent, for: date)
    }

    static func buckets(period: ActivityAnalyticsPeriod, at date: Date, records: [ActivityRecord],
                        modeID: String?, calendar: Calendar = .current) -> [ActivityChartBucket] {
        guard let span = interval(for: period, at: date, calendar: calendar) else { return [] }
        let step: Calendar.Component = period == .day ? .hour : period == .year ? .month : .day
        var result: [ActivityChartBucket] = []
        var cursor = span.start
        while cursor < span.end {
            guard let next = calendar.date(byAdding: step, value: 1, to: cursor), next > cursor else { break }
            let end = min(next, span.end)
            let label: String
            switch period {
            case .day: label = cursor.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
            case .week: label = cursor.formatted(.dateTime.weekday(.abbreviated))
            case .month: label = cursor.formatted(.dateTime.day())
            case .year: label = cursor.formatted(.dateTime.month(.abbreviated))
            }
            result.append(ActivityChartBucket(id: result.count, label: label, start: cursor, end: end, seconds: 0))
            cursor = next
        }
        if period == .day {
            result.append(ActivityChartBucket(id: result.count, label: "No time", start: nil, end: nil, seconds: 0))
        }
        for record in records where modeID == nil || record.modeID == modeID {
            if record.intervals.isEmpty {
                guard span.contains(record.activityDate) else { continue }
                if period == .day {
                    result[result.count - 1].seconds += record.activeSeconds
                } else if let index = result.firstIndex(where: { bucket in
                    guard let start = bucket.start, let end = bucket.end else { return false }
                    return start <= record.activityDate && record.activityDate < end
                }) { result[index].seconds += record.activeSeconds }
            } else {
                for interval in record.intervals {
                    for index in result.indices {
                        guard let start = result[index].start, let end = result[index].end else { continue }
                        result[index].seconds += max(0, min(interval.end, end).timeIntervalSince(max(interval.start, start)))
                    }
                }
            }
        }
        return result
    }

    static func modeTotals(period: ActivityAnalyticsPeriod, at date: Date, records: [ActivityRecord],
                           modes: [ActivityMode], filterID: String?, calendar: Calendar = .current) -> [ActivityModeTotal] {
        guard let span = interval(for: period, at: date, calendar: calendar) else { return [] }
        var totals: [String: TimeInterval] = [:]
        var labels: [String: String] = [:]
        for record in records where filterID == nil || record.modeID == filterID {
            labels[record.modeID] = record.modeLabel
            let seconds: TimeInterval
            if record.intervals.isEmpty {
                seconds = span.contains(record.activityDate) ? record.activeSeconds : 0
            } else {
                seconds = record.intervals.reduce(0) { total, interval in
                    total + max(0, min(interval.end, span.end).timeIntervalSince(max(interval.start, span.start)))
                }
            }
            totals[record.modeID, default: 0] += seconds
        }
        return totals.filter { $0.value > 0 }.map { id, seconds in
            ActivityModeTotal(id: id, name: modes.first { $0.id == id }?.name ?? labels[id] ?? id, seconds: seconds)
        }.sorted { $0.seconds == $1.seconds ? $0.name < $1.name : $0.seconds > $1.seconds }
    }
}
