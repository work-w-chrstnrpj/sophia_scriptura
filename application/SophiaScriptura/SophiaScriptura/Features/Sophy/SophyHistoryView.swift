import SwiftUI

struct SophyHistoryView: View {
    @ObservedObject var sophy: SophySession
    @ObservedObject var collections: CollectionsStore
    @ObservedObject var activity: ActivityStore
    @State private var confirmClear = false
    var body: some View {
        List {
            Section {
                Text("Action summaries stay on this iPad. Conversation text and writing suggestions are not saved here.").font(.callout).foregroundStyle(.secondary)
            }
            if sophy.history.isEmpty { ContentUnavailableView("No actions yet", systemImage: "clock", description: Text("Saved action summaries will appear here.")) }
            ForEach(sophy.history.sorted { $0.createdAt > $1.createdAt }) { entry in
                NavigationLink {
                    Form {
                        LabeledContent("Action", value: title(entry.actionType))
                        LabeledContent("Outcome", value: status(entry.status))
                        LabeledContent("Date", value: entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Items", value: String(entry.resultCount))
                        ForEach(entry.resultIDs, id: \.self) { id in
                            if let folder = collections.collection(id: id), folder.isActiveInLibrary, !collections.sophyFolderIsProtected(id) {
                                Button(folder.name, systemImage: "folder") {
                                    guard collections.collection(id: id)?.isActiveInLibrary == true, !collections.sophyFolderIsProtected(id) else { return }
                                    sophy.onOpenSource?(id, true); sophy.panelOpen = false
                                }
                            } else if let record = activity.records.first(where: { $0.id == id }) {
                                Button(record.title, systemImage: "chart.bar") { sophy.onOpenActivity?(); sophy.panelOpen = false }
                            } else if let reminder = activity.reminders.first(where: { $0.id == id }) {
                                Button(reminder.title, systemImage: "bell") { sophy.onOpenActivity?(); sophy.panelOpen = false }
                            } else { Text("Item unavailable").foregroundStyle(.secondary) }
                        }
                        Text("This is a summary, not a saved conversation. Deleting it does not delete the created items.").font(.footnote).foregroundStyle(.secondary)
                    }.navigationTitle(title(entry.actionType))
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title(entry.actionType)).font(.headline)
                        Text(status(entry.status) + " · " + String(entry.resultCount) + " items").font(.subheadline).foregroundStyle(.secondary)
                        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
                .swipeActions { Button("Delete summary", role: .destructive) { Task { await sophy.deleteHistory(entry.id) } } }
            }
        }
        .navigationTitle("Sophy History")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Clear", role: .destructive) { confirmClear = true }.disabled(sophy.isWorking || sophy.history.isEmpty) } }
        .alert("Clear Sophy History?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) { Task { await sophy.clearHistory() } }
        } message: { Text("Removes summaries and recovery receipts, not the study data Sophy created.") }
        .accessibilityIdentifier("sophy.history.list")
    }
    private func title(_ type: String) -> String {
        switch type {
        case "createFolders": "Created folders"
        case "createReminder": "Created reminder"
        case "createActivity": "Recorded activity"
        case "lookup": "Study lookup"
        case "insights": "Activity insights"
        case "enhance": "Writing enhancement"
        default: "Sophy action"
        }
    }
    private func status(_ raw: String) -> String {
        switch raw {
        case "committed", "saved": "Saved"
        case "notScheduled": "Saved · notifications unavailable"
        case "rejected": "Not saved"
        case "uncertain": "Needs inspection"
        default: "Recorded"
        }
    }
}
