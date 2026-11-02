import Foundation
@main struct VoiceDraftParserTests {
    static func main() {
        let now = ISO8601DateFormatter().date(from: "2026-10-30T12:00:00Z")!
        let a = VoiceDraftParser.parse("Schedule study cardiology tomorrow at 7 pm for one hour", now: now)
        precondition(a.kind == .block && a.durationMinutes == 60 && a.title.lowercased() == "study cardiology")
        precondition(a.start != nil)
        let b = VoiceDraftParser.parse("Buy groceries", now: now)
        precondition(b.kind == .task && b.title == "Buy groceries" && b.start == nil)
        let c = VoiceDraftParser.parse("Create event team call tomorrow at 8 am for 30 minutes", now: now)
        precondition(c.kind == .event && c.durationMinutes == 30)
        let spoken = VoiceDraftParser.parse("Schedule research tomorrow at seven pm for one hour", now: now)
        precondition(spoken.title == "research" && spoken.start != nil && spoken.durationMinutes == 60)
        let d = VoiceDraftParser.parse("Schedule write paper tomorrow at 7", now: now)
        precondition(d.needsTimeConfirmation)
        // The spoken hour must survive (it used to default to midnight).
        precondition(d.start != nil && Calendar.current.component(.hour, from: d.start!) == 7)
        let e = VoiceDraftParser.parse("Schedule review tomorrow at 5", now: now)
        precondition(e.needsTimeConfirmation && e.start != nil && Calendar.current.component(.hour, from: e.start!) == 17)
        let spokenRequest = VoiceDraftParser.parse("Can you add cardiology to my schedule for tomorrow 5 PM", now: now)
        precondition(spokenRequest.kind == .event && spokenRequest.title.lowercased() == "cardiology")
        precondition(spokenRequest.start != nil && Calendar.current.component(.hour, from: spokenRequest.start!) == 17)
        let politeRequest = VoiceDraftParser.parse("Please add lab meeting to my calendar tomorrow at 3:30 PM", now: now)
        precondition(politeRequest.kind == .event && politeRequest.title.lowercased() == "lab meeting")
        precondition(politeRequest.start != nil && Calendar.current.component(.minute, from: politeRequest.start!) == 30)
        for i in 0..<1000 {
            let r = VoiceDraftParser.parse("Add task study \(i) tomorrow at 9 pm for 25 minutes", now: now)
            precondition(r.durationMinutes == 25 && r.title == "study \(i)" && r.start != nil)
        }
        print("PASS: voice parsing, time confirmation, 1,000 sequential drafts, no silent task saves")
    }
}
