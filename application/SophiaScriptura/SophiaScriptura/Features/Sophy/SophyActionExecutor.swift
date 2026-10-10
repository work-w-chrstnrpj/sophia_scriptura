import Foundation

enum SophyActionExecutor {
    static func reconcile(
        journal: [SophyJournalEntry],
        presentIDs: Set<UUID>,
        featureRecoveredOlderGeneration: Bool,
        now: Date
    ) -> [SophyJournalEntry] {
        journal.map { entry in
            let disposition = SophyReconciler.disposition(
                entry: entry,
                presentResultIDs: presentIDs,
                featureRecoveredOlderGeneration: featureRecoveredOlderGeneration
            )
            var copy = entry
            switch disposition {
            case .terminal:
                return entry
            case .committed:
                copy.state = .committed
                copy.safeErrorCode = nil
            case .notApplied:
                copy.state = .rejected
                copy.safeErrorCode = SophySafeError.notApplied.code
            case .integrityError, .uncertain:
                copy.state = .uncertain
                copy.safeErrorCode = SophySafeError.uncertain.code
            }
            copy.updatedAt = now
            return copy
        }
    }

    @MainActor
    static func commit(
        actions: [SophyActionDraft],
        handles: [String: UUID],
        collections: CollectionsStore,
        activity: ActivityStore,
        repository: SophyFileRepository,
        now: Date,
        calendar: Calendar,
        makeID: @escaping () -> UUID = { UUID() }
    ) async -> SophyCommitOutcome {
        let loadedJournal: SophyFileRepository.LoadResult<[SophyJournalEntry]>
        let loadedHistory: SophyFileRepository.LoadResult<[SophyHistoryEntry]>
        do {
            loadedJournal = try await repository.loadJournal()
            loadedHistory = try await repository.loadHistory()
        } catch { return .rejected(.writeFailed) }
        guard !loadedJournal.mutationsDisabled, !loadedHistory.mutationsDisabled else { return .rejected(.writeFailed) }
        var journal = loadedJournal.value
        var history = loadedHistory.value
        let savedActions = actions.filter(\.mutatesSavedData)
        if let error = preflight(savedActions, handles: handles, collections: collections, activity: activity, now: now, calendar: calendar) {
            return .rejected(error)
        }
        let planID = UUID()
        let preparedEntries = savedActions.map { action in
            var entry = preparedEntry(for: action, handles: handles, now: now, makeID: makeID)
            entry.planID = planID
            return entry
        }
        journal.append(contentsOf: preparedEntries)
        guard await persist(journal: journal, history: history, repository: repository) else { return .rejected(.writeFailed) }
        var committedIDs: [UUID] = []
        var stopped = false
        for (action, prepared) in zip(savedActions, preparedEntries) {
            guard let index = journal.firstIndex(where: { $0.id == prepared.id }) else { return .uncertain(resultIDs: prepared.resultIDs) }
            journal[index].state = .applying
            journal[index].updatedAt = now
            guard await persist(journal: journal, history: history, repository: repository) else {
                return .uncertain(resultIDs: prepared.resultIDs)
            }
            let priorError = activity.errorMessage
            let outcome = await perform(action, entry: journal[index], handles: handles, collections: collections, activity: activity, now: now, calendar: calendar)
            switch outcome {
            case .committed(let ids), .alreadyCommitted(let ids):
                journal[index].state = .committed
                journal[index].resultIDs = ids
                journal[index].safeErrorCode = nil
                let status = notificationStatus(action: action, activity: activity, priorError: priorError, outcome: outcome)
                history.append(historyEntry(action: action, status: status, ids: ids, now: now, makeID: makeID))
                committedIDs.append(contentsOf: ids)
            case .partial(let ids, let error):
                return .partial(resultIDs: committedIDs + ids, error: error)
            case .rejected(let error):
                journal[index].state = .rejected
                journal[index].safeErrorCode = error.code
                history.append(historyEntry(action: action, status: "rejected", ids: journal[index].resultIDs, now: now, makeID: makeID))
                stopped = true
            case .uncertain(let ids):
                journal[index].state = .uncertain
                journal[index].resultIDs = ids
                journal[index].safeErrorCode = SophySafeError.uncertain.code
                history.append(historyEntry(action: action, status: "uncertain", ids: ids, now: now, makeID: makeID))
                stopped = true
            }
            journal[index].updatedAt = now
            guard await persist(journal: journal, history: history, repository: repository) else {
                return .uncertain(resultIDs: committedIDs + prepared.resultIDs)
            }
            if stopped {
                if case .rejected(let error) = outcome {
                    return committedIDs.isEmpty ? .rejected(error) : .partial(resultIDs: committedIDs, error: error)
                }
                if case .uncertain(let ids) = outcome { return .uncertain(resultIDs: committedIDs + ids) }
                return .uncertain(resultIDs: committedIDs)
            }
        }
        return .committed(resultIDs: committedIDs)
    }

    /// Validate every saved step before the first write; commands still revalidate live state.
    @MainActor
    private static func preflight(_ actions: [SophyActionDraft], handles: [String: UUID], collections: CollectionsStore,
                                  activity: ActivityStore, now: Date, calendar: Calendar) -> SophySafeError? {
        var proposedIntervals: [(Date, Date)] = activity.records.flatMap { $0.intervals.map { ($0.start, $0.end) } }
        if let draft = activity.snapshot.draft {
            proposedIntervals += draft.intervals.map { ($0.start, $0.end) }
            if let running = draft.runningSince { proposedIntervals.append((running, now)) }
        }
        for action in actions {
            switch action {
            case .createFolders(let destination, let nodes):
                guard (1...100).contains(nodes.count), (try? SophyResponseValidator.validateTree(nodes)) != nil else { return .invalidArguments }
                let parentID = destination.flatMap { handles[$0] }
                if destination != nil && parentID == nil { return .forgedHandle }
                if let parentID, collections.sophyFolderIsProtected(parentID) || collections.collection(id: parentID)?.isActiveInLibrary != true { return .accessDenied }
                let ids = Dictionary(uniqueKeysWithValues: nodes.map { ($0.key, $0.existingID ?? UUID()) })
                for node in nodes {
                    let name = node.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty, name.count <= 120, node.description.count <= 2_000,
                          name.localizedCaseInsensitiveCompare("No Folder") != .orderedSame else { return .invalidArguments }
                    let parent = node.parentKey.flatMap { ids[$0] } ?? parentID
                    if let existingID = node.existingID {
                        guard let folder = collections.collection(id: existingID), folder.isActiveInLibrary,
                              !collections.sophyFolderIsProtected(existingID), folder.parentID == parent,
                              folder.name.localizedCaseInsensitiveCompare(name) == .orderedSame else { return .stalePlan }
                    } else if !node.allowDuplicateName {
                        let matchingSaved = collections.children(of: parent).contains { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
                        let matchingNew = nodes.contains { $0.key != node.key && $0.parentKey == node.parentKey && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
                        if matchingSaved || matchingNew { return .invalidArguments }
                    }
                }
            case .createReminder(let title, let detail, let mode, let date, let time, let rule, _):
                guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 200, detail.count <= 2_000,
                      activity.modeIncludingArchived(mode)?.archived == false,
                      let recurrence = ActivityReminderRepeat(rawValue: rule),
                      let scheduled = localDateTime(date: date, time: time, calendar: calendar),
                      recurrence != .once || scheduled > now else { return .invalidArguments }
            case .createActivity(let title, let detail, let mode, let date, let time, let endDate, let endTime, let duration):
                guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 200, detail.count <= 2_000,
                      activity.modeIncludingArchived(mode)?.archived == false, let time,
                      let start = localDateTime(date: date, time: time, calendar: calendar) else { return .invalidArguments }
                let end: Date
                if let endDate, let endTime, let parsed = localDateTime(date: endDate, time: endTime, calendar: calendar) { end = parsed }
                else if endDate == nil, endTime == nil, let duration, (1...1440).contains(duration) { end = start.addingTimeInterval(Double(duration) * 60) }
                else { return .invalidArguments }
                guard end > start, end.timeIntervalSince(start) <= 86400,
                      duration == nil || abs(end.timeIntervalSince(start) - Double(duration!) * 60) < 0.5,
                      !proposedIntervals.contains(where: { $0.0 < end && start < $0.1 }) else { return .invalidArguments }
                proposedIntervals.append((start, end))
            default: return .unknownAction
            }
        }
        return nil
    }

    @MainActor
    private static func notificationStatus(action: SophyActionDraft, activity: ActivityStore, priorError: String?, outcome: SophyCommitOutcome) -> String {
        guard case .createReminder = action, case .committed = outcome else { return "committed" }
        if activity.errorMessage != priorError, activity.errorMessage != nil { return "notScheduled" }
        return "committed"
    }

    private static func preparedEntry(for action: SophyActionDraft, handles: [String: UUID], now: Date, makeID: () -> UUID) -> SophyJournalEntry {
        let ids: [UUID]
        switch action {
        case .createFolders(_, let nodes):
            ids = nodes.filter { $0.existingID == nil }.map { _ in makeID() }
        case .createReminder, .createActivity:
            ids = [makeID()]
        default:
            ids = []
        }
        return SophyJournalEntry(
            id: makeID(),
            planID: makeID(),
            actionType: action.typeName,
            resultIDs: ids,
            state: .prepared,
            createdAt: now,
            updatedAt: now,
            safeErrorCode: nil
        )
    }

    @MainActor
    private static func perform(
        _ action: SophyActionDraft,
        entry: SophyJournalEntry,
        handles: [String: UUID],
        collections: CollectionsStore,
        activity: ActivityStore,
        now: Date,
        calendar: Calendar
    ) async -> SophyCommitOutcome {
        switch action {
        case .createFolders(let destinationHandle, let nodes):
            let destinationID: UUID?
            if let destinationHandle {
                guard let id = handles[destinationHandle] else { return .rejected(.forgedHandle) }
                destinationID = id
            } else {
                destinationID = nil
            }
            var keyIDs: [String: UUID] = [:]
            var newIDs = entry.resultIDs.makeIterator()
            for node in nodes {
                guard let id = node.existingID ?? newIDs.next() else { return .rejected(.invalidArguments) }
                keyIDs[node.key] = id
            }
            for node in nodes where node.existingID != nil {
                guard let id = node.existingID, let existing = collections.collection(id: id),
                      existing.isActiveInLibrary, !collections.sophyFolderIsProtected(id),
                      existing.parentID == (node.parentKey.flatMap { keyIDs[$0] } ?? destinationID),
                      existing.name.localizedCaseInsensitiveCompare(node.name) == .orderedSame else { return .rejected(.stalePlan) }
            }
            let commits = nodes.filter { $0.existingID == nil }.map { node in
                SophyFolderCommit(id: keyIDs[node.key]!, name: node.name, detail: node.description,
                    parentID: node.parentKey.flatMap { keyIDs[$0] } ?? destinationID, allowDuplicateName: node.allowDuplicateName)
            }
            if commits.isEmpty { return .alreadyCommitted(resultIDs: []) }
            return await collections.createTreeFromSophy(commits, destinationID: destinationID)
        case .createReminder(let title, let description, let modeHandle, let localDate, let localTime, let repeatRule, let deleteAfterFiring):
            guard let mode = activity.modeIncludingArchived(modeHandle), !mode.archived else { return .rejected(.invalidArguments) }
            guard let rule = ActivityReminderRepeat(rawValue: repeatRule) else { return .rejected(.unsupportedRecurrence) }
            guard let date = localDateTime(date: localDate, time: localTime, calendar: calendar), let id = entry.resultIDs.first else {
                return .rejected(.invalidArguments)
            }
            return await activity.createReminderFromSophy(
                id: id, title: title, description: description, date: date, mode: mode,
                repeatRule: rule, deleteAfterFiring: deleteAfterFiring, now: now
            )
        case .createActivity(let title, let description, let modeHandle, let localDate, let localStartTime, let localEndDate, let localEndTime, let durationMinutes):
            guard let mode = activity.modeIncludingArchived(modeHandle), !mode.archived else { return .rejected(.invalidArguments) }
            guard let id = entry.resultIDs.first else { return .rejected(.invalidArguments) }
            let start: Date
            if let localStartTime, let parsed = localDateTime(date: localDate, time: localStartTime, calendar: calendar) {
                start = parsed
            } else {
                return .rejected(.invalidArguments)
            }
            let end: Date
            if let localEndDate, let localEndTime, let parsed = localDateTime(date: localEndDate, time: localEndTime, calendar: calendar) {
                end = parsed
            } else if let durationMinutes, durationMinutes > 0 {
                end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
            } else {
                return .rejected(.invalidArguments)
            }
            if let durationMinutes, abs(end.timeIntervalSince(start) - TimeInterval(durationMinutes) * 60) > 0.5 { return .rejected(.invalidArguments) }
            return await activity.createManualFromSophy(id: id, title: title, mode: mode, startedAt: start, endedAt: end, description: description)
        default:
            return .rejected(.unknownAction)
        }
    }

    static func localDateTime(date: String, time: String, calendar: Calendar) -> Date? {
        let day = date.split(separator: "-")
        let clock = time.split(separator: ":")
        guard day.count == 3, clock.count == 2,
              let year = Int(day[0]), let month = Int(day[1]), let dayNumber = Int(day[2]),
              let hour = Int(clock[0]), let minute = Int(clock[1]),
              (1...12).contains(month), (1...31).contains(dayNumber), (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = dayNumber
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let resolved = calendar.date(from: components) else { return nil }
        let actual = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: resolved)
        guard actual.year == year, actual.month == month, actual.day == dayNumber,
              actual.hour == hour, actual.minute == minute else { return nil }
        // A repeated wall-clock time needs explicit clarification instead of guessing an offset.
        if let other = calendar.date(byAdding: .hour, value: 1, to: resolved),
           calendar.dateComponents([.year, .month, .day, .hour, .minute], from: other) == actual { return nil }
        return resolved
    }

    private static func historyEntry(action: SophyActionDraft, status: String, ids: [UUID], now: Date, makeID: () -> UUID) -> SophyHistoryEntry {
        SophyHistoryEntry(id: makeID(), createdAt: now, actionType: action.typeName, status: status, resultIDs: ids, resultCount: ids.count)
    }

    private static func persist(journal: [SophyJournalEntry], history: [SophyHistoryEntry], repository: SophyFileRepository) async -> Bool {
        do {
            try await repository.saveJournal(journal)
            try await repository.saveHistory(history)
            return true
        } catch {
            return false
        }
    }
}
