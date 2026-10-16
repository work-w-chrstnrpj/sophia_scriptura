import SwiftUI
import UniformTypeIdentifiers

private extension UTType {
    static let sophiaStudyMaterial = UTType(exportedAs: "org.sophia.study-material", conformingTo: .data)
    static let sophiaCollectionFolder = UTType(exportedAs: "org.sophia.collection-folder", conformingTo: .data)
}

private enum CollectionFolderDrag {
    static func provider(id: UUID) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.sophiaCollectionFolder.identifier, visibility: .ownProcess) { completion in
            completion(Data(id.uuidString.utf8), nil)
            return nil
        }
        return provider
    }

    @MainActor
    static func receive(_ providers: [NSItemProvider], store: CollectionsStore, parentID: UUID?, expectedID: UUID? = nil, moved: @escaping () -> Void = {}) -> Bool {
        guard providers.count == 1, let provider = providers.first,
              provider.hasItemConformingToTypeIdentifier(UTType.sophiaCollectionFolder.identifier) else { return false }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.sophiaCollectionFolder.identifier) { data, _ in
            guard let data, data.count <= 64, let string = String(data: data, encoding: .utf8),
                  let id = UUID(uuidString: string), expectedID == nil || expectedID == id else { return }
            Task { @MainActor in
                if store.moveCollection(id: id, to: parentID) { moved() }
            }
        }
        return true
    }
}

private struct CollectionFolderDragModifier: ViewModifier {
    let folder: StudyCollection
    @ObservedObject var store: CollectionsStore
    @State private var targeted = false

    func body(content: Content) -> some View {
        Group {
            if folder.isActiveInLibrary && !store.isLocked(folder.id) {
                content.onDrag { CollectionFolderDrag.provider(id: folder.id) }
            } else {
                content
            }
        }
        .overlay {
            if targeted && folder.isActiveInLibrary && !store.isLocked(folder.id) {
                RoundedRectangle(cornerRadius: 18).stroke(.tint, lineWidth: 3)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.sophiaCollectionFolder, UTType.sophiaStudyMaterial], isTargeted: $targeted) { providers in
            if providers.count == 1, providers.first?.hasItemConformingToTypeIdentifier(UTType.sophiaStudyMaterial.identifier) == true {
                return CollectionStudyMaterialDrag.receive(providers, store: store, destination: folder.id)
            }
            return CollectionFolderDrag.receive(providers, store: store, parentID: folder.id)
        }
    }
}

extension View {
    func collectionFolderDragAndDrop(_ folder: StudyCollection, store: CollectionsStore) -> some View {
        modifier(CollectionFolderDragModifier(folder: folder, store: store))
    }
}

/// Full tree destination choice also makes moves between different branches accessible.
struct CollectionFolderMoveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CollectionsStore
    let folderID: UUID

    var body: some View {
        NavigationStack {
            List {
                if let folder = store.collection(id: folderID) {
                    Label(folder.name, systemImage: "folder.fill")
                        .font(.headline)
                        .collectionFolderDragAndDrop(folder, store: store)
                    Text("Choose a destination, or drag the folder onto one below. Its contents and subfolders move with it.")
                        .font(.footnote)
                }
                destination("Collections (top level)", parentID: nil, depth: 0)
                ForEach(store.libraryOutline(search: "", sort: .name)) { entry in
                    destination(entry.collection.name, parentID: entry.collection.id, depth: entry.depth + 1)
                }
            }
            .navigationTitle("Move Collection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func destination(_ name: String, parentID: UUID?, depth: Int) -> some View {
        let allowed = store.canMoveCollection(folderID, to: parentID)
        return Button {
            if store.moveCollection(id: folderID, to: parentID) { dismiss() }
        } label: {
            Label(name, systemImage: parentID == nil ? "square.grid.2x2" : "folder")
                .padding(.leading, CGFloat(depth) * 16)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .disabled(!allowed)
        .onDrop(of: [UTType.sophiaCollectionFolder], isTargeted: nil) { providers in
            CollectionFolderDrag.receive(providers, store: store, parentID: parentID, expectedID: folderID) { dismiss() }
        }
        .accessibilityIdentifier("collections.move.destination.\(parentID?.uuidString ?? "root")")
    }
}

private struct CollectionStudyMaterialDrag: Codable {
    let artifactID: UUID
    let sourceID: UUID

    static func provider(id: UUID, sourceID: UUID) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.sophiaStudyMaterial.identifier, visibility: .ownProcess) { completion in
            completion(try? JSONEncoder().encode(Self(artifactID: id, sourceID: sourceID)), nil)
            return nil
        }
        return provider
    }

    @MainActor static func receive(_ providers: [NSItemProvider], store: CollectionsStore, destination: UUID) -> Bool {
        guard providers.count == 1, let provider = providers.first else { return false }
        provider.loadDataRepresentation(forTypeIdentifier: UTType.sophiaStudyMaterial.identifier) { data, _ in
            guard let data, data.count <= 512, let value = try? JSONDecoder().decode(Self.self, from: data) else { return }
            Task { @MainActor in
                _ = store.moveStudyMaterial(value.artifactID, from: value.sourceID, to: destination)
            }
        }
        return true
    }
}

private struct CollectionStudyMaterialDragModifier: ViewModifier {
    let artifactID: UUID
    let sourceID: UUID
    @ObservedObject var store: CollectionsStore
    let enabled: Bool
    let prepare: () -> Void

    func body(content: Content) -> some View {
        if enabled && !store.isLocked(sourceID) {
            content.onDrag {
                prepare()
                return CollectionStudyMaterialDrag.provider(id: artifactID, sourceID: sourceID)
            }
        } else { content }
    }
}

extension View {
    func collectionStudyMaterialDrag(_ id: UUID, sourceID: UUID, store: CollectionsStore, enabled: Bool, prepare: @escaping () -> Void) -> some View {
        modifier(CollectionStudyMaterialDragModifier(artifactID: id, sourceID: sourceID, store: store, enabled: enabled, prepare: prepare))
    }
}
