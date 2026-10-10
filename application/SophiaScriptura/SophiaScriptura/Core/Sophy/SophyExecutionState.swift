import Foundation

enum SophySessionPhase: Equatable, Sendable {
    case idle
    case interpreting
    case clarifying
    case previewing
    case committing
    case answering
    case enhancing
    case completed
    case partiallyCompleted
    case failed
    case cancelled
    case uncertain
}

enum SophyPhaseEvent: Equatable, Sendable {
    case send
    case enhance
    case clarify
    case preview
    case answer
    case confirm
    case succeed
    case partial
    case fail
    case cancel
    case uncertain
    case reset
}

enum SophyExecutionState {
    static func transition(_ phase: SophySessionPhase, _ event: SophyPhaseEvent) -> SophySessionPhase? {
        switch (phase, event) {
        case (.idle, .send):
            return .interpreting
        case (.idle, .enhance):
            return .enhancing
        case (.interpreting, .clarify):
            return .clarifying
        case (.interpreting, .preview):
            return .previewing
        case (.interpreting, .answer):
            return .answering
        case (.interpreting, .fail):
            return .failed
        case (.interpreting, .cancel):
            return .cancelled
        case (.clarifying, .send):
            return .interpreting
        case (.clarifying, .cancel):
            return .cancelled
        case (.previewing, .confirm):
            return .committing
        case (.previewing, .send):
            return .interpreting
        case (.previewing, .cancel):
            return .cancelled
        case (.committing, .succeed):
            return .completed
        case (.committing, .partial):
            return .partiallyCompleted
        case (.committing, .fail):
            return .failed
        case (.committing, .uncertain):
            return .uncertain
        case (.answering, .succeed), (.enhancing, .succeed):
            return .completed
        case (.answering, .fail), (.enhancing, .fail):
            return .failed
        case (.answering, .cancel), (.enhancing, .cancel):
            return .cancelled
        case (.completed, .send), (.partiallyCompleted, .send), (.failed, .send), (.cancelled, .send), (.uncertain, .send):
            return .interpreting
        case (.completed, .reset), (.partiallyCompleted, .reset), (.failed, .reset), (.cancelled, .reset), (.uncertain, .reset), (.idle, .reset), (.clarifying, .reset), (.previewing, .reset):
            return .idle
        default:
            return nil
        }
    }

    static func acceptsLateCallback(activeGeneration: UUID, callbackGeneration: UUID, activeRoute: String, callbackRoute: String) -> Bool {
        activeGeneration == callbackGeneration && activeRoute == callbackRoute
    }
}
