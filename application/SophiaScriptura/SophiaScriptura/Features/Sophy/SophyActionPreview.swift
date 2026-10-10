import SwiftUI

struct SophyActionPreview: View {
    @ObservedObject var sophy: SophySession
    @ObservedObject var collections: CollectionsStore
    @ObservedObject var activity: ActivityStore
    var confirm: () -> Void
    @Environment(\.appTheme) private var theme
    private var folders: Bool { sophy.previewLines.contains { $0.id.contains(":") } }
    private var unresolvedDuplicates: Bool {
        sophy.previewLines.contains { $0.id.contains(":") && $0.resolution.isEmpty && !sophy.folderMatches(for: $0, collections: collections).isEmpty }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Review before continuing", systemImage: "checklist").font(.headline)
            Text(sophy.previewMessage).font(.callout).foregroundStyle(.secondary)
            if folders {
                Picker("Destination", selection: $sophy.destinationHandle) {
                    Text("Collections root").tag("")
                    ForEach(sophy.destinations) { Text($0.title).tag($0.handle) }
                }
                Text("Expand a folder to edit its description. Existing folders are reused only when you choose them.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach($sophy.previewLines) { $line in
                VStack(alignment: .leading, spacing: 8) {
                    if line.id.contains(":") {
                        DisclosureGroup {
                            TextField("Folder name", text: $line.title).textFieldStyle(.roundedBorder)
                            TextField("Description", text: $line.detail, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder)
                            let matches = sophy.folderMatches(for: line, collections: collections)
                            if !matches.isEmpty {
                                Picker("An existing folder matches", selection: $line.resolution) {
                                    Text("Choose reuse or create another").tag("")
                                    ForEach(matches) { Text("Use existing \($0.name)").tag("reuse:" + $0.id.uuidString) }
                                    Text("Create another folder").tag("new")
                                }
                            }
                        } label: {
                            Label(line.title, systemImage: "folder").font(.subheadline.weight(.medium))
                        }
                        Text(line.subtitle).font(.caption).foregroundStyle(.secondary)
                    } else if !line.date.isEmpty {
                        TextField("Title", text: $line.title).font(.headline).textFieldStyle(.roundedBorder)
                        Text(line.subtitle).font(.caption).foregroundStyle(.secondary)
                        TextField("Description", text: $line.detail, axis: .vertical).textFieldStyle(.roundedBorder)
                        Picker("Activity mode", selection: $line.mode) {
                            ForEach(activity.modes) { Text($0.name).tag($0.id) }
                        }
                        HStack {
                            VStack(alignment: .leading) { Text("Date · YYYY-MM-DD").font(.caption); TextField("Date", text: $line.date) }
                            VStack(alignment: .leading) { Text("Start · HH:mm").font(.caption); TextField("Time", text: $line.time) }
                        }.textFieldStyle(.roundedBorder)
                        if line.subtitle.hasPrefix("Reminder") {
                            Picker("Repeat", selection: $line.repeatRule) {
                                ForEach(ActivityReminderRepeat.allCases) { Text($0.title).tag($0.rawValue) }
                            }
                        } else {
                            HStack {
                                VStack(alignment: .leading) { Text("End date").font(.caption); TextField("YYYY-MM-DD", text: $line.endDate) }
                                VStack(alignment: .leading) { Text("End time").font(.caption); TextField("HH:mm", text: $line.endTime) }
                            }.textFieldStyle(.roundedBorder)
                            TextField("Duration in minutes", text: $line.duration).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        }
                    } else {
                        Text(line.title).font(.headline)
                        Text(line.subtitle).font(.caption).foregroundStyle(.secondary)
                        Text(line.detail).font(.callout).textSelection(.enabled)
                    }
                }
                .padding(.leading, CGFloat(min(line.depth, 5)) * 12)
                Divider()
            }
            if unresolvedDuplicates { Text("Choose how to handle the matching folders before confirming.").font(.callout).foregroundStyle(.secondary) }
            HStack {
                Button("Cancel", role: .cancel) { sophy.cancelPreview() }.accessibilityIdentifier("sophy.preview.cancel")
                Spacer()
                Button(folders ? "Confirm \(sophy.previewLines.count) folders" : "Confirm and continue", action: confirm)
                    .buttonStyle(.borderedProminent).disabled(unresolvedDuplicates || sophy.isWorking)
                    .accessibilityIdentifier("sophy.preview.confirm")
            }
        }
        .padding(16).background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16))
    }
}
