import Foundation

struct PlanPlaybackError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Collections retains progress ownership; Activity retains timer/history ownership.
/// The cursor's stable session ID makes either side of a cross-store retry recoverable.
@MainActor struct PlanPlaybackService {
    let store: CollectionsStore
    let activity: ActivityStore

    private func current(_ id: UUID) throws -> StudyPlan {
        guard let plan = store.plans.first(where: { $0.id == id }), plan.isActive,
              store.planAccessAllowed(plan) else { throw StudyMutationFailure.accessDenied }
        return plan
    }
    private func save(_ plan: StudyPlan) async throws {
        let result = await store.submit(.init(expectedPlanRevision: plan.revision, intent: .savePlan(plan, collectionID: nil)))
        guard result.receipt != nil else { throw PlanPlaybackError(message: result.message ?? "Plan save failed.") }
    }

    /// Returns false when a completed activity needs its completion modal first.
    func start(_ id: UUID, sectionID selectedSectionID: UUID? = nil, now: Date = Date()) async throws -> Bool {
        await activity.load()
        guard activity.isReady else { throw PlanPlaybackError(message: activity.errorMessage ?? "Activity is unavailable.") }
        if let selectedSectionID {
            guard try current(id).sections.contains(where: { $0.id == selectedSectionID && !$0.items.isEmpty }) else { throw StudyMutationFailure.invalid }
        }
        if try await reconcileFinishedActivity(id, now: now) { return false }
        var plan = try current(id)
        // Recover an interrupted final-item → history commit before starting another day.
        if plan.cursor?.kind == .sectionSummary, let sessionID = plan.cursor?.activitySessionID,
           activity.draft?.id == sessionID {
            try await finishSection(id, now: now); return false
        }
        guard var target = plan.playbackStartCursor(in: selectedSectionID), let sectionID = target.sectionID,
              let index = plan.sections.firstIndex(where: { $0.id == sectionID }) else {
            throw PlanPlaybackError(message: "This Plan is complete. Reset its progress in Edit to read it again.")
        }
        let draft = activity.draft
        guard draft == nil || draft?.planID == id else {
            throw PlanPlaybackError(message: "Finish the current activity before playing this Plan.")
        }
        let retainedID = target.activitySessionID.flatMap { id in activity.records.contains(where: { $0.id == id }) ? nil : id }
        let sessionID = activity.draftForPlan(id, sectionID: sectionID)?.id ?? retainedID ?? UUID()
        target.activitySessionID = sessionID; plan.cursor = target
        if plan.strictSchedule != nil && plan.strictSchedule?.startDate == nil { plan.strictSchedule?.startDate = now }
        try await save(plan)
        guard store.plans.first(where: { $0.id == id }).map(store.planAccessAllowed) == true else { throw StudyMutationFailure.accessDenied }
        let started = await activity.startPlanSession(id: sessionID, planID: id, sectionID: sectionID,
            title: "\(plan.title) - \(plan.sectionTitle(index))", modeID: plan.resolvedActivityModeID, now: now)
        guard started else { throw PlanPlaybackError(message: activity.errorMessage ?? "Activity could not start. Retry Resume.") }
        return true
    }

    /// Advances within the selected day only. Its final assignment saves a summary,
    /// then commits History. A failed History write leaves a retryable summary.
    func advance(_ id: UUID, now: Date = Date()) async throws -> Bool {
        var plan = try current(id)
        guard let cursor = plan.cursor,
              let s = plan.sections.firstIndex(where: { $0.id == cursor.sectionID }) else { throw StudyMutationFailure.invalid }
        if cursor.kind == .sectionSummary { try await finishSection(id, now: now); return true }
        guard let i = plan.sections[s].items.firstIndex(where: { $0.id == cursor.itemID }) else { throw StudyMutationFailure.invalid }
        plan.sections[s].items[i].completedAt = plan.sections[s].items[i].completedAt ?? now
        if i + 1 < plan.sections[s].items.count {
            plan.cursor = .init(kind: .item, sectionID: cursor.sectionID, itemID: plan.sections[s].items[i + 1].id,
                editionID: plan.preferredEditionID, activitySessionID: cursor.activitySessionID)
            try await save(plan); return false
        }
        plan.cursor = .init(kind: .sectionSummary, sectionID: cursor.sectionID, activitySessionID: cursor.activitySessionID)
        try await save(plan)
        try await finishSection(id, now: now)
        return true
    }

    func finishSection(_ id: UUID, now: Date = Date()) async throws {
        let plan = try current(id)
        guard let section = plan.sections.first(where: { $0.id == plan.cursor?.sectionID }),
              !section.items.isEmpty, section.items.allSatisfy({ $0.completedAt != nil }) else { throw StudyMutationFailure.invalid }
        guard let sessionID = plan.cursor?.activitySessionID else { return }
        guard await activity.finishPlanSession(id: sessionID, now: now) else {
            throw PlanPlaybackError(message: activity.errorMessage ?? "Activity could not finish. Retry Finish day.")
        }
    }

    /// Recover an already-checked day; an older History record never checks unfinished work.
    func reconcileFinishedActivity(_ id: UUID, now: Date = Date()) async throws -> Bool {
        var plan = try current(id)
        guard let cursor = plan.cursor, cursor.kind == .item, let sessionID = cursor.activitySessionID else { return false }
        await activity.flush()
        guard activity.records.contains(where: { $0.id == sessionID && $0.planID == id && $0.planSectionID == cursor.sectionID }),
              let s = plan.sections.firstIndex(where: { $0.id == cursor.sectionID }),
              !plan.sections[s].items.isEmpty,
              plan.sections[s].items.allSatisfy({ $0.completedAt != nil }) else { return false }
        guard await activity.finishPlanSession(id: sessionID, now: now) else {
            throw PlanPlaybackError(message: activity.errorMessage ?? "Activity history could not be saved.")
        }
        plan.cursor = .init(kind: .sectionSummary, sectionID: cursor.sectionID, activitySessionID: sessionID)
        try await save(plan); return true
    }

    func pause(_ id: UUID, now: Date = Date()) async -> Bool {
        guard let sessionID = store.plans.first(where: { $0.id == id })?.cursor?.activitySessionID else { return true }
        return await activity.pausePlanSession(id: sessionID, now: now)
    }
}
