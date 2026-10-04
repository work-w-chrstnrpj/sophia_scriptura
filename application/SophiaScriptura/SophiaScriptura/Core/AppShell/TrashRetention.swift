import Foundation

enum TrashRetention {
    static let dayCount = 30

    static var interval: TimeInterval { TimeInterval(dayCount * 24 * 3_600) }

    static func permanentDeleteAfter(_ trashedAt: Date) -> Date {
        trashedAt.addingTimeInterval(interval)
    }

    static func isExpired(_ trashedAt: Date, now: Date = Date()) -> Bool {
        now >= permanentDeleteAfter(trashedAt)
    }

    static func daysRemaining(until expiry: Date, now: Date = Date()) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: now, to: expiry).day ?? 0)
    }
}
