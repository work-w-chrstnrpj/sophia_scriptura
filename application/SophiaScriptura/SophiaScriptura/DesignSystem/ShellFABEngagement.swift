import SwiftUI

/// Keeps shell music and activity FABs at 60% opacity until touched; stays full opacity for 3.5s after touch.
struct ShellFABEngagementOpacity: ViewModifier {
    @Binding var engagedUntil: Date

    func body(content: Content) -> some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { timeline in
            content.opacity(engagedUntil > timeline.date ? 1 : 0.6)
        }
    }

    static func touch(_ engagedUntil: inout Date) {
        engagedUntil = Date().addingTimeInterval(3.5)
    }
}

extension View {
    func shellFABEngagementOpacity(engagedUntil: Binding<Date>) -> some View {
        modifier(ShellFABEngagementOpacity(engagedUntil: engagedUntil))
    }
}
