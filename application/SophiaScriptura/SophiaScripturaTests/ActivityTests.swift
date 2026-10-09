import XCTest
import CryptoKit
import UserNotifications
import SwiftUI
@testable import SophiaScriptura

@MainActor final class ActivityTests: XCTestCase {
    func testPauseExcludesElapsedTimeAndSurvivesReload() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ActivityFileRepository(directory: directory)
        let store = ActivityStore(repository: repository)
        await store.load()
        let start = Date(timeIntervalSince1970: 1000)
        store.start(mode: ActivityMode(id: "studying", name: "Studying", isBuiltIn: true), title: "Study", now: start)
        store.pause(now: start.addingTimeInterval(120))
        store.resume(now: start.addingTimeInterval(600))
        store.finish(title: "Study", description: "", now: start.addingTimeInterval(660))
        await store.flush()
        let reopened = ActivityStore(repository: repository)
        await reopened.load()
        XCTAssertEqual(reopened.records.first?.activeSeconds, 180)
        XCTAssertEqual(reopened.records.first?.intervals.count, 2)
    }

    func testQuizStudyingImportIsIdempotent() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActivityStore(repository: ActivityFileRepository(directory: directory))
        await store.load()
        let id = UUID()
        let link = ReviewingActivityLink(id: UUID(), quizSessionID: id, startedAt: Date(), endedAt: Date(), activeSeconds: 90, sourceDeleted: false)
        store.importQuizStudyLinks([link])
        store.importQuizStudyLinks([link])
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records.first?.quizSessionID, id)
        XCTAssertEqual(store.records.first?.activeSeconds, 90)
        XCTAssertEqual(store.records.first?.modeID, ActivityModeID.studying.id)
        await store.flush()
    }

    func testModeGoalsMigrateAndTotalPersists() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ActivityFileRepository(directory: directory)
        var legacy = ActivitySnapshot()
        legacy.dailyGoalMinutes = 12
        try await repository.save(legacy)
        let store = ActivityStore(repository: repository)
        await store.load()
        XCTAssertEqual(store.goalMinutes(for: ActivityModeID.reading.id), 12)
        XCTAssertEqual(store.goalMinutes(for: ActivityModeID.studying.id), 0)
        store.setModeGoal(20, for: ActivityModeID.studying.id)
        XCTAssertEqual(store.goalMinutes, 32)
        XCTAssertFalse(store.setModeGoals(Dictionary(uniqueKeysWithValues: store.modes.map { ($0.id, 0) })))
        XCTAssertEqual(store.goalMinutes, 32)
        await store.flush()
        let reopened = ActivityStore(repository: repository)
        await reopened.load()
        XCTAssertEqual(reopened.goalMinutes, 32)
        XCTAssertEqual(reopened.goalMinutes(for: ActivityModeID.studying.id), 20)
    }

    func testMidnightSplitsTimedMinutes() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3))!
        let interval = ActivityInterval(start: day.addingTimeInterval(-60), end: day.addingTimeInterval(60))
        let record = ActivityRecord(id: UUID(), title: "Study", modeID: "studying", modeLabel: "Studying",
            activityDate: interval.start, activeSeconds: 120, source: "timer", timeZoneID: "UTC", intervals: [interval],
            description: "", readingRange: nil, editionID: nil, quizSessionID: nil, createdAt: day, updatedAt: day)
        XCTAssertEqual(ActivityMetrics.seconds(on: day, records: [record], calendar: calendar), 60)
        XCTAssertEqual(ActivityMetrics.seconds(on: day.addingTimeInterval(-60), records: [record], calendar: calendar), 60)
    }

    func testManualOverlapIsRejectedAndArchiveRestores() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ActivityFileRepository(directory: directory)
        let store = ActivityStore(repository: repository)
        await store.load()
        let mode = ActivityMode(id: "studying", name: "Studying", isBuiltIn: true)
        let start = Date(timeIntervalSince1970: 1000)
        store.addManual(title: "First", mode: mode, startedAt: start, endedAt: start.addingTimeInterval(600), description: "")
        store.addManual(title: "Overlap", mode: mode, startedAt: start.addingTimeInterval(300),
            endedAt: start.addingTimeInterval(900), description: "")
        XCTAssertEqual(store.records.count, 1)
        XCTAssertNotNil(store.errorMessage)
        store.errorMessage = nil
        await store.flush()
        guard let archive = await store.exportArchive() else { XCTFail("Export failed"); return }
        store.delete(store.records[0].id)
        await store.flush()
        await store.restoreArchive(archive)
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records[0].title, "First")
    }

    func testManualDurationDerivesEndAndEditingOverwritesTimedRecord() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActivityStore(repository: ActivityFileRepository(directory: directory))
        await store.load()
        let mode = ActivityMode(id: "studying", name: "Studying", isBuiltIn: true)
        let start = Date(timeIntervalSince1970: 10_000)
        store.addManual(title: "Manual", mode: mode, startedAt: start, durationSeconds: 900, description: "")
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.records.first?.intervals.first?.end, start.addingTimeInterval(900))
        store.start(mode: mode, title: "Timed", now: start.addingTimeInterval(1_800))
        store.finish(title: "Timed", description: "", now: start.addingTimeInterval(2_100))
        let timed = try XCTUnwrap(store.records.first { $0.source == "timer" })
        let replacementStart = start.addingTimeInterval(2_400)
        store.addManual(title: "Corrected", mode: mode, startedAt: replacementStart,
            endedAt: replacementStart.addingTimeInterval(720), description: "Edited", replacing: timed.id)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.records.count, 2)
        let corrected = try XCTUnwrap(store.records.first { $0.id == timed.id })
        XCTAssertEqual(corrected.source, "timer")
        XCTAssertEqual(corrected.title, "Corrected")
        XCTAssertEqual(corrected.activityDate, replacementStart)
        XCTAssertEqual(corrected.activeSeconds, 720)
        XCTAssertEqual(corrected.intervals, [ActivityInterval(start: replacementStart,
            end: replacementStart.addingTimeInterval(720))])
        XCTAssertEqual(corrected.createdAt, timed.createdAt)
    }

    func testDamagedCurrentFallsBackWithoutOverwritingPrevious() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ActivityFileRepository(directory: directory)
        var first = ActivitySnapshot()
        first.dailyGoalMinutes = 12
        try await repository.save(first)
        var second = first
        second.dailyGoalMinutes = 20
        try await repository.save(second)
        try Data("bad".utf8).write(to: directory.appendingPathComponent("current.json"), options: .atomic)
        let recovered = try await repository.load()
        XCTAssertEqual(recovered.dailyGoalMinutes, 12)
        try await repository.save(recovered)
        let reloaded = try await repository.load()
        XCTAssertEqual(reloaded.dailyGoalMinutes, 12)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("damaged-") })
    }

    func testBestStreakIncludesSecondDayOfCrossMidnightTimer() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let secondDay = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3))!
        let interval = ActivityInterval(start: secondDay.addingTimeInterval(-600), end: secondDay.addingTimeInterval(600))
        let record = ActivityRecord(id: UUID(), title: "Reading", modeID: "reading", modeLabel: "Reading",
            activityDate: interval.start, activeSeconds: 1200, source: "timer", timeZoneID: "UTC", intervals: [interval],
            description: "", readingRange: nil, editionID: nil, quizSessionID: nil, createdAt: interval.start, updatedAt: interval.end)
        XCTAssertEqual(ActivityMetrics.bestStreak(records: [record], goalMinutes: 10, calendar: calendar), 2)
    }

    func testAnalyticsSplitsTimedMinutesAndFiltersModes() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 12))!
        let midnight = calendar.startOfDay(for: today)
        let readingInterval = ActivityInterval(start: midnight.addingTimeInterval(-60), end: midnight.addingTimeInterval(120))
        let reading = activityRecord(mode: "reading", date: readingInterval.start, seconds: 180, intervals: [readingInterval])
        let studying = activityRecord(mode: "studying", date: today, seconds: 300)
        let modes = [ActivityMode(id: "reading", name: "Reading"), ActivityMode(id: "studying", name: "Studying")]

        let all = ActivityAnalytics.buckets(period: .day, at: today, records: [reading, studying], modeID: nil, calendar: calendar)
        XCTAssertEqual(all.reduce(0) { $0 + $1.seconds }, 420)
        XCTAssertEqual(all.last?.label, "No time")
        XCTAssertEqual(all.last?.seconds, 300)
        let filtered = ActivityAnalytics.buckets(period: .day, at: today, records: [reading, studying], modeID: "reading", calendar: calendar)
        XCTAssertEqual(filtered.reduce(0) { $0 + $1.seconds }, 120)
        let distribution = ActivityAnalytics.modeTotals(period: .day, at: today, records: [reading, studying], modes: modes,
                                                        filterID: "reading", calendar: calendar)
        XCTAssertEqual(distribution.count, 1)
        XCTAssertEqual(distribution.first?.seconds, 120)
    }

    func testHistoryUsesRelativeGroupsInDescendingOrder() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 12))!
        let dates = [0, -1, -3, -8, -40, -400].map { calendar.date(byAdding: .day, value: $0, to: now)! }
        let records = dates.map { activityRecord(mode: "reading", date: $0, seconds: 60) }
        let groups = ActivityHistoryGrouping.groups(records, now: now, calendar: calendar)
        XCTAssertEqual(groups.map(\.title), ["Today", "Yesterday", "This Week", "This Month", "This Year", "2025"])
        XCTAssertEqual(groups.flatMap(\.records).map(\.id), records.map(\.id))
    }

    func testDeletedQuizReviewIsNotImportedAgain() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ActivityFileRepository(directory: directory)
        let store = ActivityStore(repository: repository)
        await store.load()
        let quizID = UUID()
        let link = ReviewingActivityLink(id: UUID(), quizSessionID: quizID, startedAt: Date().addingTimeInterval(-90),
                                         endedAt: Date(), activeSeconds: 90, sourceDeleted: false)
        store.importQuizStudyLinks([link])
        XCTAssertEqual(store.records.count, 1)
        store.delete(store.records[0].id)
        await store.flush()
        let reopened = ActivityStore(repository: repository)
        await reopened.load()
        reopened.importQuizStudyLinks([link])
        XCTAssertTrue(reopened.records.isEmpty)
    }

    func testReminderNotificationRecurrenceAndOneTimePruning() async throws {
        let date = Calendar.current.date(from: DateComponents(year: 2030, month: 5, day: 8, hour: 9, minute: 30))!
        let reminder = ActivityReminder(id: UUID(), title: "Read", description: "Morning reading", date: date,
                                        modeID: "reading", modeLabel: "Reading", repeatRule: .weekdays)
        let requests = ActivityReminderNotifications.requests(for: reminder)
        XCTAssertEqual(requests.count, 5)
        XCTAssertTrue(requests.allSatisfy { ($0.trigger as? UNCalendarNotificationTrigger)?.repeats == true })
        XCTAssertEqual(Set(requests.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.weekday }),
                       Set([2, 3, 4, 5, 6]))

        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Activity-reminder-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ActivityFileRepository(directory: directory)
        var snapshot = ActivitySnapshot()
        var past = reminder
        past.id = UUID()
        past.repeatRule = .once
        past.date = Date().addingTimeInterval(-3600)
        past.deleteAfterFiring = true
        var retained = past
        retained.id = UUID()
        retained.deleteAfterFiring = false
        snapshot.reminders = [past, retained, reminder]
        do { try await repository.save(snapshot) }
        catch { XCTFail("Initial reminder fixture save failed: \(error)"); return }
        let store = ActivityStore(repository: repository)
        await store.load()
        XCTAssertEqual(Set(store.reminders.map(\.id)), Set([retained.id, reminder.id]))
        await store.flush()
    }

    func testLegacyReminderCleanupPreferenceMigratesPerRecord() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ActivityFileRepository(directory: directory)
        let future = Date().addingTimeInterval(3600)
        let reminder = ActivityReminder(id: UUID(), title: "Read", description: "", date: future,
                                        modeID: "reading", modeLabel: "Reading", repeatRule: .once)
        var snapshot = ActivitySnapshot()
        snapshot.reminders = [reminder]
        snapshot.autoDeleteOneTimeReminders = true
        try await repository.save(snapshot)
        let store = ActivityStore(repository: repository)
        await store.load()
        XCTAssertEqual(store.reminders.first?.deleteAfterFiring, true)
        await store.flush()
        let reopened = ActivityStore(repository: repository)
        await reopened.load()
        XCTAssertEqual(reopened.reminders.first?.deleteAfterFiring, true)
    }

    func testReminderGroupingSeparatesRecurringAndDates() {
        let now = Date()
        let today = ActivityReminder(id: UUID(), title: "Today", description: "", date: now,
                                     modeID: "reading", modeLabel: "Reading", repeatRule: .once)
        var recurring = today
        recurring.id = UUID()
        recurring.repeatRule = .daily
        let groups = ActivityReminderGrouping.groups([today, recurring], now: now)
        XCTAssertEqual(groups.map(\.title), ["Recurring", "Today"])
    }

    func testAnalyticsPNGRenderIncludesFullDailyTimeAxis() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ActivityStore(repository: ActivityFileRepository(directory: directory))
        await store.load()
        store.addManual(title: "Study", mode: ActivityMode(id: "studying", name: "Studying"),
                        startedAt: Date(), durationSeconds: 900, description: "")
        let view = ActivityAnalyticsView(store: store, period: .constant(.day),
            anchor: .constant(Date()), modeID: .constant("all"), exporting: true)
            .environment(\.appTheme, AppTheme())
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage)
        XCTAssertGreaterThan(image.size.width, 1450)
        XCTAssertGreaterThan(image.size.height, 300)
        XCTAssertNotNil(image.pngData())
        let attachment = XCTAttachment(image: image)
        attachment.name = "Full daily analytics PNG"
        attachment.lifetime = .keepAlways
        add(attachment)
        await store.flush()
    }

    func testMeditationPassageRulesCapAtTwoVerses() {
        let available = [1, 2, 3, 4, 5]
        XCTAssertEqual(MeditationPassageRules.clampedEndVerse(start: 3, proposedEnd: 5, available: available), 4)
        XCTAssertEqual(MeditationPassageRules.clampedEndVerse(start: 3, proposedEnd: 2, available: available), 3)
        let range = MeditationPassageRules.range(book: "JHN", chapter: 3, startVerse: 16, endVerse: 20, referenceSystemID: "org.sophia.web.engwebp")
        XCTAssertEqual(range.end.verse, 20)
        XCTAssertEqual(MeditationPassageRules.verseCount(in: range), 5)
        let pair = MeditationPassageRules.range(book: "JHN", chapter: 3, startVerse: 16, endVerse: 17, referenceSystemID: "org.sophia.web.engwebp")
        XCTAssertEqual(MeditationPassageRules.verseCount(in: pair), 2)
    }

    func testMeditationJourneyPageCounts() {
        let launch = MeditationJourneyLaunch(referenceSystemID: "org.sophia.web.engwebp", editionID: nil, chosenRange: nil)
        XCTAssertEqual(MeditationJourneyBuilder.ranges(for: launch).count, 7)
        let custom = MeditationJourneyLaunch(
            referenceSystemID: "org.sophia.web.engwebp",
            editionID: nil,
            chosenRange: MeditationPassageRules.range(book: "PSA", chapter: 23, startVerse: 1, endVerse: 1, referenceSystemID: "org.sophia.web.engwebp")
        )
        XCTAssertEqual(MeditationJourneyBuilder.ranges(for: custom).count, 1)
        let range = custom.chosenRange!
        let pages = MeditationJourneyBuilder.pages(
            launch: custom,
            books: [ScriptureBook(id: "PSA", title: "Psalms", testament: "OT", order: 19, chapterCount: 150)],
            resolved: [(range, [MeditationScriptureLine(verseNumber: nil, text: "The LORD is my shepherd")])]
        )
        XCTAssertEqual(ActivityPassageLabel.text(range, books: [ScriptureBook(id: "PSA", title: "Psalms", testament: "OT", order: 19, chapterCount: 150)]), "Psalms 23:1")
        let pairRange = MeditationPassageRules.range(book: "PSA", chapter: 46, startVerse: 10, endVerse: 11, referenceSystemID: "org.sophia.web.engwebp")
        XCTAssertEqual(ActivityPassageLabel.text(pairRange, books: [ScriptureBook(id: "PSA", title: "Psalms", testament: "OT", order: 19, chapterCount: 150)]), "Psalms 46:10-11.")
        XCTAssertEqual(pages.count, 4)
        XCTAssertEqual(pages[0].kind, .intro)
        XCTAssertEqual(pages[2].kind, .closing)
        XCTAssertEqual(pages[3].kind, .exit)
    }

    private func activityRecord(mode: String, date: Date, seconds: TimeInterval,
                                intervals: [ActivityInterval] = []) -> ActivityRecord {
        ActivityRecord(id: UUID(), title: mode, modeID: mode, modeLabel: mode.capitalized,
            activityDate: date, activeSeconds: seconds, source: intervals.isEmpty ? "manual" : "timer",
            timeZoneID: "UTC", intervals: intervals, description: "", readingRange: nil,
            editionID: nil, quizSessionID: nil, createdAt: date, updatedAt: date)
    }
    func testOptionalWorkflowsPersistAndAllowUnconstrainedTimers() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ActivityFileRepository(directory: directory)
        let store = ActivityStore(repository: repository); await store.load()
        XCTAssertTrue(store.automaticReadingWorkflow); XCTAssertTrue(store.automaticContemplationWorkflow)
        store.setAutomaticWorkflow(false, for: ActivityModeID.reading.id)
        XCTAssertFalse(store.launchesWorkflow(for: ActivityModeID.reading.id))
        XCTAssertTrue(store.launchesWorkflow(for: ActivityModeID.meditating.id))
        store.setAutomaticWorkflow(false, for: ActivityModeID.meditating.id)
        let start = Date(timeIntervalSince1970: 1000)
        store.start(mode: try XCTUnwrap(store.modeIncludingArchived("reading")), title: "Free reading", now: start)
        XCTAssertEqual(store.draft?.guidedWorkflow, false)
        store.finish(title: "Free reading", description: "", now: start.addingTimeInterval(90))
        XCTAssertNil(store.errorMessage); XCTAssertNil(store.records.first?.readingRange)
        store.start(mode: try XCTUnwrap(store.modeIncludingArchived("meditating")), title: "Free contemplation", now: start.addingTimeInterval(100))
        XCTAssertEqual(store.draft?.guidedWorkflow, false)
        store.setAutomaticWorkflow(true, for: "meditating")
        XCTAssertEqual(store.draft?.guidedWorkflow, false, "Changing settings must not relaunch an active timer's workflow")
        store.finish(title: "Free contemplation", description: "", now: start.addingTimeInterval(200))
        await store.flush()
        let reopened = ActivityStore(repository: repository); await reopened.load()
        XCTAssertFalse(reopened.automaticReadingWorkflow); XCTAssertTrue(reopened.automaticContemplationWorkflow)
        XCTAssertEqual(reopened.records.count, 2)
        XCTAssertFalse(reopened.modes.contains { $0.id == "reviewing" })
        XCTAssertEqual(reopened.modeIncludingArchived("meditating")?.name, "Contemplating")
    }

    func testLegacyReviewingAndMeditatingArchiveMigratesWithoutLosingTimeOrLinks() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ActivityFileRepository(directory: directory)
        let quizID = UUID(); let recordID = UUID(); let now = Date(timeIntervalSince1970: 1000)
        var legacy = ActivitySnapshot()
        legacy.dailyGoalMinutes = 30; legacy.dailyGoalMinutesByMode = ["reading": 10, "studying": 5, "reviewing": 15]
        legacy.records = [ActivityRecord(id: recordID, title: "Quiz Me", modeID: "reviewing", modeLabel: "Reviewing",
            activityDate: now, activeSeconds: 120, source: "quiz", timeZoneID: "UTC", intervals: [],
            description: "Preserved", readingRange: nil, editionID: nil, quizSessionID: quizID, createdAt: now, updatedAt: now)]
        legacy.draft = ActivityDraft(id: UUID(), title: "Existing timer", modeID: "reviewing", modeLabel: "Reviewing",
            startedAt: now, runningSince: nil, intervals: [ActivityInterval(start: now, end: now.addingTimeInterval(60))],
            description: "Draft", readingStart: nil, editionID: nil)
        legacy.reminders = [ActivityReminder(id: UUID(), title: "Remember", description: "", date: now.addingTimeInterval(600),
            modeID: "meditating", modeLabel: "Meditating", repeatRule: .daily)]
        // Encode an actual pre-change envelope, bypassing the repository's normalized writer.
        struct Envelope: Codable { var schemaVersion = 1; let payload: Data; let checksum: String }
        let payload = try JSONEncoder().encode(legacy)
        let checksum = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        let archive = try JSONEncoder().encode(Envelope(payload: payload, checksum: checksum))
        let migrated = try await repository.restoreArchive(archive)
        XCTAssertEqual(migrated.records.first?.id, recordID); XCTAssertEqual(migrated.records.first?.quizSessionID, quizID)
        XCTAssertEqual(migrated.records.first?.activeSeconds, 120); XCTAssertEqual(migrated.records.first?.description, "Preserved")
        XCTAssertEqual(migrated.records.first?.modeID, "studying"); XCTAssertEqual(migrated.records.first?.modeLabel, "Studying")
        XCTAssertEqual(migrated.draft?.modeID, "studying"); XCTAssertEqual(migrated.draft?.activeSeconds(at: now), 60)
        XCTAssertEqual(migrated.reminders?.first?.modeID, "meditating")
        XCTAssertEqual(migrated.reminders?.first?.modeLabel, "Contemplating")
        XCTAssertNil(migrated.dailyGoalMinutesByMode?["reviewing"]); XCTAssertEqual(migrated.dailyGoalMinutesByMode?["studying"], 20)
        XCTAssertEqual(migrated.dailyGoalMinutes, 30)
        let loaded = try await repository.load(); XCTAssertEqual(loaded.dailyGoalMinutesByMode?["studying"], 20)
        XCTAssertNil(loaded.automaticReadingWorkflow); XCTAssertNil(loaded.automaticContemplationWorkflow)
        let store = ActivityStore(repository: repository); await store.load()
        store.importQuizStudyLinks([ReviewingActivityLink(id: UUID(), quizSessionID: quizID, startedAt: now,
            endedAt: now.addingTimeInterval(120), activeSeconds: 120, sourceDeleted: false)])
        XCTAssertEqual(store.records.count, 1)
        await store.flush()
    }

}
