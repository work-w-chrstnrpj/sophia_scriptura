import Foundation

/// Immutable timer state for Lock Screen / Live Activity presentation. Not persisted as study data.
struct ActivitySystemProjection: Equatable, Sendable {
    let draftID: UUID
    let revision: UInt64
    let accumulatedSeconds: TimeInterval
    let runningSince: Date?

    var isRunning: Bool { runningSince != nil }

    func elapsed(at now: Date) -> TimeInterval {
        let running = runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return max(0, accumulatedSeconds + running)
    }

    static func from(draft: ActivityDraft?, revision: UInt64) -> ActivitySystemProjection? {
        guard let draft else { return nil }
        let accumulated = draft.intervals.reduce(0) { $0 + $1.seconds }
        return ActivitySystemProjection(
            draftID: draft.id,
            revision: revision,
            accumulatedSeconds: accumulated,
            runningSince: draft.runningSince
        )
    }
}

enum ActivitySystemProjectionBuilder {
    static func from(snapshot: ActivitySnapshot, revision: UInt64) -> ActivitySystemProjection? {
        ActivitySystemProjection.from(draft: snapshot.draft, revision: revision)
    }
}
