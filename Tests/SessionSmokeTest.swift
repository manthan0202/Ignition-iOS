import Foundation

@main
struct CoreSmokeTest {
    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ignition-session-core-\(UUID().uuidString)")
        let file = folder.appendingPathComponent("sessions.json")
        let store = try IgnitionSessionStore(fileURL: file)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let s = try await store.start(title: "Review cardiology questions",
                                      nextStep: "Open question bank",
                                      duration: 25 * 60, at: start)
        let paused = try await store.pause(at: start.addingTimeInterval(9 * 60))
        assert(abs(paused.activeSeconds(asOf: start.addingTimeInterval(30 * 60)) - 540) < 0.1)
        let resumed = try await store.resume(at: start.addingTimeInterval(30 * 60))
        assert(abs(resumed.remainingSeconds(asOf: start.addingTimeInterval(30 * 60)) - 960) < 0.1)
        // Simulate app closure and recreation from persisted disk state.
        let reopened = try IgnitionSessionStore(fileURL: file)
        let afterDeadline = try await reopened.snapshot(
            at: start.addingTimeInterval(50 * 60))
        let final = afterDeadline.sessions.first!
        assert(final.phase == .ended && final.endReason == .timerElapsed)
        assert(final.outcome == nil) // Never claim user finished the task.
        assert(afterDeadline.events.filter { $0.kind == .sessionStarted }.count == 1)
        assert(afterDeadline.events.filter { $0.kind == .timerElapsed }.count == 1)
        let marked = try await reopened.recordOutcome(.madeProgress, sessionID: s.id,
                                                    at: start.addingTimeInterval(51 * 60))
        assert(marked.outcome == .madeProgress)
        print("PASS: timestamp-based countdown, pause/resume, persistence, " +
              "single footprint, reconciled elapsed time, honest outcome")
    }
}
