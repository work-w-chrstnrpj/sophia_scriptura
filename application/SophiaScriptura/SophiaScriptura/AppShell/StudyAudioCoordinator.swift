import Foundation

/// M7 narration will adopt this surface; SP-021 uses a no-op stub until narration ships.
protocol ScriptureNarrationControlling: AnyObject {
    var isNarrationActive: Bool { get }
    func pauseNarrationForMusic()
}

final class NullScriptureNarrationController: ScriptureNarrationControlling {
    var isNarrationActive: Bool { false }
    func pauseNarrationForMusic() {}
}

final class StudyAudioCoordinator {
    var narration: ScriptureNarrationControlling

    init(narration: ScriptureNarrationControlling = NullScriptureNarrationController()) {
        self.narration = narration
    }

    func willStartMusic(takeover: Bool) {
        if narration.isNarrationActive {
            narration.pauseNarrationForMusic()
        }
        _ = takeover
    }
}
