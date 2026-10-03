import SwiftUI

struct CompanionTypingIndicator: View {
    @Environment(\.appTheme) private var theme
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color(theme.palette.secondary))
                    .frame(width: 7, height: 7)
                    .opacity(dotOpacity(for: index))
            }
        }
        .accessibilityLabel("Companion is typing")
        .onReceive(Timer.publish(every: 0.38, on: .main, in: .common).autoconnect()) { _ in
            phase = (phase + 1) % 3
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        phase == index ? 1 : 0.28
    }
}
