import SwiftUI

@MainActor
final class SettingsToastCenter: ObservableObject {
    @Published private(set) var message: String?
    private var dismissTask: Task<Void, Never>?

    func show(_ text: String) {
        dismissTask?.cancel()
        message = text
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self?.message == text { self?.message = nil }
            }
        }
    }
}

struct SettingsTransientToast: View {
    @Environment(\.appTheme) private var theme
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(theme.palette.ink))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(theme.palette.paper), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(theme.palette.rule), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .padding(.top, 8)
                .padding(.trailing, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityIdentifier("settings.toast")
        }
    }
}
