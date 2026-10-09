import Foundation

enum ActivityModeID: String, Codable, CaseIterable, Identifiable {
    case reading, studying, meditating, journaling, memorizing
    var id: String { rawValue }
    var title: String {
        switch self {
        case .reading: "Reading"
        case .studying: "Studying"
        case .meditating: "Contemplating"
        case .journaling: "Journaling"
        case .memorizing: "Memorizing Verses"
        }
    }
}

struct ActivityMode: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var archived = false
    var isBuiltIn = false
}

struct ActivityInterval: Codable, Equatable {
    var start: Date
    var end: Date
    var seconds: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

struct ActivityRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var modeID: String
    var modeLabel: String
    var activityDate: Date
    var activeSeconds: TimeInterval
    var source: String
    var timeZoneID: String
    var intervals: [ActivityInterval]
    var description: String
    var readingRange: PassageRange?
    var editionID: String?
    var quizSessionID: UUID?
    var createdAt: Date
    var updatedAt: Date
}

struct ActivityDraft: Codable, Equatable {
    var id: UUID
    var title: String
    var modeID: String
    var modeLabel: String
    var startedAt: Date
    var runningSince: Date?
    var intervals: [ActivityInterval]
    var description: String
    var readingStart: VerseID?
    var editionID: String?
    var guidedWorkflow: Bool? = nil

    func activeSeconds(at now: Date) -> TimeInterval {
        intervals.reduce(0) { $0 + $1.seconds } + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    mutating func pause(at now: Date) {
        guard let start = runningSince else { return }
        intervals.append(ActivityInterval(start: start, end: max(start, now)))
        runningSince = nil
    }
}

enum ActivityReminderRepeat: String, Codable, CaseIterable, Identifiable {
    case once, daily, weekdays, weekends, weekly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .once: "Once"
        case .daily: "Daily"
        case .weekdays: "Weekdays"
        case .weekends: "Weekends"
        case .weekly: "Weekly"
        }
    }
}

struct ActivityReminder: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var description: String
    var date: Date
    var modeID: String
    var modeLabel: String
    var repeatRule: ActivityReminderRepeat
    // Optional so reminders saved before per-record cleanup was introduced still decode.
    var deleteAfterFiring: Bool? = nil
}

struct ActivitySnapshot: Codable {
    var schemaVersion = 1
    var records: [ActivityRecord] = []
    var customModes: [ActivityMode] = []
    var draft: ActivityDraft?
    var dailyGoalMinutes = 10
    // Optional so existing Activity generations migrate their total goal to Reading.
    var dailyGoalMinutesByMode: [String: Int]?
    // Optional so existing v1 Activity files continue to decode.
    var suppressedQuizSessionIDs: [UUID]?
    // Optional for existing v1 archives and local generations.
    var reminders: [ActivityReminder]?
    // Missing values preserve the guided-start behavior of older versions.
    var automaticReadingWorkflow: Bool?
    var automaticContemplationWorkflow: Bool?
    var autoDeleteOneTimeReminders: Bool? // Legacy preference, migrated to each reminder on load.
}

extension ActivitySnapshot {
    /// Wire IDs for contemplation stay stable; legacy Reviewing time becomes Studying.
    mutating func migrateBuiltInModes() {
        func canonical(_ id: String) -> String { id == "reviewing" ? ActivityModeID.studying.id : id }
        func label(_ id: String, fallback: String) -> String { ActivityModeID(rawValue: canonical(id))?.title ?? fallback }
        for i in records.indices {
            records[i].modeLabel = label(records[i].modeID, fallback: records[i].modeLabel)
            records[i].modeID = canonical(records[i].modeID)
        }
        if var value = draft {
            value.modeLabel = label(value.modeID, fallback: value.modeLabel)
            value.modeID = canonical(value.modeID); draft = value
        }
        if var values = reminders {
            for i in values.indices {
                values[i].modeLabel = label(values[i].modeID, fallback: values[i].modeLabel)
                values[i].modeID = canonical(values[i].modeID)
            }
            reminders = values
        }
        if let oldGoal = dailyGoalMinutesByMode?.removeValue(forKey: "reviewing") {
            dailyGoalMinutesByMode?[ActivityModeID.studying.id, default: 0] += oldGoal
        }
    }
}

enum ActivityMetrics {
    static func seconds(on day: Date, records: [ActivityRecord], calendar: Calendar = .current) -> TimeInterval {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return records.reduce(0) { total, record in
            if record.intervals.isEmpty {
                return total + (calendar.isDate(record.activityDate, inSameDayAs: day) ? record.activeSeconds : 0)
            }
            return total + record.intervals.reduce(0) { subtotal, interval in
                subtotal + max(0, min(interval.end, end).timeIntervalSince(max(interval.start, start)))
            }
        }
    }

    static func streak(through day: Date, records: [ActivityRecord], goalMinutes: Int, calendar: Calendar = .current) -> Int {
        var count = 0
        var cursor = calendar.startOfDay(for: day)
        if seconds(on: cursor, records: records, calendar: calendar) < Double(goalMinutes * 60),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) { cursor = yesterday }
        while seconds(on: cursor, records: records, calendar: calendar) >= Double(goalMinutes * 60) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func bestStreak(records: [ActivityRecord], goalMinutes: Int, calendar: Calendar = .current) -> Int {
        guard let first = records.map(\.activityDate).min(),
              let last = records.flatMap({ [$0.activityDate] + $0.intervals.map(\.end) }).max() else { return 0 }
        var day = calendar.startOfDay(for: first)
        let end = calendar.startOfDay(for: last)
        var current = 0
        var best = 0
        while day <= end {
            current = seconds(on: day, records: records, calendar: calendar) >= Double(goalMinutes * 60) ? current + 1 : 0
            best = max(best, current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return best
    }
}
