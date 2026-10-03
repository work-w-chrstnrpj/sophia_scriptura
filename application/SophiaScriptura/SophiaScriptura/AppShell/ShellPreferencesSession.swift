import Foundation

@MainActor final class ShellPreferencesSession: ObservableObject {
    @Published private(set) var preferences = ShellPreferences.initial

    func load() {
        preferences = ShellPreferencesStore.load()
    }

    func setShowTabActionButtons(_ visible: Bool) {
        var next = preferences
        next.showTabActionButtons = visible
        preferences = next
        ShellPreferencesStore.save(next)
    }
}
