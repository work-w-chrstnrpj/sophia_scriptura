import XCTest

final class PlanUITests: XCTestCase {
    func testAutosaveCloseReopenAndProminentAssignmentActions() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        app.buttons["collections.addMaterial"].tap()
        app.buttons["collections.newPlan"].tap()
        let title = app.textFields["plans.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); enterText("Sam", into: title)
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Saved'"), object: app.staticTexts["plans.saveStatus"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 10), .completed)
        enterText("ple Plan", into: title)
        app.swipeUp()
        app.buttons["plans.addAssignment"].firstMatch.tap()
        XCTAssertTrue(app.buttons["plans.addScripture"].waitForExistence(timeout: 10))
        let scripture = XCTAttachment(screenshot: app.screenshot()); scripture.name = "Prominent Add Scripture"; scripture.lifetime = .keepAlways; add(scripture)
        app.segmentedControls.buttons["Notes"].tap()
        XCTAssertTrue(app.buttons["plans.assignment.createNote"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Links"].tap()
        XCTAssertTrue(app.buttons["plans.assignment.createLink"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Scripture"].tap()
        app.buttons["plans.addScripture"].tap()
        app.buttons["Close"].tap() // Flushes automatically; never tap Save.
        assertMaterialPickerClosed(app)
        let item = app.buttons["collections.open.Sample Plan"]
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["collections.folder.Sample Plan"].exists, "Every Plan has a dedicated folder")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        XCTAssertTrue(app.staticTexts["Genesis 1"].waitForExistence(timeout: 5))
    }
    func testInlineEditKeepsPlanHeaderAndAutosavesWithoutAnotherModal() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        app.buttons["collections.addMaterial"].tap()
        app.buttons["collections.newPlan"].tap()
        let title = app.textFields["plans.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); enterText("Inline Plan", into: title)
        app.buttons["plans.save"].tap()
        assertMaterialPickerClosed(app)
        app.buttons["collections.open.Inline Plan"].tap()
        XCTAssertTrue(app.buttons["plans.edit"].waitForExistence(timeout: 5)); app.buttons["plans.edit"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["plans.exit"].isHittable, "Main Plan header stays visible during editing")
        XCTAssertTrue(app.buttons["plans.finishEditing"].isHittable)
        XCTAssertFalse(app.buttons["plans.save"].exists, "Existing Plan uses inline Done instead of a modal Save bar")
        XCTAssertGreaterThan(title.frame.width, app.frame.width * 0.8)
        XCTAssertFalse(app.buttons["plans.chooseLinkedFolder"].exists)
        XCTAssertFalse(app.buttons["plans.unlinkFolder"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Assignments are arranged'")).firstMatch.exists)
        enterText(" revised", into: title)
        app.buttons["plans.finishEditing"].tap()
        XCTAssertTrue(app.buttons["plans.edit"].waitForExistence(timeout: 10))
        XCTAssertFalse(title.exists)
        XCTAssertTrue(app.staticTexts["Inline Plan revised"].exists)
        app.buttons["plans.edit"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Main Plan inline edit"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["plans.addSection"].tap()
        app.buttons["plans.finishEditing"].tap()
        app.buttons["plans.exit"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        app.buttons["collections.open.Inline Plan revised"].tap()
        XCTAssertTrue(app.buttons["plans.edit"].waitForExistence(timeout: 5)); app.buttons["plans.edit"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["plans.unlinkFolder"].exists)
        XCTAssertFalse(app.staticTexts["None"].exists)
    }
    func testPlanFolderShowsDaySubfoldersAndScriptureInsideItsDay() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        app.buttons["collections.addMaterial"].tap()
        app.buttons["collections.newPlan"].tap()
        let title = app.textFields["plans.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); enterText("Section Plan", into: title)
        app.buttons["plans.save"].tap()
        assertMaterialPickerClosed(app)
        app.buttons["collections.open.Section Plan"].tap()
        XCTAssertTrue(app.buttons["plans.edit"].waitForExistence(timeout: 5)); app.buttons["plans.edit"].tap()
        let assignmentButton = app.buttons["plans.addAssignment"].firstMatch
        for _ in 0..<3 { if assignmentButton.exists && assignmentButton.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(assignmentButton.waitForExistence(timeout: 5)); assignmentButton.tap()
        let scripture = app.buttons["plans.addScripture"]
        XCTAssertTrue(scripture.waitForExistence(timeout: 10)); scripture.tap()
        app.buttons["plans.finishEditing"].tap()
        XCTAssertTrue(app.buttons["plans.edit"].waitForExistence(timeout: 10))
        app.buttons["plans.exit"].tap()
        let root = app.buttons["collections.folder.Section Plan"]
        XCTAssertTrue(root.waitForExistence(timeout: 10)); root.tap()
        let day = app.buttons["collections.folder.Day 1"]
        XCTAssertTrue(day.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["collections.open.Section Plan"].exists)
        day.tap()
        XCTAssertTrue(app.buttons["collections.open.GEN 1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["collections.open.Section Plan"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Day 1 contains its Scripture assignment"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
    func testCreateAssignmentAndReopenPlanAfterRelaunch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20))
        openFolder(app)
        app.buttons["collections.addMaterial"].tap()
        XCTAssertTrue(app.buttons["collections.newPlan"].waitForExistence(timeout: 5))
        app.buttons["collections.newPlan"].tap()
        let title = app.textFields["plans.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("My Reading Plan")
        app.swipeUp()
        let assignment = app.buttons["plans.addAssignment"].firstMatch
        XCTAssertTrue(assignment.waitForExistence(timeout: 5)); assignment.tap()
        let scripture = app.buttons["plans.addScripture"]
        if !scripture.waitForExistence(timeout: 10) {
            let attachment = XCTAttachment(string: app.debugDescription); attachment.name = "Missing assignment picker"; attachment.lifetime = .keepAlways; add(attachment)
            XCTFail("Assignment picker must expose Add Scripture"); return
        }
        app.segmentedControls.buttons["Notes"].tap()
        XCTAssertTrue(app.textFields["plans.assignment.noteTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["plans.addScripture"].exists)
        XCTAssertFalse(app.textFields["plans.assignment.linkTitle"].exists)
        app.segmentedControls.buttons["Links"].tap()
        XCTAssertTrue(app.textFields["plans.assignment.linkTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["plans.assignment.noteTitle"].exists)
        app.segmentedControls.buttons["Scripture"].tap()
        let wholeChapters = app.switches["plans.wholeChapters"]
        if (wholeChapters.value as? String) == "1" {
            wholeChapters.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.steppers.matching(NSPredicate(format: "label CONTAINS 'First verse'")).firstMatch.waitForExistence(timeout: 5))
        scripture.tap()
        scrollTo(app.staticTexts["Genesis 1:1"], app: app)
        XCTAssertTrue(app.staticTexts["Genesis 1:1"].waitForExistence(timeout: 5))
        app.buttons["plans.save"].tap()
        assertMaterialPickerClosed(app)
        let item = app.buttons["collections.open.My Reading Plan"]
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        XCTAssertTrue(app.staticTexts["Genesis 1:1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["plans.title"].exists, "Opening a Plan must show its contents, not its editor")
        XCTAssertTrue(app.buttons["plans.start"].isEnabled)
        app.buttons["plans.start"].tap()
        XCTAssertTrue(app.textViews["scripture.text"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["plans.next"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["plans.addNote"].exists)
        XCTAssertTrue(app.buttons["plans.addLink"].exists)
        XCTAssertTrue(app.buttons["plans.newConversation"].exists)
        XCTAssertTrue(app.buttons["plans.music"].exists)
        let fullscreen = XCTAttachment(screenshot: app.screenshot()); fullscreen.name = "Fullscreen Plan reader"; fullscreen.lifetime = .keepAlways; add(fullscreen)
        app.buttons["plans.addNote"].tap()
        let noteTitle = app.textFields["notes.new.title"]
        XCTAssertTrue(noteTitle.waitForExistence(timeout: 5)); noteTitle.tap(); noteTitle.typeText("Reading reflection")
        app.buttons["notes.new.create"].tap()
        let body = app.textViews["notes.body"]
        XCTAssertTrue(body.waitForExistence(timeout: 15)); body.tap(); body.typeText("My reflection stays inside the Plan.")
        app.buttons["plans.note.back"].tap()
        XCTAssertTrue(app.buttons["plans.addLink"].waitForExistence(timeout: 5)); app.buttons["plans.addLink"].tap()
        let linkTitle = app.textFields["plans.link.title"]
        XCTAssertTrue(linkTitle.waitForExistence(timeout: 5)); linkTitle.tap(); linkTitle.typeText("Study source")
        let linkURL = app.textFields["plans.link.url"]; linkURL.tap(); linkURL.typeText("example.com")
        app.buttons["plans.link.save"].tap()
        XCTAssertTrue(app.buttons["plans.music"].waitForExistence(timeout: 5)); app.buttons["plans.music"].tap()
        XCTAssertTrue(app.buttons["plans.music.toggle"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["plans.next"].tap()
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        XCTAssertTrue((body.value as? String)?.contains("My reflection stays inside the Plan.") == true)
        app.buttons["plans.next"].tap()
        XCTAssertTrue(app.staticTexts["Study source"].waitForExistence(timeout: 5))
        app.buttons["plans.next"].tap()
        XCTAssertTrue(app.staticTexts["Plan complete"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Congratulations!"].exists)
        app.buttons["plans.completion.done"].tap()
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Plan authoring"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        XCTAssertTrue(app.staticTexts["Genesis 1:1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 of 1 completed"].exists)
        XCTAssertFalse(app.images["plans.completedStamp"].exists, "The stamp belongs only on the outside Collection record")
        let noteRow = app.buttons.containing(.staticText, identifier: "Reading reflection").firstMatch
        XCTAssertTrue(noteRow.waitForExistence(timeout: 5)); noteRow.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        XCTAssertTrue((body.value as? String)?.contains("My reflection stays inside the Plan.") == true)
        app.buttons["plans.note.back"].tap()
        XCTAssertFalse(app.buttons["plans.start"].isEnabled, "Completed Plans require explicit reset before replay")
        app.buttons["plans.edit"].tap()
        XCTAssertTrue(app.textFields["plans.title"].waitForExistence(timeout: 5))
        app.swipeUp()
        let manageSection = app.buttons["Manage section"].firstMatch
        XCTAssertTrue(manageSection.waitForExistence(timeout: 5))
        let originalSectionID = manageSection.identifier
        manageSection.tap()
        XCTAssertTrue(app.buttons["Duplicate section"].waitForExistence(timeout: 5)); app.buttons["Duplicate section"].tap()
        let manageItem = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'plans.manageItem.'")).firstMatch
        XCTAssertTrue(manageItem.waitForExistence(timeout: 5)); manageItem.tap()
        XCTAssertTrue(app.buttons["Remove assignment"].waitForExistence(timeout: 5)); app.buttons["Remove assignment"].tap()
        let originalSection = app.buttons[originalSectionID]
        XCTAssertTrue(originalSection.waitForExistence(timeout: 5)); originalSection.tap()
        XCTAssertTrue(app.buttons["Remove section"].waitForExistence(timeout: 5)); app.buttons["Remove section"].tap()
        XCTAssertTrue(app.buttons["plans.addSection"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.buttons["Duplicate Plan"].exists)
        XCTAssertTrue(app.buttons["Archive Plan"].exists)
        XCTAssertTrue(app.buttons["Delete Plan"].exists)
        let actions = XCTAttachment(screenshot: app.screenshot()); actions.name = "Plan lifecycle actions"; actions.lifetime = .keepAlways; add(actions)
        app.buttons["Reset whole Plan"].tap()
        XCTAssertTrue(app.buttons["Reset progress"].waitForExistence(timeout: 5)); app.buttons["Reset progress"].tap()
        app.buttons["plans.finishEditing"].tap()
        XCTAssertTrue(app.staticTexts["0 of 1 completed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["plans.completedStamp"].exists)
        let retainedNote = app.buttons.containing(.staticText, identifier: "Reading reflection").firstMatch
        retainedNote.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        XCTAssertTrue((body.value as? String)?.contains("My reflection stays inside the Plan.") == true)
        app.buttons["plans.note.back"].tap()
        app.buttons["plans.edit"].tap(); app.swipeUp()
        let lastSection = app.buttons["Manage section"].firstMatch
        XCTAssertTrue(lastSection.waitForExistence(timeout: 5)); lastSection.tap()
        app.buttons["Remove section"].tap()
        XCTAssertTrue(app.buttons["plans.addSection"].waitForExistence(timeout: 5)); app.buttons["plans.finishEditing"].tap()
        XCTAssertTrue(app.staticTexts["0 of 0 completed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["plans.start"].isEnabled)
    }
    func testRemovingOnlySectionDoesNotTerminateEditor() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20))
        openFolder(app)
        app.buttons["collections.addMaterial"].tap()
        XCTAssertTrue(app.buttons["collections.newPlan"].waitForExistence(timeout: 5))
        app.buttons["collections.newPlan"].tap()
        let title = app.textFields["plans.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        app.swipeUp()
        let manage = app.buttons["Manage section"].firstMatch
        XCTAssertTrue(manage.waitForExistence(timeout: 5)); manage.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()
        let remove = app.buttons["Remove section"]
        if !remove.waitForExistence(timeout: 2) { manage.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap() }
        XCTAssertTrue(remove.waitForExistence(timeout: 5)); remove.tap()
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.buttons["plans.addSection"].waitForExistence(timeout: 5))
        app.buttons["plans.addSection"].tap()
        XCTAssertTrue(app.buttons["Manage section"].firstMatch.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Deletion regression")
        app.buttons["plans.save"].tap()
        assertMaterialPickerClosed(app)
        let item = app.buttons["collections.open.Deletion regression"]
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        app.buttons["plans.edit"].tap()
        app.swipeUp()
        let storedManage = app.buttons["Manage section"].firstMatch
        XCTAssertTrue(storedManage.waitForExistence(timeout: 5)); storedManage.tap()
        let storedRemove = app.buttons["Remove section"]
        XCTAssertTrue(storedRemove.waitForExistence(timeout: 5)); storedRemove.tap()
        XCTAssertTrue(app.buttons["plans.addSection"].waitForExistence(timeout: 5))
        app.buttons["plans.finishEditing"].tap()
        XCTAssertTrue(app.staticTexts["0 of 0 completed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["plans.start"].isEnabled)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        XCTAssertTrue(app.staticTexts["0 of 0 completed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["plans.start"].isEnabled)
    }
    func testStrictPlanAndFolderDeleteConfirmationsAndSectionProgress() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        func create(_ name: String) {
            app.buttons["collections.addMaterial"].tap(); app.buttons["collections.newPlan"].tap()
            let title = app.textFields["plans.title"]
            XCTAssertTrue(title.waitForExistence(timeout: 5)); enterText(name, into: title)
            app.buttons["plans.save"].tap()
            assertMaterialPickerClosed(app)
        }
        create("Delete by Plan")
        app.buttons["collections.open.Delete by Plan"].tap()
        XCTAssertTrue(app.staticTexts["0 of 1 completed"].waitForExistence(timeout: 5))
        app.buttons["plans.edit"].tap()
        XCTAssertTrue(app.textFields["plans.title"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["plans.chooseLinkedFolder"].exists)
        XCTAssertFalse(app.buttons["plans.unlinkFolder"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Assignments are arranged'")).firstMatch.exists)
        let addSection = app.buttons["plans.addSection"]
        for _ in 0..<3 { if addSection.exists && addSection.isHittable { break }; app.swipeUp() }
        addSection.tap()
        app.buttons["plans.finishEditing"].tap()
        XCTAssertTrue(app.staticTexts["0 of 2 completed"].waitForExistence(timeout: 5))
        app.buttons["plans.edit"].tap()
        let delete = app.buttons["plans.delete.begin"]
        for _ in 0..<4 { if delete.exists && delete.isHittable { break }; app.swipeUp() }
        delete.tap()
        XCTAssertTrue(app.buttons["plans.delete.confirm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'also delete its Plan folder'")).firstMatch.exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["plans.finishEditing"].exists)
        delete.tap(); app.buttons["plans.delete.confirm"].tap()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["collections.open.Delete by Plan"])
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 15), .completed)
        XCTAssertFalse(app.buttons["collections.folder.Delete by Plan"].exists)
        create("Delete by Folder")
        let root = app.buttons["collections.folder.Delete by Folder"]
        XCTAssertTrue(root.waitForExistence(timeout: 5)); root.tap()
        app.buttons["Collection actions"].firstMatch.tap(); app.buttons["Delete Collection"].tap()
        XCTAssertTrue(app.staticTexts["Delete this Plan folder?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'also delete the Plan'")).firstMatch.exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Collection actions"].firstMatch.exists)
        app.buttons["Collection actions"].firstMatch.tap(); app.buttons["Delete Collection"].tap()
        app.buttons["Delete Collection"].tap()
        let folderRemoved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: root)
        XCTAssertEqual(XCTWaiter.wait(for: [folderRemoved], timeout: 15), .completed)
        XCTAssertFalse(app.buttons["collections.open.Delete by Folder"].exists)
    }
    func testScriptureCanBeEditedFromPlanAndItsDayFolder() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        app.buttons["collections.addMaterial"].tap(); app.buttons["collections.newPlan"].tap()
        let title = app.textFields["plans.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); enterText("Editable Scripture", into: title)
        app.swipeUp()
        let addAssignment = app.buttons["plans.addAssignment"].firstMatch
        XCTAssertTrue(addAssignment.waitForExistence(timeout: 5)); addAssignment.tap()
        XCTAssertTrue(app.buttons["plans.addScripture"].waitForExistence(timeout: 10)); app.buttons["plans.addScripture"].tap()
        app.buttons["plans.save"].tap()
        assertMaterialPickerClosed(app)
        app.buttons["collections.open.Editable Scripture"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'plans.assignment.'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.navigationBars["Edit Scripture assignment"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls["Assignment type"].exists)
        let chapter = app.steppers["plans.assignment.chapter"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        chapter.buttons["plans.assignment.chapter-Increment"].tap()
        app.buttons["plans.addScripture"].tap()
        XCTAssertTrue(app.staticTexts["Genesis 2"].waitForExistence(timeout: 10))
        app.buttons["plans.exit"].tap()
        let root = app.buttons["collections.folder.Editable Scripture"]
        XCTAssertTrue(root.waitForExistence(timeout: 5)); root.tap()
        app.buttons["collections.folder.Day 1"].tap()
        let folderItem = app.buttons["collections.open.GEN 2"]
        XCTAssertTrue(folderItem.waitForExistence(timeout: 5)); folderItem.tap()
        XCTAssertTrue(app.navigationBars["Edit Scripture assignment"].waitForExistence(timeout: 5))
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Chapter 2"].exists || chapter.label.contains("2"))
        chapter.buttons["plans.assignment.chapter-Increment"].tap()
        app.buttons["plans.addScripture"].tap()
        XCTAssertTrue(app.buttons["collections.open.GEN 3"].waitForExistence(timeout: 10))
        app.buttons["BackButton"].tap()
        app.buttons["collections.open.Editable Scripture"].tap()
        XCTAssertTrue(app.staticTexts["Genesis 3"].waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.navigationBars["Edit Scripture assignment"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Genesis 3"].waitForExistence(timeout: 5))
    }
    func testOneDayPlaybackStrictScheduleCompletionAndActivityHistory() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        app.buttons["collections.addMaterial"].tap(); app.buttons["collections.newPlan"].tap()
        let title = app.textFields["plans.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); enterText("Daily Gospel", into: title)
        let strict = app.switches["plans.strictMode"]
        scrollTo(strict, app: app)
        strict.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let firstAssignment = app.buttons["plans.addAssignment"].firstMatch
        scrollTo(firstAssignment, app: app); firstAssignment.tap()
        XCTAssertTrue(app.buttons["plans.addScripture"].waitForExistence(timeout: 10)); app.buttons["plans.addScripture"].tap()
        let addSection = app.buttons["plans.addSection"]
        scrollTo(addSection, app: app); addSection.tap()
        let secondAssignment = app.buttons.matching(NSPredicate(format: "identifier == 'plans.addAssignment' AND label == 'Add assignment to Day 2'")).firstMatch
        scrollTo(secondAssignment, app: app); secondAssignment.tap()
        XCTAssertTrue(app.buttons["plans.addScripture"].waitForExistence(timeout: 10))
        app.steppers["plans.assignment.chapter"].buttons["plans.assignment.chapter-Increment"].tap()
        app.buttons["plans.addScripture"].tap()
        app.buttons["plans.save"].tap()
        assertMaterialPickerClosed(app)
        let item = app.buttons["collections.open.Daily Gospel"]
        XCTAssertTrue(item.waitForExistence(timeout: 10)); item.tap()
        XCTAssertTrue(app.buttons["plans.playDay.2"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["plans.playDay.2"].label, "Day 2")
        XCTAssertFalse(app.staticTexts["plans.dates"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'plans.dayDates.'")).count, 2)
        app.buttons["plans.playDay.2"].tap()
        XCTAssertTrue(app.textViews["scripture.text"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Genesis 2"].exists)
        XCTAssertTrue(app.buttons["plans.newConversation"].exists)
        let link = app.buttons["plans.addLink"].frame.midX
        let chat = app.buttons["plans.newConversation"].frame.midX
        let music = app.buttons["plans.music"].frame.midX
        XCTAssertGreaterThan(chat, link); XCTAssertLessThan(chat, music)
        app.buttons["plans.newConversation"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Configure a provider'")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["plans.next"].tap()
        XCTAssertTrue(app.staticTexts["Section complete"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Congratulations!"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Day completion celebration"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["plans.completion.done"].tap()
        XCTAssertTrue(item.waitForExistence(timeout: 10)); item.tap()
        XCTAssertTrue(app.staticTexts["1 of 2 completed"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["plans.playDay.1"].label, "Day 1")
        XCTAssertFalse(app.staticTexts["plans.dates"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'plans.dayDates.'")).count, 2)
        app.buttons["plans.edit"].tap()
        let dates = app.staticTexts["plans.edit.dates"]
        scrollTo(dates, app: app)
        XCTAssertTrue(dates.label.contains("Due date:")); XCTAssertTrue(dates.label.contains("Completion date:"))
        XCTAssertFalse(app.switches["Custom due date"].exists)
        XCTAssertFalse(app.buttons["plans.catchUp"].exists, "A current schedule needs no catch up")
        app.buttons["plans.finishEditing"].tap()
        app.buttons["plans.playDay.1"].tap()
        XCTAssertTrue(app.textViews["scripture.text"].waitForExistence(timeout: 15))
        app.buttons["plans.next"].tap()
        XCTAssertTrue(app.staticTexts["Plan complete"].waitForExistence(timeout: 10))
        app.buttons["plans.completion.done"].tap()
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20))
        let reveal = app.buttons["navigation.showTabs"]
        if reveal.exists && reveal.isHittable { reveal.tap() }
        app.buttons["tab.activity"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Daily Gospel - Day 1"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Daily Gospel - Day 2"].exists)
    }
    func testHalfFinishedDayKeepsChecksAndHasNoHistoryAfterRelaunch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchEnvironment["SP009_TEST_STORE"] = UUID().uuidString; app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app)
        app.buttons["collections.addMaterial"].tap(); app.buttons["collections.newPlan"].tap()
        let title = app.textFields["plans.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); enterText("Partial Plan", into: title)
        for _ in 0..<2 {
            let assignment = app.buttons["plans.addAssignment"].firstMatch
            scrollTo(assignment, app: app); assignment.tap()
            XCTAssertTrue(app.buttons["plans.addScripture"].waitForExistence(timeout: 10)); app.buttons["plans.addScripture"].tap()
        }
        app.buttons["plans.save"].tap(); assertMaterialPickerClosed(app)
        let item = app.buttons["collections.open.Partial Plan"]
        XCTAssertTrue(item.waitForExistence(timeout: 10)); item.tap()
        app.buttons["plans.start"].tap()
        XCTAssertTrue(app.textViews["scripture.text"].waitForExistence(timeout: 15))
        app.buttons["plans.next"].tap()
        XCTAssertTrue(app.buttons["plans.exit"].waitForExistence(timeout: 5)); app.buttons["plans.exit"].tap()
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["reader.book"].waitForExistence(timeout: 20)); openFolder(app); item.tap()
        let checked = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'plans.assignment.' AND value == 'Completed'"))
        XCTAssertEqual(checked.count, 1)
        XCTAssertTrue(app.staticTexts["0 of 1 completed"].exists)
        app.buttons["plans.exit"].tap()
        let reveal = app.buttons["navigation.showTabs"]
        if reveal.exists && reveal.isHittable { reveal.tap() }
        app.buttons["tab.activity"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["No activities recorded yet."].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'activity.record.'")).count, 0)
    }
    private func assertMaterialPickerClosed(_ app: XCUIApplication) {
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.navigationBars["Add Items"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed)
        XCTAssertFalse(app.buttons["collections.newPlan"].exists)
    }
    private func scrollTo(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<7 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }
    private func enterText(_ text: String, into field: XCUIElement) {
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for _ in 0..<3 {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
            let ready = XCTNSPredicateExpectation(predicate: focused, object: field)
            if XCTWaiter.wait(for: [ready], timeout: 3) == .completed { field.typeText(text); return }
        }
        XCTFail("Text field must receive keyboard focus before typing")
    }
    private func openFolder(_ app: XCUIApplication) {
        let reveal = app.buttons["navigation.showTabs"]
        let collections = app.buttons["tab.collections"]
        let folder = app.buttons["collections.folder.Plan Tests"]
        // The shell retains offscreen tabs in the accessibility tree. Existence alone
        // cannot establish a selected tab, and its dock can collapse during relaunch.
        for _ in 0..<3 {
            if reveal.exists && reveal.isHittable { reveal.tap() }
            // Coordinate tap avoids the element scroll/retry sequence outlasting
            // the three-second dock deadline after Show tab menu.
            collections.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let create = app.buttons["collections.newCollection"]
            if create.waitForExistence(timeout: 5), create.isHittable, !folder.exists {
                create.tap()
                let name = app.textFields["Name"]
                XCTAssertTrue(name.waitForExistence(timeout: 5)); enterText("Plan Tests", into: name)
                app.buttons["Create"].tap()
            }
            let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: folder)
            if XCTWaiter.wait(for: [visible], timeout: 5) == .completed { folder.tap(); return }
        }
        XCTFail("Collections folder must be visible after selecting its tab")
    }
}
