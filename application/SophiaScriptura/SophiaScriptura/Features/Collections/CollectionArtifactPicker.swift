import SwiftUI

struct CollectionArtifactPicker: View {
    @ObservedObject var store: CollectionsStore
    let collectionID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredArtifacts: [CollectionArtifact] {
        store.artifacts.filter { artifact in
            searchText.isEmpty ||
                artifact.title.localizedCaseInsensitiveContains(searchText) ||
                artifact.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredArtifacts) { artifact in
                Button {
                    store.toggleMembership(artifactID: artifact.id, collectionID: collectionID)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: artifact.kind.symbolName)
                            .foregroundStyle(artifact.kind.tint)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(artifact.title)
                                .foregroundStyle(.primary)
                            Text(artifact.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: store.contains(artifact.id, in: collectionID) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(store.contains(artifact.id, in: collectionID) ? Color.accentColor : Color.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("collections.pick.\(artifact.title)")
                .accessibilityValue(store.contains(artifact.id, in: collectionID) ? "Included" : "Not included")
            }
            .navigationTitle("Add Study Material")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search saved material")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
