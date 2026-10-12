import Foundation

enum ScriptureNarrationPreferencesStore {
    private static let defaults = UserDefaults.standard
    private static let continuousKey = "narration.continuousChapters"
    private static let followKey = "narration.followAudio"
    private static let narratorKey = "narration.preferredNarratorID"
    private static let deliveryKey = "narration.deliveryMode"
    private static let playbackRateKey = "narration.playbackRate"

    static func load() -> ScriptureNarrationPreferences {
        let deliveryRaw = defaults.string(forKey: deliveryKey)
        let delivery = deliveryRaw.flatMap(ScriptureNarrationDeliveryMode.init(rawValue:))
            ?? ScriptureNarrationPreferences.initial.deliveryMode
        return ScriptureNarrationPreferences(
            continuousChapters: defaults.object(forKey: continuousKey) as? Bool ?? false,
            followAudio: defaults.object(forKey: followKey) as? Bool ?? false,
            preferredNarratorID: defaults.string(forKey: narratorKey) ?? ScriptureNarrationNarrator.defaultID,
            deliveryMode: delivery
        )
    }

    static func save(_ preferences: ScriptureNarrationPreferences) {
        defaults.set(preferences.continuousChapters, forKey: continuousKey)
        defaults.set(preferences.followAudio, forKey: followKey)
        defaults.set(preferences.preferredNarratorID, forKey: narratorKey)
        defaults.set(preferences.deliveryMode.rawValue, forKey: deliveryKey)
    }

    static func loadPlaybackSpeed() -> ScriptureNarrationPlaybackSpeed {
        let stored = defaults.object(forKey: playbackRateKey) as? Float ?? ScriptureNarrationPlaybackSpeed.default.rawValue
        return ScriptureNarrationPlaybackSpeed.closest(to: stored)
    }

    static func savePlaybackSpeed(_ speed: ScriptureNarrationPlaybackSpeed) {
        defaults.set(speed.rawValue, forKey: playbackRateKey)
    }
}
