import Foundation

@main struct CalendarSyncRulesTests {
    static func main() {
        for index in 0..<10000 {
            // Deterministic, valid lower-case base32hex event IDs.
            let value = UUID()
            let a = CalendarSyncRules.stableGoogleEventID(value)
            let b = CalendarSyncRules.stableGoogleEventID(value)
            precondition(a == b && a.count == 34)
            precondition(a.allSatisfy { "0123456789abcdefghijklmnopqrstuv".contains($0) })
            if index % 4 == 0 {
                precondition(CalendarSyncRules.protectsLocalEdit("pending"))
                precondition(CalendarSyncRules.protectsLocalEdit("deleting"))
                precondition(CalendarSyncRules.protectsLocalEdit("conflicted"))
                precondition(!CalendarSyncRules.protectsLocalEdit("synced"))
                precondition(!CalendarSyncRules.mayCommitRemoteCursor(localDataPersisted: false))
                precondition(CalendarSyncRules.mayCommitRemoteCursor(localDataPersisted: true))
            }
        }
        precondition(CalendarSyncRules.writableGoogleCalendar("writer"))
        precondition(!CalendarSyncRules.writableGoogleCalendar("reader"))
        precondition(CalendarSyncRules.allDayDate("2026-10-30") != nil)
        precondition(CalendarSyncRules.allDayDate("2026-13-30") == nil)
        precondition(CalendarSyncRules.allDayDate("2026-02-31") == nil)
        var pacific = Calendar(identifier: .gregorian)
        pacific.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let spring = CalendarSyncRules.allDayDate("2026-03-08", calendar: pacific)!
        precondition(pacific.component(.day, from: spring) == 8)
        let fall = CalendarSyncRules.allDayDate("2026-11-01", calendar: pacific)!
        precondition(pacific.component(.day, from: fall) == 1)
        print("PASS: 10,000 stable IDs; local edit precedence; cursor safety; calendar roles; all-day parsing")
    }
}
