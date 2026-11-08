import PencilKit
import XCTest
@testable import SophiaScriptura

@MainActor final class PlanStudyExperienceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_767_225_600)
    private let web = ScriptureReferenceIdentity.bundledEditionID
    private let referenceSystem = ScriptureReferenceIdentity.bundledReferenceSystemID

    func testTravelerAppearanceDefaultsAndProjectsFromSavedPlan() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CollectionsFileRepository(directory: directory)
        let store = CollectionsStore(repository: repository)
        await store.load()
        let plan = StudyPlan(title: "Candlelight Reading", preferredEditionID: web, referenceSystemID: referenceSystem)
        let legacyData = try JSONEncoder().encode(plan)
        let legacy = try JSONDecoder().decode(StudyPlan.self, from: legacyData)
        XCTAssertNil(legacy.travelerCharacter)
        XCTAssertEqual(legacy.resolvedTravelerCharacter, .sophy)
        XCTAssertNil(legacy.travelerOutfitColor)
        XCTAssertNil(legacy.travelerBackdrop)
        XCTAssertNil(legacy.travelerEquipment)
        let created = await store.submit(.init(intent: .savePlan(plan, collectionID: nil)))
        XCTAssertNotNil(created.receipt)
        let defaultCard = try XCTUnwrap(store.presentedArtifacts(notes: []).first { $0.id == plan.id })
        XCTAssertEqual(defaultCard.planTravelerCharacter, .sophy)
        XCTAssertEqual(defaultCard.planTravelerBackdrop, .cloudy)
        XCTAssertEqual(defaultCard.planTravelerEquipment, .candle)

        var edited = try XCTUnwrap(store.plans.first { $0.id == plan.id })
        edited.travelerCharacter = .sabinus
        edited.travelerOutfitColor = .crimson
        edited.travelerBackdrop = .automatic
        edited.travelerEquipment = .armorOfGod
        let saved = await store.submit(.init(expectedPlanRevision: edited.revision,
            intent: .savePlan(edited, collectionID: nil)))
        XCTAssertNotNil(saved.receipt)

        let reopened = CollectionsStore(repository: repository)
        await reopened.load()
        var restored = try XCTUnwrap(reopened.plans.first { $0.id == plan.id })
        XCTAssertEqual(restored.travelerCharacter, .sabinus)
        XCTAssertEqual(restored.travelerOutfitColor, .crimson)
        let card = try XCTUnwrap(reopened.presentedArtifacts(notes: []).first { $0.id == plan.id })
        XCTAssertEqual(card.planTravelerCharacter, .sabinus)
        XCTAssertEqual(card.planTravelerOutfitColor, .crimson)
        XCTAssertEqual(card.planTravelerBackdrop.resolved(dark: false), .sunny)
        XCTAssertEqual(card.planTravelerBackdrop.resolved(dark: true), .moon)
        XCTAssertEqual(card.planTravelerEquipment, .armorOfGod)
        XCTAssertEqual(PlanTravelerBackdrop.mountains.resolved(dark: true), .mountains)

        restored.travelerOutfitColor = nil
        let reset = await reopened.submit(.init(expectedPlanRevision: restored.revision,
            intent: .savePlan(restored, collectionID: nil)))
        XCTAssertNotNil(reset.receipt)
        let decoded = try await repository.load()
        let resetPlan = try XCTUnwrap(decoded.snapshot.plans.first { $0.id == plan.id })
        XCTAssertNil(resetPlan.travelerOutfitColor)
        XCTAssertEqual(resetPlan.travelerCharacter, .sabinus)
    }

    func testTravelerWalkEasesForwardAndStopsAtTheNewPosition() throws {
        XCTAssertNil(PlanTravelerWalk(from: 0.5, to: 0.5, startedAt: now))
        XCTAssertNil(PlanTravelerWalk(from: 0.5, to: 0, startedAt: now))

        let walk = try XCTUnwrap(PlanTravelerWalk(from: 0.5, to: 2.0 / 3.0, startedAt: now))
        XCTAssertEqual(walk.fraction(after: -0.1), 0)
        XCTAssertEqual(walk.fraction(after: 0), 0)
        XCTAssertEqual(walk.fraction(after: walk.duration * 0.25), 0.15625)
        XCTAssertEqual(walk.fraction(after: walk.duration * 0.5), 0.5)
        XCTAssertEqual(walk.fraction(after: walk.duration * 0.75), 0.84375)
        XCTAssertEqual(walk.fraction(after: walk.duration), 1)
        XCTAssertEqual(walk.fraction(after: walk.duration + 1), 1)
    }

    func testTravelerProgressUsesFullyCompletedSections() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CollectionsStore(repository: CollectionsFileRepository(directory: directory))
        await store.load()

        let reading = PlanItemPayload.scripture(referenceSystemID: referenceSystem, book: "JHN", chapter: 1)
        for total in [2, 3] {
            var plan = StudyPlan(title: "Read in \(total) Days", preferredEditionID: web, referenceSystemID: referenceSystem,
                sections: (0..<total).map { _ in
                    PlanSection(items: [PlanItem(payload: reading), PlanItem(payload: reading)])
                })
            plan.sections[total - 1].items[0].completedAt = now
            let created = await store.submit(.init(intent: .savePlan(plan, collectionID: nil)))
            XCTAssertNotNil(created.receipt)
            let partial = try XCTUnwrap(store.presentedArtifacts(notes: []).first { $0.id == plan.id })
            XCTAssertTrue(partial.isPlanInProgress)
            XCTAssertEqual(partial.planProgress, 0)

            var edited = try XCTUnwrap(store.plans.first { $0.id == plan.id })
            for index in 0..<(total - 1) {
                for item in edited.sections[index].items.indices {
                    edited.sections[index].items[item].completedAt = now
                }
            }
            let saved = await store.submit(.init(expectedPlanRevision: edited.revision,
                intent: .savePlan(edited, collectionID: nil)))
            XCTAssertNotNil(saved.receipt)
            let card = try XCTUnwrap(store.presentedArtifacts(notes: []).first { $0.id == plan.id })
            XCTAssertTrue(card.isPlanInProgress)
            XCTAssertEqual(card.planProgress, Double(total - 1) / Double(total), accuracy: 0.000_001)
        }
    }

    func testSixtyDayPlanProjectsOnlyTodayAndTomorrowAndKeepsIdentity() throws {
        var plan = strictPlan()
        let first = reminders(plan)
        XCTAssertEqual(first.count, 2)
        XCTAssertEqual(first.compactMap(\.planOccurrence?.sectionID), Array(plan.sections.prefix(2).map(\.id)))
        XCTAssertTrue(first.allSatisfy { $0.repeatRule == .once && $0.deleteAfterFiring == true })
        XCTAssertEqual(reminders(plan, existing: first), first)

        plan.sections[0].items[0].completedAt = now
        XCTAssertEqual(reminders(plan, existing: first), [first[1]])
        let nextDay = now.addingTimeInterval(86_400)
        let next = reminders(plan, existing: first, now: nextDay)
        XCTAssertEqual(next.count, 2)
        XCTAssertEqual(next.first?.id, first[1].id)

        plan.strictSchedule = nil
        XCTAssertTrue(reminders(plan, existing: next).isEmpty)
    }

    func testReminderOverridesAndDismissalSurviveRefreshAndEncoding() throws {
        let plan = strictPlan()
        var existing = reminders(plan)
        let before = try XCTUnwrap(existing.first?.date)
        existing[0].planTimeOverride = 60
        existing[0].date = now.addingTimeInterval(3600)
        existing[1].planDismissed = true
        let refreshed = PlanReminderTime.rollingReminders(
            for: [plan], existing: existing, times: [plan.id: 600], now: now.addingTimeInterval(7200),
            isPrivate: { _ in true }
        )
        XCTAssertEqual(refreshed.map(\.id), existing.map(\.id))
        XCTAssertLessThan(try XCTUnwrap(refreshed.first?.date), before)
        XCTAssertEqual(refreshed[1].planDismissed, true)
        XCTAssertEqual(refreshed[1].title, "Study Plan reminder")
        let data = try JSONEncoder().encode(refreshed)
        XCTAssertEqual(try JSONDecoder().decode([ActivityReminder].self, from: data), refreshed)
    }

    func testActivityEditorPersistsFutureTimeAndDismissedOccurrence() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ActivityFileRepository(directory: directory)
        let store = ActivityStore(repository: repository, syncReminderNotifications: { _, _ in true })
        await store.load()
        var plan = strictPlan()
        let calendar = try XCTUnwrap(plan.strictSchedule?.calendar)
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())))
        plan.strictSchedule?.startDate = tomorrow
        store.refreshPlanReminders([plan], privatePlanIDs: [])
        let reminder = try XCTUnwrap(store.reminders.first)
        XCTAssertTrue(store.updatePlanReminder(reminder, minute: 13 * 60 + 20, useForFuture: true))
        XCTAssertEqual(store.snapshot.planReminderTimes?[plan.id], 800)
        store.deleteReminder(reminder.id)
        await store.flush()

        let reopened = ActivityStore(repository: repository, syncReminderNotifications: { _, _ in true })
        await reopened.load()
        reopened.refreshPlanReminders([plan], privatePlanIDs: [])
        XCTAssertTrue(reopened.reminders.isEmpty)
        XCTAssertEqual(reopened.snapshot.planReminderTimes?[plan.id], 800)
        await reopened.flush()
    }

    func testNoteContextIncludesTypedWordsAndOmitsInkAndLinkedQuotes() {
        var note = NoteDocument()
        var page = NotePage()
        page.body = "Typed prayer\u{FFFC}"; page.ink = Data("secret ink".utf8)
        note.content = .page(PageContent(page: page, legacyObjects: [
            NoteObject(kind: .text, text: "Typed reflection"),
            NoteObject(kind: .ink, text: "secret ink"),
            NoteObject(kind: .quote, text: "linked quote")
        ]))
        XCTAssertEqual(PlanQuestionContext.note(note).text, "Typed prayer\n\nTyped reflection")
    }

    func testScriptureContextUsesOnlyAssignedWording() async throws {
        let repository = BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self))
        let document = try await repository.chapter(book: "JHN", number: 3)
        let assignment = PlanItemPayload.scripture(referenceSystemID: referenceSystem, book: "JHN", chapter: 3, start: 16)
        let context = PlanQuestionContext.scripture(document, assignment: assignment, label: "John 3:16")
        let attached = try XCTUnwrap(context.text)
        XCTAssertTrue(attached.hasPrefix("For God so loved the world"))
        let adjacent = try XCTUnwrap(document.blocks.first { $0.kind == "body" && $0.verses.contains(17) })
        XCTAssertFalse(attached.contains(adjacent.text.trimmingCharacters(in: .whitespacesAndNewlines)))
        XCTAssertEqual(context.label, "John 3:16")
    }

    func testReferenceOnlyForLicensedEditionAndPlanContextOnlyOnRequest() async throws {
        let bible = BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self))
        let document = try await bible.chapter(book: "JHN", number: 3)
        let licensed = ChapterDocument(schemaVersion: document.schemaVersion, editionID: "api.bible.licensed",
            contentRevision: document.contentRevision, book: document.book, chapter: document.chapter, blocks: document.blocks)
        let assignment = PlanItemPayload.scripture(referenceSystemID: referenceSystem, book: "JHN", chapter: 3, start: 16)
        XCTAssertNil(PlanQuestionContext.scripture(licensed, assignment: assignment, label: "John 3:16").text)

        let preset = try XCTUnwrap(try PromptPresetCatalog.bundled().snapshot(for: "biblical-studies"))
        let conversation = CompanionConversation(providerConfigID: UUID(), providerAdapterID: "mock",
            modelID: "mock", presetSnapshot: preset, capabilitySnapshot: ProviderCapabilitySnapshot(
                adapterID: "mock", modelID: "mock", streaming: true, providerRetrieval: false,
                tools: false, usageReporting: false, cancellation: true
            ))
        let message = CompanionMessage(conversationID: conversation.id, sequence: 0, role: .user,
            content: "What does this mean?", deliveryState: .complete)
        let request = CompanionContextBuilder.completionRequest(conversation: conversation, messages: [message],
            attachments: [], pendingUserText: "", planContext: .init(label: "Study note", text: "Typed context", isScripture: false))
        XCTAssertTrue(request.turns.last?.content.contains("> Typed context") == true)
        XCTAssertTrue(request.turns.last?.content.hasSuffix(message.content) == true)
        XCTAssertNil(message.providerContent)
    }

    func testPlanInkReusesScopeAcrossReopenAndKeepsChapterDrawingsSeparate() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let bible = BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self))
        let first = try await bible.chapter(book: "JHN", number: 1)
        let second = try await bible.chapter(book: "JHN", number: 2)
        let annotations = AnnotationSession(repository: AnnotationFileRepository(directory: folder))
        let scope = PlanAnnotationScope(planID: UUID(), sectionID: UUID())
        let label = "Gospel study · Day 1"
        let prefs = ReaderPreferences()
        await annotations.open(first)
        annotations.openPlanChapter(first, scope: scope, name: label)
        await annotations.createPlanLayer(document: first, preferences: prefs, width: 760, name: label)
        let firstID = try XCTUnwrap(annotations.selected?.id)
        let points = [CGPoint(x: 40, y: 45), CGPoint(x: 75, y: 60)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 3, height: 3),
                opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: now))
        let drawing = PKDrawing(strokes: [stroke]).dataRepresentation()
        annotations.updateDrawing(drawing, layerID: firstID)
        await annotations.save()
        await annotations.createPlanLayer(document: first, preferences: prefs, width: 760, name: label)

        annotations.openPlanChapter(second, scope: scope, name: label)
        await annotations.createPlanLayer(document: second, preferences: prefs, width: 760, name: label)
        XCTAssertNotEqual(annotations.selected?.id, firstID)
        XCTAssertEqual(annotations.snapshot.groups.filter { $0.planScope == scope }.count, 2)

        let reopened = AnnotationSession(repository: AnnotationFileRepository(directory: folder))
        await reopened.open(first)
        XCTAssertNil(reopened.group)
        XCTAssertTrue(reopened.layers(for: first).isEmpty)
        XCTAssertTrue(AnnotationCollectionCatalog.layerChoices(in: reopened.snapshot).isEmpty)
        reopened.openPlanChapter(first, scope: scope, name: "Renamed · Day 1")
        XCTAssertEqual(reopened.selected?.id, firstID)
        XCTAssertEqual(reopened.selected?.drawing, drawing)
        XCTAssertEqual(reopened.selected?.name, "Renamed · Day 1")
        await reopened.save()
    }

    func testPlanReaderDoesNotMoveOrdinaryReader() async {
        let bible = BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self))
        let ordinary = ReaderSession(content: bible, state: nil)
        await ordinary.start()
        let original = ordinary.document
        let plan = ordinary.makePlanReader()
        await plan.openPlanPassage(editionID: web, book: "JHN", chapter: 3, verse: 16, endVerse: 17)
        XCTAssertEqual(plan.document?.book, "JHN")
        XCTAssertEqual(plan.emphasisVerses, [16, 17])
        XCTAssertEqual(ordinary.document?.book, original?.book)
        XCTAssertEqual(ordinary.document?.chapter, original?.chapter)
    }

    private func strictPlan() -> StudyPlan {
        StudyPlan(title: "Sixty Days", preferredEditionID: web, referenceSystemID: referenceSystem,
            sections: (1...60).map { _ in
                PlanSection(items: [PlanItem(payload: .scripture(referenceSystemID: referenceSystem,
                    book: "JHN", chapter: 1, start: 1))])
            }, strictSchedule: PlanSchedule(startDate: now, timeZoneID: "UTC"))
    }

    private func reminders(_ plan: StudyPlan, existing: [ActivityReminder] = [], now: Date? = nil) -> [ActivityReminder] {
        PlanReminderTime.rollingReminders(for: [plan], existing: existing, times: [:], now: now ?? self.now, isPrivate: { _ in false })
    }
}
