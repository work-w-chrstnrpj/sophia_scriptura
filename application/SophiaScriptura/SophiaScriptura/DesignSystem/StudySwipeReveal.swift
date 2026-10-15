import SwiftUI

/// One transient action rail across mounted tabs and editor presentations.
@Observable
final class StudySwipeCoordinator {
    var activeID: UUID?
    func close() { activeID = nil }
    func close(_ id: UUID) { if activeID == id { close() } }
}

private struct StudySwipeCoordinatorKey: EnvironmentKey {
    static let defaultValue: StudySwipeCoordinator? = nil
}
extension EnvironmentValues {
    var studySwipeCoordinator: StudySwipeCoordinator? {
        get { self[StudySwipeCoordinatorKey.self] }
        set { self[StudySwipeCoordinatorKey.self] = newValue }
    }
}

/// Horizontal actions for records hosted in ScrollView/LazyVStack rather than List.
/// Vertical drags remain owned by the surrounding scroll view; no full-swipe commit.
struct StudySwipeReveal<Actions: View>: ViewModifier {
    var enabled: Bool
    var identifier: String
    @ViewBuilder var actions: () -> Actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.studySwipeCoordinator) private var sharedCoordinator
    @State private var localCoordinator = StudySwipeCoordinator()
    @State private var identity = UUID()
    @State private var opened = false
    private var coordinator: StudySwipeCoordinator { sharedCoordinator ?? localCoordinator }
    @State private var drag: CGFloat = 0
    private let width: CGFloat = 200
    private var offset: CGFloat { min(0, max(-width, (opened ? -width : 0) + drag)) }

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            content
                .allowsHitTesting(!opened)
                .offset(x: offset)
            if opened {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { close() }
            }
            if enabled && offset < 0 {
                HStack(spacing: 4) { actions() }
                    .buttonStyle(StudySwipeActionStyle())
                    .font(.callout)
                    .lineLimit(1)
                    .frame(minHeight: 44)
                    .frame(width: width)
                    .zIndex(1)
            }
        }
        .clipped()
        .contentShape(Rectangle())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
            .highPriorityGesture(DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard enabled, abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                    coordinator.activeID = identity
                    drag = value.translation.width
                }
                .onEnded { value in
                    guard enabled else { return }
                    let horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.2
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                        if horizontal && abs(value.translation.width) > 20 { opened = value.translation.width < 0 }
                        drag = 0
                        if opened { coordinator.activeID = identity }
                        else { coordinator.close(identity) }
                    }
                }, including: enabled ? .all : .subviews)
            .accessibilityAction(named: "Show actions") { if enabled { coordinator.activeID = identity; opened = true } }
            .accessibilityAction(named: "Hide actions") { close() }
            .onChange(of: coordinator.activeID) { _, active in
                if active != identity { opened = false; drag = 0 }
            }
            .onChange(of: enabled) { _, active in if !active { close() } }
            .onDisappear { close() }
    }
    private func close() {
        opened = false; drag = 0
        coordinator.close(identity)
    }
}

extension View {
    func studySwipeReveal<Actions: View>(enabled: Bool = true, identifier: String, @ViewBuilder actions: @escaping () -> Actions) -> some View {
        modifier(StudySwipeReveal(enabled: enabled, identifier: identifier, actions: actions))
    }
}

/// Keeps a 44-point target without the system large-control padding truncating
/// action titles in narrow note cards.
private struct StudySwipeActionStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        let color = configuration.role == .destructive ? Color.red : Color(theme.palette.accent)
        configuration.label
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(color)
            .frame(minWidth: 64, minHeight: 44)
            .padding(.horizontal, 8)
            .background(color.opacity(configuration.isPressed ? 0.25 : 0.14), in: Capsule())
    }
}
