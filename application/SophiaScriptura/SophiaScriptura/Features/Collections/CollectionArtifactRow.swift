import SwiftUI

struct CollectionArtifactRow: View {
    @Environment(\.appTheme) private var theme
    let artifact: CollectionArtifact
    let fromDescendant: Bool
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: artifact.kind.symbolName)
                .font(.headline)
                .foregroundStyle(artifact.kind.tint)
                .frame(width: 34, height: 34)
                .background(artifact.kind.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(artifact.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
                    .lineLimit(2)
                Text(fromDescendant ? "From child folder · \(artifact.subtitle)" : artifact.subtitle)
                    .font(.caption)
                    .foregroundStyle(Color(theme.palette.secondary))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Menu {
                if fromDescendant {
                    Text("Open the child folder to manage this item.")
                } else {
                    Button("Remove from This Collection", role: .destructive, action: remove)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color(theme.palette.secondary))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Actions for \(artifact.title)")
            .accessibilityIdentifier("collections.itemActions.\(artifact.title)")
        }
        .padding(14)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
