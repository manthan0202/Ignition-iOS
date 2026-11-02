// IGNITION SESSION CORE — reference implementation (Foundation only).
// This is tested state/persistence logic, NOT a finished iOS app.
// Screen Time shields, ActivityKit, WidgetKit, EventKit and audio belong
// in separate iOS adapters driven by the events emitted here.
import Foundation

public enum FocusPhase: String, Codable, Sendable {
    case active, paused, onBreak, ended
}

public enum FocusOutcome: String, Codable, Sendable {
    case finished, madeProgress, notFinished
}

public enum FocusEndReason: String, Codable, Sendable {
    case timerElapsed, endedEarly, emergencyExit
}

public enum FocusEventKind: String, Codable, Sendable {
    case sessionStarted, paused, resumed, breakStarted, breakEnded
    case timerElapsed, endedEarly, emergencyExit, outcomeRecorded, nextStepSaved, reviewAcknowledged
}

public struct FocusEvent: Codable, Identifiable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let taskID: UUID?
    public let kind: FocusEventKind
    // When the event was actually logged. Don't confuse this with a planned time.
    public let recordedAt: Date
    // For time-reconciled completion, when the deadline mathematically occurred.
    public let effectiveAt: Date
}

public struct FocusSession: Codable, Identifiable, Sendable {
    public let id: UUID
    public let taskID: UUID?
    /// Optional reservation that launched this timer. A block is not a task.
    /// Codable decodes a missing optional key as nil in older session files.
    public let blockID: UUID?
    public let title: String
    public var nextStep: String?
    public let targetSeconds: TimeInterval
    public let startedAt: Date
    public var phase: FocusPhase
    public var accumulatedActiveSeconds: TimeInterval
    public var lastActiveStart: Date?
    public var breakStartedAt: Date?
    public var endedAt: Date?
    public var endReason: FocusEndReason?
    public var outcome: FocusOutcome?
    public var reviewAcknowledgedAt: Date?

    public func activeSeconds(asOf date: Date) -> TimeInterval {
        let extra: TimeInterval
        if phase == .active, let anchor = lastActiveStart {
            extra = max(0, date.timeIntervalSince(anchor))
        } else {
            extra = 0
        }
        return min(targetSeconds, max(0, accumulatedActiveSeconds + extra))
    }

    public func remainingSeconds(asOf date: Date) -> TimeInterval {
        max(0, targetSeconds - activeSeconds(asOf: date))
    }
}

public struct FocusSnapshot: Codable, Sendable {
    public var sessions: [FocusSession] = []
    public var events: [FocusEvent] = []

    public func ongoingSession() -> FocusSession? {
        sessions.first { $0.phase != .ended }
    }
}

public enum IgnitionSessionError: Error, Equatable {
    case sessionAlreadyInProgress
    case noOngoingSession
    case invalidTransition
    case invalidDuration
    case noSuchSession
}

public actor IgnitionSessionStore {
    private let fileURL: URL
    private var record: FocusSnapshot

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            self.record = try JSONDecoder().decode(
                FocusSnapshot.self,
                from: Data(contentsOf: fileURL)
            )
        } else {
            self.record = FocusSnapshot()
        }
    }

    /// Recovery constructor: start with a fresh snapshot at a new path while
    /// preserving the unreadable original file. No forced try/crash required.
    public init(emptyAt fileURL: URL) {
        self.fileURL = fileURL
        self.record = FocusSnapshot()
    }

    private func commit(_ updated: FocusSnapshot) throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(updated)
        try data.write(to: fileURL, options: .atomic)
        record = updated
    }

    private func addEvent(
        _ kind: FocusEventKind,
        for session: FocusSession,
        recordedAt: Date,
        effectiveAt: Date? = nil,
        into snapshot: inout FocusSnapshot
    ) {
        snapshot.events.append(FocusEvent(
            id: UUID(), sessionID: session.id, taskID: session.taskID,
            kind: kind, recordedAt: recordedAt, effectiveAt: effectiveAt ?? recordedAt
        ))
    }

    // Reconcile a session after app suspension / process restart. The deadline
    // is derived from timestamps; no background per-second loop is necessary.
    private func reconcile(at now: Date) throws {
        guard let index = record.sessions.firstIndex(where: { $0.phase == .active }) else {
            return
        }
        let current = record.sessions[index]
        guard current.remainingSeconds(asOf: now) <= 0 else { return }
        var next = record
        var completed = current
        let previouslyAccumulated = current.accumulatedActiveSeconds
        let needed = max(0, current.targetSeconds - previouslyAccumulated)
        let inferredDeadline = (current.lastActiveStart ?? now).addingTimeInterval(needed)
        completed.accumulatedActiveSeconds = current.targetSeconds
        completed.lastActiveStart = nil
        completed.phase = .ended
        completed.endedAt = inferredDeadline
        completed.endReason = .timerElapsed
        // Do not set outcome or task-completed status automatically.
        next.sessions[index] = completed
        addEvent(.timerElapsed, for: completed, recordedAt: now,
                 effectiveAt: inferredDeadline, into: &next)
        try commit(next)
    }

    public func snapshot(at now: Date = Date()) throws -> FocusSnapshot {
        try reconcile(at: now)
        return record
    }

    @discardableResult
    public func start(
        taskID: UUID? = nil, blockID: UUID? = nil, title: String = "Quick focus",
        nextStep: String? = nil, duration: TimeInterval,
        at now: Date = Date()
    ) throws -> FocusSession {
        guard duration > 0 && duration.isFinite else { throw IgnitionSessionError.invalidDuration }
        try reconcile(at: now)
        guard record.ongoingSession() == nil else {
            throw IgnitionSessionError.sessionAlreadyInProgress
        }
        let session = FocusSession(
            id: UUID(), taskID: taskID, blockID: blockID, title: title, nextStep: nextStep,
            targetSeconds: duration, startedAt: now, phase: .active,
            accumulatedActiveSeconds: 0, lastActiveStart: now,
            breakStartedAt: nil, endedAt: nil, endReason: nil, outcome: nil,
            reviewAcknowledgedAt: nil
        )
        var next = record
        next.sessions.append(session)
        addEvent(.sessionStarted, for: session, recordedAt: now, into: &next)
        try commit(next)
        return session
    }

    private func suspend(_ newPhase: FocusPhase, kind: FocusEventKind,
                         at now: Date) throws -> FocusSession {
        try reconcile(at: now)
        guard let index = record.sessions.firstIndex(where: { $0.phase != .ended }) else {
            throw IgnitionSessionError.noOngoingSession
        }
        let current = record.sessions[index]
        guard current.phase == .active else { throw IgnitionSessionError.invalidTransition }
        var next = record
        var changed = current
        changed.accumulatedActiveSeconds = current.activeSeconds(asOf: now)
        changed.lastActiveStart = nil
        changed.phase = newPhase
        changed.breakStartedAt = newPhase == .onBreak ? now : nil
        next.sessions[index] = changed
        addEvent(kind, for: changed, recordedAt: now, into: &next)
        try commit(next)
        return changed
    }

    @discardableResult
    public func pause(at now: Date = Date()) throws -> FocusSession {
        try suspend(.paused, kind: .paused, at: now)
    }

    @discardableResult
    public func startBreak(at now: Date = Date()) throws -> FocusSession {
        try suspend(.onBreak, kind: .breakStarted, at: now)
    }

    @discardableResult
    public func resume(at now: Date = Date()) throws -> FocusSession {
        try reconcile(at: now)
        guard let index = record.sessions.firstIndex(where: { $0.phase != .ended }) else {
            throw IgnitionSessionError.noOngoingSession
        }
        let current = record.sessions[index]
        guard current.phase == .paused || current.phase == .onBreak else {
            throw IgnitionSessionError.invalidTransition
        }
        var next = record
        var changed = current
        changed.phase = .active
        changed.lastActiveStart = now
        changed.breakStartedAt = nil
        next.sessions[index] = changed
        if current.phase == .onBreak {
            addEvent(.breakEnded, for: changed, recordedAt: now, into: &next)
        }
        addEvent(.resumed, for: changed, recordedAt: now, into: &next)
        try commit(next)
        return changed
    }

    @discardableResult
    public func end(emergency: Bool = false,
                    at now: Date = Date()) throws -> FocusSession {
        try reconcile(at: now)
        guard let index = record.sessions.firstIndex(where: { $0.phase != .ended }) else {
            throw IgnitionSessionError.noOngoingSession
        }
        var next = record
        var changed = next.sessions[index]
        changed.accumulatedActiveSeconds = changed.activeSeconds(asOf: now)
        changed.lastActiveStart = nil
        changed.breakStartedAt = nil
        changed.phase = .ended
        changed.endedAt = now
        changed.endReason = emergency ? .emergencyExit : .endedEarly
        next.sessions[index] = changed
        addEvent(emergency ? .emergencyExit : .endedEarly,
                 for: changed, recordedAt: now, into: &next)
        try commit(next)
        return changed
    }

    @discardableResult
    public func recordOutcome(_ outcome: FocusOutcome, sessionID: UUID,
                              at now: Date = Date()) throws -> FocusSession {
        guard let index = record.sessions.firstIndex(where: { $0.id == sessionID }) else {
            throw IgnitionSessionError.noSuchSession
        }
        guard record.sessions[index].phase == .ended else {
            throw IgnitionSessionError.invalidTransition
        }
        var next = record
        var changed = next.sessions[index]
        changed.outcome = outcome
        next.sessions[index] = changed
        addEvent(.outcomeRecorded, for: changed, recordedAt: now, into: &next)
        try commit(next)
        return changed
    }

    @discardableResult
    public func saveNextStep(_ text: String?, sessionID: UUID,
                             at now: Date = Date()) throws -> FocusSession {
        guard let index = record.sessions.firstIndex(where: { $0.id == sessionID }) else {
            throw IgnitionSessionError.noSuchSession
        }
        var next = record
        var changed = next.sessions[index]
        changed.nextStep = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        next.sessions[index] = changed
        addEvent(.nextStepSaved, for: changed, recordedAt: now, into: &next)
        try commit(next)
        return changed
    }
    /// Atomically acknowledge the Close screen, even when the user selects Skip.
    @discardableResult
    public func recordReview(outcome: FocusOutcome?, nextStep: String?,
                             sessionID: UUID, at now: Date = Date()) throws -> FocusSession {
        guard let index = record.sessions.firstIndex(where: { $0.id == sessionID }) else {
            throw IgnitionSessionError.noSuchSession
        }
        var updated = record
        var session = updated.sessions[index]
        guard session.phase == .ended else { throw IgnitionSessionError.invalidTransition }
        guard session.reviewAcknowledgedAt == nil else { return session }
        if let outcome { session.outcome = outcome }
        if let nextStep, !nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            session.nextStep = nextStep.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        session.reviewAcknowledgedAt = now
        updated.sessions[index] = session
        if outcome != nil { addEvent(.outcomeRecorded, for: session, recordedAt: now, into: &updated) }
        if let nextStep, !nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addEvent(.nextStepSaved, for: session, recordedAt: now, into: &updated)
        }
        addEvent(.reviewAcknowledged, for: session, recordedAt: now, into: &updated)
        try commit(updated)
        return session
    }

}
