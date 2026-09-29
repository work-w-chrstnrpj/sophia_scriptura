import SwiftUI

struct CollectionEditorSheet: View {
    @ObservedObject var store: CollectionsStore
    let parentID: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var detail = ""
    @State private var accent: CollectionAccent = .oxblood

    var body: some View {
        NavigationStack {
            Form {
                Section("Topic") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $detail, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Folder accent") {
                    Picker("Accent", selection: $accent) {
                        ForEach(CollectionAccent.allCases) { option in
                            Label(option.rawValue.capitalized, systemImage: "circle.fill")
                                .tag(option)
                        }
                    }
                }
            }
            .navigationTitle(parentID == nil ? "New Collection" : "New Child Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard store.createCollection(name: name, detail: detail, parentID: parentID, accent: accent) != nil else { return }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
