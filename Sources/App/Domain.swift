import Foundation
import SwiftUI

enum ItemTint: String, Codable, CaseIterable, Identifiable {
    case blue, purple, orange, green
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .blue: return Color(red: 0.24, green: 0.43, blue: 0.88)
        case .purple: return Color(red: 0.54, green: 0.36, blue: 0.74)
        case .orange: return Color(red: 0.86, green: 0.58, blue: 0.30)
        case .green: return Color(red: 0.30, green: 0.64, blue: 0.48)
        }
    }
}

struct WorkItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var nextStep: String = ""
    var notes: String = ""
    var urlText: String = ""
    var scheduledStart: Date? = nil
    var durationMinutes: Int = 30
    var isComplete: Bool = false
    var tint: ItemTint = .blue
    var isFixed: Bool = false
    var calendarEventIdentifier: String? = nil
    var syncToAppleCalendar: Bool = false
    // Optional fields allow older on-device JSON records to decode unchanged.
    var externalProvider: String? = nil
    var externalCalendarID: String? = nil
    var externalEventID: String? = nil
    var externalETag: String? = nil
    var externalUniversalID: String? = nil
    var syncState: String? = nil // pending / synced / failed; never claim success early
    var isAllDay: Bool? = nil
    var createdAt: Date = Date()
    var scheduledEnd: Date? { scheduledStart?.addingTimeInterval(TimeInterval(durationMinutes * 60)) }
}

// BEGIN_FOCUS_BLOCK_MODEL (Foundation-only, exercised by Tests)
/// A time reservation is NOT a task. Multiple task IDs may be attached to a
/// block, and one task may be attached to multiple blocks without being copied.
struct FocusBlock: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var start: Date
    var durationMinutes: Int
    var taskIDs: [UUID] = []
    var createdAt: Date = Date()
    var end: Date { start.addingTimeInterval(TimeInterval(durationMinutes * 60)) }
}

struct FocusBlockPlan: Codable, Equatable {
    private(set) var blocks: [FocusBlock] = []

    func block(_ id: UUID) -> FocusBlock? { blocks.first { $0.id == id } }
    func blocks(containing taskID: UUID) -> [FocusBlock] {
        blocks.filter { $0.taskIDs.contains(taskID) }
    }
    func forDay(_ day: Date, calendar: Calendar = .current) -> [FocusBlock] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return blocks.filter { $0.start < end && $0.end > start }.sorted { $0.start < $1.start }
    }
    @discardableResult mutating func create(at start: Date,
                                           durationMinutes: Int = 60,
                                           title: String = "Focus block",
                                           taskID: UUID? = nil) -> UUID {
        let id = UUID()
        let block = FocusBlock(id: id, title: title.isEmpty ? "Focus block" : title,
                               start: start, durationMinutes: Self.validDuration(durationMinutes),
                               taskIDs: taskID.map { [$0] } ?? [])
        blocks.append(block)
        return id
    }
    mutating func upsert(_ block: FocusBlock) {
        var cleaned = block
        cleaned.durationMinutes = Self.validDuration(block.durationMinutes)
        var seen = Set<UUID>()
        cleaned.taskIDs = block.taskIDs.filter { seen.insert($0).inserted }
        if let index = blocks.firstIndex(where: { $0.id == block.id }) { blocks[index] = cleaned }
        else { blocks.append(cleaned) }
    }
    @discardableResult mutating func assign(_ taskID: UUID, to blockID: UUID) -> Bool {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return false }
        if !blocks[index].taskIDs.contains(taskID) { blocks[index].taskIDs.append(taskID) }
        return true
    }
    @discardableResult mutating func remove(_ taskID: UUID, from blockID: UUID) -> Bool {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return false }
        blocks[index].taskIDs.removeAll { $0 == taskID }
        return true
    }
    mutating func removeAllReferences(to taskID: UUID) {
        for index in blocks.indices { blocks[index].taskIDs.removeAll { $0 == taskID } }
    }
    @discardableResult mutating func move(_ blockID: UUID, to date: Date) -> Bool {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return false }
        blocks[index].start = date
        return true
    }
    @discardableResult mutating func resize(_ blockID: UUID, to minutes: Int) -> Bool {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return false }
        blocks[index].durationMinutes = Self.validDuration(minutes)
        return true
    }
    @discardableResult mutating func rename(_ blockID: UUID, to title: String) -> Bool {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        blocks[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
    }
    mutating func delete(_ blockID: UUID) { blocks.removeAll { $0.id == blockID } }

    static func validDuration(_ value: Int) -> Int { min(360, max(15, (value + 7) / 15 * 15)) }

    /// Snap against start-of-day rather than the Unix epoch, including non-UTC timezones.
    static func snap(_ date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        let minutes = date.timeIntervalSince(day) / 60
        let offset = max(0, (minutes / 15).rounded() * 15)
        return calendar.date(byAdding: .minute, value: Int(offset), to: day) ?? date
    }
}

// END_FOCUS_BLOCK_MODEL

// Backward-compatible decode: previously saved task files have no `blocks` key.
// Missing blocks must not make old tasks unreadable.
struct DataSnapshot: Codable {
    var tasks: [WorkItem] = []
    var blockPlan: FocusBlockPlan = FocusBlockPlan()

    enum CodingKeys: String, CodingKey { case tasks, blockPlan }
    init(tasks: [WorkItem] = [], blockPlan: FocusBlockPlan = FocusBlockPlan()) {
        self.tasks = tasks
        self.blockPlan = blockPlan
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeIfPresent([WorkItem].self, forKey: .tasks) ?? []
        blockPlan = try container.decodeIfPresent(FocusBlockPlan.self, forKey: .blockPlan) ?? FocusBlockPlan()
    }
}

@MainActor
final class WorkRepository: ObservableObject {
    @Published private(set) var items: [WorkItem] = []
    @Published private(set) var blockPlan = FocusBlockPlan()
    var blocks: [FocusBlock] { blockPlan.blocks }
    private var path: URL
    private(set) var recoveryWarning: String?

    init() {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: IgnitionConfig.group)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        path = base.appendingPathComponent("ignition-work-v1.json")
        if FileManager.default.fileExists(atPath: path.path) {
            do {
                let data = try Data(contentsOf: path)
                let saved = try JSONDecoder().decode(DataSnapshot.self, from: data)
                items = saved.tasks
                blockPlan = saved.blockPlan
            } catch {
                // Preserve the damaged source; write new tasks to a different file.
                path = base.appendingPathComponent("ignition-work-recovery-\(UUID().uuidString).json")
                recoveryWarning = "Could not read task history; original file was preserved."
            }
        }
    }
    func upsert(_ item: WorkItem) {
        if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item }
        else { items.append(item) }
        persist()
    }
    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        blockPlan.removeAllReferences(to: id)
        persist()
    }
    func setComplete(_ id: UUID, _ complete: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isComplete = complete
        persist()
    }
    func schedule(_ id: UUID, to date: Date) {
        guard let index = items.firstIndex(where: { $0.id == id }), !items[index].isFixed else { return }
        items[index].scheduledStart = date
        persist()
    }
    func resize(_ id: UUID, by minutes: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }), !items[index].isFixed else { return }
        items[index].durationMinutes = min(360, max(5, items[index].durationMinutes + minutes))
        persist()
    }
    func shift(_ id: UUID, by minutes: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              !items[index].isFixed,
              let start = items[index].scheduledStart else { return }
        items[index].scheduledStart = start.addingTimeInterval(Double(minutes * 60))
        persist()
    }
    func item(_ id: UUID?) -> WorkItem? { items.first { $0.id == id } }
    func upcoming(after now: Date = Date()) -> [WorkItem] {
        items.filter { !$0.isComplete && ($0.scheduledStart ?? .distantPast) >= now }
            .sorted { ($0.scheduledStart ?? .distantFuture) < ($1.scheduledStart ?? .distantFuture) }
    }
    func forDay(_ day: Date) -> [WorkItem] {
        let startOfDay = Calendar.current.startOfDay(for: day)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)
        return items.filter { item in
            guard let start = item.scheduledStart else { return false }
            let end = item.scheduledEnd ?? start.addingTimeInterval(60)
            // Include events crossing midnight, not just those starting today.
            return start < endOfDay && end > startOfDay
        }.sorted { ($0.scheduledStart ?? .distantFuture) < ($1.scheduledStart ?? .distantFuture) }
    }
    // Focus blocks are local time reservations; they do not implicitly alter
    // WorkItem.scheduledStart or external Apple Calendar events.
    func createBlock(at date: Date, taskID: UUID? = nil) -> UUID? {
        if let taskID, item(taskID) == nil { return nil }
        let title = taskID.flatMap { item($0)?.title } ?? "Focus block"
        let id = blockPlan.create(at: FocusBlockPlan.snap(date), title: title, taskID: taskID)
        persist()
        return id
    }
    func upsertBlock(_ block: FocusBlock) {
        var copy = block
        copy.taskIDs = block.taskIDs.filter { item($0) != nil }
        blockPlan.upsert(copy)
        persist()
    }
    func assign(_ taskID: UUID, to blockID: UUID) {
        guard item(taskID) != nil, blockPlan.assign(taskID, to: blockID) else { return }
        persist()
    }
    func unassign(_ taskID: UUID, from blockID: UUID) {
        if blockPlan.remove(taskID, from: blockID) { persist() }
    }
    func moveBlock(_ id: UUID, to date: Date) {
        if blockPlan.move(id, to: FocusBlockPlan.snap(date)) { persist() }
    }
    func resizeBlock(_ id: UUID, to minutes: Int) {
        if blockPlan.resize(id, to: minutes) { persist() }
    }
    func deleteBlock(_ id: UUID) { blockPlan.delete(id); persist() }
    func block(_ id: UUID?) -> FocusBlock? { id.flatMap { blockPlan.block($0) } }
    func blocksForDay(_ date: Date) -> [FocusBlock] { blockPlan.forDay(date) }
    func tasks(in block: FocusBlock) -> [WorkItem] { block.taskIDs.compactMap { item($0) } }


    /// Reconcile a fetched day without duplicating imported events or deleting
    /// independent tasks. Pending local writes win over stale remote echoes.
    func reconcileEventKit(_ imported: [WorkItem], for day: Date) {
        let beginning = Calendar.current.startOfDay(for: day)
        let ending = Calendar.current.date(byAdding: .day, value: 1, to: beginning) ?? beginning.addingTimeInterval(86400)
        reconcileEventKit(imported, in: DateInterval(start: beginning, end: ending))
    }

    /// Single durable update for a month of EventKit records, using the same
    /// identity/deduplication and pending-local-write precedence as day sync.
    /// Avoid 28–31 separate disk writes and redraws while the grid is open.
    func reconcileEventKit(_ imported: [WorkItem], in interval: DateInterval) {
        let beginning = interval.start
        let ending = interval.end
        let incomingKeys = Set(imported.compactMap { item -> String? in
            guard let c = item.externalCalendarID, let e = item.externalEventID else { return nil }
            return c + ":" + e
        })
        for fresh in imported {
            guard let c = fresh.externalCalendarID, let e = fresh.externalEventID else { continue }
            // If the same Google event was seen through two connections,
            // keep the existing direct Google record rather than making two
            // agenda cards that could be edited by different writers.
            if let uid = fresh.externalUniversalID,
               items.contains(where: { $0.externalProvider == "google" && $0.externalUniversalID == uid }) {
                continue
            }
            if let index = items.firstIndex(where: {
                // Handle existing records created before provider identity was
                // added, and EventKit IDs that changed on a remote edit.
                ($0.externalProvider == "eventkit" && $0.externalCalendarID == c &&
                 ($0.externalEventID == e ||
                  (fresh.externalUniversalID != nil && $0.externalUniversalID == fresh.externalUniversalID))) ||
                ($0.externalProvider == nil && $0.calendarEventIdentifier == e)
            }) {
                if CalendarSyncRules.protectsLocalEdit(items[index].syncState) { continue }
                var existing = items[index]
                existing.title = fresh.title
                existing.notes = fresh.notes
                existing.scheduledStart = fresh.scheduledStart
                existing.durationMinutes = fresh.durationMinutes
                existing.isFixed = fresh.isFixed
                existing.isAllDay = fresh.isAllDay
                existing.calendarEventIdentifier = fresh.calendarEventIdentifier
                existing.externalProvider = "eventkit"
                existing.externalCalendarID = c
                existing.externalEventID = e
                existing.externalUniversalID = fresh.externalUniversalID
                existing.syncState = "synced"
                items[index] = existing
            } else { items.append(fresh) }
        }
        // Missing external events represent deleted or moved occurrences. Do
        // not remove a locally modified item still queued for publication.
        items.removeAll { item in
            guard item.externalProvider == "eventkit",
                  !CalendarSyncRules.protectsLocalEdit(item.syncState),
                  let start = item.scheduledStart, start >= beginning, start < ending,
                  let c = item.externalCalendarID, let e = item.externalEventID else { return false }
            return !incomingKeys.contains(c + ":" + e)
        }
        persist()
    }

    func clearGoogleImportedCache() {
        items.removeAll { $0.externalProvider == "google" &&
            $0.syncState != "pending" && $0.syncState != "failed" && $0.syncState != "conflicted" }
        persist()
    }

    @discardableResult
    func applyGoogle(_ delta: GoogleCalendarService.CalendarDelta) -> Bool {
        if delta.tokenExpired {
            // Replace only this Google calendar cache after a 410, not tasks.
            items.removeAll { $0.externalProvider == "google" &&
                $0.externalCalendarID == delta.calendarID &&
                !CalendarSyncRules.protectsLocalEdit($0.syncState) }
        }
        let deleted = Set(delta.removedIDs)
        items.removeAll { $0.externalProvider == "google" &&
            $0.externalCalendarID == delta.calendarID &&
            $0.externalEventID.map { deleted.contains($0) } == true &&
            !CalendarSyncRules.protectsLocalEdit($0.syncState) }
        for item in delta.upserts {
            guard let eventID = item.externalEventID else { continue }
            // Avoid double-ingesting a Google event already exposed to us by
            // iOS Calendar; prefer the EventKit path for that same source UID.
            if let uid = item.externalUniversalID,
               items.contains(where: { $0.externalProvider == "eventkit" && $0.externalUniversalID == uid }) {
                continue
            }
            if let index = items.firstIndex(where: { $0.externalProvider == "google" &&
                $0.externalCalendarID == delta.calendarID && $0.externalEventID == eventID }) {
                if CalendarSyncRules.protectsLocalEdit(items[index].syncState) { continue }
                var existing = items[index]
                existing.title = item.title
                existing.notes = item.notes
                existing.scheduledStart = item.scheduledStart
                existing.durationMinutes = item.durationMinutes
                existing.externalETag = item.externalETag
                existing.externalUniversalID = item.externalUniversalID
                existing.isFixed = item.isFixed
                existing.isAllDay = item.isAllDay
                items[index] = existing
            } else { items.append(item) }
        }
        return persist()
    }

    @discardableResult private func persist() -> Bool {
        do {
            try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(DataSnapshot(tasks: items, blockPlan: blockPlan))
            try data.write(to: path, options: .atomic)
            return true
        } catch {
            recoveryWarning = "Task saving failed: \(error.localizedDescription)"
            return false
        }
    }
}
