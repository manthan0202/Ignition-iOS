import EventKit
import Foundation

/// EventKit is the preferred local integration for BOTH iCloud and Google
/// calendars that the user has already enabled in iOS Settings → Calendar.
/// Never mirror the same remote Google calendar through a second writer.
@MainActor
final class CalendarService {
    private let store = EKEventStore()
    var isAuthorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    func requestAccess() async throws -> Bool {
        if isAuthorized { return true }
        return try await store.requestFullAccessToEvents()
    }
    func load(day: Date, requestPermission: Bool = false) async throws -> [WorkItem] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        return try await load(from: start, to: end, requestPermission: requestPermission)
    }

    /// Read the visible month with one EventKit request. Read-only: never
    /// writes to the external calendar or requests access just to show a grid.
    func load(from start: Date, to end: Date,
              requestPermission: Bool = false) async throws -> [WorkItem] {
        let granted: Bool
        if isAuthorized { granted = true }
        else if requestPermission { granted = try await requestAccess() }
        else { granted = false }
        guard granted else { return [] }
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
        return events.map { event in
            var item = WorkItem(title: event.title ?? "Untitled event", nextStep: "",
                                notes: event.notes ?? "", scheduledStart: event.startDate,
                                durationMinutes: max(5, Int(event.endDate.timeIntervalSince(event.startDate) / 60)),
                                tint: .orange, isFixed: !event.calendar.allowsContentModifications,
                                calendarEventIdentifier: event.eventIdentifier,
                                syncToAppleCalendar: true)
            item.externalProvider = "eventkit"
            item.externalCalendarID = event.calendar.calendarIdentifier
            item.externalEventID = event.eventIdentifier
            item.externalUniversalID = event.calendarItemExternalIdentifier
            item.syncState = "synced"
            item.isAllDay = event.isAllDay
            return item
        }
    }
    func save(task: WorkItem) async throws -> String? {
        guard let start = task.scheduledStart else { return nil }
        guard try await requestAccess() else {
            throw NSError(domain: "IgnitionCalendar", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Calendar permission not granted"])
        }
        let event: EKEvent
        if let id = task.calendarEventIdentifier {
            guard let existing = store.event(withIdentifier: id),
                  existing.calendar.allowsContentModifications else {
                throw NSError(domain: "IgnitionCalendar", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Original event cannot be edited; refresh before retrying"])
            }
            event = existing
        } else {
            event = EKEvent(eventStore: store)
            guard let target = store.defaultCalendarForNewEvents, target.allowsContentModifications else {
                throw NSError(domain: "IgnitionCalendar", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "No writable default calendar selected in iOS Settings"])
            }
            event.calendar = target
        }
        event.title = task.title
        event.startDate = start
        event.endDate = start.addingTimeInterval(TimeInterval(max(5, task.durationMinutes) * 60))
        event.notes = task.notes
        event.isAllDay = task.isAllDay ?? false
        try store.save(event, span: .thisEvent)
        return event.eventIdentifier
    }
}

// Keep external deletion separate from local task deletion. A failed remote
// delete must not erase the only record of the provider identity.
extension CalendarService {
    func delete(task: WorkItem) async throws {
        guard try await requestAccess() else {
            throw NSError(domain: "IgnitionCalendar", code: 11,
                          userInfo: [NSLocalizedDescriptionKey: "Calendar permission is required to delete this event"])
        }
        guard let id = task.calendarEventIdentifier ?? task.externalEventID,
              let event = store.event(withIdentifier: id),
              event.calendar.allowsContentModifications else {
            throw NSError(domain: "IgnitionCalendar", code: 12,
                          userInfo: [NSLocalizedDescriptionKey: "Event was moved or is read-only; refresh the calendar before deleting"])
        }
        try store.remove(event, span: .thisEvent, commit: true)
    }
}
