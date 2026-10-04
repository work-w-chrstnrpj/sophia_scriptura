import SwiftUI

/// Folder outline with checkmarks plus an inline New Collection form.
/// Single selection is used for Move; multiple selection for Save and Add to Collections.
struct CollectionFolderChooser: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: CollectionsStore
    @Binding var selection: Set<UUID>
    var single = false
    var excluded: UUID? = nil

    @State private var creating = false
    @State private var newName = ""
    @State private var newAccent: CollectionAccent = .preset
    @FocusState private var nameFocused: Bool

    var body: some View {
        let entries = store.outline()
        if entries.isEmpty && !creating {
            Text("You have no collections yet.")
                .font(.subheadline)
                .foregroundStyle(Color(theme.palette.secondary))
        }
        ForEach(entries) { entry in
            row(entry)
        }
        if creating {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    CollectionFolderGlyph(accent: newAccent, size: 36)
                    TextField("Collection name", text: $newName)
                        .font(.body.weight(.medium))
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(create)
                        .accessibilityIdentifier("collections.chooser.newName")
                }
                CollectionColorGrid(selection: $newAccent)
                HStack {
                    Button("Cancel") { withAnimation { resetNew() } }
                        .buttonStyle(CollectionSecondaryButtonStyle())
                    Spacer()
                    Button("Create", action: create)
                        .buttonStyle(CollectionProminentButtonStyle())
                        .disabled(trimmedName.isEmpty)
                        .accessibilityIdentifier("collections.chooser.create")
                }
            }
            .padding(.vertical, 6)
        } else {
            Button {
                withAnimation { creating = true }
                nameFocused = true
            } label: {
                Label("New Collection", systemImage: "folder.badge.plus")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(theme.palette.accent))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("collections.chooser.new")
        }
    }

    private var trimmedName: String { newName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func row(_ entry: CollectionOutlineEntry) -> some View {
        let folder = entry.collection
        let selected = selection.contains(folder.id)
        let disabled = folder.id == excluded
        return Button {
            toggle(folder.id)
        } label: {
            HStack(spacing: 12) {
                CollectionFolderGlyph(accent: folder.accent, icon: folder.icon ?? .folder, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                        .font(.body)
                        .foregroundStyle(Color(theme.palette.ink))
                    if disabled {
                        Text("Current collection")
                            .font(.caption)
                            .foregroundStyle(Color(theme.palette.secondary))
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color(theme.palette.accent) : Color(theme.palette.rule))
            }
            .padding(.leading, CGFloat(entry.depth) * 24)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .accessibilityLabel(folder.name)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("collections.choose.\(folder.name)")
    }

    private func toggle(_ id: UUID) {
        if single {
            selection = selection.contains(id) ? [] : [id]
        } else if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    private func create() {
        guard let id = store.createCollection(name: trimmedName, detail: "", parentID: nil, accent: newAccent) else { return }
        if single { selection = [id] } else { selection.insert(id) }
        withAnimation { resetNew() }
    }

    private func resetNew() {
        creating = false
        newName = ""
        newAccent = .preset
        nameFocused = false
    }
}

/// Move one item to another collection, or choose every collection it belongs to.
struct CollectionDestinationPicker: View {
    enum Mode: Equatable {
        case move(from: UUID?)
        case assign
    }

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CollectionsStore
    let artifact: CollectionArtifact
    let mode: Mode
    var notes: NotesSession

    @State private var selection: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        CollectionItemGlyph(kind: artifact.kind, accent: store.accent(for: artifact.id), size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(artifact.title)
                                .font(.system(.headline, design: .serif))
                            Text(artifact.subtitle)
                                .font(.caption)
                                .foregroundStyle(Color(theme.palette.secondary))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color(theme.palette.soft))

                Section {
                    CollectionFolderChooser(store: store, selection: $selection, single: isMove, excluded: source)
                } header: {
                    Text(isMove ? "Move to" : "Collections")
                } footer: {
                    Text(isMove
                         ? "The item leaves this collection and appears in the one you choose."
                         : "An item can belong to several collections. Unselect all to keep it in No Folder.")
                }
                .listRowBackground(Color(theme.palette.soft))
            }
            .appSurface()
            .navigationTitle(isMove ? "Move" : "Add to Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isMove ? "Move" : "Done", action: commit)
                        .fontWeight(.semibold)
                        .disabled(isMove && selection.isEmpty)
                        .accessibilityIdentifier("collections.destination.confirm")
                }
            }
        }
        .onAppear {
            store.link(notes: notes.snapshot.notes)
            if !isMove { selection = store.collectionIDs(containing: artifact.id) }
        }
    }

    private var isMove: Bool { if case .move = mode { return true } else { return false } }
    private var source: UUID? { if case .move(let from) = mode { return from } else { return nil } }

    private func commit() {
        store.link(notes: notes.snapshot.notes)
        switch mode {
        case .move(let from):
            guard let destination = selection.first else { return }
            store.move(artifactID: artifact.id, from: from, to: destination)
        case .assign:
            store.setMemberships(artifactID: artifact.id, collectionIDs: selection)
        }
        dismiss()
    }
}
