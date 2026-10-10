import Foundation

enum SophyInsights {
    struct Report: Equatable, Sendable {
        var ownerText: String
        var providerLines: [String]
        var timeZoneID: String
        var incomplete: Bool
        var isEmpty: Bool
    }

    static func report(
        records: [ActivityRecord],
        modes: [ActivityMode],
        period: ActivityAnalyticsPeriod,
        at date: Date,
        calendar: Calendar,
        now: Date = Date()
    ) -> Report {
        let span = ActivityAnalytics.interval(for: period, at: date, calendar: calendar)
        let totals = ActivityAnalytics.modeTotals(period: period, at: date, records: records, modes: modes, filterID: nil, calendar: calendar)
        let incomplete = span.map { now < $0.end } ?? true
        let zone = calendar.timeZone.identifier
        guard !totals.isEmpty else {
            return Report(
                ownerText: "No study time is recorded for this \(period.rawValue).",
                providerLines: ["period=\(period.rawValue)", "timezone=\(zone)", "incomplete=\(incomplete)", "empty=true"],
                timeZoneID: zone,
                incomplete: incomplete,
                isEmpty: true
            )
        }
        let owner = totals.map { total in
            "\(total.name): \(formatted(total.seconds))"
        }.joined(separator: "\n")
        let provider = totals.map { total in
            "\(providerLabel(modeID: total.id, modes: modes)): \(Int(total.seconds.rounded()))s"
        }
        var lines = ["period=\(period.rawValue)", "timezone=\(zone)", "incomplete=\(incomplete)", "empty=false"]
        lines.append(contentsOf: provider)
        return Report(
            ownerText: owner,
            providerLines: lines,
            timeZoneID: zone,
            incomplete: incomplete,
            isEmpty: false
        )
    }

    static func providerLabel(modeID: String, modes: [ActivityMode]) -> String {
        if ActivityModeID(rawValue: modeID) != nil {
            return modes.first { $0.id == modeID }?.name ?? modeID
        }
        let customs = modes.filter { !$0.isBuiltIn }.sorted { $0.id < $1.id }
        if let index = customs.firstIndex(where: { $0.id == modeID }) {
            return "Custom activity \(index + 1)"
        }
        return "Custom activity"
    }

    static func period(named raw: String) -> ActivityAnalyticsPeriod? {
        switch raw.lowercased() {
        case "day", "today": return .day
        case "week": return .week
        case "month": return .month
        case "year": return .year
        default: return nil
        }
    }

    private static func formatted(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }
}
