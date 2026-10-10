import ActivityKit
import Combine
import Foundation

enum ActivityLiveActivityPresentationStatus: Equatable {
    case unavailable
    case disabled
    case denied
    case active
    case failed(String)
}

protocol ActivityLiveActivityClient: Sendable {
    var activitiesEnabled: Bool { get }
    func existingActivities() -> [Activity<StudyActivityLiveActivityAttributes>]
    @discardableResult
    func request(attributes: StudyActivityLiveActivityAttributes, content: ActivityContent<StudyActivityLiveActivityAttributes.ContentState>) async throws -> Activity<StudyActivityLiveActivityAttributes>
    func update(_ activity: Activity<StudyActivityLiveActivityAttributes>, content: ActivityContent<StudyActivityLiveActivityAttributes.ContentState>) async
    func end(_ activity: Activity<StudyActivityLiveActivityAttributes>, content: ActivityContent<StudyActivityLiveActivityAttributes.ContentState>, dismissalPolicy: ActivityUIDismissalPolicy) async
}

struct LiveActivityKitClient: ActivityLiveActivityClient {
    var activitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func existingActivities() -> [Activity<StudyActivityLiveActivityAttributes>] {
        Activity<StudyActivityLiveActivityAttributes>.activities
    }

    func request(attributes: StudyActivityLiveActivityAttributes, content: ActivityContent<StudyActivityLiveActivityAttributes.ContentState>) async throws -> Activity<StudyActivityLiveActivityAttributes> {
        try Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    func update(_ activity: Activity<StudyActivityLiveActivityAttributes>, content: ActivityContent<StudyActivityLiveActivityAttributes.ContentState>) async {
        await activity.update(content)
    }

    func end(_ activity: Activity<StudyActivityLiveActivityAttributes>, content: ActivityContent<StudyActivityLiveActivityAttributes.ContentState>, dismissalPolicy: ActivityUIDismissalPolicy) async {
        await activity.end(content, dismissalPolicy: dismissalPolicy)
    }
}

@MainActor
final class ActivityLiveActivityCoordinator: ObservableObject {
    private let client: ActivityLiveActivityClient
    private var generation = UUID()
    private var operation: Task<Void, Never>?
    private var boundActivityID: String?
    private var suppressedDraftIDs: Set<UUID> = []
    private(set) var status: ActivityLiveActivityPresentationStatus = .unavailable

    init(client: ActivityLiveActivityClient = LiveActivityKitClient()) {
        self.client = client
        refreshAvailability()
    }

    func refreshAvailability() {
        status = client.activitiesEnabled ? .active : .disabled
    }

    func userDismissedPresentation(for draftID: UUID) {
        suppressedDraftIDs.insert(draftID)
    }

    func reconcile(projection: ActivitySystemProjection?, sceneActive: Bool) {
        generation = UUID()
        let token = generation
        operation?.cancel()
        operation = Task { [weak self] in
            await self?.apply(projection: projection, sceneActive: sceneActive, token: token)
        }
    }

    private func apply(projection: ActivitySystemProjection?, sceneActive: Bool, token: UUID) async {
        guard token == generation else { return }
        refreshAvailability()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = .disabled
            await endAllSophiaActivities(token: token)
            return
        }

        guard let projection else {
            await endAllSophiaActivities(token: token)
            boundActivityID = nil
            return
        }

        if suppressedDraftIDs.contains(projection.draftID) {
            await endAllSophiaActivities(token: token)
            return
        }

        guard sceneActive else { return }

        let content = contentState(for: projection)
        let attributes = StudyActivityLiveActivityAttributes(draftID: projection.draftID)
        do {
            let activities = client.existingActivities()
            let matching = activities.filter { $0.attributes.draftID == projection.draftID }
            let orphan = activities.filter { $0.attributes.draftID != projection.draftID }
            for activity in orphan {
                guard token == generation else { return }
                await client.end(activity, content: content, dismissalPolicy: .immediate)
            }
            if let activity = matching.first {
                boundActivityID = activity.id
                for duplicate in matching.dropFirst() {
                    await client.end(duplicate, content: content, dismissalPolicy: .immediate)
                }
                guard token == generation else { return }
                await client.update(activity, content: content)
                status = .active
            } else {
                guard token == generation else { return }
                let activity = try await client.request(attributes: attributes, content: content)
                boundActivityID = activity.id
                status = .active
            }
        } catch {
            status = .failed("Live Activity could not update.")
        }
    }

    private func endAllSophiaActivities(token: UUID) async {
        for activity in client.existingActivities() {
            guard token == generation else { return }
            let empty = ActivityContent(state: StudyActivityLiveActivityAttributes.ContentState(accumulatedSeconds: 0, runningSince: nil, revision: 0), staleDate: nil)
            await client.end(activity, content: empty, dismissalPolicy: .immediate)
        }
    }

    private func contentState(for projection: ActivitySystemProjection) -> ActivityContent<StudyActivityLiveActivityAttributes.ContentState> {
        ActivityContent(
            state: StudyActivityLiveActivityAttributes.ContentState(
                accumulatedSeconds: projection.accumulatedSeconds,
                runningSince: projection.runningSince,
                revision: projection.revision
            ),
            staleDate: nil
        )
    }
}
