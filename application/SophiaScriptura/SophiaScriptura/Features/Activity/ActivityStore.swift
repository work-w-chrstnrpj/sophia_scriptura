import Foundation
import Combine

@MainActor final class ActivityStore: ObservableObject {
    @Published private(set) var snapshot = ActivitySnapshot()
    @Published var errorMessage: String?
    @Published var finishRequestID: UUID?
    @Published var startRequestID: UUID?
    @Published private(set) var remindersEnabled = false
    private let repository: ActivityFileRepository
    private var loaded = false
    private var pendingSave: Task<Void, Never>?
    private var pendingReminderSync: Task<Void, Never>?

    init(repository: ActivityFileRepository = ActivityFileRepository()) { self.repository = repository }

    var records: [ActivityRecord] { snapshot.records.sorted { $0.activityDate > $1.activityDate } }
    var draft: ActivityDraft? { snapshot.draft }
    var goalMinutes: Int { snapshot.dailyGoalMinutes }
    func goalMinutes(for modeID: String) -> Int { snapshot.dailyGoalMinutesByMode?[modeID] ?? 0 }
    var reminders: [ActivityReminder] { (snapshot.reminders ?? []).sorted { $0.date < $1.date } }
    var isReady: Bool { loaded }
    var modes: [ActivityMode] {
        ActivityModeID.allCases.map { ActivityMode(id: $0.id, name: $0.title, isBuiltIn: true) }
        + snapshot.customModes.filter { !$0.archived }
    }
    func modeIncludingArchived(_ id: String) -> ActivityMode? {
        modes.first { $0.id == id } ?? snapshot.customModes.first { $0.id == id }
    }

    func load() async {
        guard !loaded else { return }
        do {
            snapshot = try await repository.load(); loaded = true
            migrateModeGoals()
            migrateReminderCleanupPreference()
            pruneExpiredReminders()
            syncReminders(requestPermission: false)
        }
        catch { errorMessage = "Activity data could not be loaded: \(error.localizedDescription)" }
    }

    private func persist() {
        guard loaded else { errorMessage = "Activity data must load before changes can be saved."; return }
        let value = snapshot
        let prior = pendingSave
        pendingSave = Task {
            await prior?.value
            do { try await repository.save(value) }
            catch { errorMessage = "Activity changes were not saved: \(error.localizedDescription)" }
        }
    }

    func flush() async { await pendingSave?.value; await pendingReminderSync?.value }

    func exportArchive() async -> Data? {
        await flush()
        do { return try await repository.exportArchive() }
        catch { errorMessage = "Activity export failed: \(error.localizedDescription)"; return nil }
    }

    func restoreArchive(_ data: Data) async {
        await flush()
        do {
            snapshot = try await repository.restoreArchive(data); loaded = true
            migrateModeGoals()
            migrateReminderCleanupPreference()
            pruneExpiredReminders()
            syncReminders(requestPermission: false)
        }
        catch { errorMessage = "Activity restore failed. Existing data was kept: \(error.localizedDescription)" }
    }

    func start(mode: ActivityMode, title: String, readingStart: VerseID? = nil, editionID: String? = nil, now: Date = Date()) {
        guard loaded else { errorMessage = "Activity data is not available."; return }
        errorMessage = nil
        guard snapshot.draft == nil else { errorMessage = "Finish the current activity before starting another."; return }
        snapshot.draft = ActivityDraft(id: UUID(), title: title, modeID: mode.id, modeLabel: mode.name,
            startedAt: now, runningSince: now, intervals: [], description: "", readingStart: readingStart, editionID: editionID)
        persist()
    }

    func pause(now: Date = Date()) {
        snapshot.draft?.pause(at: now)
        persist()
    }

    func resume(now: Date = Date()) {
        guard snapshot.draft?.runningSince == nil else { return }
        snapshot.draft?.runningSince = now
        persist()
    }

    func finish(title: String, description: String, readingEnd: VerseID? = nil, bookOrder: [String: Int] = [:], now: Date = Date()) {
        guard var draft = snapshot.draft else { return }
        errorMessage = nil
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { errorMessage = "Enter an activity title."; return }
        if draft.readingStart != nil && readingEnd == nil { errorMessage = "Choose the ending verse."; return }
        if let start = draft.readingStart, let end = readingEnd {
            guard start.referenceSystemID == end.referenceSystemID,
                  let first = bookOrder[start.book], let last = bookOrder[end.book],
                  (first, start.chapter, start.verse) <= (last, end.chapter, end.verse) else {
                errorMessage = "The ending verse must be at or after the starting verse."; return
            }
        }
        draft.pause(at: now)
        guard draft.activeSeconds(at: now) > 0 else { errorMessage = "Activity duration must be greater than zero."; return }
        let range = draft.readingStart.flatMap { start in readingEnd.map { PassageRange(start: start, end: $0) } }
        let record = ActivityRecord(id: draft.id, title: cleaned, modeID: draft.modeID, modeLabel: draft.modeLabel,
            activityDate: draft.startedAt, activeSeconds: draft.activeSeconds(at: now), source: "timer", timeZoneID: TimeZone.current.identifier,
            intervals: draft.intervals, description: description, readingRange: range,
            editionID: draft.editionID, quizSessionID: nil, createdAt: draft.startedAt, updatedAt: now)
        snapshot.records.append(record)
        snapshot.draft = nil
        persist()
    }

    func discardDraft() { snapshot.draft = nil; persist() }
    func requestFinish() { finishRequestID = UUID() }
    func clearFinishRequest() { finishRequestID = nil }
    func requestStart() { startRequestID = UUID() }
    func clearStartRequest() { startRequestID = nil }

    func addManual(title: String, mode: ActivityMode, startedAt: Date, endedAt: Date? = nil,
                   durationSeconds: TimeInterval? = nil, description: String, replacing id: UUID? = nil) {
        guard loaded else { errorMessage = "Activity data is not available."; return }
        errorMessage = nil
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { errorMessage = "Enter an activity title."; return }
        guard let finalEnd = endedAt ?? durationSeconds.map({ startedAt.addingTimeInterval($0) }),
              finalEnd > startedAt else {
            errorMessage = endedAt == nil ? "Enter a duration greater than zero." : "End time must follow start time."
            return
        }
        let previousIndex = id.flatMap { identifier in snapshot.records.firstIndex { $0.id == identifier } }
        if id != nil && previousIndex == nil { errorMessage = "This activity could not be found. Reopen History and try again."; return }
        let interval = ActivityInterval(start: startedAt, end: finalEnd)
        let overlaps = snapshot.records.filter { $0.id != id }.contains { record in
            record.intervals.contains { $0.start < finalEnd && startedAt < $0.end }
        } || (snapshot.draft.map { draft in
            draft.intervals.contains { $0.start < finalEnd && startedAt < $0.end }
            || (draft.runningSince.map { $0 < finalEnd && startedAt < Date() } ?? false)
        } ?? false)
        guard !overlaps else { errorMessage = "This time overlaps another saved activity. Correct the existing record first."; return }
        let now = Date()
        let previous = previousIndex.map { snapshot.records[$0] }
        let record = ActivityRecord(id: id ?? UUID(), title: cleaned, modeID: mode.id, modeLabel: mode.name,
            activityDate: startedAt, activeSeconds: interval.seconds, source: previous?.source ?? "manual", timeZoneID: TimeZone.current.identifier,
            intervals: [interval], description: description, readingRange: previous?.readingRange,
            editionID: previous?.editionID, quizSessionID: previous?.quizSessionID, createdAt: previous?.createdAt ?? now, updatedAt: now)
        if let previousIndex { snapshot.records[previousIndex] = record }
        else { snapshot.records.append(record) }
        persist()
    }

    func delete(_ id: UUID) {
        if let quizID = snapshot.records.first(where: { $0.id == id })?.quizSessionID {
            var suppressed = snapshot.suppressedQuizSessionIDs ?? []
            if !suppressed.contains(quizID) { suppressed.append(quizID) }
            snapshot.suppressedQuizSessionIDs = suppressed
        }
        snapshot.records.removeAll { $0.id == id }
        persist()
    }
    func setModeGoal(_ minutes: Int, for modeID: String) {
        guard modes.contains(where: { $0.id == modeID }) else { return }
        var goals = snapshot.dailyGoalMinutesByMode ?? [ActivityModeID.reading.id: snapshot.dailyGoalMinutes]
        for mode in modes where goals[mode.id] == nil { goals[mode.id] = 0 }
        goals[modeID] = max(0, min(minutes, 1440))
        _ = setModeGoals(goals)
    }

    @discardableResult
    func setModeGoals(_ requested: [String: Int]) -> Bool {
        let activeIDs = Set(modes.map(\.id))
        let goals = requested.filter { activeIDs.contains($0.key) }
        guard goals.count == activeIDs.count, goals.values.allSatisfy({ (0...1440).contains($0) }) else {
            errorMessage = "Enter a goal from 0 to 1,440 minutes for each activity type."
            return false
        }
        let total = goals.values.reduce(0, +)
        guard (1...1440).contains(total) else {
            errorMessage = total == 0 ? "Keep at least one minute of daily goals."
                : "The total daily goal cannot exceed 1,440 minutes."
            return false
        }
        snapshot.dailyGoalMinutesByMode = goals
        snapshot.dailyGoalMinutes = total
        errorMessage = nil
        persist()
        return true
    }

    private func migrateModeGoals() {
        guard snapshot.dailyGoalMinutesByMode == nil else { return }
        snapshot.dailyGoalMinutesByMode = [ActivityModeID.reading.id: snapshot.dailyGoalMinutes]
        persist()
    }

    @discardableResult
    func upsertReminder(id: UUID? = nil, title: String, description: String, date: Date,
                        mode: ActivityMode, repeatRule: ActivityReminderRepeat,
                        deleteAfterFiring: Bool = false) -> Bool {
        guard loaded else { return false }
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { errorMessage = "Enter a reminder title."; return false }
        let scheduledDate = Calendar.current.date(bySetting: .second, value: 0, of: date) ?? date
        guard repeatRule != .once || scheduledDate > Date() else {
            errorMessage = "Choose a future date and time for a one-time reminder."; return false
        }
        var values = snapshot.reminders ?? []
        values.removeAll { $0.id == id }
        values.append(ActivityReminder(id: id ?? UUID(), title: cleaned, description: description,
            date: scheduledDate, modeID: mode.id, modeLabel: mode.name, repeatRule: repeatRule,
            deleteAfterFiring: repeatRule == .once && deleteAfterFiring))
        snapshot.reminders = values
        errorMessage = nil
        persist()
        syncReminders(requestPermission: true)
        return true
    }

    func deleteReminder(_ id: UUID) {
        snapshot.reminders?.removeAll { $0.id == id }
        persist()
        syncReminders(requestPermission: false)
    }

    func pruneExpiredReminders(now: Date = Date()) {
        let before = snapshot.reminders?.count ?? 0
        snapshot.reminders?.removeAll { $0.repeatRule == .once && $0.deleteAfterFiring == true && $0.date <= now }
        if (snapshot.reminders?.count ?? 0) != before {
            persist()
            syncReminders(requestPermission: false)
        }
    }

    private func migrateReminderCleanupPreference() {
        guard let legacy = snapshot.autoDeleteOneTimeReminders else { return }
        for index in (snapshot.reminders ?? []).indices where snapshot.reminders?[index].repeatRule == .once {
            if snapshot.reminders?[index].deleteAfterFiring == nil {
                snapshot.reminders?[index].deleteAfterFiring = legacy
            }
        }
        snapshot.autoDeleteOneTimeReminders = nil
        persist()
    }

    private func syncReminders(requestPermission: Bool) {
        let prior = pendingReminderSync
        pendingReminderSync = Task {
            await prior?.value
            do {
                remindersEnabled = try await ActivityReminderNotifications.sync(reminders,
                    requestPermission: requestPermission)
                if requestPermission && !remindersEnabled {
                    errorMessage = "Reminder saved, but notifications are off. Enable Sophia notifications in iPad Settings."
                }
            } catch { errorMessage = "Reminder notification could not be scheduled: \(error.localizedDescription)" }
        }
    }

    func addMode(_ name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        snapshot.customModes.append(ActivityMode(id: UUID().uuidString, name: cleaned))
        persist()
    }

    func archiveMode(_ id: String) {
        guard let index = snapshot.customModes.firstIndex(where: { $0.id == id }) else { return }
        snapshot.customModes[index].archived = true
        let removedGoal = snapshot.dailyGoalMinutesByMode?.removeValue(forKey: id) ?? 0
        if removedGoal > 0 {
            let total = snapshot.dailyGoalMinutesByMode?.values.reduce(0, +) ?? 0
            if total == 0 { snapshot.dailyGoalMinutesByMode?[ActivityModeID.reading.id] = 1 }
            snapshot.dailyGoalMinutes = snapshot.dailyGoalMinutesByMode?.values.reduce(0, +) ?? 1
        }
        persist()
    }

    func importReviewingLinks(_ links: [ReviewingActivityLink]) {
        guard loaded else { return }
        var changed = false
        for link in links where !snapshot.records.contains(where: { $0.quizSessionID == link.quizSessionID })
            && !(snapshot.suppressedQuizSessionIDs ?? []).contains(link.quizSessionID) {
            let intersectsTimer = snapshot.draft.map { draft in
                draft.intervals.contains { $0.start < link.endedAt && link.startedAt < $0.end }
                || (draft.runningSince.map { $0 < link.endedAt && link.startedAt < Date() } ?? false)
            } ?? false
            let intersectsRecord = snapshot.records.contains { record in
                record.intervals.contains { $0.start < link.endedAt && link.startedAt < $0.end }
                || (record.intervals.isEmpty && record.source == "manual" && Calendar.current.isDate(record.activityDate, inSameDayAs: link.startedAt))
            }
            if intersectsTimer || intersectsRecord {
                errorMessage = "A Quiz Me review overlaps another activity. Correct the activity before importing its Reviewing time."
                continue
            }
            let mode = ActivityModeID.reviewing
            let now = Date()
            snapshot.records.append(ActivityRecord(id: link.id, title: "Quiz Me", modeID: mode.id,
                modeLabel: mode.title, activityDate: link.startedAt, activeSeconds: Double(link.activeSeconds),
                source: "quiz", timeZoneID: TimeZone.current.identifier, intervals: [], description: "", readingRange: nil, editionID: nil,
                quizSessionID: link.quizSessionID, createdAt: now, updatedAt: now))
            changed = true
        }
        if changed { persist() }
    }
}
