import Foundation

struct ActivityHistoryGroup: Identifiable {
    let id: String
    let title: String
    let records: [ActivityRecord]
}

enum ActivityHistoryGrouping {
    static func groups(_ records: [ActivityRecord], now: Date = Date(), calendar: Calendar = .current) -> [ActivityHistoryGroup] {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let week = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let month = calendar.dateInterval(of: .month, for: now)?.start ?? today
        let year = calendar.dateInterval(of: .year, for: now)?.start ?? today
        var buckets: [String: [ActivityRecord]] = [:]
        var titles: [String: String] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.activityDate)
            let key: String
            let title: String
            if day >= today { key = "today"; title = "Today" }
            else if day >= yesterday { key = "yesterday"; title = "Yesterday" }
            else if day >= week { key = "week"; title = "This Week" }
            else if day >= month { key = "month"; title = "This Month" }
            else if day >= year { key = "year"; title = "This Year" }
            else {
                let value = calendar.component(.year, from: day)
                key = "year-\(value)"; title = String(value)
            }
            buckets[key, default: []].append(record)
            titles[key] = title
        }
        let ordered = ["today", "yesterday", "week", "month", "year"]
            + buckets.keys.filter { $0.hasPrefix("year-") }.sorted(by: >)
        return ordered.compactMap { key in
            guard let values = buckets[key], let title = titles[key] else { return nil }
            return ActivityHistoryGroup(id: key, title: title,
                records: values.sorted { $0.activityDate == $1.activityDate ? $0.createdAt > $1.createdAt : $0.activityDate > $1.activityDate })
        }
    }
}
