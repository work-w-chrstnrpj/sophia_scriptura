import SwiftUI

struct CollectionDetailView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: CollectionsStore
    let collectionID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var filter: CollectionArtifactFilter = .all
    @State private var sort: CollectionArtifactSort = .modified
    @State private var includeDescendants = false
    @State private var showingPicker = false
    @State private var showingChildEditor = false
    @State private var showingDeleteAlert = false

    private var currentCollection: StudyCollection? { store.collection(id: collectionID) }

    private var visibleArtifacts: [CollectionArtifact] {
        let kind = filter.kind
        let filtered = store.artifacts(for: collectionID, includingDescendants: includeDescendants)
            .filter { kind == nil || $0.kind == kind }

        switch sort {
        case .modified:
            return filtered.sorted { $0.modifiedAt > $1.modifiedAt }
        case .title:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        Group {
            if let collection = currentCollection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        collectionHeader(collection)
                        childFolders
                        studyMaterial
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .accessibilityIdentifier("collections.detailContent")
                .appSurface()
                .navigationTitle(collection.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Add Study Material", systemImage: "plus") { showingPicker = true }
                            Button("Create Child Folder", systemImage: "folder.badge.plus") { showingChildEditor = true }
                            Divider()
                            Button("Delete Collection", systemImage: "trash", role: .destructive) {
                                showingDeleteAlert = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Collection actions")
                    }
                }
                .sheet(isPresented: $showingPicker) {
                    CollectionArtifactPicker(store: store, collectionID: collectionID)
                }
                .sheet(isPresented: $showingChildEditor) {
                    CollectionEditorSheet(store: store, parentID: collectionID)
                }
                .alert("Delete \(collection.name)?", isPresented: $showingDeleteAlert) {
                    Button("Delete Folder", role: .destructive) {
                        store.deleteCollection(id: collectionID)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Your study material will remain safe. Child folders will move to this folder's parent.")
                }
            } else {
                ContentUnavailableView("Collection unavailable", systemImage: "folder.badge.questionmark")
            }
        }
    }

    private func collectionHeader(_ collection: StudyCollection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.title)
                    .foregroundStyle(collection.accent.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(collection.name)
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(Color(theme.palette.ink))
                    Text(collection.detail.isEmpty ? "No description" : collection.detail)
                        .font(.subheadline)
                        .foregroundStyle(Color(theme.palette.secondary))
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Label("\(store.membershipCount(for: collectionID)) direct", systemImage: "square.stack.3d.up")
                Text("·")
                Label("\(store.children(of: collectionID).count) child folders", systemImage: "folder")
            }
            .font(.caption)
            .foregroundStyle(Color(theme.palette.secondary))
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var childFolders: some View {
        let children = store.children(of: collectionID).sorted { $0.name < $1.name }
        if !children.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Child folders")
                    .font(.headline)
                    .foregroundStyle(Color(theme.palette.ink))

                ForEach(children) { child in
                    NavigationLink {
                        CollectionDetailView(store: store, collectionID: child.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(child.accent.color)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(child.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(theme.palette.ink))
                                Text("\(store.membershipCount(for: child.id, includingDescendants: true)) items")
                                    .font(.caption)
                                    .foregroundStyle(Color(theme.palette.secondary))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(theme.palette.secondary))
                        }
                        .padding(14)
                        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("collections.folder.\(child.name)")
                }
            }
        }
    }

    private var studyMaterial: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Study material")
                    .font(.headline)
                    .foregroundStyle(Color(theme.palette.ink))
                Spacer()
                Menu {
                    Toggle("Include child folders", isOn: $includeDescendants)
                    Picker("Sort", selection: $sort) {
                        ForEach(CollectionArtifactSort.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Label("View options", systemImage: "slider.horizontal.3")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel("Study material view options")
            }

            Picker("Show", selection: $filter) {
                ForEach(CollectionArtifactFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("collections.filter")

            if visibleArtifacts.isEmpty {
                ContentUnavailableView {
                    Label("Nothing here yet", systemImage: "square.stack.3d.up.slash")
                } description: {
                    Text(includeDescendants ? "Add study material or create a child folder." : "Add study material to this collection.")
                } actions: {
                    Button("Add Study Material") { showingPicker = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(visibleArtifacts) { artifact in
                        CollectionArtifactRow(
                            artifact: artifact,
                            fromDescendant: includeDescendants && !store.contains(artifact.id, in: collectionID)
                        ) {
                            store.removeArtifact(artifact.id, from: collectionID)
                        }
                    }
                }
            }
        }
    }
}
