import SwiftUI

/// Confirms a bookmark or gleaning and where it should live before anything is stored.
struct PassageSaveSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CollectionsStore
    let draft: SavedPassage

    @State private var insight = ""
    @State private var selection: Set<UUID> = []
    @FocusState private var insightFocused: Bool

    private var isGleaning: Bool { draft.kind == .gleaning }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            CollectionItemGlyph(kind: isGleaning ? .gleaning : .bookmark, accent: previewAccent, size: 36)
                            Text(draft.referenceLabel)
                                .font(.system(.headline, design: .serif))
                                .accessibilityIdentifier("collections.save.reference")
                        }
                        Text(draft.passageText)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Color(theme.palette.ink))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color(theme.palette.soft))

                if isGleaning {
                    Section("Insight") {
                        TextField("What did you glean from this passage?", text: $insight, axis: .vertical)
                            .lineLimit(3...8)
                            .focused($insightFocused)
                            .accessibilityIdentifier("collections.save.insight")
                    }
                    .listRowBackground(Color(theme.palette.soft))
                }

                Section {
                    CollectionFolderChooser(store: store, selection: $selection)
                } header: {
                    Text("Save to")
                } footer: {
                    Text(selection.isEmpty
                         ? "Not choosing a collection keeps it in No Folder."
                         : "It will appear in every collection you choose.")
                }
                .listRowBackground(Color(theme.palette.soft))
            }
            .appSurface()
            .navigationTitle(isGleaning ? "New Gleaning" : "New Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("collections.save.confirm")
                }
            }
        }
        .onAppear { if isGleaning { insightFocused = true } }
    }

    private var previewAccent: CollectionAccent {
        let chosen = store.collections.filter { selection.contains($0.id) }
        return chosen.first?.accent ?? store.collection(id: StudyCollection.unfiledID)?.accent ?? .slate
    }

    private func save() {
        var passage = draft
        passage.insight = isGleaning ? insight.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let id = store.addPassage(passage)
        for folder in selection {
            store.addMembership(artifactID: id, collectionID: folder)
        }
        dismiss()
    }
}
