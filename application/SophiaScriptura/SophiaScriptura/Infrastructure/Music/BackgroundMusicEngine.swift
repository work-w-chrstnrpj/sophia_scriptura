import AVFoundation
import Foundation

@MainActor
protocol BackgroundMusicEngineDelegate: AnyObject {
    func backgroundMusicEngineDidFinishTrack(_ engine: BackgroundMusicEngine)
    func backgroundMusicEngineWasInterrupted(_ engine: BackgroundMusicEngine)
}

final class BackgroundMusicEngine: NSObject {
    @MainActor weak var delegate: BackgroundMusicEngineDelegate?
    private var player: AVAudioPlayer?
    private var observers: [NSObjectProtocol] = []

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    @MainActor
    func installObservers() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] note in
                Task { @MainActor in self?.handleInterruption(note) }
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance(), queue: .main) { [weak self] note in
                Task { @MainActor in self?.handleRouteChange(note) }
            }
        ]
    }

    @MainActor var isPlaying: Bool { player?.isPlaying == true }

    @MainActor
    func prepare(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
    }

    @MainActor
    func play(takeover: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true, options: takeover ? .notifyOthersOnDeactivation : [])
        guard player?.play() == true else { throw MusicCatalogError.missingTrackFile(trackID: urlLabel) }
    }

    @MainActor
    func pause() {
        player?.pause()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    @MainActor
    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    @MainActor private var urlLabel: String { player?.url?.lastPathComponent ?? "unknown" }

    @MainActor
    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            player?.pause()
            delegate?.backgroundMusicEngineWasInterrupted(self)
        case .ended:
            break
        @unknown default:
            break
        }
    }

    @MainActor
    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        if reason == .oldDeviceUnavailable {
            player?.pause()
            delegate?.backgroundMusicEngineWasInterrupted(self)
        }
    }
}

extension BackgroundMusicEngine: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            delegate?.backgroundMusicEngineDidFinishTrack(self)
        }
    }
}
