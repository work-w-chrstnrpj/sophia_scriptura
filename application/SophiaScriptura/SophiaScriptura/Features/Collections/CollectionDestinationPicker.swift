import SwiftUI

/// Folder outline with checkmarks plus an inline New Collection form.
/// Single selection is used for Move; multiple selection for Save and Add to Collections.
struct CollectionFolderChooser: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: CollectionsStore
    @ObservedObject private var protection = ItemProtectionSession.shared
    @Binding var selection: Set<UUID>
    var single = false
    var excluded: UUID? = nil

    @State private var creating = false
    @State private var newName = ""
    @State private var newAccent: CollectionAccent = .preset
    @State private var collapsed: Set<UUID> = []
    @FocusState private var nameFocused: Bool

    var body: some View {
        let _ = protection.unlocked
        let entries = store.outline()
        let visible = entries.hidingCollapsedSubfolders(collapsed)
        if entries.isEmpty && !creating {
            Text("You have no collections yet.")
                .font(.subheadline)
                .foregroundStyle(Color(theme.palette.secondary))
        }
        ForEach(visible) { entry in
            row(entry, entries: entries)
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

    private func row(_ entry: CollectionOutlineEntry, entries: [CollectionOutlineEntry]) -> some View {
        let folder = entry.collection
        let selected = selection.contains(folder.id)
        let locked = store.isLocked(folder.id)
        let disabled = locked || folder.id == excluded
        let hasSubfolders = hasSubfolders(entry, in: entries)
        let expanded = !collapsed.contains(folder.id)
        return HStack(spacing: 4) {
            if hasSubfolders {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if expanded { collapsed.insert(folder.id) } else { collapsed.remove(folder.id) }
                    }
                } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .frame(width: 22, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(theme.palette.secondary))
                .accessibilityLabel(expanded ? "Hide subfolders" : "Show subfolders")
                .accessibilityIdentifier("collections.choose.disclose.\(folder.name)")
            } else {
                Color.clear.frame(width: 22, height: 32)
            }
            Button {
                toggle(folder.id)
            } label: {
                HStack(spacing: 12) {
                    CollectionFolderGlyph(accent: locked ? .stone : folder.accent, icon: folder.icon ?? .folder, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.name)
                            .font(.body)
                            .foregroundStyle(Color(theme.palette.ink))
                        if locked {
                            Label("Locked", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(Color(theme.palette.secondary))
                        } else if folder.id == excluded {
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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .opacity(disabled ? 0.5 : 1)
            .accessibilityLabel(locked ? "\(folder.name), locked" : folder.name)
            .accessibilityValue(selected ? "Selected" : "Not selected")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("collections.choose.\(folder.name)")
        }
        .padding(.leading, CGFloat(entry.depth) * 24)
    }

    private func hasSubfolders(_ entry: CollectionOutlineEntry, in entries: [CollectionOutlineEntry]) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        let next = entries.index(after: index)
        return next < entries.endIndex && entries[next].depth > entry.depth
    }

    private func toggle(_ id: UUID) {
        guard !store.isLocked(id) else { return }
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
    @ObservedObject private var protection = ItemProtectionSession.shared

    @State private var selection: Set<UUID> = []
    @State private var filingError: String?

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
                    Text(noteLocked
                         ? "Unlock Notes before changing where this note is filed."
                         : isMove
                         ? "The item leaves this collection and appears in the one you choose."
                         : "An item can belong to several collections. Unselect all to keep it in No Folder. Locked collections stay unchanged.")
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
                        .disabled(noteLocked || (isMove && selection.isEmpty))
                        .accessibilityIdentifier("collections.destination.confirm")
                }
            }
        }
        .alert("Could not change collections", isPresented: Binding(get: { filingError != nil }, set: { if !$0 { filingError = nil } })) {
            Button("OK") { filingError = nil }
        } message: { Text(filingError ?? "") }
        .onAppear {
            store.link(notes: notes.snapshot.notes)
            if !isMove { selection = store.collectionIDs(containing: artifact.id) }
        }
    }

    private var isMove: Bool { if case .move = mode { return true } else { return false } }
    private var source: UUID? { if case .move(let from) = mode { return from } else { return nil } }

    private var noteLocked: Bool {
        let _ = protection.unlocked
        return notes.snapshot.notes.contains { $0.id == artifact.id && notes.isLocked($0) }
    }

    private func commit() {
        guard !noteLocked else { return }
        store.link(notes: notes.snapshot.notes)
        let succeeded: Bool
        switch mode {
        case .move(let from):
            guard let destination = selection.first else { return }
            succeeded = store.move(artifactID: artifact.id, from: from, to: destination)
        case .assign:
            succeeded = store.setMemberships(artifactID: artifact.id, collectionIDs: selection)
        }
        if succeeded { dismiss() }
        else { filingError = store.notice ?? "The collections changed. Check your selection and try again." }
    }
}
