import SwiftUI

struct CollectionArtifactRow: View {
    enum Placement {
        case folder
        case unfiled
        case subfolder
    }

    @Environment(\.appTheme) private var theme
    let artifact: CollectionArtifact
    let accent: CollectionAccent
    let placement: Placement
    let open: () -> Void
    var move: () -> Void = {}
    var assign: () -> Void = {}
    var remove: () -> Void = {}
    var deletePassage: () -> Void = {}

    private var isPassage: Bool { artifact.kind == .bookmark || artifact.kind == .gleaning }

    private var deleteTitle: String {
        switch artifact.kind {
        case .gleaning: return "Delete Gleaning"
        case .link: return "Delete Link"
        default: return "Delete Bookmark"
        }
    }

    private var caption: String {
        let base: String
        switch artifact.kind {
        case .bookmark: base = "Bookmark"
        case .gleaning: base = artifact.insight.isEmpty ? "Gleaning" : "Gleaning · \(artifact.insight)"
        default: base = artifact.subtitle
        }
        return placement == .subfolder ? "In a subfolder · \(base)" : base
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button(action: open) {
                HStack(alignment: .center, spacing: 14) {
                    CollectionItemGlyph(kind: artifact.kind, accent: accent, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(artifact.title)
                            .font(isPassage ? .system(.body, design: .serif).weight(.semibold) : .body.weight(.semibold))
                            .foregroundStyle(Color(theme.palette.ink))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(Color(theme.palette.secondary))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("collections.open.\(artifact.title)")

            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.secondary))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Actions for \(artifact.title)")
            .accessibilityIdentifier("collections.itemActions.\(artifact.title)")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 10)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu { actions }
    }

    @ViewBuilder
    private var actions: some View {
        switch placement {
        case .subfolder:
            Text("Open its subfolder to organize this item.")
        case .unfiled:
            Button("Add to Collection…", systemImage: "folder.badge.plus", action: assign)
        case .folder:
            Button("Move to…", systemImage: "folder", action: move)
            Button("Add to Another Collection…", systemImage: "folder.badge.plus", action: assign)
            Divider()
            Button("Remove from This Collection", systemImage: "minus.circle", action: remove)
        }
        if placement != .subfolder && (isPassage || artifact.kind == .link) {
            Divider()
            Button(deleteTitle, systemImage: "trash", role: .destructive, action: deletePassage)
        }
    }
}
