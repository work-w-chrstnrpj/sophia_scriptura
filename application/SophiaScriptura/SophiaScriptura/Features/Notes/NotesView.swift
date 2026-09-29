import SwiftUI

/// Notes tab. Phase 6 adds OneNote-style notes mixing text and ink with images, tables,
/// quotes, and link cards; tag grouping; sort by title/date; card and list views.
struct NotesView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("SP-006 · Native experiment") {
                    NavigationLink {
                        CanvasExperimentView()
                    } label: {
                        Label("Open canvas experiment", systemImage: "pencil.and.outline")
                    }
                    .accessibilityIdentifier("notes.openCanvasExperiment")
                    Text("A disposable study sample with text, Pencil ink, an image, and explicit grouping. Saves locally; separate from future personal notes.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Notes")
        }
    }
}

#Preview {
    NotesView()
}
