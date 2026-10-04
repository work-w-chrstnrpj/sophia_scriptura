import SwiftUI

/// Color-labeled folder tile (Direction C).
struct CollectionCard: View {
    @Environment(\.appTheme) private var theme
    let collection: StudyCollection
    let itemCount: Int
    let subfolderCount: Int
    var kindHints: [CollectionArtifactKind] = []

    private var washOpacity: Double { theme.dark ? 0.20 : 0.15 }
    private var tint: Color { collection.accent.resolvedColor(in: theme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                accentCircleIcon
                Spacer(minLength: 0)
                if !kindHints.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(kindHints) { kind in
                            Circle()
                                .fill(kind.tint)
                                .frame(width: 7, height: 7)
                                .overlay(Circle().stroke(Color(theme.palette.paper).opacity(0.5), lineWidth: 0.5))
                        }
                    }
                    .accessibilityLabel("Contains \(kindHints.map(\.title).joined(separator: ", "))")
                }
            }

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
            }

            Spacer(minLength: 4)

            HStack(spacing: 10) {
                Text(CollectionCount.items(itemCount))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                if subfolderCount > 0 {
                    Label("\(subfolderCount)", systemImage: "folder.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(theme.palette.secondary))
                        .labelStyle(.titleAndIcon)
                        .imageScale(.small)
                        .accessibilityLabel(CollectionCount.subfolders(subfolderCount))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background(tint.opacity(washOpacity))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(theme.palette.rule), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var accentCircleIcon: some View {
        Image(systemName: (collection.icon ?? .folder).symbolName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color(theme.palette.paper))
            .frame(width: 44, height: 44)
            .background(tint, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Full-width No Folder row using the same color-forward treatment.
struct CollectionFolderRow: View {
    @Environment(\.appTheme) private var theme
    let accent: CollectionAccent
    var unfiled = false
    var icon: CollectionIcon = .folder
    let title: String
    let subtitle: String
    let itemCount: Int
    let subfolderCount: Int
    var kindHints: [CollectionArtifactKind] = []

    private var washOpacity: Double { theme.dark ? 0.20 : 0.15 }
    private var tint: Color { accent.resolvedColor(in: theme) }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: unfiled ? "tray.fill" : icon.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(theme.palette.paper))
                .frame(width: 48, height: 48)
                .background(tint, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
                    .lineLimit(2)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if !kindHints.isEmpty {
                HStack(spacing: 5) {
                    ForEach(kindHints) { kind in
                        Circle()
                            .fill(unfiled ? Color(theme.palette.secondary).opacity(0.55) : kind.tint)
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityLabel("Contains \(kindHints.map(\.title).joined(separator: ", "))")
            }

            Text(CollectionCount.items(itemCount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(theme.palette.secondary))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(tint.opacity(washOpacity))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(theme.palette.rule), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
