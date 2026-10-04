import Foundation

/// Reads version metadata from the app bundle (Xcode `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`).
enum AppVersion {
    static var marketing: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    static var fullLabel: String {
        "\(marketing) (\(build))"
    }
}
