import XCTest
@testable import SophiaScriptura

@MainActor final class PlanPlaybackTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 1_767_225_600)
    private func plan() -> StudyPlan {
        StudyPlan(title: "Gospel Plan", preferredEditionID: ScriptureReferenceIdentity.bundledEditionID,
            referenceSystemID: "org.sophia.web.engwebp", sections: (1...2).map { chapter in
                PlanSection(items: (1...2).map { verse in
                    PlanItem(payload: .scripture(referenceSystemID: "org.sophia.web.engwebp", book: "JHN", chapter: chapter, start: verse))
                })
            })
    }
    private func fixture(_ root: URL, value: StudyPlan? = nil) async throws -> (CollectionsStore, ActivityStore, PlanPlaybackService, UUID) {
        let store = CollectionsStore(repository: CollectionsFileRepository(directory: root.appendingPathComponent("collections")))
        await store.load()
        let activity = ActivityStore(repository: ActivityFileRepository(directory: root.appendingPathComponent("activity")),
            syncReminderNotifications: { _, _ in false })
        await activity.load(); await activity.flush()
        let value = value ?? plan()
        let result = await store.submit(.init(intent: .savePlan(value, collectionID: nil)))
        XCTAssertNotNil(result.receipt)
        return (store, activity, PlanPlaybackService(store: store, activity: activity), value.id)
    }
    func testPlaybackStopsAfterOneDayThenNextResumeStartsNextDay() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, activity, service, id) = try await fixture(root)
        let started = try await service.start(id, now: epoch); XCTAssertTrue(started)
        XCTAssertEqual(activity.draft?.title, "Gospel Plan - Day 1")
        XCTAssertEqual(activity.draft?.modeID, "reading")
        let first = try await service.advance(id, now: epoch.addingTimeInterval(10)); XCTAssertFalse(first)
        let day = try await service.advance(id, now: epoch.addingTimeInterval(30)); XCTAssertTrue(day)
        XCTAssertNil(activity.draft); XCTAssertEqual(activity.records.count, 1)
        XCTAssertEqual(activity.records[0].activeSeconds, 30)
        XCTAssertEqual(store.plans[0].completedSectionCount, 1)
        XCTAssertEqual(store.plans[0].cursor?.kind, .sectionSummary)
        XCTAssertTrue(store.plans[0].sections[1].items.allSatisfy { $0.completedAt == nil })
        try await service.finishSection(id, now: epoch.addingTimeInterval(40))
        XCTAssertEqual(activity.records.count, 1, "Completion retry must be idempotent")
        let nextDay = try await service.start(id, now: epoch.addingTimeInterval(100)); XCTAssertTrue(nextDay)
        XCTAssertEqual(activity.draft?.title, "Gospel Plan - Day 2")
        _ = try await service.advance(id, now: epoch.addingTimeInterval(120))
        _ = try await service.advance(id, now: epoch.addingTimeInterval(150))
        XCTAssertEqual(activity.records.count, 2); XCTAssertTrue(store.plans[0].isComplete)
        XCTAssertNil(store.plans[0].playbackStartCursor)
        XCTAssertEqual(store.plans[0].completionDate, epoch.addingTimeInterval(150))
        let reopened = ActivityStore(repository: ActivityFileRepository(directory: root.appendingPathComponent("activity")), syncReminderNotifications: { _, _ in false })
        await reopened.load()
        XCTAssertEqual(Set(reopened.records.map(\.title)), ["Gospel Plan - Day 1", "Gospel Plan - Day 2"])
        XCTAssertTrue(reopened.records.allSatisfy { $0.planID == id })
    }
    func testPauseReopenAndRepeatedResumeKeepOneTimerAndExcludePausedTime() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (_, activity, service, id) = try await fixture(root)
        _ = try await service.start(id, now: epoch)
        let sessionID = activity.draft?.id
        let paused = await service.pause(id, now: epoch.addingTimeInterval(20)); XCTAssertTrue(paused)
        let store = CollectionsStore(repository: CollectionsFileRepository(directory: root.appendingPathComponent("collections"))); await store.load()
        let reopened = ActivityStore(repository: ActivityFileRepository(directory: root.appendingPathComponent("activity")), syncReminderNotifications: { _, _ in false }); await reopened.load()
        let resumed = PlanPlaybackService(store: store, activity: reopened)
        _ = try await resumed.start(id, now: epoch.addingTimeInterval(100))
        _ = try await resumed.start(id, now: epoch.addingTimeInterval(110))
        XCTAssertEqual(reopened.draft?.id, sessionID)
        _ = try await resumed.advance(id, now: epoch.addingTimeInterval(120))
        _ = try await resumed.advance(id, now: epoch.addingTimeInterval(140))
        XCTAssertEqual(reopened.records.first?.activeSeconds, 60)
    }
    func testUnrelatedTimerBlocksPlaybackWithoutChangingProgress() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, activity, service, id) = try await fixture(root)
        activity.start(mode: .init(id: "studying", name: "Studying"), title: "Other", now: epoch)
        let before = store.plans[0]
        do { _ = try await service.start(id, now: epoch); XCTFail("Existing timer must be kept") } catch {}
        XCTAssertEqual(store.plans[0], before); XCTAssertEqual(activity.draft?.title, "Other")
    }
    func testStoppingHalfwayKeepsCheckedAssignmentsWithoutHistoryAndResumesSameDay() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, activity, service, id) = try await fixture(root)
        _ = try await service.start(id, now: epoch)
        _ = try await service.advance(id, now: epoch.addingTimeInterval(10))
        let session = activity.draft?.id
        activity.finish(title: "Gospel Plan - Day 1", description: "", now: epoch.addingTimeInterval(60)); await activity.flush()
        XCTAssertTrue(activity.records.isEmpty); XCTAssertNil(activity.draft?.runningSince)
        XCTAssertEqual(store.plans[0].completedCount, 1)
        let reconciled = try await service.reconcileFinishedActivity(id); XCTAssertFalse(reconciled)
        let reopenedStore = CollectionsStore(repository: CollectionsFileRepository(directory: root.appendingPathComponent("collections"))); await reopenedStore.load()
        let reopenedActivity = ActivityStore(repository: ActivityFileRepository(directory: root.appendingPathComponent("activity")), syncReminderNotifications: { _, _ in false }); await reopenedActivity.load()
        XCTAssertEqual(reopenedStore.plans[0].completedCount, 1); XCTAssertTrue(reopenedActivity.records.isEmpty)
        let resumed = PlanPlaybackService(store: reopenedStore, activity: reopenedActivity)
        _ = try await resumed.start(id, now: epoch.addingTimeInterval(100))
        XCTAssertEqual(reopenedActivity.draft?.id, session)
        let completed = try await resumed.advance(id, now: epoch.addingTimeInterval(120)); XCTAssertTrue(completed)
        XCTAssertEqual(reopenedActivity.records.count, 1)
        XCTAssertEqual(reopenedActivity.records[0].activeSeconds, 80)
        XCTAssertEqual(reopenedStore.plans[0].completedSectionCount, 1)
    }
    func testHistoryWriteFailureRetainsTimerAndSummaryForRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, activity, service, id) = try await fixture(root)
        _ = try await service.start(id, now: epoch)
        _ = try await service.advance(id, now: epoch.addingTimeInterval(10))
        let directory = root.appendingPathComponent("activity")
        // Replace only this disposable test repository with an unwritable parent.
        try FileManager.default.moveItem(at: directory, to: root.appendingPathComponent("kept-activity"))
        try Data("blocked".utf8).write(to: directory)
        do { _ = try await service.advance(id, now: epoch.addingTimeInterval(30)); XCTFail("Write must fail") } catch {}
        XCTAssertNotNil(activity.draft); XCTAssertTrue(activity.records.isEmpty)
        XCTAssertEqual(store.plans[0].cursor?.kind, .sectionSummary)
        try FileManager.default.removeItem(at: directory)
        try FileManager.default.moveItem(at: root.appendingPathComponent("kept-activity"), to: directory)
        try await service.finishSection(id, now: epoch.addingTimeInterval(40))
        try await service.finishSection(id, now: epoch.addingTimeInterval(50))
        XCTAssertNil(activity.draft); XCTAssertEqual(activity.records.count, 1)
    }
    func testIncompleteDayCannotBeRecordedThroughPlanFinishCommand() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, activity, service, id) = try await fixture(root)
        _ = try await service.start(id, now: epoch)
        do { try await service.finishSection(id, now: epoch.addingTimeInterval(60)); XCTFail("Unfinished assignments must not be auto-checked") } catch {}
        XCTAssertEqual(store.plans[0].completedCount, 0); XCTAssertTrue(activity.records.isEmpty)
        XCTAssertNotNil(activity.draft)
    }
    func testPendingSummaryReopensForCompletionBeforeStartingAnotherDay() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, activity, service, id) = try await fixture(root)
        _ = try await service.start(id, now: epoch)
        var pending = store.plans[0]
        let firstID = pending.sections[0].id
        for i in pending.sections[0].items.indices { pending.sections[0].items[i].completedAt = epoch.addingTimeInterval(30) }
        pending.cursor = .init(kind: .sectionSummary, sectionID: firstID, activitySessionID: activity.draft?.id)
        _ = await store.submit(.init(expectedPlanRevision: pending.revision, intent: .savePlan(pending, collectionID: nil)))
        let started = try await service.start(id, now: epoch.addingTimeInterval(40)); XCTAssertFalse(started)
        XCTAssertNil(activity.draft); XCTAssertEqual(activity.records.count, 1)
        XCTAssertEqual(store.plans[0].cursor?.sectionID, firstID)
        XCTAssertEqual(store.plans[0].completedSectionCount, 1)
    }
    func testStrictDatesAnchorOnceAndSelectedActivityTypePersists() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var value = plan(); value.strictSchedule = .init(timeZoneID: "Asia/Manila"); value.activityModeID = "studying"
        let (store, activity, service, id) = try await fixture(root, value: value)
        _ = try await service.start(id, now: epoch)
        XCTAssertEqual(store.plans[0].strictSchedule?.startDate, epoch)
        XCTAssertEqual(activity.draft?.modeID, "studying")
        _ = await service.pause(id, now: epoch.addingTimeInterval(10))
        _ = try await service.start(id, now: epoch.addingTimeInterval(86_400))
        XCTAssertEqual(store.plans[0].strictSchedule?.startDate, epoch)
        let reopened = CollectionsStore(repository: CollectionsFileRepository(directory: root.appendingPathComponent("collections"))); await reopened.load()
        XCTAssertEqual(reopened.plans[0].strictSchedule, store.plans[0].strictSchedule)
        XCTAssertEqual(reopened.plans[0].activityModeID, "studying")
    }
    func testSevenDayScheduleCalendarRolloverOverridesAndStrictOff() throws {
        var value = plan(); value.sections = (0..<7).map { _ in PlanSection() }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Manila")!
        let jan1 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        value.strictSchedule = .init(startDate: jan1, timeZoneID: "Asia/Manila")
        XCTAssertEqual(value.strictSchedule?.label(value.dueDate(for: 0)!), "Jan. 1, 2026")
        XCTAssertEqual(value.strictSchedule?.label(value.dueDate(for: 6)!), "Jan. 7, 2026")
        value.sections[6].dueDate = calendar.date(byAdding: .day, value: 9, to: jan1)
        XCTAssertEqual(value.dueDate, value.sections[6].dueDate)
        value.strictSchedule = nil
        XCTAssertEqual(value.sectionTitle(0), "Day 1"); XCTAssertNil(value.dueDate)
        let dst = PlanSchedule(startDate: Date(timeIntervalSince1970: 1_773_000_000), timeZoneID: "America/New_York")
        XCTAssertEqual(dst.calendar.dateComponents([.day], from: dst.date(for: 0)!, to: dst.date(for: 3)!).day, 3)
    }
    func testLegacyPlanAndActivityPayloadsDecodeWithNewFieldsAbsent() throws {
        var value = plan(); value.cursor = value.playbackStartCursor
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
        json.removeValue(forKey: "activityModeID"); json.removeValue(forKey: "strictSchedule")
        let decoded = try JSONDecoder().decode(StudyPlan.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.strictSchedule); XCTAssertEqual(decoded.resolvedActivityModeID, "reading")
        XCTAssertNil(decoded.cursor?.activitySessionID); XCTAssertNil(decoded.sections.first?.dueDate)
        var snapshot = ActivitySnapshot()
        snapshot.draft = ActivityDraft(id: UUID(), title: "Legacy", modeID: "reading", modeLabel: "Reading", startedAt: epoch, intervals: [], description: "")
        let roundtrip = try JSONDecoder().decode(ActivitySnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertNil(roundtrip.draft?.planID); XCTAssertNil(roundtrip.draft?.planSectionID)
        XCTAssertEqual(try JSONDecoder().decode(StudyPlan.self, from: JSONEncoder().encode(decoded)), decoded)
    }
}


extension PlanPlaybackTests {
    func testCatchUpRebasesAllUnfinishedDaysAndKeepsCompletedDatesAndChecks() throws {
        var value = plan()
        let schedule = PlanSchedule(startDate: epoch, timeZoneID: "Asia/Manila")
        value.strictSchedule = schedule
        value.sections += [value.sections[0], value.sections[1]]
        for i in value.sections.indices {
            value.sections[i].id = UUID()
            for j in value.sections[i].items.indices { value.sections[i].items[j].id = UUID() }
        }
        // Day 1 and Day 3 are done, with a partially checked Day 2 between them.
        for s in [0, 2] { for i in value.sections[s].items.indices { value.sections[s].items[i].completedAt = epoch } }
        value.sections[1].items[0].completedAt = epoch
        let checks = value.sections.map { $0.items.map(\.completedAt) }
        let completedDue = [value.dueDate(for: 0), value.dueDate(for: 2)]
        let today = schedule.calendar.date(byAdding: .day, value: 10, to: epoch)!
        XCTAssertTrue(value.canCatchUp(now: today)); XCTAssertTrue(value.catchUp(now: today))
        XCTAssertEqual(value.dueDate(for: 1), schedule.calendar.startOfDay(for: today))
        XCTAssertEqual(value.dueDate(for: 3), schedule.calendar.date(byAdding: .day, value: 1, to: schedule.calendar.startOfDay(for: today)))
        XCTAssertEqual([value.dueDate(for: 0), value.dueDate(for: 2)], completedDue)
        XCTAssertEqual(value.sections.map { $0.items.map(\.completedAt) }, checks)
        XCTAssertFalse(value.canCatchUp(now: today)); XCTAssertFalse(value.catchUp(now: today))
        XCTAssertNoThrow(try value.validate())
        XCTAssertTrue(value.scheduleCaption(for: 1)?.contains("Not completed") == true)
        XCTAssertEqual(try JSONDecoder().decode(StudyPlan.self, from: JSONEncoder().encode(value)), value)
    }
    func testCatchUpIsOptionalUnavailableWithoutOverdueDatesAndUsesScheduleTimeZone() {
        var value = plan(); let original = value
        XCTAssertFalse(value.catchUp(now: epoch)); XCTAssertEqual(value, original)
        value.strictSchedule = .init(startDate: epoch, timeZoneID: "Asia/Manila")
        XCTAssertFalse(value.canCatchUp(now: epoch))
        XCTAssertFalse(value.canCatchUp(now: epoch.addingTimeInterval(-86_400)))
        let today = epoch.addingTimeInterval(86_400)
        XCTAssertTrue(value.canCatchUp(now: today))
        let before = value
        XCTAssertEqual(value, before, "Checking availability must not reschedule anything")
        for s in value.sections.indices { for i in value.sections[s].items.indices { value.sections[s].items[i].completedAt = epoch } }
        XCTAssertFalse(value.canCatchUp(now: today))
        XCTAssertNotNil(value.scheduleCaption()); XCTAssertNotNil(value.completionDate)
    }
}


extension PlanPlaybackTests {
    func testExplicitDayStartsThatDayAndRecordsOnlyItsCompletion() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, activity, service, id) = try await fixture(root)
        let sectionID = store.plans[0].sections[1].id
        let started = try await service.start(id, sectionID: sectionID, now: epoch); XCTAssertTrue(started)
        XCTAssertEqual(store.plans[0].cursor?.sectionID, sectionID)
        XCTAssertEqual(store.plans[0].items.first(where: { $0.id == store.plans[0].cursor?.itemID })?.payload.chapter, 2)
        XCTAssertEqual(activity.draft?.title, "Gospel Plan - Day 2")
        _ = try await service.advance(id, now: epoch.addingTimeInterval(10))
        XCTAssertTrue(activity.records.isEmpty)
        _ = try await service.advance(id, now: epoch.addingTimeInterval(30))
        XCTAssertEqual(activity.records.map(\.title), ["Gospel Plan - Day 2"])
        XCTAssertTrue(store.plans[0].sections[0].items.allSatisfy { $0.completedAt == nil })
    }
    func testDaySwitchRetainsPausedTimeChecksAndSessionsAcrossReopen() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, activity, service, id) = try await fixture(root)
        let first = store.plans[0].sections[0].id, second = store.plans[0].sections[1].id
        _ = try await service.start(id, sectionID: first, now: epoch)
        let firstSession = activity.draft?.id
        _ = try await service.advance(id, now: epoch.addingTimeInterval(10))
        _ = await service.pause(id, now: epoch.addingTimeInterval(20))
        _ = try await service.start(id, sectionID: second, now: epoch.addingTimeInterval(100))
        let secondSession = activity.draft?.id
        _ = await service.pause(id, now: epoch.addingTimeInterval(130))
        XCTAssertTrue(activity.records.isEmpty); XCTAssertEqual(store.plans[0].completedCount, 1)
        let reopenedStore = CollectionsStore(repository: CollectionsFileRepository(directory: root.appendingPathComponent("collections"))); await reopenedStore.load()
        let reopened = ActivityStore(repository: ActivityFileRepository(directory: root.appendingPathComponent("activity")), syncReminderNotifications: { _, _ in false }); await reopened.load()
        let resumed = PlanPlaybackService(store: reopenedStore, activity: reopened)
        _ = try await resumed.start(id, sectionID: first, now: epoch.addingTimeInterval(200))
        XCTAssertEqual(reopened.draft?.id, firstSession)
        _ = try await resumed.advance(id, now: epoch.addingTimeInterval(220))
        XCTAssertEqual(reopened.records[0].activeSeconds, 40)
        _ = try await resumed.start(id, sectionID: second, now: epoch.addingTimeInterval(300))
        XCTAssertEqual(reopened.draft?.id, secondSession)
        _ = try await resumed.advance(id, now: epoch.addingTimeInterval(310))
        _ = try await resumed.advance(id, now: epoch.addingTimeInterval(320))
        XCTAssertEqual(reopened.records.first(where: { $0.id == secondSession })?.activeSeconds, 50)
        XCTAssertEqual(reopened.records.count, 2)
        let snapshot = try await ActivityFileRepository(directory: root.appendingPathComponent("activity")).load()
        XCTAssertTrue(snapshot.pausedPlanDrafts?.isEmpty == true)
    }
    func testCompletedDayCanReplayWithoutResettingItsChecksOrDates() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (store, activity, service, id) = try await fixture(root)
        let day = store.plans[0].sections[0].id
        _ = try await service.start(id, sectionID: day, now: epoch)
        _ = try await service.advance(id, now: epoch.addingTimeInterval(10))
        _ = try await service.advance(id, now: epoch.addingTimeInterval(20))
        let dates = store.plans[0].sections[0].items.map(\.completedAt)
        _ = try await service.start(id, sectionID: day, now: epoch.addingTimeInterval(100))
        let replaySession = activity.draft?.id
        _ = await service.pause(id, now: epoch.addingTimeInterval(110))
        _ = try await service.start(id, now: epoch.addingTimeInterval(200))
        XCTAssertEqual(activity.draft?.id, replaySession)
        _ = try await service.advance(id, now: epoch.addingTimeInterval(210))
        _ = try await service.advance(id, now: epoch.addingTimeInterval(220))
        XCTAssertEqual(activity.records.count, 2)
        XCTAssertEqual(store.plans[0].sections[0].items.map(\.completedAt), dates)
        XCTAssertEqual(store.plans[0].completedSectionCount, 1)
    }
    func testInvalidOrEmptyDayRejectsWithoutMutatingProgressOrTimer() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var value = plan(); value.sections.append(.init())
        let (store, activity, service, id) = try await fixture(root, value: value)
        let before = store.plans[0]
        for day in [UUID(), before.sections.last!.id] {
            do { _ = try await service.start(id, sectionID: day, now: epoch); XCTFail("Invalid/empty day must reject") } catch {}
        }
        XCTAssertEqual(store.plans[0], before); XCTAssertNil(activity.draft)
    }
    func testPausedDayArchiveCompatibilityAndValidation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ActivityFileRepository(directory: root)
        let legacy = try JSONDecoder().decode(ActivitySnapshot.self, from: JSONEncoder().encode(ActivitySnapshot()))
        XCTAssertNil(legacy.pausedPlanDrafts)
        var value = legacy
        let paused = ActivityDraft(id: UUID(), title: "Plan - Day 1", modeID: "reading", modeLabel: "Reading",
            startedAt: epoch, intervals: [.init(start: epoch, end: epoch.addingTimeInterval(30))], description: "",
            planID: UUID(), planSectionID: UUID())
        value.pausedPlanDrafts = [paused]; try await repository.save(value)
        let archive = try await repository.exportArchive()
        let restored = try await repository.inspectArchive(archive)
        XCTAssertEqual(restored.pausedPlanDrafts, [paused])
        value.pausedPlanDrafts = [paused, paused]
        do { try await repository.save(value); XCTFail("Duplicate paused session must reject") } catch {}
        let retained = try await repository.load(); XCTAssertEqual(retained.pausedPlanDrafts, [paused])
        let store = ActivityStore(repository: repository, syncReminderNotifications: { _, _ in false }); await store.load()
        store.removeAllActivityRecords(); await store.flush()
        XCTAssertNil(store.snapshot.pausedPlanDrafts)
    }
}
