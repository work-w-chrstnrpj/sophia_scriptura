import Observation

/// Transient shell presentation. Activity extends one deadline without restarting a task
/// for every scroll frame; the countdown uses monotonic time and stops offscreen.
@MainActor
@Observable
final class ShellChromeState {
    nonisolated static let visibilityDelay: Duration = .seconds(3)
    private(set) var isVisible = true
    /// Reading surfaces let the dock fade away; library tabs pin it so it never disappears
    /// from a screen that has nothing to scroll.
    var autoHides = true {
        didSet {
            guard autoHides != oldValue else { return }
            if autoHides { reveal() } else { pin() }
        }
    }
    @ObservationIgnored private var deadline: ContinuousClock.Instant?
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private let clock = ContinuousClock()
    @ObservationIgnored private let delay: Duration

    init(delay: Duration = ShellChromeState.visibilityDelay) { self.delay = delay }

    func hideImmediately() {
        hideTask?.cancel()
        hideTask = nil
        deadline = nil
        isVisible = false
    }

    func reveal() {
        isVisible = true
        guard autoHides else { return }
        deadline = clock.now.advanced(by: delay)
        guard hideTask == nil else { return }
        hideTask = Task { [weak self] in
            while let target = self?.deadline {
                do { try await ContinuousClock().sleep(until: target) }
                catch { return }
                guard let self, !Task.isCancelled else { return }
                if let latest = self.deadline, self.clock.now >= latest {
                    self.isVisible = false
                    self.deadline = nil
                    self.hideTask = nil
                    return
                }
            }
        }
    }

    private func pin() {
        hideTask?.cancel()
        hideTask = nil
        deadline = nil
        isVisible = true
    }

    func stop() {
        hideTask?.cancel()
        hideTask = nil
        deadline = nil
    }
}
