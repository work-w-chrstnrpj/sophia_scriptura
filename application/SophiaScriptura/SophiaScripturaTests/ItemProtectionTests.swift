import XCTest
import PencilKit
@testable import SophiaScriptura

@MainActor final class ItemProtectionTests: XCTestCase {
    final class Vault: ItemLockCredentialVault {
        var value: ItemLockCredential?
        var failWrite = false
        init(_ value: ItemLockCredential? = nil) { self.value = value }
        func read() throws -> ItemLockCredential? { value }
        func write(_ credential: ItemLockCredential) throws {
            if failWrite { throw ItemLockError.credentialsUnavailable }; value = credential
        }
    }
    final class Biometrics: ItemBiometricAuthenticating {
        var pending: CheckedContinuation<Bool, Error>?
        var cancelled = false
        func authenticate() async throws -> Bool { try await withCheckedThrowingContinuation { pending = $0 } }
        func cancel() { cancelled = true }
        func complete(_ result: Bool) { let wait = pending; pending = nil; wait?.resume(returning: result) }
    }
    final class Clock { var date = Date(timeIntervalSince1970: 1000) }
    private let password = "Sophia test password 42"
    private func session(_ clock: Clock = Clock()) throws -> (ItemProtectionSession, Vault) {
        let vault = Vault(try ItemLockCredential.make(password: password))
        return (ItemProtectionSession(vault: vault, now: { clock.date }, startTimer: false), vault)
    }
    private func prompt(_ session: ItemProtectionSession) async throws {
        for _ in 0..<100 { if session.prompt != nil { return }; await Task.yield() }
        XCTFail("Authentication prompt was not presented"); throw ItemLockError.busy
    }
    private func unlock(_ session: ItemProtectionSession, _ domains: Set<ItemProtectionSession.Domain>) async throws {
        let task = Task { try await session.authenticate(domains) }
        try await prompt(session)
        await session.password(password, confirmation: "")
        try await task.value
    }
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Lock-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }; return url
    }
    func testSaltedVerifierRejectsEmptyWrongAndOverlongPasswords() throws {
        let first = try ItemLockCredential.make(password: password)
        let second = try ItemLockCredential.make(password: password)
        XCTAssertNotEqual(first.salt, second.salt); XCTAssertNotEqual(first.verifier, second.verifier)
        XCTAssertTrue(try first.verifies(password)); XCTAssertFalse(try first.verifies("wrong")); XCTAssertFalse(try first.verifies(""))
        XCTAssertThrowsError(try ItemLockCredential.make(password: "short"))
        XCTAssertFalse(try first.verifies(String(repeating: "x", count: 257)))
        XCTAssertFalse(String(data: try JSONEncoder().encode(first), encoding: .utf8)!.contains(password))
    }
    func testLegacyRecordsDecodeUnprotectedAndBindingsRoundTrip() throws {
        var note = NoteDocument(); var folder = StudyCollection(id: UUID(), name: "Test", detail: "", parentID: nil, accent: .rose, modifiedAt: Date())
        let decoder = JSONDecoder(); let encoder = JSONEncoder()
        XCTAssertNil(try decoder.decode(NoteDocument.self, from: encoder.encode(note)).protectionID)
        XCTAssertNil(try decoder.decode(StudyCollection.self, from: encoder.encode(folder)).protectionID)
        note.protectionID = UUID(); folder.protectionID = note.protectionID
        XCTAssertEqual(try decoder.decode(NoteDocument.self, from: encoder.encode(note)).protectionID, note.protectionID)
        XCTAssertEqual(try decoder.decode(StudyCollection.self, from: encoder.encode(folder)).protectionID, folder.protectionID)
    }
    func testIndependentIdleDeadlinesAndCombinedLock() async throws {
        let clock = Clock(); let (protection, vault) = try session(clock)
        try await unlock(protection, [.notes, .collections])
        clock.date.addTimeInterval(599); protection.activity(in: .notes)
        clock.date.addTimeInterval(1); protection.expire()
        XCTAssertFalse(protection.isLocked(vault.value!.id, in: .notes)); XCTAssertTrue(protection.isLocked(vault.value!.id, in: .collections))
        XCTAssertFalse(protection.isLocked(nil, in: .collections))
        clock.date.addTimeInterval(600); protection.expire(); XCTAssertTrue(protection.unlocked.isEmpty)
        try await unlock(protection, [.notes, .collections]); protection.lock([.notes, .collections]); XCTAssertTrue(protection.unlocked.isEmpty)
    }
    func testMixedStateCancellationPreservesPriorGrantAndForcedLockCancelsPending() async throws {
        let (protection, _) = try session(); try await unlock(protection, [.notes])
        let combined = Task { try await protection.authenticate([.notes, .collections]) }
        try await prompt(protection); protection.cancel()
        do { try await combined.value; XCTFail("Cancelled authentication succeeded") } catch {}
        XCTAssertEqual(protection.unlocked, [.notes])
        let pending = Task { try await protection.authenticate([.collections]) }
        try await prompt(protection); protection.lock([.collections])
        do { try await pending.value; XCTFail("Forced lock did not invalidate authentication") } catch {}
        XCTAssertEqual(protection.unlocked, [.notes])
    }
    func testLatePasswordSuccessCannotUndoForcedLock() async throws {
        let (protection, _) = try session()
        let authentication = Task { try await protection.authenticate([.notes, .collections]) }
        try await prompt(protection)
        let verification = Task { await protection.password(password, confirmation: "") }
        await Task.yield(); protection.lock([.notes, .collections])
        await verification.value
        do { try await authentication.value; XCTFail("Stale result granted access") } catch {}
        XCTAssertTrue(protection.unlocked.isEmpty)
    }
    func testCombinedAuthorizationRejectsForeignCredentialBeforeGrantingEitherCategory() async throws {
        let (protection, vault) = try session()
        do { try await protection.authorize([.notes: [vault.value!.id], .collections: [UUID()]]) ; XCTFail("Foreign credential accepted") } catch {}
        XCTAssertNil(protection.prompt); XCTAssertTrue(protection.unlocked.isEmpty)
    }
    func testFreshLaunchNeverRestoresGrantsAndBackgroundExpiryIsEnforced() async throws {
        let clock = Clock(); let (protection, vault) = try session(clock)
        try await unlock(protection, [.notes]); protection.sceneActive(false, background: true)
        clock.date.addTimeInterval(601); protection.sceneActive(true)
        XCTAssertTrue(protection.unlocked.isEmpty); XCTAssertFalse(protection.obscured)
        let restarted = ItemProtectionSession(vault: vault, startTimer: false)
        XCTAssertEqual(restarted.credential?.id, vault.value?.id); XCTAssertTrue(restarted.unlocked.isEmpty)
    }
    func testFailedAttemptsAreThrottledAcrossRestartAndKeychainFailureDoesNotGrantAccess() async throws {
        let clock = Clock(); let (protection, vault) = try session(clock)
        let pending = Task { try await protection.authenticate([.notes]) }; try await prompt(protection)
        for _ in 0..<5 { await protection.password("incorrect", confirmation: "") }
        await protection.password(password, confirmation: ""); XCTAssertTrue(protection.unlocked.isEmpty)
        protection.cancel(); _ = try? await pending.value
        let restarted = ItemProtectionSession(vault: vault, now: { clock.date }, startTimer: false)
        let second = Task { try await restarted.authenticate([.notes]) }; try await prompt(restarted)
        await restarted.password(password, confirmation: ""); XCTAssertTrue(restarted.unlocked.isEmpty)
        clock.date.addTimeInterval(31); vault.failWrite = true
        await restarted.password(password, confirmation: ""); XCTAssertTrue(restarted.unlocked.isEmpty)
        restarted.cancel(); _ = try? await second.value
    }
    func testProtectedNoteCommandsAreGuardedButArchiveTrashAndDeletionRemainAvailable() async throws {
        let (protection, _) = try session(); let repository = NotesFileRepository(directory: try directory())
        let notes = NotesSession(repository: repository); notes.protection = protection; await notes.load()
        let id = try XCTUnwrap(notes.create(kind: .page, title: "Secret"))
        let protect = Task { await notes.setProtected(id, enabled: true) }; try await prompt(protection)
        await protection.password(password, confirmation: ""); await protect.value
        let binding = try XCTUnwrap(notes.note?.protectionID)
        protection.lock([.notes]); notes.selectedNoteID = id
        notes.updateNote(id: id, title: "Changed", tags: "hidden", paper: .ruled, color: .rose)
        notes.setColor(.gold, for: id); notes.edit { $0.page?.body = "bypass" }
        XCTAssertNil(notes.note); XCTAssertEqual(notes.snapshot.notes[0].title, "Secret"); XCTAssertEqual(notes.snapshot.notes[0].page?.body, "")
        notes.archive(id); notes.moveToTrash(id)
        XCTAssertEqual(notes.snapshot.notes[0].protectionID, binding); XCTAssertTrue(notes.snapshot.notes[0].isTrashed)
        notes.permanentlyDelete(id); XCTAssertTrue(notes.snapshot.notes.isEmpty)
    }
    func testIdleLockFlushesPendingNativeEditsBeforeConcealingAndSavesThem() async throws {
        let clock = Clock(); let (protection, _) = try session(clock)
        let notes = NotesSession(repository: NotesFileRepository(directory: try directory())); notes.protection = protection; await notes.load()
        let id = try XCTUnwrap(notes.create(kind: .page))
        let setup = Task { await notes.setProtected(id, enabled: true) }; try await prompt(protection)
        await protection.password(password, confirmation: ""); await setup.value
        notes.flushSurface = { notes.edit { $0.page?.body = "Last pending keystroke" } }
        protection.willLock = { domains in if domains.contains(.notes) { notes.concealProtectedNote() } }
        clock.date.addTimeInterval(600); protection.expire(); await notes.save()
        XCTAssertNil(notes.selectedNoteID); XCTAssertEqual(notes.snapshot.notes[0].page?.body, "Last pending keystroke"); XCTAssertFalse(notes.dirty)
        XCTAssertTrue(protection.isLocked(notes.snapshot.notes[0].protectionID, in: .notes))
    }
    func testProtectedAncestorGatesDescendantsAndMembershipMovesAreAtomic() async throws {
        let (protection, vault) = try session()
        let parent = StudyCollection(protectionID: vault.value!.id, id: UUID(), name: "Private", detail: "secret", parentID: nil, accent: .rose, modifiedAt: Date())
        let child = StudyCollection(id: UUID(), name: "Child", detail: "", parentID: parent.id, accent: .rose, modifiedAt: Date())
        let plain = StudyCollection(id: UUID(), name: "Plain", detail: "", parentID: nil, accent: .gold, modifiedAt: Date())
        let artifact = CollectionArtifact(id: UUID(), title: "Test", subtitle: "", kind: .bookmark, modifiedAt: Date())
        let membership = CollectionMembership(collectionID: plain.id, artifactID: artifact.id)
        let store = CollectionsStore(collections: [parent, child, plain], artifacts: [artifact], memberships: [membership]); store.protection = protection
        XCTAssertTrue(store.isLocked(child.id)); XCTAssertTrue(store.artifactIDs(for: child.id, includingDescendants: true).isEmpty)
        store.move(artifactID: artifact.id, from: plain.id, to: child.id)
        XCTAssertEqual(store.memberships, [membership]); XCTAssertFalse(store.updateCollection(id: child.id, name: "Changed", detail: "", accent: .gold))
        try await unlock(protection, [.collections]); XCTAssertFalse(store.isLocked(child.id)); XCTAssertTrue(protection.isLocked(vault.value!.id, in: .notes))
        store.move(artifactID: artifact.id, from: plain.id, to: child.id); XCTAssertTrue(store.contains(artifact.id, in: child.id))
        protection.lock([.collections]); store.moveCollectionToTrash(id: parent.id)
        XCTAssertNil(store.collection(id: child.id)?.parentID); XCTAssertTrue(store.contains(artifact.id, in: child.id))
    }
    func testProtectedNoteCannotBeFiledThroughUnprotectedCollection() throws {
        let (protection, vault) = try session(); var note = NoteDocument(); note.protectionID = vault.value!.id
        let folder = StudyCollection(id: UUID(), name: "Plain", detail: "", parentID: nil, accent: .rose, modifiedAt: Date())
        let store = CollectionsStore(collections: [folder], artifacts: [], memberships: []); store.protection = protection; store.link(notes: [note])
        store.addMembership(artifactID: note.id, collectionID: folder.id); XCTAssertTrue(store.memberships.isEmpty)
        XCTAssertEqual(store.notice, ItemLockError.locked.localizedDescription)
    }
    func testProtectedRepositorySchemaAndLegacyRestoreCannotStripProtection() async throws {
        let directory = try directory(); let repository = NotesFileRepository(directory: directory)
        var note = NoteDocument(); note.title = "Original"; var plain = NotesSnapshot(); plain.notes = [note]
        let saved = try await repository.save(plain, expectedRevision: 0); let oldBackup = try await repository.exportArchive()
        var protected = saved; protected.notes[0].protectionID = UUID()
        let locked = try await repository.save(protected, expectedRevision: saved.revision)
        XCTAssertEqual(locked.schemaVersion, 4)
        let restored = try await repository.restore(oldBackup, expectedRevision: locked.revision)
        XCTAssertEqual(restored.notes[0].protectionID, protected.notes[0].protectionID)
        let inspected = try NotesFileRepository.inspectArchive(await repository.exportArchive()); XCTAssertEqual(inspected.schemaVersion, 4)
        let collections = CollectionsFileRepository(directory: try self.directory())
        let folder = StudyCollection(protectionID: UUID(), id: UUID(), name: "Protected", detail: "", parentID: nil, accent: .rose, modifiedAt: Date())
        let snapshot = try await collections.save(CollectionsSnapshot(collections: [folder]), expectedRevision: 0)
        XCTAssertEqual(snapshot.schemaVersion, 2)
        let loaded = try await collections.load(); XCTAssertEqual(loaded.snapshot.collections[0].protectionID, folder.protectionID)
    }
    func testRemovalRequiresUnlockAndNoFolderCannotBeProtected() async throws {
        let (protection, vault) = try session()
        let folder = StudyCollection(protectionID: vault.value!.id, id: UUID(), name: "Protected", detail: "", parentID: nil, accent: .rose, modifiedAt: Date())
        let store = CollectionsStore(collections: [folder], artifacts: [], memberships: []); store.protection = protection
        let remove = Task { await store.setProtected(folder.id, enabled: false) }; try await prompt(protection)
        protection.cancel(); await remove.value; XCTAssertEqual(store.collection(id: folder.id)?.protectionID, folder.protectionID)
        await store.setProtected(StudyCollection.unfiledID, enabled: true); XCTAssertNil(protection.prompt)
        let retry = Task { await store.setProtected(folder.id, enabled: false) }; try await prompt(protection)
        await protection.password(password, confirmation: ""); await retry.value; XCTAssertNil(store.collection(id: folder.id)?.protectionID)
    }

    func testRemovingProtectionPromptsAgainWhileTheCategoryIsUnlocked() async throws {
        let vault = Vault(try ItemLockCredential.make(password: password)); let provider = Biometrics()
        let protection = ItemProtectionSession(vault: vault, startTimer: false, biometricsProvider: provider)
        let notes = NotesSession(repository: NotesFileRepository(directory: try directory())); notes.protection = protection; await notes.load()
        let id = try XCTUnwrap(notes.create(kind: .page, title: "Secret"))
        let protect = Task { await notes.setProtected(id, enabled: true) }; try await prompt(protection)
        await protection.password(password, confirmation: ""); await protect.value
        XCTAssertTrue(protection.unlocked.contains(.notes))
        let cancelled = Task { await notes.setProtected(id, enabled: false) }; try await prompt(protection)
        XCTAssertTrue(protection.prompt?.confirmRemoval == true)
        protection.cancel(); await cancelled.value
        XCTAssertNotNil(notes.snapshot.notes[0].protectionID)
        let retry = Task { await notes.setProtected(id, enabled: false) }; try await prompt(protection)
        let biometric = Task { await protection.biometrics() }
        for _ in 0..<100 { if provider.pending != nil { break }; await Task.yield() }
        provider.complete(true); await biometric.value; await retry.value
        XCTAssertNil(notes.snapshot.notes[0].protectionID)

        let folder = StudyCollection(protectionID: vault.value!.id, id: UUID(), name: "Protected", detail: "", parentID: nil, accent: .rose, modifiedAt: Date())
        let store = CollectionsStore(collections: [folder], artifacts: [], memberships: []); store.protection = protection
        try await unlock(protection, [.collections])
        let remove = Task { await store.setProtected(folder.id, enabled: false) }; try await prompt(protection)
        XCTAssertTrue(protection.prompt?.confirmRemoval == true)
        protection.cancel(); await remove.value
        XCTAssertEqual(store.collection(id: folder.id)?.protectionID, folder.protectionID)
    }

    func testHoldMenuMatchesProtectionState() {
        XCTAssertEqual(ItemProtectionMenu.actions(protectionID: nil, locked: false), .protect)
        XCTAssertEqual(ItemProtectionMenu.actions(protectionID: nil, locked: true), .protect)
        let binding = UUID()
        XCTAssertEqual(ItemProtectionMenu.actions(protectionID: binding, locked: false), .lockAndRemove)
        XCTAssertEqual(ItemProtectionMenu.actions(protectionID: binding, locked: true), .unlock)
    }
    func testBiometricSuccessGrantsBothAndLateCallbackCannotRestoreAccess() async throws {
        let vault = Vault(try ItemLockCredential.make(password: password)); let provider = Biometrics()
        let protection = ItemProtectionSession(vault: vault, startTimer: false, biometricsProvider: provider)
        let first = Task { try await protection.authenticate([.notes, .collections]) }; try await prompt(protection)
        let biometric = Task { await protection.biometrics() }
        for _ in 0..<100 { if provider.pending != nil { break }; await Task.yield() }
        provider.complete(true); await biometric.value; try await first.value
        XCTAssertEqual(protection.unlocked, [.notes, .collections])
        protection.lock([.notes, .collections])
        let second = Task { try await protection.authenticate([.notes, .collections]) }; try await prompt(protection)
        let late = Task { await protection.biometrics() }
        for _ in 0..<100 { if provider.pending != nil { break }; await Task.yield() }
        protection.lock([.notes, .collections]); provider.complete(true); await late.value
        _ = try? await second.value; XCTAssertTrue(provider.cancelled); XCTAssertTrue(protection.unlocked.isEmpty)
    }
    func testPasswordChangeAuthenticatesPreservesBindingAndRelocksBothCategories() async throws {
        let (protection, vault) = try session(); let originalID = vault.value!.id
        try await unlock(protection, [.notes, .collections])
        let change = Task { try await protection.changePassword() }; try await prompt(protection)
        XCTAssertFalse(protection.prompt!.setup)
        await protection.password(password, confirmation: "")
        for _ in 0..<100 { if protection.prompt?.changePassword == true { break }; await Task.yield() }
        XCTAssertTrue(protection.prompt?.changePassword == true)
        let replacement = "Replacement test password 99"
        await protection.password(replacement, confirmation: replacement); try await change.value
        XCTAssertEqual(vault.value!.id, originalID); XCTAssertTrue(protection.unlocked.isEmpty)
        XCTAssertTrue(try vault.value!.verifies(replacement)); XCTAssertFalse(try vault.value!.verifies(password))
    }

    func testLayoutAndInactiveFlushDoNotExtendIdleDeadline() async throws {
        let clock = Clock(); let (protection, _) = try session(clock)
        let notes = NotesSession(repository: NotesFileRepository(directory: try directory())); notes.protection = protection; await notes.load()
        let id = try XCTUnwrap(notes.create(kind: .page))
        let setup = Task { await notes.setProtected(id, enabled: true) }; try await prompt(protection)
        await protection.password(password, confirmation: ""); await setup.value
        clock.date.addTimeInterval(599)
        notes.edit({ $0.page?.height = 1800 }, record: false)
        protection.willLock = { _ in notes.edit { $0.page?.body = "Buffered text" } }
        protection.sceneActive(false, background: true)
        clock.date.addTimeInterval(1); protection.sceneActive(true)
        XCTAssertTrue(protection.unlocked.isEmpty)
    }

    func testCollectionRestoreUsesCurrentRevisionAndRetainsMatchingProtection() async throws {
        let (protection, _) = try session()
        let store = CollectionsStore(repository: CollectionsFileRepository(directory: try directory())); store.protection = protection; await store.load()
        let first = try XCTUnwrap(store.createCollection(name: "First", detail: "", parentID: nil, accent: .rose)); await store.flush()
        let backup = try store.exportBackupSnapshot()
        let setup = Task { await store.setProtected(first, enabled: true) }; try await prompt(protection)
        await protection.password(password, confirmation: ""); await setup.value
        let originalBinding = store.collection(id: first)?.protectionID
        _ = store.createCollection(name: "Later", detail: "", parentID: nil, accent: .gold); await store.flush()
        await store.restoreBackupSnapshot(backup)
        XCTAssertEqual(store.notice, "Collections restored from backup.")
        XCTAssertEqual(store.collections.filter { !$0.isUnfiled }.map(\.id), [first])
        XCTAssertEqual(store.collection(id: first)?.protectionID, originalBinding); XCTAssertTrue(store.isLocked(first))
    }
    func testResetInvalidatesPendingAuthenticationWithoutGrantingAccess() async throws {
        let (protection, _) = try session()
        let notes = NotesSession(repository: NotesFileRepository(directory: try directory())); notes.protection = protection; await notes.load()
        let pending = Task { try await protection.authenticate([.notes]) }; try await prompt(protection)
        notes.removeAllNotes(); _ = try? await pending.value
        XCTAssertNil(protection.prompt); XCTAssertTrue(protection.unlocked.isEmpty)
    }

    func testMissingAndMalformedCredentialsRemainFailClosedAfterNewPasswordSetup() async throws {
        let lostBinding = UUID(); let vault = Vault()
        let protection = ItemProtectionSession(vault: vault, startTimer: false)
        let setup = Task { try await protection.authenticate([.notes], setupIfNeeded: true) }; try await prompt(protection)
        await protection.password(password, confirmation: password); try await setup.value
        XCTAssertTrue(protection.isLocked(lostBinding, in: .notes))
        let malformed = ItemLockCredential(id: UUID(), salt: Data(), verifier: Data(count: 32), rounds: 600_000)
        let broken = ItemProtectionSession(vault: Vault(malformed), startTimer: false)
        do { try await broken.authenticate([.notes], setupIfNeeded: true); XCTFail("Malformed verifier accepted") } catch {}
        XCTAssertNil(broken.prompt); XCTAssertTrue(broken.isLocked(malformed.id, in: .notes))
    }
    func testSimultaneousRequestsCannotReplaceTheFirstPrompt() async throws {
        let (protection, _) = try session()
        let pending = Task { try await protection.authenticate([.notes]) }; try await prompt(protection)
        let original = protection.prompt?.id
        do { try await protection.authenticate([.collections]); XCTFail("Second prompt replaced first") } catch {}
        XCTAssertEqual(protection.prompt?.id, original); XCTAssertEqual(protection.prompt?.domains, [.notes])
        protection.cancel(); _ = try? await pending.value
    }

    func testAutomaticRecoveryCannotDropANewProtectionBinding() async throws {
        let notesFolder = try directory(); let notes = NotesFileRepository(directory: notesFolder)
        var note = NoteDocument(kind: .page); note.page?.body = "Private retained content"
        var first = NotesSnapshot(); first.notes = [note]
        let plain = try await notes.save(first, expectedRevision: 0)
        var locked = plain; let binding = UUID(); locked.notes[0].protectionID = binding
        _ = try await notes.save(locked, expectedRevision: plain.revision)
        try Data("damaged".utf8).write(to: notesFolder.appendingPathComponent("current.json"), options: .atomic)
        let recovered = try await notes.load()
        XCTAssertTrue(recovered.recovered); XCTAssertEqual(recovered.snapshot.notes[0].protectionID, binding)
        XCTAssertEqual(recovered.snapshot.notes[0].page?.body, note.page?.body); XCTAssertEqual(recovered.snapshot.schemaVersion, 4)
        XCTAssertTrue(FileManager.default.fileExists(atPath: notesFolder.appendingPathComponent("before-item-protection.notes").path))
        let collectionFolder = try directory(); let collections = CollectionsFileRepository(directory: collectionFolder)
        let folder = StudyCollection(id: UUID(), name: "Private", detail: "Preserved", parentID: nil, accent: .rose, modifiedAt: Date())
        let saved = try await collections.save(CollectionsSnapshot(collections: [folder]), expectedRevision: 0)
        var protected = saved; protected.collections[0].protectionID = binding
        _ = try await collections.save(protected, expectedRevision: saved.revision)
        try Data("damaged".utf8).write(to: collectionFolder.appendingPathComponent("current.json"), options: .atomic)
        let restored = try await collections.load()
        XCTAssertTrue(restored.recovered); XCTAssertEqual(restored.snapshot.collections[0].protectionID, binding)
        XCTAssertEqual(restored.snapshot.collections[0].detail, folder.detail); XCTAssertEqual(restored.snapshot.schemaVersion, 2)
    }

    func testRejectedInkRecoveryRetainsTheSourceNoteProtection() async throws {
        let (protection, _) = try session()
        let notes = NotesSession(repository: NotesFileRepository(directory: try directory())); notes.protection = protection; await notes.load()
        let source = try XCTUnwrap(notes.create(kind: .canvas))
        let setup = Task { await notes.setProtected(source, enabled: true) }; try await prompt(protection)
        await protection.password(password, confirmation: ""); await setup.value
        let binding = try XCTUnwrap(notes.note?.protectionID)
        notes.retainRejectedInk(PKDrawing().dataRepresentation())
        await notes.recoverRejectedInk()
        XCTAssertNotEqual(notes.selectedNoteID, source); XCTAssertEqual(notes.note?.protectionID, binding)
        XCTAssertEqual(notes.snapshot.notes.first(where: { $0.id == source })?.protectionID, binding)
    }

    func testLockedCollectionHidesMemberNotesUntilThatCollectionIsUnlocked() async throws {
        let (protection, vault) = try session()
        let parent = StudyCollection(protectionID: vault.value!.id, id: UUID(), name: "Private", detail: "", parentID: nil, accent: .rose, modifiedAt: Date())
        let child = StudyCollection(id: UUID(), name: "Child", detail: "", parentID: parent.id, accent: .rose, modifiedAt: Date())
        let open = StudyCollection(id: UUID(), name: "Open", detail: "", parentID: nil, accent: .gold, modifiedAt: Date())
        let secret = UUID(); let nested = UUID(); let plain = UUID(); let shared = UUID(); let unfiled = UUID()
        let store = CollectionsStore(
            collections: [parent, child, open],
            artifacts: [],
            memberships: [
                CollectionMembership(collectionID: parent.id, artifactID: secret),
                CollectionMembership(collectionID: child.id, artifactID: nested),
                CollectionMembership(collectionID: open.id, artifactID: plain),
                CollectionMembership(collectionID: parent.id, artifactID: shared),
                CollectionMembership(collectionID: open.id, artifactID: shared)
            ]
        )
        store.protection = protection
        XCTAssertTrue(store.concealsNote(secret))
        XCTAssertTrue(store.concealsNote(nested))
        XCTAssertTrue(store.concealsNote(shared))
        XCTAssertFalse(store.concealsNote(plain))
        XCTAssertFalse(store.concealsNote(unfiled))
        try await unlock(protection, [.notes, .collections])
        XCTAssertFalse(store.concealsNote(secret))
        XCTAssertFalse(store.concealsNote(nested))
        XCTAssertFalse(store.concealsNote(shared))
        protection.lock([.collections])
        XCTAssertTrue(store.concealsNote(secret))
        XCTAssertEqual(protection.unlocked, [.notes])
    }

    func testNotesUnderLockedCollectionSubfoldersStayHiddenAtEveryDepth() async throws {
        let (protection, vault) = try session()
        let binding = try XCTUnwrap(vault.value).id
        func folder(_ name: String, parent: UUID?, protected: Bool = false) -> StudyCollection {
            StudyCollection(
                protectionID: protected ? binding : nil,
                id: UUID(),
                name: name,
                detail: "",
                parentID: parent,
                accent: .rose,
                modifiedAt: Date()
            )
        }
        let root = folder("Private", parent: nil, protected: true)
        let child = folder("Child", parent: root.id)
        let grandchild = folder("Grandchild", parent: child.id)
        let great = folder("Great", parent: grandchild.id)
        let deepest = folder("Deepest", parent: great.id)
        let open = folder("Open", parent: nil)
        let openChild = folder("Open Child", parent: open.id)
        let middle = folder("Middle", parent: open.id, protected: true)
        let underMiddle = folder("Under Middle", parent: middle.id)
        let underUnder = folder("Under Under", parent: underMiddle.id)
        let rootNote = UUID(), childNote = UUID(), grandNote = UUID(), greatNote = UUID(), deepNote = UUID()
        let openNote = UUID(), middleNote = UUID(), nestedMiddleNote = UUID(), shared = UUID()
        let store = CollectionsStore(
            collections: [root, child, grandchild, great, deepest, open, openChild, middle, underMiddle, underUnder],
            artifacts: [],
            memberships: [
                CollectionMembership(collectionID: root.id, artifactID: rootNote),
                CollectionMembership(collectionID: child.id, artifactID: childNote),
                CollectionMembership(collectionID: grandchild.id, artifactID: grandNote),
                CollectionMembership(collectionID: great.id, artifactID: greatNote),
                CollectionMembership(collectionID: deepest.id, artifactID: deepNote),
                CollectionMembership(collectionID: openChild.id, artifactID: openNote),
                CollectionMembership(collectionID: middle.id, artifactID: middleNote),
                CollectionMembership(collectionID: underUnder.id, artifactID: nestedMiddleNote),
                CollectionMembership(collectionID: deepest.id, artifactID: shared),
                CollectionMembership(collectionID: open.id, artifactID: shared)
            ]
        )
        store.protection = protection
        let hidden = store.folderIDsHiddenFromNotes()
        XCTAssertTrue(hidden.isSuperset(of: [root.id, child.id, grandchild.id, great.id, deepest.id, middle.id, underMiddle.id, underUnder.id]))
        XCTAssertFalse(hidden.contains(open.id))
        XCTAssertFalse(hidden.contains(openChild.id))
        for note in [rootNote, childNote, grandNote, greatNote, deepNote, middleNote, nestedMiddleNote, shared] {
            XCTAssertTrue(store.concealsNote(note))
        }
        XCTAssertFalse(store.concealsNote(openNote))
        try await unlock(protection, [.notes, .collections])
        XCTAssertTrue(store.folderIDsHiddenFromNotes().isEmpty)
        XCTAssertFalse(store.concealsNote(deepNote))
        XCTAssertFalse(store.concealsNote(nestedMiddleNote))
        XCTAssertFalse(store.concealsNote(shared))
        protection.lock([.collections])
        XCTAssertTrue(store.concealsNote(deepNote))
        XCTAssertTrue(store.concealsNote(nestedMiddleNote))
        XCTAssertTrue(store.concealsNote(shared))
        XCTAssertFalse(store.concealsNote(openNote))
        XCTAssertEqual(protection.unlocked, [.notes])
    }

    func testDeepSubfolderMembershipSurvivesReloadAndStaysHidden() async throws {
        let (protection, _) = try session()
        let folder = try directory()
        let writing = CollectionsStore(repository: CollectionsFileRepository(directory: folder))
        writing.protection = protection
        await writing.load()
        let root = try XCTUnwrap(writing.createCollection(name: "Private", detail: "", parentID: nil, accent: .rose))
        let child = try XCTUnwrap(writing.createCollection(name: "Child", detail: "", parentID: root, accent: .rose))
        let grandchild = try XCTUnwrap(writing.createCollection(name: "Grandchild", detail: "", parentID: child, accent: .rose))
        let deepest = try XCTUnwrap(writing.createCollection(name: "Deepest", detail: "", parentID: grandchild, accent: .rose))
        let notes = NotesSession(repository: NotesFileRepository(directory: try directory()))
        notes.protection = protection
        await notes.load()
        let noteID = try XCTUnwrap(notes.create(kind: .page, title: "Nested"))
        writing.link(notes: notes.snapshot.notes)
        writing.addMembership(artifactID: noteID, collectionID: deepest)
        let protect = Task { await writing.setProtected(root, enabled: true) }
        try await prompt(protection)
        await protection.password(password, confirmation: "")
        await protect.value
        await writing.flush()
        protection.lock([.collections])

        let reading = CollectionsStore(repository: CollectionsFileRepository(directory: folder))
        reading.protection = protection
        await reading.load()
        XCTAssertEqual(reading.collection(id: deepest)?.parentID, grandchild)
        XCTAssertEqual(reading.collection(id: grandchild)?.parentID, child)
        XCTAssertEqual(reading.collection(id: child)?.parentID, root)
        XCTAssertTrue(reading.concealsNote(noteID))
        XCTAssertTrue(reading.folderIDsHiddenFromNotes().isSuperset(of: [root, child, grandchild, deepest]))
    }

    func testSettingsControlsFollowProtectedItemsAndMixedSessions() {
        let none = ItemProtectionControlState.make(notesProtected: false, collectionsProtected: false, unlocked: [.notes, .collections])
        XCTAssertEqual(none.summary, "No protected items")
        XCTAssertFalse(none.lockAllEnabled); XCTAssertFalse(none.unlockAllEnabled)
        XCTAssertEqual(none.notesStatus, "No protected notes"); XCTAssertNotNil(none.explanation)
        let partial = ItemProtectionControlState.make(notesProtected: true, collectionsProtected: true, unlocked: [.notes])
        XCTAssertEqual(partial.summary, "Partially unlocked")
        XCTAssertTrue(partial.lockAllEnabled); XCTAssertTrue(partial.unlockAllEnabled)
        XCTAssertEqual(partial.status(.notes), "Unlocked"); XCTAssertEqual(partial.status(.collections), "Locked")
        let notesOnly = ItemProtectionControlState.make(notesProtected: true, collectionsProtected: false, unlocked: [])
        XCTAssertEqual(notesOnly.summary, "Fully locked"); XCTAssertFalse(notesOnly.lockAllEnabled); XCTAssertTrue(notesOnly.unlockAllEnabled)
        XCTAssertEqual(notesOnly.collectionsStatus, "No protected collections")
        let both = ItemProtectionControlState.make(notesProtected: true, collectionsProtected: true, unlocked: [.notes, .collections])
        XCTAssertEqual(both.summary, "Fully unlocked"); XCTAssertTrue(both.lockAllEnabled); XCTAssertFalse(both.unlockAllEnabled)
    }

    func testArchivingANoteLeavesACollectionsPromptUntouched() async throws {
        let (protection, _) = try session()
        let notes = NotesSession(repository: NotesFileRepository(directory: try directory())); notes.protection = protection; await notes.load()
        let id = try XCTUnwrap(notes.create(kind: .page, title: "Plain"))
        let pending = Task { try await protection.authenticate([.collections]) }; try await prompt(protection)
        notes.archive(id)
        XCTAssertEqual(protection.prompt?.domains, [.collections]); XCTAssertTrue(protection.unlocked.isEmpty)
        protection.cancel(); _ = try? await pending.value
    }

    func testDeletingANoteInvalidatesOnlyTheNotesPrompt() async throws {
        let (protection, _) = try session()
        let notes = NotesSession(repository: NotesFileRepository(directory: try directory())); notes.protection = protection; await notes.load()
        let id = try XCTUnwrap(notes.create(kind: .page, title: "Plain"))
        let pending = Task { try await protection.authenticate([.notes]) }; try await prompt(protection)
        notes.permanentlyDelete(id)
        do { try await pending.value; XCTFail("Deleting a note left its unlock prompt active") } catch {}
        XCTAssertNil(protection.prompt); XCTAssertTrue(protection.unlocked.isEmpty)
    }

    func testRemovingAllCollectionsRevokesOnlyThatSession() async throws {
        let (protection, vault) = try session()
        let folder = StudyCollection(protectionID: vault.value!.id, id: UUID(), name: "Private", detail: "", parentID: nil, accent: .rose, modifiedAt: Date())
        let store = CollectionsStore(collections: [folder], artifacts: [], memberships: []); store.protection = protection
        try await unlock(protection, [.notes, .collections])
        store.removeAllCollections()
        XCTAssertEqual(protection.unlocked, [.notes])
        XCTAssertTrue(store.collections.allSatisfy(\.isUnfiled))
    }

    func testSharedProtectedNoteOpensThroughPlainCollectionAndRelockRevokesEditorAccess() async throws {
        let (protection, vault) = try session()
        var document = NoteDocument(kind: .page)
        document.title = "Shared secret"; document.protectionID = vault.value!.id
        document.page?.body = "accepted content"
        let repository = NotesFileRepository(directory: try directory())
        var snapshot = NotesSnapshot(); snapshot.notes = [document]
        _ = try await repository.save(snapshot, expectedRevision: 0)
        let notes = NotesSession(repository: repository); notes.protection = protection; await notes.load()
        let privateFolder = StudyCollection(protectionID: vault.value!.id, id: UUID(), name: "Private", detail: "", parentID: nil, accent: .rose, modifiedAt: Date())
        let openFolder = StudyCollection(id: UUID(), name: "Open", detail: "", parentID: nil, accent: .gold, modifiedAt: Date())
        let store = CollectionsStore(collections: [privateFolder, openFolder], artifacts: [], memberships: [
            CollectionMembership(collectionID: privateFolder.id, artifactID: document.id),
            CollectionMembership(collectionID: openFolder.id, artifactID: document.id)
        ]); store.protection = protection; store.link(notes: notes.snapshot.notes); notes.collections = store
        XCTAssertTrue(store.concealsNote(document.id))
        notes.open(document.id); XCTAssertNil(notes.selectedNoteID); XCTAssertNil(protection.prompt)
        notes.open(document.id, from: openFolder.id)
        try await prompt(protection); XCTAssertEqual(protection.prompt?.domains, [.notes])
        await protection.password(password, confirmation: "")
        for _ in 0..<100 { if notes.selectedNoteID == document.id { break }; await Task.yield() }
        XCTAssertEqual(notes.note?.page?.body, "accepted content")
        XCTAssertEqual(notes.openingCollectionID, openFolder.id)
        XCTAssertTrue(store.isLocked(privateFolder.id)); XCTAssertTrue(store.concealsNote(document.id))
        let protectOrigin = Task { await store.setProtected(openFolder.id, enabled: true) }
        try await prompt(protection); await protection.password(password, confirmation: ""); await protectOrigin.value
        XCTAssertNotNil(notes.note)
        notes.flushSurface = { notes.edit { $0.page?.body = "flushed before lock" } }
        protection.willLock = { _ in notes.flushSurface?() }
        protection.lock([.collections])
        XCTAssertNil(notes.note)
        notes.edit { $0.page?.body = "blocked mutation" }
        XCTAssertEqual(notes.snapshot.notes.first?.page?.body, "flushed before lock")
        notes.concealInaccessibleNote(); XCTAssertNil(notes.selectedNoteID)
        XCTAssertNil(notes.openingCollectionID)
        XCTAssertTrue(protection.unlocked.contains(.notes))
        await notes.save()
    }

    func testCollectionOriginIsRecheckedAfterNoteAuthentication() async throws {
        let (protection, vault) = try session()
        var document = NoteDocument(); document.protectionID = vault.value!.id
        let repository = NotesFileRepository(directory: try directory())
        var snapshot = NotesSnapshot(); snapshot.notes = [document]
        _ = try await repository.save(snapshot, expectedRevision: 0)
        let notes = NotesSession(repository: repository); notes.protection = protection; await notes.load()
        let folder = StudyCollection(id: UUID(), name: "Open", detail: "", parentID: nil, accent: .gold, modifiedAt: Date())
        let store = CollectionsStore(collections: [folder], artifacts: [], memberships: [CollectionMembership(collectionID: folder.id, artifactID: document.id)])
        store.protection = protection; notes.collections = store
        notes.open(document.id, from: folder.id); try await prompt(protection)
        store.deleteCollection(id: folder.id)
        await protection.password(password, confirmation: "")
        for _ in 0..<100 { await Task.yield() }
        XCTAssertNil(notes.selectedNoteID); XCTAssertNil(notes.note)
    }

    func testFilingChangesOnlyUnlockedEdgesAndReportsRejectedChanges() throws {
        let (protection, vault) = try session()
        let locked = StudyCollection(protectionID: vault.value!.id, id: UUID(), name: "Locked", detail: "", parentID: nil, accent: .rose, modifiedAt: Date())
        let first = StudyCollection(id: UUID(), name: "First", detail: "", parentID: nil, accent: .gold, modifiedAt: Date())
        let second = StudyCollection(id: UUID(), name: "Second", detail: "", parentID: nil, accent: .gold, modifiedAt: Date())
        let item = CollectionArtifact(id: UUID(), title: "Bookmark", subtitle: "", kind: .bookmark, modifiedAt: Date())
        let store = CollectionsStore(collections: [locked, first, second], artifacts: [item], memberships: [
            CollectionMembership(collectionID: locked.id, artifactID: item.id),
            CollectionMembership(collectionID: first.id, artifactID: item.id)
        ]); store.protection = protection
        XCTAssertTrue(store.setMemberships(artifactID: item.id, collectionIDs: [locked.id, second.id]))
        XCTAssertEqual(store.collectionIDs(containing: item.id), [locked.id, second.id])
        XCTAssertFalse(store.setMemberships(artifactID: item.id, collectionIDs: [first.id]))
        XCTAssertEqual(store.collectionIDs(containing: item.id), [locked.id, second.id])
        XCTAssertEqual(store.notice, ItemLockError.locked.localizedDescription)
        XCTAssertFalse(store.move(artifactID: item.id, from: second.id, to: locked.id))
        XCTAssertEqual(store.collectionIDs(containing: item.id), [locked.id, second.id])
        XCTAssertTrue(store.setMemberships(artifactID: item.id, collectionIDs: [locked.id]))
        XCTAssertTrue(store.setMemberships(artifactID: item.id, collectionIDs: [locked.id]))
        XCTAssertFalse(store.setMemberships(artifactID: UUID(), collectionIDs: [second.id]))
    }

    func testTrashPrivacyHidesCollectionTagsAndBodyMatchesButRetainsTitles() async throws {
        let (protection, vault) = try session()
        var hidden = NoteDocument(kind: .page); hidden.title = "Visible title"; hidden.tags = ["sensitive tag"]
        hidden.page?.body = "private body phrase"; hidden.trashedAt = Date()
        var active = NoteDocument(); active.tags = ["active hidden tag"]
        var plain = NoteDocument(kind: .page); plain.title = "Plain"; plain.tags = ["public tag"]; plain.page?.body = "public body"
        plain.trashedAt = Date()
        let locked = StudyCollection(protectionID: vault.value!.id, id: UUID(), name: "Locked", detail: "", parentID: nil, accent: .rose, modifiedAt: Date())
        let store = CollectionsStore(collections: [locked], artifacts: [], memberships: [
            CollectionMembership(collectionID: locked.id, artifactID: hidden.id),
            CollectionMembership(collectionID: locked.id, artifactID: active.id)
        ]); store.protection = protection
        XCTAssertEqual(store.visibleNoteTags(in: [hidden, active, plain]), ["public tag"])
        XCTAssertEqual(store.searchableNoteText(hidden), hidden.title)
        XCTAssertFalse(store.searchableNoteText(hidden).contains("private body phrase"))
        XCTAssertTrue(store.searchableNoteText(plain).contains("public body"))
        try await unlock(protection, [.collections])
        XCTAssertTrue(store.searchableNoteText(hidden).contains("private body phrase"))
        XCTAssertEqual(store.visibleNoteTags(in: [hidden, plain]), ["public tag", "sensitive tag"])
        hidden.protectionID = vault.value!.id
        XCTAssertEqual(store.searchableNoteText(hidden), hidden.title)
        XCTAssertEqual(store.visibleNoteTags(in: [hidden, plain]), ["public tag"])
    }

}
