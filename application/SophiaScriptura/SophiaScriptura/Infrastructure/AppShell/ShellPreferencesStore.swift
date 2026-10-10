import Foundation

struct ShellPreferences: Equatable, Sendable {
    var showTabActionButtons: Bool
    var allowPictureInPicture: Bool = true

    static let initial = ShellPreferences(showTabActionButtons: true)
}

enum ShellPreferencesStore {
    private static let tabActionsKey = "shell.showTabActionButtons"

    private static let pipKey = "shell.allowPictureInPicture"

    static func load(defaults: UserDefaults = .standard) -> ShellPreferences {
        ShellPreferences(
            showTabActionButtons: defaults.object(forKey: tabActionsKey) as? Bool ?? true,
            allowPictureInPicture: defaults.object(forKey: pipKey) as? Bool ?? true
        )
    }

    static func save(_ preferences: ShellPreferences, defaults: UserDefaults = .standard) {
        defaults.set(preferences.allowPictureInPicture, forKey: pipKey)
        defaults.set(preferences.showTabActionButtons, forKey: tabActionsKey)
    }
}
