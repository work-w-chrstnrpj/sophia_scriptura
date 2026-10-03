import Foundation

@MainActor
final class MusicSession: ObservableObject {
    @Published private(set) var bundledCatalog: MusicCatalog?
    @Published private(set) var userTracks: [MusicTrackDefinition] = []
    @Published private(set) var preferences = MusicPreferences.initial
    @Published private(set) var snapshot = MusicPlaybackSnapshot.initial
    @Published var loadError: String?

    private let engine = BackgroundMusicEngine()
    private let coordinator = StudyAudioCoordinator()
    private let userLibrary: UserMusicLibraryStore
    private var loaded = false

    init(userLibrary: UserMusicLibraryStore = .default()) {
        self.userLibrary = userLibrary
        engine.delegate = self
        engine.installObservers()
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
        if autoplay { play(takeover: true) }
    }

    private func play(takeover: Bool) {
        guard let track = currentTrack, let url = fileURL(for: track) else { return }
        coordinator.willStartMusic(takeover: takeover)
        do {
            try engine.prepare(url: url)
            try engine.play(takeover: takeover)
            snapshot.hasStartedPlayback = true
            snapshot.phase = .playing
            loadError = nil
        } catch {
            loadError = "Playback failed: \(error.localizedDescription)"
            snapshot.phase = .paused
        }
    }

    private func pause(userInitiated: Bool) {
        engine.pause()
        snapshot.phase = userInitiated ? .paused : .interrupted
    }

    private func advanceTrack() {
        guard let currentID = snapshot.selectedTrackID else { return }
        if let nextID = MusicTrackDefinition.nextTrackID(in: tracks, after: currentID, loopAll: snapshot.loopAll) {
            selectTrack(nextID, autoplay: snapshot.phase == .playing)
            if snapshot.phase == .playing { play(takeover: false) }
        } else {
            engine.stop()
            snapshot.phase = .paused
        }
    }

    private func clearPlayback() {
        engine.stop()
        preferences.selectedTrackID = nil
        snapshot = MusicPlaybackSnapshot(selectedTrackID: nil, loopAll: preferences.loopAll, phase: .idle, hasStartedPlayback: false)
        MusicPreferencesStore.save(preferences)
    }

    func pauseForNarration() {
        guard snapshot.phase == .playing else { return }
        pause(userInitiated: false)
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
            selectTrack(nextID, autoplay: true)
            play(takeover: false)
        } else {
            engine.stop()
            snapshot.phase = .paused
        }
    }

    func backgroundMusicEngineWasInterrupted(_ engine: BackgroundMusicEngine) {
        snapshot.phase = .interrupted
    }
}
