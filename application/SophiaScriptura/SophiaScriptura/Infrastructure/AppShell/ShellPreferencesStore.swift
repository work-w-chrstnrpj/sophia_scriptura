import Foundation

struct ShellPreferences: Equatable, Sendable {
    var showTabActionButtons: Bool

    static let initial = ShellPreferences(showTabActionButtons: true)
}

enum ShellPreferencesStore {
    private static let defaults = UserDefaults.standard
    private static let tabActionsKey = "shell.showTabActionButtons"

    static func load() -> ShellPreferences {
        ShellPreferences(
            showTabActionButtons: defaults.object(forKey: tabActionsKey) as? Bool ?? true
        )
    }

    static func save(_ preferences: ShellPreferences) {
        defaults.set(preferences.showTabActionButtons, forKey: tabActionsKey)
    }
}
