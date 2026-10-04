import SwiftUI

struct NoteColorGrid: View {
    @Binding var selection: CollectionAccent

    var body: some View {
        CollectionColorGrid(selection: $selection)
    }
}

struct NoteColorPickerSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: CollectionAccent
    var onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NoteColorGrid(selection: $selection)
                } header: {
                    Text("Color")
                } footer: {
                    Text("Preset accent follows your appearance choice in Settings. Other swatches stay fixed. Colors the note in the library only; the writing surface uses your appearance preset.")
                }
                .listRowBackground(Color(theme.palette.soft))
            }
            .appSurface()
            .navigationTitle("Note color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
