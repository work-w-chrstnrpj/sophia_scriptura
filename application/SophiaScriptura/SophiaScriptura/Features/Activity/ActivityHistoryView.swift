import SwiftUI

struct ActivityHistoryView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: ActivityStore
    let books: [ScriptureBook]
    let open: (ActivityRecord) -> Void
    let edit: (ActivityRecord) -> Void
    let delete: (ActivityRecord) -> Void
    var modeFilter: String? = nil
    var onStartNew: (() -> Void)? = nil

    var body: some View {
        List {
            if let onStartNew {
                Section {
                    ActivityPrimaryActionButton(
                        title: "Start new scripture contemplation",
                        systemImage: "sparkles",
                        action: onStartNew,
                        accessibilityID: "activity.contemplation.start"
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            ForEach(ActivityHistoryGrouping.groups(store.records.filter { modeFilter == nil || $0.modeID == modeFilter })) { group in
                Section {
                    ForEach(group.records) { record in
                        ActivityHistoryRow(record: record, books: books, open: { open(record) },
                                           edit: { edit(record) }, delete: { delete(record) })
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    Text(group.title).foregroundStyle(Color(theme.palette.secondary))
                }
            }
        }
        .listStyle(.plain)
        .appSurface()
        .background(Color(theme.palette.paper).ignoresSafeArea())
        .navigationTitle(modeFilter == ActivityModeID.meditating.id ? "Scripture Contemplation" : "Activity History")
        .toolbarBackground(Color(theme.palette.paper), for: .navigationBar)
    }
}

struct ActivityHistoryRow: View {
    @Environment(\.appTheme) private var theme
    let record: ActivityRecord
    let books: [ScriptureBook]
    let open: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Image(systemName: record.modeID == ActivityModeID.reading.id ? "book" : "clock")
                    .font(.title3)
                    .foregroundStyle(Color(theme.palette.accent))
                    .frame(width: 42, height: 42)
                    .background(Color(theme.palette.accent).opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.system(.headline, design: .serif).weight(.semibold))
                        .foregroundStyle(Color(theme.palette.ink))
                    Text("\(record.modeLabel) · \(record.activityDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(Color(theme.palette.secondary))
                    if let range = record.readingRange {
                        Text(ActivityPassageLabel.text(range, books: books))
                            .font(.caption)
                            .foregroundStyle(Color(theme.palette.secondary))
                    }
                }
                Spacer(minLength: 8)
                Text(ActivityDuration.text(record.activeSeconds))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color(theme.palette.ink))
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.secondary))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(theme.palette.rule), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") }
                .tint(.red)
            Button(action: edit) { Label("Edit", systemImage: "pencil") }
                .tint(Color(theme.palette.accent))
        }
        .accessibilityIdentifier("activity.record.\(record.id.uuidString)")
    }
}

struct ActivityRecordDetailView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let record: ActivityRecord
    let books: [ScriptureBook]
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: record.modeID == ActivityModeID.reading.id ? "book" : "clock")
                            .font(.title2)
                            .foregroundStyle(Color(theme.palette.accent))
                            .frame(width: 48, height: 48)
                            .background(Color(theme.palette.accent).opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.modeLabel.uppercased())
                                .font(.caption.weight(.semibold)).tracking(1)
                                .foregroundStyle(Color(theme.palette.secondary))
                            Text(record.title)
                                .font(.system(.title2, design: .serif).weight(.semibold))
                                .foregroundStyle(Color(theme.palette.ink))
                        }
                        Spacer(minLength: 8)
                        Text(ActivityDuration.text(record.activeSeconds))
                            .font(.title3.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(Color(theme.palette.ink))
                    }
                    Divider().overlay(Color(theme.palette.rule))
                    HStack(spacing: 16) {
                        detail("Date", value: record.activityDate.formatted(date: .abbreviated, time: .shortened))
                        detail("Source", value: record.source.capitalized)
                    }
                    if let range = record.readingRange {
                        detail("Passage", value: ActivityPassageLabel.text(range, books: books))
                    }
                    if !record.description.isEmpty {
                        detail("Description", value: record.description)
                    }
                }
                .padding(20)
                .frame(maxWidth: 720, alignment: .leading)
                .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(theme.palette.rule), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .frame(maxWidth: .infinity)
                HStack(spacing: 12) {
                    Button { edit() } label: { Label("Edit", systemImage: "pencil") }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(Color(theme.palette.paper))
                    Button(role: .destructive) {
                        dismiss()
                        delete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .foregroundStyle(.red)
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.top, 4)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
            }
            .appSurface()
            .navigationTitle("Activity Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.height(350), .large])
    }

    private func detail(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased()).font(.caption2.weight(.semibold))
                .foregroundStyle(Color(theme.palette.secondary))
            Text(value).font(.subheadline).foregroundStyle(Color(theme.palette.ink))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum ActivityPassageLabel {
    static func text(_ range: PassageRange, books: [ScriptureBook]) -> String {
        let bookTitle = books.first { $0.id == range.start.book }?.title ?? range.start.book
        if range.start == range.end {
            return "\(bookTitle) \(range.start.chapter):\(range.start.verse)"
        }
        if range.start.book == range.end.book, range.start.chapter == range.end.chapter {
            return "\(bookTitle) \(range.start.chapter):\(range.start.verse)-\(range.end.verse)."
        }
        let last = books.first { $0.id == range.end.book }?.title ?? range.end.book
        return "\(bookTitle) \(range.start.chapter):\(range.start.verse) – \(last) \(range.end.chapter):\(range.end.verse)"
    }
}

enum ActivityDuration {
    static func text(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let seconds = value % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}
