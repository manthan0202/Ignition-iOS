import Foundation

@main
struct FocusBlocksStressTest {
    static func main() throws {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ detail: String) {
            precondition(condition(), detail)
            count += 1
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        var components = DateComponents()
        components.year = 2026; components.month = 10; components.day = 30
        components.hour = 10; components.minute = 1
        let base = calendar.date(from: components)!
        let a = UUID(), b = UUID(), c = UUID()
        var plan = FocusBlockPlan()
        let id1 = plan.create(at: base, durationMinutes: 90, taskID: a)
        check(plan.blocks.count == 1, "block created")
        check(plan.block(id1)?.durationMinutes == 90, "90 minute duration")
        check(plan.block(id1)?.taskIDs == [a], "first task assigned")
        check(plan.assign(b, to: id1), "second task assigned")
        check(plan.assign(b, to: id1), "idempotent assignment")
        check(plan.block(id1)?.taskIDs.count == 2, "no duplicate task links")
        let id2 = plan.create(at: base.addingTimeInterval(3600), taskID: a)
        check(plan.blocks(containing: a).count == 2, "same task can be in multiple blocks")
        check(plan.block(id2)?.taskIDs == [a], "same shared task ID")
        check(plan.remove(a, from: id1), "remove from one block")
        check(plan.block(id2)?.taskIDs == [a], "other block retains task")
        check(plan.assign(a, to: id1), "reassign")
        check(plan.assign(c, to: id1), "third task")
        check(plan.block(id1)?.taskIDs.count == 3, "three tasks")
        check(plan.resize(id1, to: 105), "resized")
        check(plan.block(id1)?.end.timeIntervalSince(base) == 6300, "resized exact end")
        check(plan.resize(id1, to: -99), "too short clamped")
        check(plan.block(id1)?.durationMinutes == 15, "minimum 15 minutes")
        check(plan.resize(id1, to: 9000), "too long clamped")
        check(plan.block(id1)?.durationMinutes == 360, "maximum six hours")
        check(plan.move(id1, to: base.addingTimeInterval(7200)), "moved")
        check(plan.block(id1)?.start == base.addingTimeInterval(7200), "move persisted")
        check(plan.rename(id1, to: "  Study  "), "rename")
        check(plan.block(id1)?.title == "Study", "trim title")
        check(!plan.rename(id1, to: " "), "reject blank")
        let packed = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(FocusBlockPlan.self, from: packed)
        check(plan == decoded, "JSON roundtrip")
        check(decoded.blocks(containing: a).count == 2, "links survive reopen")
        decoded.blocks.forEach { check($0.durationMinutes >= 15, "valid duration") }
        plan.removeAllReferences(to: a)
        check(plan.blocks(containing: a).isEmpty, "delete task cleans all blocks")
        check(plan.block(id1)?.taskIDs.contains(b) == true, "unrelated tasks remain")
        plan.delete(id2)
        check(plan.blocks.count == 1, "delete block keeps others")
        check(FocusBlockPlan.snap(base, calendar: calendar) == calendar.date(bySettingHour: 10, minute: 0, second: 0, of: base)!, "local-time quarter snap")
        let late = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: base)!
        let crossing = plan.create(at: late, durationMinutes: 120)
        let next = calendar.date(byAdding: .day, value: 1, to: base)!
        check(plan.forDay(base, calendar: calendar).contains { $0.id == crossing }, "crossing block visible first day")
        check(plan.forDay(next, calendar: calendar).contains { $0.id == crossing }, "crossing block visible second day")
        for _ in 0..<75 {
            var cycle = FocusBlockPlan()
            let x = cycle.create(at: base, durationMinutes: 45, taskID: a)
            _ = cycle.assign(b, to: x)
            _ = cycle.resize(x, to: 60)
            _ = cycle.move(x, to: base.addingTimeInterval(900))
            let payload = try JSONEncoder().encode(cycle)
            let recovered = try JSONDecoder().decode(FocusBlockPlan.self, from: payload)
            check(recovered == cycle, "cycle survives serialization")
        }
        print("Focus block checks passed: \(count)")
    }
}
