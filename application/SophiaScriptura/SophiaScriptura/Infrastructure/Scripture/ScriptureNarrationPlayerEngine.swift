import AVFoundation
import Foundation

@MainActor
final class ScriptureNarrationPlayerEngine {
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var verseBoundaryObservers: [Any] = []
    private var endObserver: NSObjectProtocol?
    var onPeriodicTime: ((TimeInterval) -> Void)?
    var onEnded: (() -> Void)?
    var onFailed: ((String) -> Void)?

    var currentTime: TimeInterval {
        guard let item = player?.currentItem else { return 0 }
        let seconds = item.currentTime().seconds
        return seconds.isFinite ? max(0, seconds) : 0
    }

    var duration: TimeInterval {
        guard let item = player?.currentItem else { return 0 }
        let seconds = item.duration.seconds
        return seconds.isFinite && seconds > 0 ? seconds : 0
    }

    private(set) var playbackRate: Float = 1

    var isPlaying: Bool {
        guard let player else { return false }
        return player.rate > 0.01
    }
    var isLoaded: Bool { player?.currentItem != nil }

    func setPlaybackRate(_ rate: Float) {
        let clamped = max(0.5, min(3, rate))
        playbackRate = clamped
        if isPlaying {
            player?.rate = clamped
        }
    }

    func load(url: URL, takeover: Bool) async throws {
        tearDownObservers()
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        player?.defaultRate = playbackRate
        installObservers(on: item)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [])
        try session.setActive(true, options: takeover ? .notifyOthersOnDeactivation : [])
        try await waitUntilReady(item)
    }

    func play(takeover: Bool = true) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true, options: takeover ? .notifyOthersOnDeactivation : [])
        player?.playImmediately(atRate: playbackRate)
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        tearDownObservers()
        player?.pause()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Fires when playback crosses each verse start time (sample-accurate; not polling).
    func installVerseBoundaryObservers(
        _ verseStarts: [(verse: Int, start: TimeInterval)],
        handler: @escaping (Int) -> Void
    ) {
        clearVerseBoundaryObservers()
        guard let player else { return }
        for pair in verseStarts where pair.start > 0.001 {
            let boundary = NSValue(time: CMTime(seconds: pair.start, preferredTimescale: 1000))
            let verse = pair.verse
            let token = player.addBoundaryTimeObserver(forTimes: [boundary], queue: .main) {
                handler(verse)
            }
            verseBoundaryObservers.append(token)
        }
    }

    func clearVerseBoundaryObservers() {
        guard let player else {
            verseBoundaryObservers.removeAll()
            return
        }
        for token in verseBoundaryObservers {
            player.removeTimeObserver(token)
        }
        verseBoundaryObservers.removeAll()
    }

    func seek(to seconds: TimeInterval) {
        let clamped = max(0, seconds)
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        onPeriodicTime?(clamped)
    }

    private func waitUntilReady(_ item: AVPlayerItem) async throws {
        if item.status == .readyToPlay, item.duration.seconds.isFinite, item.duration.seconds > 0 { return }
        for _ in 0..<240 {
            if item.status == .failed {
                throw NSError(
                    domain: "ScriptureNarrationPlayerEngine",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: item.error?.localizedDescription ?? "Playback failed."]
                )
            }
            if item.status == .readyToPlay {
                let seconds = item.duration.seconds
                if seconds.isFinite, seconds > 0 { return }
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw NSError(
            domain: "ScriptureNarrationPlayerEngine",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Audio took too long to load."]
        )
    }

    private func installObservers(on item: AVPlayerItem) {
        guard let player else { return }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.onPeriodicTime?(self.currentTime)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onEnded?() }
        }
    }

    private func tearDownObservers() {
        clearVerseBoundaryObservers()
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }
}
