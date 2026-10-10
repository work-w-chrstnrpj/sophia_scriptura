import Foundation

enum SystemControlsRouting {
    static func openActivityTab(from url: URL, open: () -> Void) -> Bool {
        guard StudyActivityDeepLink.isActivityDeepLink(url) else { return false }
        open()
        return true
    }
}
