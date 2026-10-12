import Foundation

@MainActor
final class MusicSession: ObservableObject {
    @Published private(set) var bundledCatalog: MusicCatalog?
    @Published private(set) var userTracks: [MusicTrackDefinition] = []
    @Published private(set) var preferences = MusicPreferences.initial
    @Published private(set) var snapshot = MusicPlaybackSnapshot.initial
    @Published var loadError: String?

    private let engine = BackgroundMusicEngine()
    private var coordinator = StudyAudioCoordinator()
    private let nowPlaying = MusicNowPlayingCoordinator()
    private let userLibrary: UserMusicLibraryStore
    private var loaded = false
    private var canAdvance = false

    init(userLibrary: UserMusicLibraryStore = .default()) {
        self.userLibrary = userLibrary
        engine.delegate = self
        engine.installObservers()
        nowPlaying.attach(handler: self)
    }

    var tracks: [MusicTrackDefinition] {
        let bundled = bundledCatalog?.tracks ?? []
        let merged = bundled + userTracks
        return merged.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var bundledTracks: [MusicTrackDefinition] { bundledCatalog?.tracks ?? [] }

    var currentTrack: MusicTrackDefinition? {
        guard let id = snapshot.selectedTrackID else { return nil }
        return track(id: id)
    }

    var showsNowActiveItem: Bool { snapshot.hasStartedPlayback && snapshot.selectedTrackID != nil }

    func load() {
        guard !loaded else { return }
        do {
            bundledCatalog = try MusicCatalog.bundled()
            userTracks = try userLibrary.loadTracks()
            preferences = MusicPreferencesStore.load()
            if let id = preferences.selectedTrackID, track(id: id) == nil {
                preferences.selectedTrackID = nil
                MusicPreferencesStore.save(preferences)
            }
            snapshot.selectedTrackID = preferences.selectedTrackID
            snapshot.loopAll = preferences.loopAll
            snapshot.phase = .idle
            snapshot.hasStartedPlayback = false
            loaded = true
        } catch {
            loadError = "Background music could not load: \(error.localizedDescription)"
        }
    }

    func setPictureInPictureActive(_ active: Bool) {
        engine.keepsAudioSessionForPiP = active
        if !active { engine.releaseAudioSessionIfIdle() }
    }

    func setShowFloatingControl(_ visible: Bool) {
        var next = preferences
        next.showFloatingControl = visible
        preferences = next
        MusicPreferencesStore.save(preferences)
    }

    func importUserTrack(from url: URL) {
        do {
            let track = try userLibrary.importFile(from: url)
            userTracks = try userLibrary.loadTracks()
            loadError = nil
            selectTrack(track.id, autoplay: true)
        } catch {
            loadError = importErrorMessage(for: error)
        }
    }

    func deleteUserTrack(id: String) {
        do {
            try userLibrary.deleteTrack(id: id)
            userTracks = try userLibrary.loadTracks()
            if snapshot.selectedTrackID == id {
                engine.stop()
                preferences.selectedTrackID = nil
                snapshot.selectedTrackID = nil
                snapshot.phase = .idle
                snapshot.hasStartedPlayback = false
                MusicPreferencesStore.save(preferences)
                syncNowPlaying()
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func renameUserTrack(id: String, title: String) {
        do {
            try userLibrary.renameTrack(id: id, title: title)
            userTracks = try userLibrary.loadTracks()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func replaceUserTrackFile(id: String, from url: URL) {
        do {
            try userLibrary.replaceTrackFile(id: id, from: url)
            userTracks = try userLibrary.loadTracks()
            loadError = nil
            if snapshot.selectedTrackID == id, snapshot.phase == .playing {
                play(takeover: true)
            }
        } catch {
            loadError = importErrorMessage(for: error)
        }
    }

    func containsApprovedTrack(_ id: String) -> Bool {
        track(id: id) != nil
    }

    func selectApprovedTrack(_ id: String) -> Bool {
        guard track(id: id) != nil else { return false }
        selectTrack(id, autoplay: false)
        return true
    }

    func handle(_ command: MusicCommand) {
        switch command {
        case .selectTrack(let id):
            selectTrack(id, autoplay: true)
        case .play:
            play(takeover: true)
        case .pause:
            pause(userInitiated: true)
        case .togglePlayPause:
            if snapshot.phase == .playing { pause(userInitiated: true) } else { play(takeover: true) }
        case .next:
            advanceTrack()
        case .setLoopAll(let value):
            preferences.loopAll = value
            snapshot.loopAll = value
            MusicPreferencesStore.save(preferences)
        case .clear:
            clearPlayback()
        }
    }

    private func track(id: String) -> MusicTrackDefinition? {
        bundledCatalog?.track(id: id) ?? userTracks.first { $0.id == id }
    }

    private func fileURL(for track: MusicTrackDefinition) -> URL? {
        if track.isUserLibrary { return userLibrary.fileURL(for: track.id) }
        return bundledCatalog?.fileURL(for: track)
    }

    private func selectTrack(_ id: String, autoplay: Bool) {
        guard track(id: id) != nil else { return }
        engine.stop()
        preferences.selectedTrackID = id
        snapshot.selectedTrackID = id
        snapshot.phase = .idle
        MusicPreferencesStore.save(preferences)
        refreshAdvanceEligibility()
        if autoplay { play(takeover: true) } else { syncNowPlaying() }
    }

    private func play(takeover: Bool) {
        guard let track = currentTrack, let url = fileURL(for: track) else { return }
        coordinator.willStartMusic(takeover: takeover)
        do {
            if engine.preparedFileURL != url || !engine.hasPreparedPlayer {
                try engine.prepare(url: url)
            }
            try engine.play(takeover: takeover)
            snapshot.hasStartedPlayback = true
            snapshot.phase = .playing
            loadError = nil
            refreshAdvanceEligibility()
            syncNowPlaying()
        } catch {
            loadError = "Playback failed: \(error.localizedDescription)"
            snapshot.phase = .paused
            syncNowPlaying()
        }
    }

    private func pause(userInitiated: Bool) {
        engine.pause()
        snapshot.phase = userInitiated ? .paused : .interrupted
        syncNowPlaying()
    }

    private func advanceTrack() {
        guard let currentID = snapshot.selectedTrackID else { return }
        let wasPlaying = snapshot.phase == .playing
        if let nextID = MusicTrackDefinition.nextTrackID(in: tracks, after: currentID, loopAll: snapshot.loopAll) {
            selectTrack(nextID, autoplay: false)
            refreshAdvanceEligibility()
            if wasPlaying { play(takeover: false) } else { syncNowPlaying() }
        } else {
            engine.stop()
            snapshot.phase = .paused
            canAdvance = false
            syncNowPlaying()
        }
    }

    private func clearPlayback() {
        engine.stop()
        preferences.selectedTrackID = nil
        snapshot = MusicPlaybackSnapshot(selectedTrackID: nil, loopAll: preferences.loopAll, phase: .idle, hasStartedPlayback: false)
        MusicPreferencesStore.save(preferences)
        canAdvance = false
        nowPlaying.clearMetadata()
    }

    private func refreshAdvanceEligibility() {
        guard let currentID = snapshot.selectedTrackID else { canAdvance = false; return }
        canAdvance = MusicTrackDefinition.nextTrackID(in: tracks, after: currentID, loopAll: snapshot.loopAll) != nil
    }

    private func syncNowPlaying() {
        guard snapshot.hasStartedPlayback, let track = currentTrack else {
            nowPlaying.clearMetadata()
            return
        }
        let duration = engine.duration
        let elapsed = duration > 0 ? min(engine.currentTime, duration) : engine.currentTime
        let playing = snapshot.phase == .playing && engine.isPlaying
        nowPlaying.apply(MusicNowPlayingSnapshot(
            title: track.title,
            duration: duration,
            elapsed: elapsed,
            rate: playing ? 1 : 0,
            canPlay: snapshot.phase != .playing,
            canPause: snapshot.phase == .playing,
            canNext: canAdvance
        ))
    }

    func pauseForNarration() {
        guard snapshot.phase == .playing else { return }
        pause(userInitiated: false)
    }

    func attachStudyAudio(_ coordinator: StudyAudioCoordinator) {
        self.coordinator = coordinator
    }

    private func importErrorMessage(for error: Error) -> String {
        if let catalogError = error as? MusicCatalogError {
            switch catalogError {
            case .unsupportedAudioFormat:
                return "That file type is not supported. Use M4A, MP3, WAV, AAC, CAF, or AIFF."
            case .importAccessDenied:
                return "Sophia could not read that file. Try downloading it to Files first, then import again."
            default:
                break
            }
        }
        return "Import failed: \(error.localizedDescription)"
    }
}

extension MusicSession: BackgroundMusicEngineDelegate {
    func backgroundMusicEngineDidFinishTrack(_ engine: BackgroundMusicEngine) {
        if let currentID = snapshot.selectedTrackID,
           let nextID = MusicTrackDefinition.nextTrackID(in: tracks, after: currentID, loopAll: snapshot.loopAll) {
            selectTrack(nextID, autoplay: false)
            play(takeover: false)
        } else {
            engine.stop()
            snapshot.phase = .paused
            canAdvance = false
            syncNowPlaying()
        }
    }

    func backgroundMusicEngineWasInterrupted(_ engine: BackgroundMusicEngine) {
        snapshot.phase = .interrupted
        syncNowPlaying()
    }
}

extension MusicSession: MusicNowPlayingCommandHandling {
    func handleNowPlayingCommand(_ command: MusicCommand) {
        handle(command)
    }
}
