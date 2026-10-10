import Foundation
import MediaPlayer

struct MusicNowPlayingSnapshot: Equatable {
    var title: String
    var duration: TimeInterval
    var elapsed: TimeInterval
    var rate: Double
    var canPlay: Bool
    var canPause: Bool
    var canNext: Bool
}

protocol MusicNowPlayingCommandHandling: AnyObject {
    func handleNowPlayingCommand(_ command: MusicCommand)
}

@MainActor
final class MusicNowPlayingCoordinator {
    private weak var handler: MusicNowPlayingCommandHandling?
    private var installed = false
    private var playTarget: Any?
    private var pauseTarget: Any?
    private var toggleTarget: Any?
    private var nextTarget: Any?

    func attach(handler: MusicNowPlayingCommandHandling) {
        self.handler = handler
        installIfNeeded()
    }

    func detach() {
        clearMetadata()
        setCommandsEnabled(play: false, pause: false, toggle: false, next: false)
        removeHandlers()
        installed = false
    }

    func apply(_ snapshot: MusicNowPlayingSnapshot) {
        installIfNeeded()
        if snapshot.title.isEmpty || (!snapshot.canPlay && !snapshot.canPause && snapshot.rate == 0 && snapshot.duration <= 0) {
            clearMetadata()
            setCommandsEnabled(play: false, pause: false, toggle: false, next: false)
            return
        }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = snapshot.title
        if snapshot.duration.isFinite, snapshot.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = snapshot.duration
            let elapsed = min(max(0, snapshot.elapsed), snapshot.duration)
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        } else if snapshot.elapsed.isFinite, snapshot.elapsed > 0 {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = snapshot.elapsed
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = snapshot.rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        setCommandsEnabled(play: snapshot.canPlay, pause: snapshot.canPause, toggle: snapshot.canPlay || snapshot.canPause, next: snapshot.canNext)
    }

    func clearMetadata() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func installIfNeeded() {
        guard !installed else { return }
        installed = true
        let center = MPRemoteCommandCenter.shared()
        playTarget = center.playCommand.addTarget { [weak self] _ in self?.dispatch(.play) ?? .commandFailed }
        pauseTarget = center.pauseCommand.addTarget { [weak self] _ in self?.dispatch(.pause) ?? .commandFailed }
        toggleTarget = center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.dispatch(.togglePlayPause) ?? .commandFailed }
        nextTarget = center.nextTrackCommand.addTarget { [weak self] _ in self?.dispatch(.next) ?? .commandFailed }
        center.previousTrackCommand.isEnabled = false
        center.seekForwardCommand.isEnabled = false
        center.seekBackwardCommand.isEnabled = false
        center.changePlaybackRateCommand.isEnabled = false
        center.ratingCommand.isEnabled = false
        center.likeCommand.isEnabled = false
        center.dislikeCommand.isEnabled = false
        center.bookmarkCommand.isEnabled = false
    }

    private func removeHandlers() {
        let center = MPRemoteCommandCenter.shared()
        if let playTarget { center.playCommand.removeTarget(playTarget) }
        if let pauseTarget { center.pauseCommand.removeTarget(pauseTarget) }
        if let toggleTarget { center.togglePlayPauseCommand.removeTarget(toggleTarget) }
        if let nextTarget { center.nextTrackCommand.removeTarget(nextTarget) }
        playTarget = nil
        pauseTarget = nil
        toggleTarget = nil
        nextTarget = nil
    }

    private func setCommandsEnabled(play: Bool, pause: Bool, toggle: Bool, next: Bool) {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = play
        center.pauseCommand.isEnabled = pause
        center.togglePlayPauseCommand.isEnabled = toggle
        center.nextTrackCommand.isEnabled = next
    }

    private func dispatch(_ command: MusicCommand) -> MPRemoteCommandHandlerStatus {
        guard let handler else { return .commandFailed }
        handler.handleNowPlayingCommand(command)
        return .success
    }
}
