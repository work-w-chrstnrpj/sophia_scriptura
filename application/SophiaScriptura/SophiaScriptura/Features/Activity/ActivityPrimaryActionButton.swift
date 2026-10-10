import SwiftUI

struct ActivityPrimaryActionButton: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let systemImage: String
    let action: () -> Void
    var accessibilityID: String?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(Color(theme.palette.accent).opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                Text(title)
                    .font(.system(.headline, design: .serif).weight(.semibold))
                Spacer()
            }
            .foregroundStyle(Color(theme.palette.accent))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(theme.palette.accent), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID ?? title)
    }
}
