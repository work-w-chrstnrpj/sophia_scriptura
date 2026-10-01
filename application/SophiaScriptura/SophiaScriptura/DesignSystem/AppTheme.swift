import SwiftUI

/// One presentation palette flows from the owner's appearance settings into every tab.
struct AppTheme: Equatable {
    var appearance: ScriptureAppearance = .oldPaper
    var dark = false
    var palette: ReaderPalette { appearance.palette(dark: dark) }
    var traits: UITraitCollection { UITraitCollection(userInterfaceStyle: dark ? .dark : .light) }
}
private struct AppThemeKey: EnvironmentKey { static let defaultValue = AppTheme() }
extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
private struct AppSurface: ViewModifier {
    @Environment(\.appTheme) private var theme
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color(theme.palette.paper).ignoresSafeArea())
            .foregroundStyle(Color(theme.palette.ink))
            .toolbarBackground(Color(theme.palette.paper), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
extension View {
    func appSurface() -> some View { modifier(AppSurface()) }
}
