import SwiftUI

struct CollectionArtifactPicker: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: CollectionsStore
    let collectionID: UUID
    var notes: NotesSession

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var addingLink = false
    @State private var linkTitle = ""
    @State private var linkURL = "https://"
    @State private var linkRejected = false

    private var accent: CollectionAccent { store.collection(id: collectionID)?.accent ?? .slate }

    private var filteredArtifacts: [CollectionArtifact] {
        store.presentedArtifacts(notes: notes.snapshot.notes).filter { artifact in
            searchText.isEmpty ||
                artifact.title.localizedCaseInsensitiveContains(searchText) ||
                artifact.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if addingLink {
                        TextField("Title", text: $linkTitle)
                            .accessibilityIdentifier("collections.newLink.title")
                        TextField("https://", text: $linkURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("collections.newLink.url")
                        if linkRejected {
                            Text("Use a full http or https address.")
                                .font(.caption)
                                .foregroundStyle(Color(theme.palette.secondary))
                        }
                        Button("Save Link", action: createLink)
                            .disabled(linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("collections.newLink.create")
                    } else {
                        Button {
                            addingLink = true
                        } label: {
                            Label("New Link", systemImage: "link.badge.plus")
                                .foregroundStyle(Color(theme.palette.accent))
                        }
                        .accessibilityIdentifier("collections.newLink")
                    }
                } footer: {
                    Text("Notes, bookmarks, gleanings, links, and the sample conversation can all live here.")
                }
                .listRowBackground(Color(theme.palette.soft))

                ForEach(filteredArtifacts) { artifact in
                let included = store.contains(artifact.id, in: collectionID)
                Button {
                    store.link(notes: notes.snapshot.notes)
                    store.toggleMembership(artifactID: artifact.id, collectionID: collectionID)
                } label: {
                    HStack(spacing: 12) {
                        CollectionItemGlyph(kind: artifact.kind, accent: included ? accent : store.accent(for: artifact.id), size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(artifact.title)
                                .foregroundStyle(Color(theme.palette.ink))
                            Text(artifact.kind == .bookmark ? "Bookmark" : artifact.kind == .gleaning ? "Gleaning" : artifact.subtitle)
                                .font(.caption)
                                .foregroundStyle(Color(theme.palette.secondary))
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: included ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(included ? accent.color : Color(theme.palette.rule))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color(theme.palette.soft))
                .accessibilityIdentifier("collections.pick.\(artifact.title)")
                .accessibilityValue(included ? "Included" : "Not included")
                }
            }
            .appSurface()
            .navigationTitle("Add Study Material")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search saved material")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func createLink() {
        guard let id = store.addLink(title: linkTitle, url: linkURL) else {
            linkRejected = true
            return
        }
        store.link(notes: notes.snapshot.notes)
        if !store.contains(id, in: collectionID) {
            store.toggleMembership(artifactID: id, collectionID: collectionID)
        }
        linkTitle = ""
        linkURL = "https://"
        linkRejected = false
        addingLink = false
    }
}
