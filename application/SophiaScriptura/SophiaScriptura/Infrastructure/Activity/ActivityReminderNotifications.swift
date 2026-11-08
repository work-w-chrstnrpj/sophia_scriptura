import Foundation
import UserNotifications

enum ActivityReminderNotifications {
    private static let prefix = "activity-reminder-"

    static func sync(_ reminders: [ActivityReminder], requestPermission: Bool) async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if requestPermission && status == .notDetermined {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            status = await center.notificationSettings().authorizationStatus
        }
        guard status == .authorized || status == .provisional || status == .ephemeral else { return false }

        let requests = reminders.flatMap(requests(for:))
        guard requests.count <= 64 else { throw ActivityReminderError.tooManyNotifications }
        let existing = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(prefix) }
        let desiredIDs = Set(requests.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: existing.map(\.identifier).filter { !desiredIDs.contains($0) })
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.identifier, $0) })
        for request in requests {
            if let current = existingByID[request.identifier],
               let oldTrigger = current.trigger as? UNCalendarNotificationTrigger,
               let newTrigger = request.trigger as? UNCalendarNotificationTrigger,
               oldTrigger.dateComponents == newTrigger.dateComponents,
               oldTrigger.repeats == newTrigger.repeats,
               current.content.title == request.content.title,
               current.content.body == request.content.body { continue }
            try await center.add(request)
        }
        return true
    }

    static func requests(for reminder: ActivityReminder) -> [UNNotificationRequest] {
        guard reminder.repeatRule != .once || reminder.date > Date() else { return [] }
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: reminder.date)
        let weekdays: [Int]
        switch reminder.repeatRule {
        case .once, .daily: weekdays = []
        case .weekdays: weekdays = [2, 3, 4, 5, 6]
        case .weekends: weekdays = [1, 7]
        case .weekly: weekdays = [calendar.component(.weekday, from: reminder.date)]
        }
        let choices = weekdays.isEmpty ? [nil] : weekdays.map(Optional.some)
        return choices.map { weekday in
            var components = time
            if reminder.repeatRule == .once {
                components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            } else {
                components.weekday = weekday
            }
            let content = UNMutableNotificationContent()
            content.title = reminder.planOccurrence == nil ? reminder.title : "Sophia study reminder"
            content.body = reminder.description.isEmpty ? "Time for \(reminder.modeLabel)." : reminder.description
            content.sound = .default
            content.userInfo = ["activityReminderID": reminder.id.uuidString]
            let suffix = weekday.map(String.init) ?? "once"
            return UNNotificationRequest(identifier: prefix + reminder.id.uuidString + "-" + suffix,
                content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components,
                    repeats: reminder.repeatRule != .once))
        }
    }
}

enum ActivityReminderError: LocalizedError {
    case tooManyNotifications
    var errorDescription: String? {
        "Too many reminder notifications are scheduled. Keep fewer active reminders or choose a recurrence with fewer days."
    }
}

final class ActivityForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
