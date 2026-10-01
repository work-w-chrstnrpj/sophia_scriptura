import SwiftUI

struct CollectionCard: View {
    @Environment(\.appTheme) private var theme
    let collection: StudyCollection
    let directCount: Int
    let descendantCount: Int
    let childCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(collection.accent.color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.secondary))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(collection.name)
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
                    .lineLimit(2)
                Text(collection.detail.isEmpty ? "No description" : collection.detail)
                    .font(.caption)
                    .foregroundStyle(Color(theme.palette.secondary))
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Text("\(directCount) direct")
                if childCount > 0 {
                    Text("· \(childCount) child")
                }
                if descendantCount != directCount {
                    Text("· \(descendantCount) total")
                }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color(theme.palette.secondary))
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(theme.palette.soft))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(collection.accent.color.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
    }
}
