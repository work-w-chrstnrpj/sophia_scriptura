import SwiftUI

struct CollectionCard: View {
    @Environment(\.appTheme) private var theme
    let collection: StudyCollection
    let itemCount: Int
    let subfolderCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CollectionFolderGlyph(accent: collection.accent, unfiled: collection.isUnfiled, icon: collection.icon ?? .folder, size: 46)
                .padding(.bottom, 16)

            Text(collection.name)
                .font(.system(.headline, design: .serif).weight(.semibold))
                .foregroundStyle(Color(theme.palette.ink))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if !collection.detail.isEmpty {
                Text(collection.detail)
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 4)
            }

            Spacer(minLength: 14)

            Text(subfolderCount > 0
                 ? "\(CollectionCount.items(itemCount)) · \(CollectionCount.subfolders(subfolderCount))"
                 : CollectionCount.items(itemCount))
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(theme.palette.secondary))
                .monospacedDigit()
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(theme.palette.soft))
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(collection.accent.color)
                .frame(height: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(collection.accent.color.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
