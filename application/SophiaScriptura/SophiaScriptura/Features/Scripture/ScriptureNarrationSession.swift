import Foundation
import Observation

@MainActor @Observable
final class ScriptureNarrationSession: ScriptureNarrationControlling {
    private(set) var snapshot = ScriptureNarrationPlaybackSnapshot()
    private(set) var preferences = ScriptureNarrationPreferencesStore.load()
    private(set) var playbackHighlightVerse: Int?
    var showsPlayerSheet = false
    var followSuspendedReason: String?

    private let engine = ScriptureNarrationPlayerEngine()
    private let client = HelloAOChapterNarrationClient()
    private let mediaStore = ScriptureNarrationMediaStore()
    let downloadQueue = ScriptureNarrationDownloadQueue()

    private weak var music: MusicSession?
    private weak var reader: ReaderSession?
    private var epoch = ScriptureNarrationOperationEpoch.fresh()
    private var validatedTiming: ScriptureNarrationTimingValidation.ValidatedTiming?
    private var chapterVerseNumbers: [Int] = []
    private var loadedPackage: HelloAOChapterNarrationPackage?
    private var loadTask: Task<Void, Never>?
    private var playWhenLoadCompletes = false
    private(set) var playbackSpeed: ScriptureNarrationPlaybackSpeed = ScriptureNarrationPreferencesStore.loadPlaybackSpeed()
    private(set) var sleepTimerSelection: ScriptureNarrationSleepTimer = .off
    private(set) var sleepTimerRemainingSeconds: Int?
    private var sleepTimerTask: Task<Void, Never>?

    var canGoToPreviousChapter: Bool { loadedPackage?.previousChapterPath != nil }
    var canGoToNextChapter: Bool { loadedPackage?.nextChapterPath != nil }
    var canGoToPreviousVerse: Bool {
        guard let timing = validatedTiming else { return false }
        let current = playbackHighlightVerse
            ?? ScriptureNarrationTimingValidation.highlightedVerse(at: engine.currentTime, in: timing, duration: snapshot.duration)
        return ScriptureNarrationTimingValidation.previousVerse(before: current, in: timing) != nil
    }
    var canGoToNextVerse: Bool {
        guard let timing = validatedTiming else { return false }
        let current = playbackHighlightVerse
            ?? ScriptureNarrationTimingValidation.highlightedVerse(at: engine.currentTime, in: timing, duration: snapshot.duration)
        return ScriptureNarrationTimingValidation.nextVerse(after: current, in: timing) != nil
    }

    var isNarrationActive: Bool {
        switch snapshot.phase {
        case .playing, .paused, .buffering, .loading:
            return true
        default:
            return false
        }
    }

    func bind(music: MusicSession, reader: ReaderSession) {
        self.music = music
        self.reader = reader
        engine.setPlaybackRate(playbackSpeed.rawValue)
        engine.onPeriodicTime = { [weak self] time in self?.handlePeriodicTime(time) }
        engine.onEnded = { [weak self] in self?.handlePlaybackEnded() }
        engine.onFailed = { [weak self] message in self?.fail(message) }
    }

    func pauseNarrationForMusic() {
        guard isNarrationActive else { return }
        engine.pause()
        if case .playing = snapshot.phase { snapshot.phase = .paused }
        pauseSleepTimerCountdown()
        syncHighlight(at: engine.currentTime)
    }

    func setContinuousChapters(_ enabled: Bool) {
        preferences.continuousChapters = enabled
        ScriptureNarrationPreferencesStore.save(preferences)
    }

    func setFollowAudio(_ enabled: Bool) {
        preferences.followAudio = enabled
        ScriptureNarrationPreferencesStore.save(preferences)
        followSuspendedReason = nil
    }

    func setPreferredNarrator(_ id: String) {
        preferences.preferredNarratorID = id
        ScriptureNarrationPreferencesStore.save(preferences)
    }

    func setDeliveryMode(_ mode: ScriptureNarrationDeliveryMode) {
        preferences.deliveryMode = mode
        ScriptureNarrationPreferencesStore.save(preferences)
    }

    func setPlaybackSpeed(_ speed: ScriptureNarrationPlaybackSpeed) {
        playbackSpeed = speed
        engine.setPlaybackRate(speed.rawValue)
        ScriptureNarrationPreferencesStore.savePlaybackSpeed(speed)
    }

    func setSleepTimer(_ timer: ScriptureNarrationSleepTimer) {
        sleepTimerSelection = timer
        pauseSleepTimerCountdown()
        guard let duration = timer.duration else {
            sleepTimerRemainingSeconds = nil
            return
        }
        sleepTimerRemainingSeconds = Int(duration.rounded())
        resumeSleepTimerCountdownIfNeeded()
    }

    private func pauseSleepTimerCountdown() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
    }

    private func resumeSleepTimerCountdownIfNeeded() {
        pauseSleepTimerCountdown()
        guard sleepTimerSelection != .off,
              let remaining = sleepTimerRemainingSeconds,
              remaining > 0,
              snapshot.phase == .playing else { return }
        sleepTimerTask = Task { [weak self] in
            guard let self else { return }
            var left = remaining
            while !Task.isCancelled {
                while self.snapshot.phase != .playing && !Task.isCancelled {
                    self.sleepTimerRemainingSeconds = left
                    try? await Task.sleep(for: .milliseconds(250))
                }
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                guard self.snapshot.phase == .playing else { continue }
                left -= 1
                self.sleepTimerRemainingSeconds = max(0, left)
                if left <= 0 {
                    self.stop()
                    return
                }
            }
        }
    }

    var sleepTimerIsActive: Bool {
        sleepTimerRemainingSeconds != nil && sleepTimerSelection != .off
    }

    func availabilityMessage(forEditionID editionID: String) -> String? {
        guard ScriptureNarrationCatalog.supportsNarration(editionID: editionID) else {
            return "Narration is available for Berean Standard Bible (BSB) only."
        }
        return nil
    }

    /// Loads the reader's current BSB chapter into the player without starting playback.
    func prepareCurrentChapter() {
        guard let reader, let document = reader.document else { return }
        guard ScriptureNarrationCatalog.supportsNarration(editionID: document.editionID) else { return }
        if isLoadedChapter(document.book, document.chapter), hasPreparedPlaybackState {
            return
        }
        loadTask?.cancel()
        loadTask = Task { await loadChapter(document: document, edition: reader.edition, takeover: false, autoplay: false) }
    }

    private func isLoadedChapter(_ bookID: String, _ chapter: Int) -> Bool {
        snapshot.asset?.bookID == bookID && snapshot.asset?.chapter == chapter && loadedPackage != nil
    }

    private var hasPreparedPlaybackState: Bool {
        switch snapshot.phase {
        case .idle, .failed: return false
        default: return true
        }
    }

    func playCurrentChapter() {
        guard let reader, let document = reader.document else { return }
        guard ScriptureNarrationCatalog.supportsNarration(editionID: document.editionID) else { return }
        loadTask?.cancel()
        loadTask = Task { await loadChapter(document: document, edition: reader.edition, takeover: true, autoplay: true) }
    }

    /// When the reader chapter changes while the player is open, align the loaded asset (keeps playback if it was playing).
    func syncWithReaderChapterIfNeeded() {
        guard let reader, let document = reader.document else { return }
        guard ScriptureNarrationCatalog.supportsNarration(editionID: document.editionID) else { return }
        if snapshot.asset?.bookID == document.book, snapshot.asset?.chapter == document.chapter { return }
        let autoplay = snapshot.phase == .playing
        loadTask?.cancel()
        loadTask = Task { await loadChapter(document: document, edition: reader.edition, takeover: autoplay, autoplay: autoplay) }
    }

    func togglePlayPause() {
        switch snapshot.phase {
        case .playing:
            engine.pause()
            snapshot.phase = .paused
            pauseSleepTimerCountdown()
        case .paused, .ended:
            if snapshot.duration <= 0 || !engine.isLoaded {
                playWhenLoadCompletes = false
                playCurrentChapter()
                return
            }
            music?.pauseForNarration()
            engine.play(takeover: true)
            snapshot.phase = .playing
            resumeSleepTimerCountdownIfNeeded()
            syncHighlight(at: engine.currentTime)
        case .loading:
            playWhenLoadCompletes = true
        case .idle, .failed:
            playWhenLoadCompletes = false
            playCurrentChapter()
        default:
            break
        }
    }

    func nextVerse() {
        seekToAdjacentVerse(forward: true)
    }

    func previousVerse() {
        seekToAdjacentVerse(forward: false)
    }

    private func seekToAdjacentVerse(forward: Bool) {
        guard let timing = validatedTiming else { return }
        let current = playbackHighlightVerse
            ?? ScriptureNarrationTimingValidation.highlightedVerse(at: engine.currentTime, in: timing, duration: snapshot.duration)
        let targetVerse = forward
            ? ScriptureNarrationTimingValidation.nextVerse(after: current, in: timing)
            : ScriptureNarrationTimingValidation.previousVerse(before: current, in: timing)
        guard let targetVerse,
              let start = ScriptureNarrationTimingValidation.startTime(forVerse: targetVerse, in: timing) else { return }
        engine.seek(to: start)
        snapshot.elapsed = start
        syncHighlight(at: start)
        if snapshot.phase == .paused || snapshot.phase == .ended {
            music?.pauseForNarration()
            engine.play(takeover: true)
            snapshot.phase = .playing
            resumeSleepTimerCountdownIfNeeded()
        }
    }

    func stop() {
        loadTask?.cancel()
        playWhenLoadCompletes = false
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerRemainingSeconds = nil
        sleepTimerSelection = .off
        epoch = ScriptureNarrationOperationEpoch.fresh()
        engine.stop()
        validatedTiming = nil
        loadedPackage = nil
        chapterVerseNumbers = []
        playbackHighlightVerse = nil
        reader?.setPlaybackHighlight(nil)
        snapshot = ScriptureNarrationPlaybackSnapshot()
    }

    func seek(by delta: TimeInterval) {
        let target = max(0, min(engine.duration, engine.currentTime + delta))
        engine.seek(to: target)
        snapshot.elapsed = target
        syncHighlight(at: target)
    }

    func seek(to progress: Double) {
        guard engine.duration > 0 else { return }
        let target = max(0, min(engine.duration, progress * engine.duration))
        engine.seek(to: target)
        snapshot.elapsed = target
        syncHighlight(at: target)
    }

    func previousChapter() {
        guard let path = loadedPackage?.previousChapterPath else { return }
        navigateChapter(relativePath: path)
    }

    func nextChapter() {
        guard let path = loadedPackage?.nextChapterPath else { return }
        navigateChapter(relativePath: path)
    }

    private func navigateChapter(relativePath: String) {
        guard let reader else { return }
        let components = relativePath.split(separator: "/")
        guard components.count >= 4,
              let chapter = Int(components.last?.replacingOccurrences(of: ".json", with: "") ?? "") else { return }
        let bookID = String(components[components.count - 2])
        let autoplay = snapshot.phase == .playing
        loadTask?.cancel()
        loadTask = Task {
            if preferences.followAudio {
                await reader.navigate(book: bookID, chapter: chapter)
            }
            if let document = reader.document, document.book == bookID, document.chapter == chapter {
                await loadChapter(document: document, edition: reader.edition, takeover: autoplay, autoplay: autoplay)
                return
            }
            await loadChapter(
                bookID: bookID,
                chapter: chapter,
                readerEditionID: reader.document?.editionID,
                contentRevision: reader.document?.contentRevision ?? "",
                takeover: autoplay,
                autoplay: autoplay
            )
        }
    }

    private func loadChapter(
        bookID: String,
        chapter: Int,
        readerEditionID: String?,
        contentRevision: String,
        takeover: Bool,
        autoplay: Bool
    ) async {
        guard let aoTranslationID = ScriptureNarrationCatalog.aoTranslationID(forEditionID: ScriptureNarrationCatalog.bsbEditionID) else { return }
        let token = ScriptureNarrationOperationEpoch.fresh()
        epoch = token
        snapshot.phase = .loading
        let narratorID = preferences.preferredNarratorID
        let pseudoDocument = ChapterDocument(
            schemaVersion: 1,
            editionID: readerEditionID ?? ScriptureNarrationCatalog.bsbEditionID,
            contentRevision: contentRevision,
            book: bookID,
            chapter: chapter,
            blocks: []
        )
        if await chapterHasSavedAudio(
            aoTranslationID: aoTranslationID,
            bookID: bookID,
            chapter: chapter,
            narratorID: narratorID
        ) {
            chapterVerseNumbers = []
            await loadChapter(document: pseudoDocument, edition: nil, takeover: takeover, autoplay: autoplay, epochToken: token)
            return
        }
        do {
            chapterVerseNumbers = try await client.fetchVerseNumbers(
                translationID: aoTranslationID,
                bookID: bookID,
                chapter: chapter
            )
            await loadChapter(document: pseudoDocument, edition: nil, takeover: takeover, autoplay: autoplay, epochToken: token)
        } catch {
            guard epoch.id == token.id else { return }
            fail(narrationErrorMessage(error, attemptedLocal: false))
        }
    }

    private func loadChapter(document: ChapterDocument, edition: ScriptureEdition?, takeover: Bool, autoplay: Bool, epochToken: ScriptureNarrationOperationEpoch? = nil) async {
        guard let aoTranslationID = ScriptureNarrationCatalog.aoTranslationID(forEditionID: ScriptureNarrationCatalog.bsbEditionID) else { return }
        let token = epochToken ?? ScriptureNarrationOperationEpoch.fresh()
        if epochToken == nil { epoch = token }
        if autoplay { music?.pauseForNarration() }
        snapshot.phase = .loading
        let narratorID = preferences.preferredNarratorID
        do {
            try await resolveChapterVerseNumbers(
                aoTranslationID: aoTranslationID,
                document: document,
                narratorID: narratorID
            )
        } catch {
            guard epoch.id == token.id else { return }
            fail(narrationErrorMessage(error, attemptedLocal: false))
            return
        }

        let identity = ScriptureAudioAssetIdentity(
            sourceID: .helloAO,
            editionID: ScriptureNarrationCatalog.bsbEditionID,
            referenceSystemID: ScriptureReferenceIdentity.referenceSystemID(forEditionID: ScriptureNarrationCatalog.bsbEditionID) ?? "org.sophia.helloao.BSB",
            contentRevision: document.contentRevision,
            aoTranslationID: aoTranslationID,
            bookID: document.book,
            chapter: document.chapter,
            narratorID: narratorID,
            recordingRevision: edition?.contentRevision ?? document.contentRevision,
            rightsPolicyID: ScriptureNarrationCatalog.rightsPolicyID
        )
        snapshot.asset = identity
        snapshot.editionDisplayName = ScriptureNarrationCatalog.bsbDisplayName
        snapshot.narratorDisplayName = ScriptureNarrationNarrator(rawValue: narratorID)?.displayName ?? narratorID

        var skipLocalFiles = false
        var retriedAfterLocalFailure = false
        for attempt in 0..<2 {
            do {
                let (package, playbackURL, usesLocal) = try await resolvePlaybackMedia(
                    aoTranslationID: aoTranslationID,
                    bookID: document.book,
                    chapter: document.chapter,
                    narratorID: narratorID,
                    skipLocalFiles: skipLocalFiles
                )
                guard epoch.id == token.id else { return }
                loadedPackage = package
                snapshot.usesLocalAudio = usesLocal
                if var asset = snapshot.asset {
                    asset = ScriptureAudioAssetIdentity(
                        sourceID: asset.sourceID,
                        editionID: asset.editionID,
                        referenceSystemID: asset.referenceSystemID,
                        contentRevision: asset.contentRevision,
                        aoTranslationID: asset.aoTranslationID,
                        bookID: asset.bookID,
                        chapter: asset.chapter,
                        narratorID: asset.narratorID,
                        recordingRevision: package.translationSHA256 ?? asset.recordingRevision,
                        rightsPolicyID: usesLocal
                            ? ScriptureNarrationCatalog.offlineRightsPolicyID
                            : ScriptureNarrationCatalog.streamingRightsPolicyID
                    )
                    snapshot.asset = asset
                }
                try await engine.load(url: playbackURL, takeover: takeover || attempt > 0)
                guard epoch.id == token.id else { return }
                engine.setPlaybackRate(playbackSpeed.rawValue)

                snapshot.duration = engine.duration
                applyTimingValidation(package: package, document: document)
                let shouldPlay = autoplay || playWhenLoadCompletes
                playWhenLoadCompletes = false
                if shouldPlay {
                    music?.pauseForNarration()
                    engine.play(takeover: true)
                    snapshot.phase = .playing
                    resumeSleepTimerCountdownIfNeeded()
                    snapshot.elapsed = engine.currentTime
                    syncHighlight(at: engine.currentTime)
                    maybeFollowReader(to: document)
                } else {
                    engine.pause()
                    snapshot.phase = .paused
                    snapshot.elapsed = 0
                    syncHighlight(at: 0)
                }
                return
            } catch {
                guard epoch.id == token.id else { return }
                if attempt == 0, !skipLocalFiles, !retriedAfterLocalFailure {
                    retriedAfterLocalFailure = true
                    skipLocalFiles = true
                    continue
                }
                fail(narrationErrorMessage(error, attemptedLocal: retriedAfterLocalFailure))
                return
            }
        }
    }

    private func resolvePlaybackMedia(
        aoTranslationID: String,
        bookID: String,
        chapter: Int,
        narratorID: String,
        skipLocalFiles: Bool = false
    ) async throws -> (HelloAOChapterNarrationPackage, URL, Bool) {
        if !skipLocalFiles,
           await mediaStore.localAudioURL(
            aoTranslationID: aoTranslationID,
            narratorID: narratorID,
            bookID: bookID,
            chapter: chapter
        ) != nil {
            let local = try await mediaStore.localPlaybackPackage(
                aoTranslationID: aoTranslationID,
                narratorID: narratorID,
                bookID: bookID,
                chapter: chapter
            )
            return (local.0, local.1, true)
        }

        let remotePackage = try await client.fetchChapterNarration(
            translationID: aoTranslationID,
            bookID: bookID,
            chapter: chapter,
            narratorID: narratorID
        )

        switch preferences.deliveryMode {
        case .streaming:
            return (remotePackage, remotePackage.audioURL, false)
        case .saveForOffline:
            let fileURL = try await mediaStore.ensureLocalPlaybackURL(
                remotePackage: remotePackage,
                aoTranslationID: aoTranslationID,
                narratorID: narratorID,
                bookID: bookID,
                chapter: chapter
            )
            let savedPackage = HelloAOChapterNarrationPackage(
                audioURL: fileURL,
                timingStartTimes: remotePackage.timingStartTimes,
                nextChapterPath: remotePackage.nextChapterPath,
                previousChapterPath: remotePackage.previousChapterPath,
                translationSHA256: remotePackage.translationSHA256
            )
            return (savedPackage, fileURL, true)
        }
    }

    private func chapterHasSavedAudio(
        aoTranslationID: String,
        bookID: String,
        chapter: Int,
        narratorID: String
    ) async -> Bool {
        await mediaStore.localAudioURL(
            aoTranslationID: aoTranslationID,
            narratorID: narratorID,
            bookID: bookID,
            chapter: chapter
        ) != nil
    }

    private func resolveChapterVerseNumbers(
        aoTranslationID: String,
        document: ChapterDocument,
        narratorID: String
    ) async throws {
        let offlineVerses = ScriptureNarrationTimingValidation.verseNumbers(from: document)
        if await chapterHasSavedAudio(
            aoTranslationID: aoTranslationID,
            bookID: document.book,
            chapter: document.chapter,
            narratorID: narratorID
        ), !offlineVerses.isEmpty {
            chapterVerseNumbers = offlineVerses
            return
        }
        do {
            chapterVerseNumbers = try await client.fetchVerseNumbers(
                translationID: aoTranslationID,
                bookID: document.book,
                chapter: document.chapter
            )
        } catch {
            if offlineVerses.isEmpty {
                throw error
            }
            chapterVerseNumbers = offlineVerses
        }
    }

    private func applyTimingValidation(package: HelloAOChapterNarrationPackage, document: ChapterDocument) {
        let readerMatches = document.editionID == ScriptureNarrationCatalog.bsbEditionID
        guard readerMatches else {
            validatedTiming = nil
            engine.clearVerseBoundaryObservers()
            snapshot.highlightingAvailable = false
            snapshot.highlightingStatusMessage = "Highlighting unavailable while reading a different translation."
            return
        }
        guard let starts = package.timingStartTimes else {
            validatedTiming = nil
            engine.clearVerseBoundaryObservers()
            snapshot.highlightingAvailable = false
            snapshot.highlightingStatusMessage = "Highlighting unavailable"
            return
        }
        switch ScriptureNarrationTimingValidation.validate(
            startTimes: starts,
            verseNumbers: chapterVerseNumbers,
            duration: engine.duration > 0 ? engine.duration : nil
        ) {
        case .success(let validated):
            validatedTiming = validated
            snapshot.highlightingAvailable = true
            snapshot.highlightingStatusMessage = nil
            engine.installVerseBoundaryObservers(validated.verseStarts) { [weak self] verse in
                self?.applyPlaybackHighlight(verse: verse)
            }
        case .failure:
            validatedTiming = nil
            engine.clearVerseBoundaryObservers()
            snapshot.highlightingAvailable = false
            snapshot.highlightingStatusMessage = "Highlighting unavailable"
        }
    }

    private func handlePeriodicTime(_ time: TimeInterval) {
        snapshot.elapsed = time
        if engine.duration > 0 { snapshot.duration = engine.duration }
    }

    private func applyPlaybackHighlight(verse: Int?) {
        guard playbackHighlightVerse != verse else { return }
        playbackHighlightVerse = verse
        reader?.setPlaybackHighlight(verse)
    }

    private func syncHighlight(at time: TimeInterval) {
        guard snapshot.highlightingAvailable, let timing = validatedTiming else {
            applyPlaybackHighlight(verse: nil)
            return
        }
        let verse = ScriptureNarrationTimingValidation.highlightedVerse(
            at: time,
            in: timing,
            duration: snapshot.duration
        )
        applyPlaybackHighlight(verse: verse)
    }

    private func handlePlaybackEnded() {
        snapshot.phase = .ended
        snapshot.elapsed = snapshot.duration
        syncHighlight(at: snapshot.duration)
        if preferences.continuousChapters, loadedPackage?.nextChapterPath != nil {
            nextChapter()
        }
    }

    private func fail(_ message: String) {
        engine.stop()
        loadedPackage = nil
        validatedTiming = nil
        snapshot.phase = .failed(message)
        playbackHighlightVerse = nil
        reader?.setPlaybackHighlight(nil)
    }

    private func narrationErrorMessage(_ error: Error, attemptedLocal: Bool) -> String {
        let description = error.localizedDescription
        if description.localizedCaseInsensitiveContains("offline")
            || description.localizedCaseInsensitiveContains("not connected to the internet") {
            if attemptedLocal {
                return "This saved chapter could not be played. Re-download BSB audio in Translation downloads, or connect to the internet to stream."
            }
            return "You're offline and this chapter isn't saved on this iPad. Download BSB audio in Translation downloads while online."
        }
        if description.localizedCaseInsensitiveContains("cannot open") {
            return "This chapter audio could not be opened. Re-download BSB audio in Translation downloads, or switch to Stream when online in Settings."
        }
        if let media = error as? ScriptureNarrationMediaError {
            return media.localizedDescription
        }
        if let narration = error as? HelloAOChapterNarrationError {
            return narration.localizedDescription
        }
        return description
    }

    private func maybeFollowReader(to document: ChapterDocument) {
        guard preferences.followAudio, let reader else { return }
        guard reader.document?.editionID == ScriptureNarrationCatalog.bsbEditionID else {
            followSuspendedReason = "Follow paused — reader shows a different translation."
            return
        }
        if reader.document?.book != document.book || reader.document?.chapter != document.chapter {
            followSuspendedReason = nil
            Task { await reader.navigate(book: document.book, chapter: document.chapter) }
        }
    }

    func returnToAudioChapter() {
        guard let asset = snapshot.asset, let reader else { return }
        followSuspendedReason = nil
        Task { await reader.navigate(book: asset.bookID, chapter: asset.chapter) }
    }
}
