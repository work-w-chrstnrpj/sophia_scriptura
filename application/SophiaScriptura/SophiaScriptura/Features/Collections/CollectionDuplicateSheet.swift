import SwiftUI

struct CollectionDuplicateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CollectionsStore
    let folderID: UUID
    @State private var includeContents = true
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Include contents", isOn: $includeContents)
                    .accessibilityIdentifier("collections.duplicate.contents")
                Text("Subfolders are copied. Include contents to add the same existing items to the copy; editing an item affects both collections.")
                    .foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Duplicate Collection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Duplicate") {
                        busy = true
                        Task {
                            if await store.duplicateCollection(folderID, includeContents: includeContents) != nil { dismiss() }
                            else { error = store.notice ?? "This collection could not be duplicated."; busy = false }
                        }
                    }
                    .disabled(busy)
                    .accessibilityIdentifier("collections.duplicate.confirm")
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(busy)
    }
}
