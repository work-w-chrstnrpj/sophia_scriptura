import Foundation

struct SophyPreferences: Equatable, Sendable {
    var enabled: Bool
    var edge: String
    var vertical: Double
    var character: StudyCompanionCharacter
    /// When false, the companion stays on screen but idle verse bubbles are suppressed.
    var idleScriptureQuotesEnabled: Bool
    /// Continuous idling time before the next verse bubble appears.
    var idleDelayBeforeQuoteSeconds: Int

    static let initial = SophyPreferences(
        enabled: false, edge: "trailing", vertical: 0.72,
        character: .sophy, idleScriptureQuotesEnabled: true, idleDelayBeforeQuoteSeconds: 60
    )
}

enum SophyPreferencesStore {
    static let enabledKey = "sophy.enabled"
    static let edgeKey = "sophy.edge"
    static let verticalKey = "sophy.vertical"
    static let characterKey = "sophy.character"
    static let idleQuotesKey = "sophy.idleScriptureQuotesEnabled"
    static let idleDelayKey = "sophy.idleDelayBeforeQuoteSeconds"
    static let legacyQuoteIntervalMinutesKey = "sophy.quoteIntervalMinutes"

    static let idleDelayChoices = [30, 60, 120, 300, 600]

    static func load(defaults: UserDefaults = .standard) -> SophyPreferences {
        let edge = defaults.string(forKey: edgeKey)
        let vertical = defaults.object(forKey: verticalKey) as? Double
        let quotesEnabled = defaults.object(forKey: idleQuotesKey) as? Bool ?? true
        let delay = resolvedIdleDelay(defaults: defaults)
        return SophyPreferences(
            enabled: defaults.object(forKey: enabledKey) as? Bool ?? false,
            edge: edge == "leading" ? "leading" : "trailing",
            vertical: min(0.9, max(0.15, vertical ?? 0.72)),
            character: StudyCompanionCharacter.stored(defaults.string(forKey: characterKey)),
            idleScriptureQuotesEnabled: quotesEnabled,
            idleDelayBeforeQuoteSeconds: delay
        )
    }

    static func save(_ preferences: SophyPreferences, defaults: UserDefaults = .standard) {
        defaults.set(preferences.enabled, forKey: enabledKey)
        defaults.set(preferences.edge == "leading" ? "leading" : "trailing", forKey: edgeKey)
        defaults.set(min(0.9, max(0.15, preferences.vertical)), forKey: verticalKey)
        defaults.set(preferences.character.rawValue, forKey: characterKey)
        defaults.set(preferences.idleScriptureQuotesEnabled, forKey: idleQuotesKey)
        defaults.set(preferences.idleDelayBeforeQuoteSeconds, forKey: idleDelayKey)
    }

    static func label(for delaySeconds: Int) -> String {
        if delaySeconds < 60 { return "\(delaySeconds) seconds" }
        if delaySeconds % 60 == 0 {
            let minutes = delaySeconds / 60
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
        return "\(delaySeconds) seconds"
    }

    private static func resolvedIdleDelay(defaults: UserDefaults) -> Int {
        if let stored = defaults.object(forKey: idleDelayKey) as? Int,
           idleDelayChoices.contains(stored) { return stored }
        if let legacyMinutes = defaults.object(forKey: legacyQuoteIntervalMinutesKey) as? Int {
            let migrated = legacyMinutes * 60
            if idleDelayChoices.contains(migrated) { return migrated }
        }
        return 60
    }
}
