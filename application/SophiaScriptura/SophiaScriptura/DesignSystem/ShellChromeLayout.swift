import SwiftUI

/// Shared horizontal alignment for the tab dock and other shell controls.
enum ShellChromeLayout {
    static let tabDockMaxWidth: CGFloat = 740
    static let tabDockHorizontalInset: CGFloat = 16
    /// Inner padding on the tab dock capsule (matches `navigationDock`).
    static let tabDockInnerPadding: CGFloat = 6
    static let fabStackSpacing: CGFloat = 10
    /// Matches `navigationDock` vertical size (capsule + outer padding).
    static let tabDockOuterHeight: CGFloat = 92
    static var shellFABBottomPaddingWhenTabsVisible: CGFloat { tabDockOuterHeight + fabStackSpacing }
}

extension View {
    /// Matches the leading edge of the centered bottom tab dock cluster.
    func shellTabDockLeadingAlignment() -> some View {
        padding(.leading, ShellChromeLayout.tabDockInnerPadding)
            .frame(maxWidth: ShellChromeLayout.tabDockMaxWidth, alignment: .leading)
            .padding(.horizontal, ShellChromeLayout.tabDockHorizontalInset)
            .frame(maxWidth: .infinity)
    }
}
