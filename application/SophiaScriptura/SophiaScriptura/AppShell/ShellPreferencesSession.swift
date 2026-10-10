import Foundation

@MainActor final class ShellPreferencesSession: ObservableObject {
    @Published private(set) var preferences = ShellPreferences.initial

    func load() {
        preferences = ShellPreferencesStore.load()
    }

    func setAllowPictureInPicture(_ enabled: Bool) {
        var next = preferences
        next.allowPictureInPicture = enabled
        preferences = next
        ShellPreferencesStore.save(next)
    }

    func setShowTabActionButtons(_ visible: Bool) {
        var next = preferences
        next.showTabActionButtons = visible
        preferences = next
        ShellPreferencesStore.save(next)
    }
}
