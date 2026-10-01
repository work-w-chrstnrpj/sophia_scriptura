import Foundation
import Observation

@MainActor @Observable final class ReaderSession {
    private var content: any ScriptureContentRepository
    private let bundled: any ScriptureContentRepository
    let library: (any TranslationLibrary)?
    private let state: (any ReaderStateRepository)?
    private var snapshot = ReaderSnapshot()
    private var saveTask: Task<Void, Never>?
    private var requestID = UUID()
    private var stateWritable = true
    private(set) var books: [ScriptureBook] = []
    private(set) var edition: ScriptureEdition?
    private(set) var document: ChapterDocument?
    private(set) var preferences = ReaderPreferences()
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var notice: String?
    private(set) var targetVerse = 1
    private(set) var navigationID = UUID()
    private(set) var restorationLocation: ReadingLocation?
    var beforeNavigation: (@MainActor () async -> Bool)?
    var hubVerse: VerseID?
    private(set) var translations: [TranslationStatus] = []
    private(set) var syncMessage: String?
    private(set) var syncing = false
    private(set) var syncFraction = 0.0
    private var lastSyncSucceeded = false
    var abbreviation: String { edition?.abbreviation ?? "WEB" }
    var isLicensed: Bool { edition?.id.hasPrefix("api.bible.") == true }

    var currentBook: ScriptureBook? { books.first { $0.id == document?.book } }
    var title: String { "\(currentBook?.title ?? "Scripture") \(document.map { String($0.chapter) } ?? "")" }

    init(content: any ScriptureContentRepository, state: (any ReaderStateRepository)?, library: (any TranslationLibrary)? = nil) {
        self.content = content; self.bundled = content; self.state = state; self.library = library
        if state == nil { notice = ScriptureError.persistence.localizedDescription; stateWritable = false }
    }

    func start() async {
        guard (document == nil || error != nil), !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if let saved = try state?.load() { snapshot = saved }
            preferences = snapshot.preferences.validated
        } catch {
            stateWritable = false
            notice = "Saved reader data could not be opened. Reading is session-only; the original store is untouched."
        }
        do {
            let desired = snapshot.location?.editionID ?? preferences.preferredEdition
            if desired.hasPrefix("api.bible."), let library {
                content = try await library.repository(editionID:desired)
            }
            edition = try await content.edition()
            books = try await content.books()
            let location = snapshot.location
            guard (location?.editionID ?? preferences.preferredEdition) == edition?.id,
                  location == nil || location?.verse.referenceSystemID == edition?.referenceSystemID
            else { throw ScriptureError.editionUnavailable }
            await navigate(book: location?.verse.book ?? "GEN", chapter: location?.verse.chapter ?? 1,
                           verse: location?.verse.verse ?? 1, restoring: location)
        } catch { self.error = error.localizedDescription; document = nil }
        await refreshTranslations()
    }

    func navigate(book: String, chapter: Int, verse: Int = 1, restoring: ReadingLocation? = nil) async {
        if let beforeNavigation, !(await beforeNavigation()) { return }
        let request = UUID(); requestID = request
        let repository = content
        error = nil
        do {
            let loaded = try await repository.chapter(book: book, number: chapter)
            guard requestID == request else { return }
            let nearest = loaded.verseNumbers.min(by: { abs($0 - verse) < abs($1 - verse) }) ?? 1
            if restoring != nil {
                if nearest != verse || restoring?.contentRevision != loaded.contentRevision {
                    notice = "Reading position restored by verse in the current edition."
                }
                if let blockID = restoring?.blockID,
                   !loaded.blocks.contains(where: { $0.id == blockID && (0...$0.text.utf16.count).contains(restoring?.utf16Offset ?? 0) }) {
                    notice = "Reading position restored by verse; the previous text offset is unavailable."
                }
            } else if !loaded.verseNumbers.contains(verse) {
                throw ScriptureError.passageUnmapped
            }
            document = loaded; targetVerse = nearest; navigationID = UUID()
            let validBlock = restoring.flatMap { location in
                loaded.blocks.first { $0.id == location.blockID && $0.kind == "body" &&
                    $0.verses.contains(nearest) && (0...$0.text.utf16.count).contains(location.utf16Offset ?? -1) &&
                    location.contentRevision == loaded.contentRevision }
            }
            snapshot.location = ReadingLocation(editionID: loaded.editionID, contentRevision: loaded.contentRevision,
                                                verse: loaded.verse(nearest), blockID: validBlock?.id,
                                                utf16Offset: validBlock == nil ? nil : restoring?.utf16Offset)
            restorationLocation = snapshot.location
            save()
        } catch {
            guard requestID == request else { return }
            self.error = error.localizedDescription
            if isLicensed { document = nil; hubVerse = nil }
        }
    }

    /// Picker previews never change the reader or persist progress.
    func availableVerses(book: String, chapter: Int) async throws -> [Int] {
        try await content.chapter(book:book,number:chapter).verseNumbers
    }

    func stepChapter(_ delta: Int) async {
        guard let doc = document, let index = books.firstIndex(where: { $0.id == doc.book }) else { return }
        let candidate = doc.chapter + delta
        if candidate >= 1 && candidate <= books[index].chapterCount {
            await navigate(book: doc.book, chapter: candidate)
        } else if books.indices.contains(index + delta) {
            let book = books[index + delta]
            await navigate(book: book.id, chapter: delta > 0 ? 1 : book.chapterCount)
        }
    }

    func visibleLocation(_ verse: Int, blockID: String?, utf16Offset: Int?) {
        guard let doc = document, doc.verseNumbers.contains(verse) else { return }
        snapshot.location = ReadingLocation(editionID: doc.editionID, contentRevision: doc.contentRevision,
                                            verse: doc.verse(verse), blockID: blockID, utf16Offset: utf16Offset)
        targetVerse = verse
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }
    func refreshTranslations() async {
        guard let library else { return }
        do { translations = try await library.statuses() }
        catch { syncMessage = error.localizedDescription }
    }
    func configureProvider(key: String) async {
        do { try await library?.setCredential(key); syncMessage = "Key saved securely on this device." }
        catch { syncMessage = error.localizedDescription }
    }
    func selectEdition(_ id: String) async {
        if let beforeNavigation, !(await beforeNavigation()) { return }
        let token = UUID(); requestID = token
        do {
            let repository: any ScriptureContentRepository
            if id == "web.engwebp" { repository = bundled }
            else if let library { repository = try await library.repository(editionID:id) }
            else { throw ScriptureError.editionUnavailable }
            let newEdition = try await repository.edition()
            let newBooks = try await repository.books()
            let book = document?.book ?? snapshot.location?.verse.book ?? "GEN"
            let chapter = document?.chapter ?? snapshot.location?.verse.chapter ?? 1
            let loaded = try await repository.chapter(book:book,number:chapter)
            guard requestID == token else { return }
            let verse = loaded.verseNumbers.min(by:{ abs($0 - targetVerse) < abs($1 - targetVerse) }) ?? 1
            content = repository; edition = newEdition; books = newBooks; hubVerse = nil
            preferences.preferredEdition = id; snapshot.preferences = preferences
            await navigate(book:book,chapter:chapter,verse:verse)
        } catch { notice = error.localizedDescription }
    }
    func syncTranslation(_ id: String) async {
        guard let library, !syncing else { return }
        syncing = true; syncFraction = 0; lastSyncSucceeded = false
        defer { syncing = false }
        syncMessage = "Downloading… Keep Sophia open. You can resume an interrupted download."
        do {
            try await library.sync(id) { [weak self] done, total in
                Task { @MainActor in
                    self?.syncFraction = Double(done) / Double(max(1,total))
                    self?.syncMessage = "Downloaded \(done) of \(total) chapters. Keep Sophia open."
                }
            }
            await refreshTranslations()
            lastSyncSucceeded = true
            syncMessage = "Download complete. Offline access renewed for up to 30 days."
            if edition?.id == "api.bible." + id || snapshot.location?.editionID == "api.bible." + id {
                await selectEdition("api.bible." + id)
            }
        } catch { syncMessage = error.localizedDescription; await checkAccess() }
    }
    func syncAllTranslations() async {
        guard !syncing else { return }
        for item in LicensedTranslation.approved {
            await syncTranslation(item.id)
            if !lastSyncSucceeded { break }
        }
    }
    func checkAccess() async {
        guard isLicensed else { return }
        do { _ = try await content.edition() }
        catch {
            requestID = UUID(); document = nil; hubVerse = nil
            self.error = error.localizedDescription
        }
    }
    func suspendLicensedContent() {
        save()
        if isLicensed { requestID = UUID(); document = nil; hubVerse = nil }
    }
    func resume() async {
        if isLicensed, document == nil {
            await navigate(book:snapshot.location?.verse.book ?? "GEN",chapter:snapshot.location?.verse.chapter ?? 1,
                           verse:snapshot.location?.verse.verse ?? 1,restoring:snapshot.location)
        }
        await refreshTranslations()
    }
    func authorizeQuote(_ selection: ChapterTextMap.Selection) async -> String? {
        guard !selection.text.isEmpty else { return nil }
        guard selection.editionID.hasPrefix("api.bible.") else { return selection.text }
        guard selection.editionID == document?.editionID else { return nil }
        let attribution = edition?.attribution ?? ""
        do {
            guard let library else { throw LicensedContentError.expired }
            try await library.authorizeQuote(editionID:selection.editionID,verses:selection.passages.count,characters:selection.text.count)
            return selection.text + "\n\n" + attribution
        } catch { notice = error.localizedDescription; await checkAccess(); return nil }
    }

    func updatePreferences(_ value: ReaderPreferences) {
        // Reflow from the last observed source anchor, never the chapter's initial jump.
        if let location = snapshot.location {
            targetVerse = location.verse.verse
            restorationLocation = location
        }
        preferences = value.validated
        snapshot.preferences = preferences
        save()
    }
    func save() {
        guard stateWritable else { return }
        snapshot.updatedAt = Date()
        do { try state?.save(snapshot) }
        catch { notice = ScriptureError.persistence.localizedDescription }
    }
}
