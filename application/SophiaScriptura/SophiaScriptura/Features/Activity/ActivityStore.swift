import Foundation
import Combine

@MainActor final class ActivityStore: ObservableObject {
    @Published private(set) var snapshot = ActivitySnapshot()
    @Published var errorMessage: String?
    @Published var finishRequestID: UUID?
    @Published var startRequestID: UUID?
    @Published var sophyContemplationRequest: SophyContemplationRequest?
    @Published private(set) var remindersEnabled = false
    @Published private(set) var committedProjection: ActivitySystemProjection?
    @Published private(set) var committedRevision: UInt64 = 0
    private let repository: ActivityFileRepository
    private var saveRevision: UInt64 = 0
    private(set) var recoveredOlderGeneration = false
    private var loaded = false
    private var pendingSave: Task<Void, Never>?
    private var sophyCommitInFlight = false
    private var pendingReminderSync: Task<Void, Never>?

    private let syncReminderNotifications: ([ActivityReminder], Bool) async throws -> Bool

    init(repository: ActivityFileRepository = ActivityFileRepository(),
         syncReminderNotifications: @escaping ([ActivityReminder], Bool) async throws -> Bool = { reminders, requestPermission in
             try await ActivityReminderNotifications.sync(reminders, requestPermission: requestPermission)
         }) {
        self.repository = repository
        self.syncReminderNotifications = syncReminderNotifications
    }

    var records: [ActivityRecord] { snapshot.records.sorted { $0.activityDate > $1.activityDate } }
    var draft: ActivityDraft? { snapshot.draft }
    var goalMinutes: Int { snapshot.dailyGoalMinutes }
    func goalMinutes(for modeID: String) -> Int { snapshot.dailyGoalMinutesByMode?[modeID] ?? 0 }
    var reminders: [ActivityReminder] { (snapshot.reminders ?? []).sorted { $0.date < $1.date } }
    var isReady: Bool { loaded }
    var automaticReadingWorkflow: Bool { snapshot.automaticReadingWorkflow ?? true }
    var automaticContemplationWorkflow: Bool { snapshot.automaticContemplationWorkflow ?? true }
    func launchesWorkflow(for modeID: String) -> Bool {
        switch modeID {
        case ActivityModeID.reading.id: automaticReadingWorkflow
        case ActivityModeID.meditating.id: automaticContemplationWorkflow
        default: false
        }
    }
    func setAutomaticWorkflow(_ enabled: Bool, for modeID: String) {
        guard !rejectWhileSophyCommits() else { return }

        guard loaded else { return }
        if modeID == ActivityModeID.reading.id { snapshot.automaticReadingWorkflow = enabled }
        else if modeID == ActivityModeID.meditating.id { snapshot.automaticContemplationWorkflow = enabled }
        else { return }
        persist()
    }
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
            snapshot = try await repository.load(); recoveredOlderGeneration = await repository.didRecoverOlderGeneration(); loaded = true
            saveRevision = 0
            acknowledgeCommitted(snapshot, revision: 0)
            migrateModeGoals()
            migrateReminderCleanupPreference()
            pruneExpiredReminders()
            syncReminders(requestPermission: false)
        }
        catch { errorMessage = "Activity data could not be loaded: \(error.localizedDescription)" }
    }

    func createManualFromSophy(id: UUID, title: String, mode: ActivityMode, startedAt: Date, endedAt: Date, description: String) async -> SophyCommitOutcome {
        guard loaded else { return .rejected(.writeFailed) }
        guard !sophyCommitInFlight else { return .rejected(.busy) }
        sophyCommitInFlight = true
        defer { sophyCommitInFlight = false }
        await flush()
        if snapshot.records.contains(where: { $0.id == id }) { return .alreadyCommitted(resultIDs: [id]) }
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 200, description.count <= 2_000, endedAt > startedAt else {
            return .rejected(.invalidArguments)
        }
        let overlaps = snapshot.records.contains { record in
            record.intervals.contains { $0.start < endedAt && startedAt < $0.end }
        } || (snapshot.draft.map { draft in
            draft.intervals.contains { $0.start < endedAt && startedAt < $0.end }
                || (draft.runningSince.map { $0 < endedAt && startedAt < Date() } ?? false)
        } ?? false)
        guard !overlaps else { return .rejected(.invalidArguments) }
        var candidate = snapshot
        let interval = ActivityInterval(start: startedAt, end: endedAt)
        candidate.records.append(ActivityRecord(
            id: id, title: cleaned, modeID: mode.id, modeLabel: mode.name, activityDate: startedAt,
            activeSeconds: interval.seconds, source: "manual", timeZoneID: TimeZone.current.identifier,
            intervals: [interval], description: description, readingRange: nil, editionID: nil,
            quizSessionID: nil, createdAt: Date(), updatedAt: Date()
        ))
        do {
            try await repository.save(candidate)
            snapshot = candidate
            saveRevision += 1
            acknowledgeCommitted(candidate, revision: saveRevision)
            errorMessage = nil
            return .committed(resultIDs: [id])
        } catch {
            return .uncertain(resultIDs: [id])
        }
    }

    func createReminderFromSophy(id: UUID, title: String, description: String, date: Date, mode: ActivityMode, repeatRule: ActivityReminderRepeat, deleteAfterFiring: Bool, now: Date = Date()) async -> SophyCommitOutcome {
        guard loaded else { return .rejected(.writeFailed) }
        guard !sophyCommitInFlight else { return .rejected(.busy) }
        sophyCommitInFlight = true
        defer { sophyCommitInFlight = false }
        await flush()
        if (snapshot.reminders ?? []).contains(where: { $0.id == id }) { return .alreadyCommitted(resultIDs: [id]) }
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 200, description.count <= 2_000 else { return .rejected(.invalidArguments) }
        let scheduled = Calendar.current.date(bySetting: .second, value: 0, of: date) ?? date
        guard repeatRule != .once || scheduled > now else { return .rejected(.invalidArguments) }
        var candidate = snapshot
        var values = candidate.reminders ?? []
        values.append(ActivityReminder(id: id, title: cleaned, description: description, date: scheduled, modeID: mode.id, modeLabel: mode.name, repeatRule: repeatRule, deleteAfterFiring: repeatRule == .once && deleteAfterFiring))
        candidate.reminders = values
        do {
            try await repository.save(candidate)
            snapshot = candidate
            saveRevision += 1
            acknowledgeCommitted(candidate, revision: saveRevision)
            errorMessage = nil
        } catch {
            return .uncertain(resultIDs: [id])
        }
        do {
            remindersEnabled = try await syncReminderNotifications(reminders, true)
            if !remindersEnabled {
                errorMessage = "Reminder saved, but notifications are off. Enable Sophia notifications in iPad Settings."
            }
        } catch {
            errorMessage = "Reminder saved, but notifications could not be scheduled."
        }
        return .committed(resultIDs: [id])
    }

    private func rejectWhileSophyCommits() -> Bool {
        guard sophyCommitInFlight else { return false }
        errorMessage = SophySafeError.busy.message
        return true
    }

    private func persist() {
        guard !sophyCommitInFlight else {
            errorMessage = SophySafeError.busy.message
            return
        }
        guard loaded else { errorMessage = "Activity data must load before changes can be saved."; return }
        saveRevision += 1
        let revision = saveRevision
        let candidate = snapshot
        let prior = pendingSave
        pendingSave = Task {
            await prior?.value
            do {
                try await repository.save(candidate)
                await MainActor.run {
                    self.acknowledgeCommitted(candidate, revision: revision)
                    self.errorMessage = nil
                }
            }
            catch { errorMessage = "Activity changes were not saved: \(error.localizedDescription)" }
        }
    }

    private func acknowledgeCommitted(_ snapshot: ActivitySnapshot, revision: UInt64) {
        guard revision >= committedRevision else { return }
        committedRevision = revision
        committedProjection = ActivitySystemProjectionBuilder.from(snapshot: snapshot, revision: revision)
    }

    func flush() async { await pendingSave?.value; await pendingReminderSync?.value }

    func exportArchive() async -> Data? {
        await flush()
        do { return try await repository.exportArchive() }
        catch { errorMessage = "Activity export failed: \(error.localizedDescription)"; return nil }
    }

    func restoreArchive(_ data: Data) async {
        guard !rejectWhileSophyCommits() else { return }

        await flush()
        do {
            snapshot = try await repository.restoreArchive(data); loaded = true
            saveRevision = 0
            acknowledgeCommitted(snapshot, revision: 0)
            migrateModeGoals()
            migrateReminderCleanupPreference()
            pruneExpiredReminders()
            syncReminders(requestPermission: false)
        }
        catch { errorMessage = "Activity restore failed. Existing data was kept: \(error.localizedDescription)" }
    }

    func start(mode: ActivityMode, title: String, readingStart: VerseID? = nil, editionID: String? = nil,
               guidedWorkflow: Bool = false, now: Date = Date()) {
        guard !rejectWhileSophyCommits() else { return }

        guard loaded else { errorMessage = "Activity data is not available."; return }
        errorMessage = nil
        guard snapshot.draft == nil else { errorMessage = "Finish the current activity before starting another."; return }
        snapshot.draft = ActivityDraft(id: UUID(), title: title, modeID: mode.id, modeLabel: mode.name,
            startedAt: now, runningSince: now, intervals: [], description: "", readingStart: readingStart, editionID: editionID, guidedWorkflow: guidedWorkflow)
        persist()
    }

    func pause(now: Date = Date()) {
        guard !rejectWhileSophyCommits() else { return }

        snapshot.draft?.pause(at: now)
        persist()
    }

    func resume(now: Date = Date()) {
        guard !rejectWhileSophyCommits() else { return }

        guard snapshot.draft?.runningSince == nil else { return }
        snapshot.draft?.runningSince = now
        persist()
    }

    func finish(title: String, description: String, readingStart: VerseID? = nil, readingEnd: VerseID? = nil,
               bookOrder: [String: Int] = [:], now: Date = Date()) {
        guard !rejectWhileSophyCommits() else { return }

        guard var draft = snapshot.draft else { return }
        errorMessage = nil
        if let readingStart { draft.readingStart = readingStart }
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

    func discardDraft() {
        guard !rejectWhileSophyCommits() else { return }
 snapshot.draft = nil; persist() }
    func requestFinish() { finishRequestID = UUID() }
    func clearFinishRequest() { finishRequestID = nil }
    func requestStart() { startRequestID = UUID() }
    func clearStartRequest() { startRequestID = nil }

    func addManual(title: String, mode: ActivityMode, startedAt: Date, endedAt: Date? = nil,
                   durationSeconds: TimeInterval? = nil, description: String, replacing id: UUID? = nil) {
        guard !rejectWhileSophyCommits() else { return }
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
        guard !rejectWhileSophyCommits() else { return }

        if let quizID = snapshot.records.first(where: { $0.id == id })?.quizSessionID {
            var suppressed = snapshot.suppressedQuizSessionIDs ?? []
            if !suppressed.contains(quizID) { suppressed.append(quizID) }
            snapshot.suppressedQuizSessionIDs = suppressed
        }
        snapshot.records.removeAll { $0.id == id }
        persist()
    }
    func setModeGoal(_ minutes: Int, for modeID: String) {
        guard !rejectWhileSophyCommits() else { return }

        guard modes.contains(where: { $0.id == modeID }) else { return }
        var goals = snapshot.dailyGoalMinutesByMode ?? [ActivityModeID.reading.id: snapshot.dailyGoalMinutes]
        for mode in modes where goals[mode.id] == nil { goals[mode.id] = 0 }
        goals[modeID] = max(0, min(minutes, 1440))
        _ = setModeGoals(goals)
    }

    @discardableResult
    func setModeGoals(_ requested: [String: Int]) -> Bool {
        guard !rejectWhileSophyCommits() else { return false }

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
        guard !rejectWhileSophyCommits() else { return false }
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
        guard !rejectWhileSophyCommits() else { return }

        snapshot.reminders?.removeAll { $0.id == id }
        persist()
        syncReminders(requestPermission: false)
    }

    func removeAllReminders() {
        guard !rejectWhileSophyCommits() else { return }

        guard loaded else { return }
        snapshot.reminders = []
        persist()
        syncReminders(requestPermission: false)
    }

    func removeAllActivityRecords() {
        guard !rejectWhileSophyCommits() else { return }

        guard loaded else { return }
        snapshot.records.removeAll()
        snapshot.draft = nil
        persist()
    }

    func pruneExpiredReminders(now: Date = Date()) {
        guard !rejectWhileSophyCommits() else { return }

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
        guard !rejectWhileSophyCommits() else { return }

        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        snapshot.customModes.append(ActivityMode(id: UUID().uuidString, name: cleaned))
        persist()
    }

    func archiveMode(_ id: String) {
        guard !rejectWhileSophyCommits() else { return }

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

    func importQuizStudyLinks(_ links: [ReviewingActivityLink]) {
        if sophyCommitInFlight {
            Task { @MainActor in
                while self.sophyCommitInFlight { await Task.yield() }
                self.importQuizStudyLinks(links)
            }
            return
        }
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
                errorMessage = "A Quiz Me session overlaps another activity. Correct the activity before importing its Studying time."
                continue
            }
            let mode = ActivityModeID.studying
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
