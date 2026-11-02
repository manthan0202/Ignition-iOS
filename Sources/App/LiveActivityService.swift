import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    private(set) var lastStatus = "Not started"

    func sync(session: FocusSession?, tasks: [WorkItem] = []) async {
        guard let session, session.phase != .ended else { await endAll(); return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            lastStatus = "Live Activities disabled for Ignition in iPhone Settings"
            return
        }
        let now = Date()
        let remaining = max(0, Int(ceil(session.remainingSeconds(asOf: now))))
        let running = session.phase == .active
        // Use a mathematically stable deadline. Using Date()+remaining on every
        // refresh changes the content by fractions of a second and causes
        // redundant ActivityKit updates even when nothing meaningful changed.
        let deadline = running && session.lastActiveStart != nil
            ? session.lastActiveStart!.addingTimeInterval(
                session.targetSeconds - session.accumulatedActiveSeconds)
            : now.addingTimeInterval(TimeInterval(remaining))
        let previews = tasks.prefix(3).map { item in
            IgnitionLiveTask(title: String(item.title.prefix(64)), isComplete: item.isComplete)
        }
        let state = IgnitionLiveAttributes.ContentState(
            deadline: deadline,
            isRunning: running,
            secondsAtPause: running ? 0 : remaining,
            phaseLabel: running ? "Focusing" : (session.phase == .onBreak ? "On break" : "Paused"),
            completedTaskCount: tasks.filter(\.isComplete).count,
            totalTaskCount: tasks.count,
            visibleTasks: previews,
            nextStep: session.nextStep.map { String($0.prefix(90)) },
            activeSecondsAtUpdate: running ? 0 : Int(session.activeSeconds(asOf: now))
        )
        let content = ActivityContent(state: state, staleDate: running ? state.deadline : nil)
        let matching = Activity<IgnitionLiveAttributes>.activities.first { $0.attributes.sessionID == session.id }
        if let matching {
            // Updating only when something changes avoids redundant updates
            // and needless wakeups; the OS renders the countdown itself.
            if matching.content.state != state { await matching.update(content) }
            lastStatus = "Active on system · session \(session.id.uuidString.prefix(8))"
        } else {
            // End a stale, unrelated activity before beginning the new one.
            await endAll()
            let attrs = IgnitionLiveAttributes(
                sessionID: session.id,
                task: String(session.title.prefix(100)),
                totalSeconds: max(1, Int(session.targetSeconds))
            )
            do {
                let activity = try Activity<IgnitionLiveAttributes>.request(
                    attributes: attrs, content: content, pushType: nil
                )
                lastStatus = "Running · \(activity.id)"
            } catch {
                lastStatus = "Failed to start Live Activity: \(error.localizedDescription)"
                print(lastStatus)
            }
        }
    }

    func endAll() async {
        lastStatus = "No active Live Activity"
        for activity in Activity<IgnitionLiveAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
