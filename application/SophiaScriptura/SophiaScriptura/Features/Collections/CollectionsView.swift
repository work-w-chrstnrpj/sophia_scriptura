import SwiftUI

/// M5 prototype: a local Collections library with nested folders and shared memberships.
/// Persistence and cross-feature repositories remain intentionally outside this slice.
struct CollectionsView: View {
    @StateObject private var store = CollectionsStore.demo()
    @State private var searchText = ""
    @State private var sort: CollectionLibrarySort = .modified
    @State private var showingNewCollection = false

    private var visibleCollections: [StudyCollection] {
        let roots = store.collections.filter { searchText.isEmpty ? $0.parentID == nil : true }
        let filtered = roots.filter { collection in
            searchText.isEmpty ||
                collection.name.localizedCaseInsensitiveContains(searchText) ||
                collection.detail.localizedCaseInsensitiveContains(searchText)
        }

        switch sort {
        case .modified:
            return filtered.sorted { $0.modifiedAt > $1.modifiedAt }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .itemCount:
            return filtered.sorted {
                store.membershipCount(for: $0.id, includingDescendants: true) >
                    store.membershipCount(for: $1.id, includingDescendants: true)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text("Sample workspace · Changes reset when the app closes. Items are examples and cannot be opened yet.")
                    .font(.footnote)
                    .foregroundStyle(CollectionSurface.secondaryInk)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("collections.demoNotice")
                if visibleCollections.isEmpty {
                    ContentUnavailableView {
                        Label(searchText.isEmpty ? "No Collections Yet" : "No Matching Collections", systemImage: "folder")
                    } description: {
                        Text(searchText.isEmpty
                            ? "Create a topic to gather Scripture, notes, conversations, and links."
                            : "Try a different name or description.")
                    } actions: {
                        if searchText.isEmpty {
                            Button("Create a Topic") { showingNewCollection = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 420)
                } else {
                    VStack(alignment: .leading, spacing: 22) {
                        header

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 190), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(visibleCollections) { collection in
                                NavigationLink {
                                    CollectionDetailView(store: store, collectionID: collection.id)
                                } label: {
                                    CollectionCard(
                                        collection: collection,
                                        directCount: store.membershipCount(for: collection.id),
                                        descendantCount: store.membershipCount(for: collection.id, includingDescendants: true),
                                        childCount: store.children(of: collection.id).count
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("collections.folder.\(collection.name)")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .background(CollectionSurface.background.ignoresSafeArea())
            .navigationTitle("Collections")
            .searchable(text: $searchText, prompt: "Search collections")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(CollectionLibrarySort.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Sort collections")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewCollection = true
                    } label: {
                        Label("New Collection", systemImage: "folder.badge.plus")
                    }
                    .accessibilityIdentifier("collections.newCollection")
                }
            }
            .sheet(isPresented: $showingNewCollection) {
                CollectionEditorSheet(store: store, parentID: nil)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Gather what you are learning")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(CollectionSurface.ink)
            Text("Keep passages, notes, conversations, and links together without duplicating them.")
                .font(.subheadline)
                .foregroundStyle(CollectionSurface.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    CollectionsView()
}
