import ActivityKit
import Foundation

struct StudyActivityLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var accumulatedSeconds: TimeInterval
        var runningSince: Date?
        var revision: UInt64
    }

    var draftID: UUID
}

enum StudyActivityDeepLink {
    static let scheme = "sophiascriptura"
    static let activityHost = "activity"

    static var activityURL: URL { URL(string: "\(scheme)://\(activityHost)")! }
}
