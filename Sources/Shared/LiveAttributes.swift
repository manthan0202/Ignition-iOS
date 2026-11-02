import ActivityKit
import Foundation

// All Live Activity text is a compact snapshot: the extension may not read
// the app's private task repository while Ignition is suspended.
struct IgnitionLiveTask: Codable, Hashable {
    let title: String
    let isComplete: Bool
}

struct IgnitionLiveAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var deadline: Date
        var isRunning: Bool
        var secondsAtPause: Int
        var phaseLabel: String
        var completedTaskCount: Int
        var totalTaskCount: Int
        var visibleTasks: [IgnitionLiveTask]
        var nextStep: String?
        var activeSecondsAtUpdate: Int

        init(deadline: Date, isRunning: Bool, secondsAtPause: Int,
             phaseLabel: String, completedTaskCount: Int = 0,
             totalTaskCount: Int = 0, visibleTasks: [IgnitionLiveTask] = [],
             nextStep: String? = nil, activeSecondsAtUpdate: Int = 0) {
            self.deadline = deadline
            self.isRunning = isRunning
            self.secondsAtPause = max(0, secondsAtPause)
            self.phaseLabel = phaseLabel
            self.completedTaskCount = max(0, completedTaskCount)
            self.totalTaskCount = max(0, totalTaskCount)
            self.visibleTasks = Array(visibleTasks.prefix(3))
            self.nextStep = nextStep
            self.activeSecondsAtUpdate = max(0, activeSecondsAtUpdate)
        }

        // Old activities only contained these first four properties. Decode
        // missing new fields as empty instead of failing after app upgrades.
        private enum CodingKeys: String, CodingKey {
            case deadline, isRunning, secondsAtPause, phaseLabel
            case completedTaskCount, totalTaskCount, visibleTasks, nextStep, activeSecondsAtUpdate
        }
        init(from decoder: Decoder) throws {
            let data = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                deadline: try data.decode(Date.self, forKey: .deadline),
                isRunning: try data.decode(Bool.self, forKey: .isRunning),
                secondsAtPause: try data.decode(Int.self, forKey: .secondsAtPause),
                phaseLabel: try data.decode(String.self, forKey: .phaseLabel),
                completedTaskCount: try data.decodeIfPresent(Int.self, forKey: .completedTaskCount) ?? 0,
                totalTaskCount: try data.decodeIfPresent(Int.self, forKey: .totalTaskCount) ?? 0,
                visibleTasks: try data.decodeIfPresent([IgnitionLiveTask].self, forKey: .visibleTasks) ?? [],
                nextStep: try data.decodeIfPresent(String.self, forKey: .nextStep),
                activeSecondsAtUpdate: try data.decodeIfPresent(Int.self, forKey: .activeSecondsAtUpdate) ?? 0
            )
        }
    }
    var sessionID: UUID
    var task: String
    var totalSeconds: Int
}
