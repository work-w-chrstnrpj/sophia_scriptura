import Foundation

struct PlanReminderOccurrence: Codable, Hashable {
    let planID: UUID
    let sectionID: UUID
    let dueDay: Date
}

enum PlanReminderTime {
    static func minute(of date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    static func displayDate(_ minute: Int, calendar: Calendar) -> Date {
        date(on: Date(), minute: minute, calendar: calendar) ?? Date()
    }

    static func date(on day: Date, minute: Int, calendar: Calendar) -> Date? {
        guard (0..<1440).contains(minute) else { return nil }
        guard let time = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day),
              calendar.isDate(time, inSameDayAs: day) else { return nil }
        return time
    }

    static func rollingReminders(
        for plans: [StudyPlan], existing: [ActivityReminder], times: [UUID: Int],
        now: Date, isPrivate: (UUID) -> Bool
    ) -> [ActivityReminder] {
        let previous = Dictionary(existing.compactMap { reminder in
            reminder.planOccurrence.map { ($0, reminder) }
        }, uniquingKeysWith: { first, _ in first })
        var reminders = existing.filter { $0.planOccurrence == nil }
        for plan in plans where plan.isActive {
            guard let schedule = plan.strictSchedule else { continue }
            let calendar = schedule.calendar
            let today = calendar.startOfDay(for: now)
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { continue }
            for index in plan.sections.indices {
                let section = plan.sections[index]
                guard !section.items.isEmpty, plan.completionDate(for: index) == nil,
                      let due = plan.dueDate(for: index) else { continue }
                let day = calendar.startOfDay(for: due)
                guard day == today || day == tomorrow else { continue }
                let occurrence = PlanReminderOccurrence(planID: plan.id, sectionID: section.id, dueDay: day)
                let saved = previous[occurrence]
                let time = saved?.planTimeOverride ?? times[plan.id] ?? schedule.initialReminderMinute
                guard let date = date(on: day, minute: time, calendar: calendar) else { continue }
                let expired = saved.map { $0.date <= now } ?? false
                guard date > now || expired || saved?.planDismissed == true else { continue }
                reminders.append(ActivityReminder(
                    id: saved?.id ?? UUID(),
                    title: isPrivate(plan.id) ? "Study Plan reminder" : "\(plan.title) · \(plan.sectionTitle(index))",
                    description: "", date: expired ? (saved?.date ?? date) : date,
                    modeID: ActivityModeID.reading.id, modeLabel: ActivityModeID.reading.title,
                    repeatRule: .once, deleteAfterFiring: true, planOccurrence: occurrence,
                    planTimeZoneID: schedule.timeZoneID, planTimeOverride: saved?.planTimeOverride, planDismissed: saved?.planDismissed
                ))
            }
        }
        return reminders
    }
}
