import Foundation

@main
struct SessionStressTest {
    static func require(_ result: @autoclosure () -> Bool, _ detail: String) {
        guard result() else { fatalError("FAILED: \(detail)") }
    }
    static func fresh(_ label: String) throws -> (IgnitionSessionStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ignition-stress-\(label)-\(UUID().uuidString)/sessions.json")
        return (try IgnitionSessionStore(fileURL: url), url)
    }
    static func main() async throws {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        var checks = 0
        do {
            let (store, url) = try fresh("deadline")
            let s = try await store.start(title: "Exam", nextStep: "Question 7", duration: 120, at: base)
            require(abs(s.remainingSeconds(asOf: base.addingTimeInterval(119)) - 1) < 0.1, "pre-deadline countdown")
            let atDeadline = try await store.snapshot(at: base.addingTimeInterval(120))
            require(atDeadline.sessions[0].phase == .ended, "exact deadline should complete")
            require(atDeadline.sessions[0].endReason == .timerElapsed, "exact deadline reason")
            require(atDeadline.sessions[0].outcome == nil, "timer never fabricates completion")
            require(atDeadline.sessions[0].reviewAcknowledgedAt == nil, "elapsed session prompts review")
            require(atDeadline.events.filter { $0.kind == .timerElapsed }.count == 1, "one expiration event")
            let again = try await store.snapshot(at: base.addingTimeInterval(1200))
            require(again.events.filter { $0.kind == .timerElapsed }.count == 1, "expiration idempotent")
            let restored = try IgnitionSessionStore(fileURL: url)
            let onReopen = try await restored.snapshot(at: base.addingTimeInterval(1300))
            require(onReopen.sessions[0].reviewAcknowledgedAt == nil, "review persists unacknowledged after process restart")
            let acknowledged = try await restored.recordReview(outcome:nil, nextStep:nil, sessionID:s.id,at:base.addingTimeInterval(1301))
            require(acknowledged.outcome == nil && acknowledged.reviewAcknowledgedAt != nil, "Skip saved without invented outcome")
            _ = try await restored.recordReview(outcome:.finished,nextStep:"wrong",sessionID:s.id,at:base.addingTimeInterval(1302))
            let final = try await restored.snapshot(at:base.addingTimeInterval(1400))
            require(final.sessions[0].outcome == nil && final.events.filter { $0.kind == .reviewAcknowledged }.count == 1, "no double review")
            checks += 11
        }
        do {
            // Existing customers already have JSON written by the older
            // version, before reviewAcknowledgedAt existed.
            let (store, _) = try fresh("migration")
            _ = try await store.start(duration: 60, at: base)
            let snapshot = try await store.snapshot(at: base.addingTimeInterval(1))
            let encoded = try JSONEncoder().encode(snapshot)
            var json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
            var sessions = json["sessions"] as! [[String: Any]]
            sessions[0].removeValue(forKey: "reviewAcknowledgedAt")
            json["sessions"] = sessions
            let legacy = try JSONSerialization.data(withJSONObject: json)
            let decoded = try JSONDecoder().decode(FocusSnapshot.self, from: legacy)
            require(decoded.sessions.count == 1 && decoded.sessions[0].reviewAcknowledgedAt == nil,
                    "old session JSON remains readable")
            checks += 1
        }
        do {
            let (store, _) = try fresh("break")
            let s = try await store.start(duration:1500,at:base)
            _ = try await store.pause(at:base.addingTimeInterval(60))
            var snap = try await store.snapshot(at:base.addingTimeInterval(2000))
            require(snap.sessions[0].phase == .paused && snap.sessions[0].activeSeconds(asOf:base.addingTimeInterval(2000)) == 60,"paused time frozen")
            _ = try await store.resume(at:base.addingTimeInterval(2000))
            _ = try await store.startBreak(at:base.addingTimeInterval(2050))
            snap = try await store.snapshot(at:base.addingTimeInterval(9000))
            require(snap.sessions[0].phase == .onBreak && snap.sessions[0].activeSeconds(asOf:base.addingTimeInterval(9000)) == 110,"break time frozen")
            _ = try await store.resume(at:base.addingTimeInterval(9100))
            let ended = try await store.end(at:base.addingTimeInterval(9110))
            require(ended.endReason == .endedEarly && ended.phase == .ended && ended.activeSeconds(asOf:base.addingTimeInterval(9900)) == 120,"manual end records only active seconds")
            let review = try await store.recordReview(outcome:.finished,nextStep:"Chapter 2",sessionID:s.id,at:base.addingTimeInterval(9200))
            require(review.outcome == .finished && review.nextStep == "Chapter 2", "atomic truthful review")
            checks += 4
        }
        do {
            let (store, _) = try fresh("transitions")
            do { _ = try await store.start(duration:0,at:base);fatalError("zero duration accepted") }
            catch IgnitionSessionError.invalidDuration {checks += 1}
            do { _ = try await store.start(duration:.infinity,at:base);fatalError("infinite duration accepted") }
            catch IgnitionSessionError.invalidDuration {checks += 1}
            _ = try await store.start(duration:60,at:base)
            do { _ = try await store.start(duration:60,at:base);fatalError("double start accepted") }
            catch IgnitionSessionError.sessionAlreadyInProgress {checks += 1}
            do { _ = try await store.resume(at:base.addingTimeInterval(10));fatalError("resume active accepted") }
            catch IgnitionSessionError.invalidTransition {checks += 1}
            _ = try await store.end(emergency:true,at:base.addingTimeInterval(12))
            let next = try await store.start(duration:30,at:base.addingTimeInterval(100))
            let final = try await store.snapshot(at:base.addingTimeInterval(150))
            require(final.sessions.count == 2 && final.sessions[1].id == next.id && final.sessions[1].phase == .ended, "new session follows old without mixing footprints")
            require(final.events.filter { $0.kind == .sessionStarted }.count == 2,"one start event per session")
            checks += 2
        }
        do {
            let (_, url) = try fresh("corrupt")
            try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
            let payload = Data("not valid JSON".utf8)
            try payload.write(to:url)
            do { _ = try IgnitionSessionStore(fileURL:url);fatalError("damaged JSON was treated as empty history") }
            catch { let got = try Data(contentsOf:url); require(got == payload, "corrupt source preserved");checks += 1 }
        }
        do {
            // End-to-end repeated starts on a single store: one footprint and
            // one expiration event for every interval, no cross-session mixing.
            let (store, file) = try fresh("repeated")
            for i in 0..<75 {
                let when = base.addingTimeInterval(TimeInterval(i * 100))
                let session = try await store.start(duration: 30, at: when)
                _ = try await store.snapshot(at: when.addingTimeInterval(31))
                _ = try await store.recordReview(outcome: i.isMultiple(of: 3) ? .finished : nil,
                                                 nextStep: nil, sessionID: session.id,
                                                 at: when.addingTimeInterval(33))
            }
            let reopened = try IgnitionSessionStore(fileURL: file)
            let snapshot = try await reopened.snapshot(at:base.addingTimeInterval(9000))
            require(snapshot.sessions.count == 75, "75 sessions durable")
            require(snapshot.events.filter { $0.kind == .sessionStarted }.count == 75, "75 unique starts")
            require(snapshot.events.filter { $0.kind == .timerElapsed }.count == 75, "75 unique timeouts")
            require(snapshot.events.filter { $0.kind == .reviewAcknowledged }.count == 75, "75 durable review decisions")
            require(snapshot.sessions.filter { $0.outcome == .finished }.count == 25, "only explicit finished sessions")
            checks += 5
        }
        print("PASS: \(checks) assertions: expiry, background reload, skipped review, idempotency, pause, break, invalid transitions, emergency, corrupt data")
    }
}
