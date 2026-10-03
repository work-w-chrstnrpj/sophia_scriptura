import Foundation

struct MusicPreferences: Codable, Equatable, Sendable {
    var selectedTrackID: String?
    var loopAll: Bool
    var showFloatingControl: Bool

    static let initial = MusicPreferences(selectedTrackID: nil, loopAll: true, showFloatingControl: true)
}

enum MusicPreferencesStore {
    private static let defaults = UserDefaults.standard
    private static let selectedKey = "music.selectedTrackID"
    private static let loopKey = "music.loopAll"
    private static let fabKey = "music.showFloatingControl"

    static func load() -> MusicPreferences {
        MusicPreferences(
            selectedTrackID: defaults.string(forKey: selectedKey),
            loopAll: defaults.object(forKey: loopKey) as? Bool ?? true,
            showFloatingControl: defaults.object(forKey: fabKey) as? Bool ?? true
        )
    }

    static func save(_ preferences: MusicPreferences) {
        if let id = preferences.selectedTrackID {
            defaults.set(id, forKey: selectedKey)
        } else {
            defaults.removeObject(forKey: selectedKey)
        }
        defaults.set(preferences.loopAll, forKey: loopKey)
        defaults.set(preferences.showFloatingControl, forKey: fabKey)
    }
}
