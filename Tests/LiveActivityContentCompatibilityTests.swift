import Foundation

struct OldState: Codable {
    let deadline: Date
    let isRunning: Bool
    let secondsAtPause: Int
    let phaseLabel: String
}

@main
struct CompatTests {
    static func main() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let old = OldState(deadline: now.addingTimeInterval(120), isRunning: true, secondsAtPause: 120, phaseLabel: "Focusing")
        let oldData = try encoder.encode(old)
        let upgraded = try decoder.decode(IgnitionLiveAttributes.ContentState.self, from: oldData)
        assert(upgraded.totalTaskCount == 0 && upgraded.visibleTasks.isEmpty)
        for i in 0..<3000 {
            let rows = (0..<(i%8)).map { IgnitionLiveTask(title: "Task \($0)", isComplete: $0%2 == 0) }
            let state = IgnitionLiveAttributes.ContentState(deadline: now.addingTimeInterval(TimeInterval(i)), isRunning: i%2 == 0, secondsAtPause: i%900, phaseLabel: "Paused", completedTaskCount:i%8, totalTaskCount:8, visibleTasks:rows, nextStep:"Hello", activeSecondsAtUpdate: 20)
            assert(state.visibleTasks.count <= 3)
            let decoded = try decoder.decode(IgnitionLiveAttributes.ContentState.self, from: encoder.encode(state))
            assert(decoded == state)
        }
        print("Live Activity Codable migration and 3000 state roundtrips passed")
    }
}
