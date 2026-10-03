import SwiftUI

struct ActivityRemindersView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ActivityStore
    let reminder: ActivityReminder?
    @State private var title = ""
    @State private var details = ""
    @State private var date = Date().addingTimeInterval(3600)
    @State private var modeID = ActivityModeID.reading.id
    @State private var repeatRule: ActivityReminderRepeat = .once
    @State private var deleteAfterFiring = false

    private var mode: ActivityMode { store.modeIncludingArchived(modeID) ?? store.modes[0] }
    private var selectableModes: [ActivityMode] {
        var values = store.modes
        if let archived = store.modeIncludingArchived(modeID), !values.contains(where: { $0.id == archived.id }) {
            values.append(archived)
        }
        return values
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(reminder == nil ? "Create reminder" : "Edit reminder") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $details, axis: .vertical).lineLimit(2...4)
                    Picker("Activity type", selection: $modeID) {
                        ForEach(selectableModes) { mode in Text(mode.name).tag(mode.id) }
                    }
                    DatePicker("Date and time", selection: $date,
                               displayedComponents: [.date, .hourAndMinute])
                    Picker("Repeat", selection: $repeatRule) {
                        ForEach(ActivityReminderRepeat.allCases) { rule in Text(rule.title).tag(rule) }
                    }
                    if repeatRule == .once {
                        Toggle("Delete after it fires", isOn: $deleteAfterFiring)
                        Text("If selected, this reminder is removed when Sophia next opens or becomes active after its time.")
                            .font(.footnote).foregroundStyle(Color(theme.palette.secondary))
                    } else {
                        Text(repeatRule == .weekly
                             ? "The selected date sets the weekday. This repeats every week at the selected time."
                             : "This repeats at the selected time on the chosen days, beginning with the next matching day.")
                            .font(.footnote).foregroundStyle(Color(theme.palette.secondary))
                    }
                    Button(reminder == nil ? "Save reminder" : "Save changes") { save() }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(Color(theme.palette.paper))
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("activity.reminder.save")
                }
            }
            .appSurface()
            .navigationTitle(reminder == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close reminder")
                }
            }
            .alert("Reminder", isPresented: Binding(get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            guard let reminder else { return }
            title = reminder.title
            details = reminder.description
            date = reminder.date
            modeID = reminder.modeID
            repeatRule = reminder.repeatRule
            deleteAfterFiring = reminder.deleteAfterFiring ?? false
        }
    }

    private func save() {
        if store.upsertReminder(id: reminder?.id, title: title, description: details, date: date,
                                mode: mode, repeatRule: repeatRule, deleteAfterFiring: deleteAfterFiring) {
            dismiss()
        }
    }
}

struct ActivityReminderHistoryView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: ActivityStore
    let edit: (ActivityReminder) -> Void
    let delete: (ActivityReminder) -> Void

    var body: some View {
        List {
            ForEach(ActivityReminderGrouping.groups(store.reminders)) { group in
                Section {
                    ForEach(group.reminders) { reminder in
                        ActivityReminderRow(reminder: reminder,
                            open: { edit(reminder) }, edit: { edit(reminder) }, delete: { delete(reminder) })
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
        .navigationTitle("Reminders")
        .toolbarBackground(Color(theme.palette.paper), for: .navigationBar)
    }
}

struct ActivityReminderRow: View {
    @Environment(\.appTheme) private var theme
    let reminder: ActivityReminder
    let open: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundStyle(Color(theme.palette.accent))
                    .frame(width: 42, height: 42)
                    .background(Color(theme.palette.accent).opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.system(.headline, design: .serif).weight(.semibold))
                        .foregroundStyle(Color(theme.palette.ink))
                    Text("\(reminder.modeLabel) · \(reminder.repeatRule.title) · \(reminder.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote).foregroundStyle(Color(theme.palette.secondary))
                    if !reminder.description.isEmpty {
                        Text(reminder.description).font(.caption)
                            .foregroundStyle(Color(theme.palette.secondary)).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.secondary))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(theme.palette.rule), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") }.tint(.red)
            Button(action: edit) { Label("Edit", systemImage: "pencil") }.tint(Color(theme.palette.accent))
        }
        .accessibilityIdentifier("activity.reminder.\(reminder.id.uuidString)")
    }
}

enum ActivityReminderGrouping {
    struct Group: Identifiable {
        let title: String
        let reminders: [ActivityReminder]
        var id: String { title }
    }

    static func groups(_ reminders: [ActivityReminder], now: Date = Date(), calendar: Calendar = .current) -> [Group] {
        let ordered = reminders.sorted { $0.date < $1.date }
        let titles = ordered.map { reminder -> String in
            if reminder.repeatRule != .once { return "Recurring" }
            if reminder.date < calendar.startOfDay(for: now) { return "Past" }
            if calendar.isDate(reminder.date, inSameDayAs: now) { return "Today" }
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
               calendar.isDate(reminder.date, inSameDayAs: tomorrow) { return "Tomorrow" }
            if calendar.isDate(reminder.date, equalTo: now, toGranularity: .weekOfYear) { return "This Week" }
            if calendar.isDate(reminder.date, equalTo: now, toGranularity: .month) { return "This Month" }
            if calendar.isDate(reminder.date, equalTo: now, toGranularity: .year) { return "This Year" }
            return String(calendar.component(.year, from: reminder.date))
        }
        let preferred = ["Recurring", "Today", "Tomorrow", "This Week", "This Month", "This Year"]
        let unique = Array(Set(titles)).sorted { a, b in
            let first = preferred.firstIndex(of: a) ?? (a == "Past" ? Int.max : preferred.count)
            let second = preferred.firstIndex(of: b) ?? (b == "Past" ? Int.max : preferred.count)
            return first == second ? a < b : first < second
        }
        return unique.map { title in
            Group(title: title, reminders: zip(ordered, titles).compactMap { $0.1 == title ? $0.0 : nil })
        }
    }
}
