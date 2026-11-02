import Foundation

@main
struct BlockSessionIdentityTest {
    static func main() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("ignition-block-session-\(UUID().uuidString)", isDirectory: true)
        let path = base.appendingPathComponent("session.json")
        defer { try? FileManager.default.removeItem(at: base) }
        let blockID = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let store = try IgnitionSessionStore(fileURL: path)
        let started = try await store.start(blockID: blockID, title: "Study block", nextStep: "Question 7", duration: 1500, at: startedAt)
        precondition(started.blockID == blockID)
        precondition(started.taskID == nil, "Block timer must not claim one task's completion")
        let resumedStore = try IgnitionSessionStore(fileURL: path)
        let recovered = try await resumedStore.snapshot(at: startedAt.addingTimeInterval(35))
        precondition(recovered.ongoingSession()?.blockID == blockID)
        precondition(recovered.ongoingSession()?.remainingSeconds(asOf: startedAt.addingTimeInterval(35)) == 1465)
        let ended = try await resumedStore.snapshot(at: startedAt.addingTimeInterval(1501))
        precondition(ended.sessions.last?.endReason == .timerElapsed)
        precondition(ended.sessions.last?.blockID == blockID)
        precondition(ended.sessions.last?.outcome == nil)
        // Simulate a previously saved session from before blockID existed.
        let legacy = try JSONSerialization.jsonObject(with: Data(contentsOf: path)) as! [String: Any]
        var patched = legacy
        var sessions = patched["sessions"] as! [[String: Any]]
        sessions[0].removeValue(forKey: "blockID")
        patched["sessions"] = sessions
        let legacyData = try JSONSerialization.data(withJSONObject: patched)
        let legacySnapshot = try JSONDecoder().decode(FocusSnapshot.self, from: legacyData)
        precondition(legacySnapshot.sessions.first?.blockID == nil)
        print("PASS: focus block session identity, restart, expiry, no false completion, legacy decode")
    }
}
