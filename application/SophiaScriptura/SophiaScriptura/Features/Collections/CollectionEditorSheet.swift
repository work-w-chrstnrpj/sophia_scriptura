import SwiftUI

/// Creates a collection or subfolder, or edits one. No Folder only exposes its color.
struct CollectionEditorSheet: View {
    @ObservedObject private var protection = ItemProtectionSession.shared
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CollectionsStore
    let parentID: UUID?
    var editingID: UUID? = nil

    @State private var initialized = false
    @State private var createdID: UUID?
    @State private var name = ""
    @State private var detail = ""
    @State private var accent: CollectionAccent = .preset
    @State private var icon: CollectionIcon = .folder
    @FocusState private var nameFocused: Bool

    private var editing: StudyCollection? { editingID.flatMap(store.collection(id:)) }
    private var unfiled: Bool { editing?.isUnfiled == true }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var title: String {
        if unfiled { return "No Folder Color" }
        if editing != nil { return "Edit Collection" }
        return parentID == nil ? "New Collection" : "New Subfolder"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        CollectionFolderGlyph(accent: accent, unfiled: unfiled, icon: icon, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(unfiled ? "No Folder" : (trimmedName.isEmpty ? "Untitled" : trimmedName))
                                .font(.system(.headline, design: .serif))
                                .foregroundStyle(trimmedName.isEmpty && !unfiled ? Color(theme.palette.secondary) : Color(theme.palette.ink))
                            if let parent = parentID.flatMap(store.collection(id:)) {
                                Text("Inside \(parent.name)")
                                    .font(.caption)
                                    .foregroundStyle(Color(theme.palette.secondary))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
                .listRowBackground(Color(theme.palette.soft))

                if !unfiled {
                    Section("Details") {
                        TextField("Name", text: $name)
                            .focused($nameFocused)
                            .submitLabel(.done)
                        TextField("Description (optional)", text: $detail, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    .listRowBackground(Color(theme.palette.soft))

                    Section("Icon") {
                        CollectionIconGrid(selection: $icon)
                    }
                    .listRowBackground(Color(theme.palette.soft))
                }

                if let notice = store.notice { Text(notice).foregroundStyle(.red) }
                Section {
                    CollectionColorGrid(selection: $accent)
                } header: {
                    Text("Color")
                } footer: {
                    Text("Preset accent uses the color from your appearance preset in Settings and updates when you change it.")
                }
                .listRowBackground(Color(theme.palette.soft))
            }
            .appSurface()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { autosave(); Task { await store.flush(); if store.notice == nil { dismiss() } } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Create" : "Save", action: commit)
                        .fontWeight(.semibold)
                        .disabled(!unfiled && trimmedName.isEmpty)
                }
            }
        }
        .overlay {
            if let id = editingID ?? parentID, store.isLocked(id) {
                Color(uiColor: .systemBackground).ignoresSafeArea().overlay { ContentUnavailableView("Collection locked", systemImage: "lock.fill") }
            }
        }
        .onChange(of: name) { _, _ in autosave() }
        .onChange(of: detail) { _, _ in autosave() }
        .onChange(of: accent) { _, _ in autosave() }
        .onChange(of: icon) { _, _ in autosave() }
        .onDisappear { Task { await store.flush() } }
        .onChange(of: protection.unlocked) { _, _ in
            if let id = editingID ?? parentID, store.isLocked(id) { dismiss() }
        }
        .onAppear {
            if let id = editingID ?? parentID, store.isLocked(id) { dismiss(); return }
            if let editing {
                name = editing.isUnfiled ? "" : editing.name
                detail = editing.detail
                accent = editing.accent
                icon = editing.icon ?? .folder
            } else {
                accent = parentID.flatMap(store.collection(id:))?.accent ?? .preset
                nameFocused = true
            }
            initialized = true
        }
    }

    private func commit() {
        autosave()
        Task { await store.flush(); if store.notice == nil { dismiss() } }
    }
    private func autosave() {
        guard initialized, unfiled || !trimmedName.isEmpty else { return }
        if let editingID = editingID ?? createdID {
            if store.collection(id: editingID)?.isUnfiled == true {
                guard store.updateUnfiledAccent(accent) else { return }
            } else {
                guard store.updateCollection(id: editingID, name: name, detail: detail, accent: accent, icon: icon) else { return }
            }
        } else {
            createdID = store.createCollection(name: name, detail: detail, parentID: parentID, accent: accent, icon: icon)
        }
    }
}
