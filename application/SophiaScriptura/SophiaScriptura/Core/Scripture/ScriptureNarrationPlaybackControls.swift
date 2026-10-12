import Foundation

enum ScriptureNarrationPlaybackSpeed: Float, CaseIterable, Identifiable, Sendable {
    case half = 0.5
    case threeQuarters = 0.75
    case normal = 1
    case oneAndQuarter = 1.25
    case oneAndHalf = 1.5
    case oneAndThreeQuarters = 1.75
    case double = 2
    case triple = 3

    var id: Float { rawValue }

    static var `default`: ScriptureNarrationPlaybackSpeed { .normal }

    /// Two even rows of four speeds for the player sheet grid.
    static let speedRows: [[ScriptureNarrationPlaybackSpeed]] = [
        [.half, .threeQuarters, .normal, .oneAndQuarter],
        [.oneAndHalf, .oneAndThreeQuarters, .double, .triple]
    ]

    static func closest(to rate: Float) -> ScriptureNarrationPlaybackSpeed {
        allCases.min(by: { abs($0.rawValue - rate) < abs($1.rawValue - rate) }) ?? .normal
    }

    var label: String {
        switch self {
        case .half: return "0.5×"
        case .threeQuarters: return "0.75×"
        case .normal: return "1×"
        case .oneAndQuarter: return "1.25×"
        case .oneAndHalf: return "1.5×"
        case .oneAndThreeQuarters: return "1.75×"
        case .double: return "2×"
        case .triple: return "3×"
        }
    }

    var accessibilityLabel: String {
        self == .normal ? "Normal speed" : "\(label) speed"
    }
}

enum ScriptureNarrationSleepTimer: Equatable, CaseIterable, Identifiable, Sendable {
    case off
    case minutes(Int)
    case oneHour
    case twoHours

    var id: String {
        switch self {
        case .off: return "off"
        case .minutes(let value): return "m-\(value)"
        case .oneHour: return "1h"
        case .twoHours: return "2h"
        }
    }

    static var allCases: [ScriptureNarrationSleepTimer] {
        [.off] + [5, 10, 15, 20, 25, 30].map { .minutes($0) } + [.oneHour, .twoHours]
    }

    var label: String {
        switch self {
        case .off: return "Off"
        case .minutes(let value): return "\(value) minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        }
    }

    var duration: TimeInterval? {
        switch self {
        case .off: return nil
        case .minutes(let value): return TimeInterval(value * 60)
        case .oneHour: return 3600
        case .twoHours: return 7200
        }
    }
}

enum ScriptureNarrationPlayerAccessory: String, Identifiable, Sendable {
    case speed
    case settings
    case timer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speed: return "Playback speed"
        case .settings: return "Audio settings"
        case .timer: return "Sleep timer"
        }
    }
}

enum ScriptureNarrationSleepTimerFormatting {
    static func countdownLabel(remainingSeconds: Int) -> String {
        guard remainingSeconds > 0 else { return "0:00" }
        if remainingSeconds >= 3600 {
            let hours = remainingSeconds / 3600
            let minutes = (remainingSeconds % 3600) / 60
            return String(format: "%d:%02d", hours, minutes)
        }
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
