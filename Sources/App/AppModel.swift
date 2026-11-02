import Foundation
import SwiftUI
import WidgetKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    let work = WorkRepository()
    let protection = ProtectionService()
    let live = LiveActivityService()
    let notices = Notifications()
    let events = CalendarService()
    let google = GoogleCalendarService()
    let audio = FocusAudioPlayer()
    private let engine: IgnitionSessionStore
    private var workObserver: AnyCancellable?
    private var protectionObserver: AnyCancellable?
    private var notificationActionObserver: AnyCancellable?
    private var expiryWatch: Task<Void, Never>?
    private var pendingReviewAfterFocus = false
    private var isRefreshing = false
    private var refreshQueued = false
    private var calendarSyncingIDs = Set<UUID>()
    private var googleSyncingIDs = Set<UUID>()
    private var calendarRefreshInProgress = false
    @Published var calendarSyncStatus = "Connect Apple Calendar to sync"
    struct CalendarConflict {
        let localID: UUID
        let remote: WorkItem
    }
    @Published var calendarConflict: CalendarConflict?
    var conflictDescription: String {
        guard let conflict = calendarConflict, let local = work.item(conflict.localID) else { return "" }
        let a = local.scheduledStart?.formatted(date: .abbreviated, time: .shortened) ?? "No time"
        let b = conflict.remote.scheduledStart?.formatted(date: .abbreviated, time: .shortened) ?? "No time"
        return "Ignition: \(local.title) at \(a)\nGoogle: \(conflict.remote.title) at \(b)"
    }
    func resolveCalendarConflict(useGoogle: Bool) {
        guard let conflict = calendarConflict, var local = work.item(conflict.localID) else { return }
        if useGoogle {
            local.title = conflict.remote.title
            local.notes = conflict.remote.notes
            local.scheduledStart = conflict.remote.scheduledStart
            local.durationMinutes = conflict.remote.durationMinutes
            local.syncState = "synced"
        } else {
            // Rebase against the newly retrieved provider version. A second
            // 412 will show the conflict again instead of overwriting blindly.
            local.syncState = "pending"
        }
        local.externalETag = conflict.remote.externalETag
        work.upsert(local)
        calendarConflict = nil
        if !useGoogle { syncGoogleItem(local.id) }
    }
    @Published var session: FocusSession?
    @Published var lastEnded: FocusSession?
    @Published var journal: [FocusEvent] = []
    @Published var sessionsHistory: [FocusSession] = []
    @Published var selectedBlockID: UUID?
    @Published var selectedTaskID: UUID?
    @Published var defaultMinutes: Int = {
        let stored = UserDefaults.standard.integer(forKey: "IgnitionDefaultMinutes")
        return [2, 10, 15, 25, 45, 60].contains(stored) ? stored : 25
    }() {
        didSet { UserDefaults.standard.set(defaultMinutes, forKey: "IgnitionDefaultMinutes") }
    }
    @Published var showFocus = false
    @Published var showClose = false
    @Published var showStartSmall = false
    @Published var errorMessage: String?
    @Published var selectedDate: Date = Date()
    @Published var importedCalendar = false
    @Published var settingsOpen = false
    @Published var liveActivityStatus = "Not started"

    init() {
        let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: IgnitionConfig.group)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let path = root.appendingPathComponent("sessions-v1.json")
        do { engine = try IgnitionSessionStore(fileURL: path) }
        catch {
            // Never overwrite a damaged session history silently.
            let fallback = root.appendingPathComponent("sessions-recovery-\(UUID().uuidString).json")
            engine = IgnitionSessionStore(emptyAt: fallback)
            errorMessage = "Could not read session history. Original data was preserved."
        }
        if let warning = work.recoveryWarning { errorMessage = warning }
        workObserver = work.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        protectionObserver = protection.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        notificationActionObserver = NotificationCenter.default.publisher(for: .ignitionNotificationStartFocus)
            .sink { [weak self] _ in
                Task { @MainActor in await self?.consumePendingNotificationAction() }
            }
        // MainTabs .task performs the first refresh; do not race it with an
        // additional initializer-launched refresh / Live Activity request.
    }

    /// Handles an explicit "Start focus" notification action. Ordinary
    /// notification delivery does not create a focus session or apply shields.
    func consumePendingNotificationAction() async {
        let key = "ignition.pendingStartTaskID"
        guard let raw = UserDefaults.standard.string(forKey: key),
              let id = UUID(uuidString: raw) else { return }
        UserDefaults.standard.removeObject(forKey: key)
        guard let item = work.item(id), !item.isComplete, !item.isFixed else { return }
        chooseTask(id)
        await lockIn()
    }

    var selectedTask: WorkItem? { work.item(selectedTaskID) }
    var selectedBlock: FocusBlock? { work.block(selectedBlockID) }
    var focusBlock: FocusBlock? { work.block(session?.blockID) }

    func chooseTask(_ id: UUID?) {
        selectedBlockID = nil
        selectedTaskID = id
    }
    func chooseBlock(_ id: UUID?) {
        selectedTaskID = nil
        selectedBlockID = id
    }
    func completeBlockTask(_ id: UUID, completed: Bool) {
        guard work.item(id) != nil else { return }
        work.setComplete(id, completed)
        if completed { notices.cancelForItem(id) }
        // Task checkboxes are independent from timer state. Push their current
        // real values to the Lock Screen immediately, without resetting time.
        Task { [weak self] in
            guard let self else { return }
            await self.live.sync(session: self.session, tasks: self.liveTasks(for: self.session))
            self.liveActivityStatus = self.live.lastStatus
        }
    }

    private func liveTasks(for active: FocusSession?) -> [WorkItem] {
        guard let active else { return [] }
        if let block = work.block(active.blockID) { return work.tasks(in: block) }
        if let task = work.item(active.taskID) { return [task] }
        return []
    }

    var activeSession: Bool { session?.phase != .ended && session != nil }

    /// Re-arm the foreground timer on start/resume and scene reactivation.
    /// Backgrounds may suspend this Task; reopening the app calls refresh().
    private func armDeadlineWatch() {
        expiryWatch?.cancel()
        expiryWatch = nil
        guard let session else { return }
        let sessionID = session.id
        let seconds: TimeInterval
        if session.phase == .active {
            seconds = max(0, session.remainingSeconds(asOf: Date()))
        } else if session.phase == .onBreak, let breakStarted = session.breakStartedAt {
            // Break release is its own five-minute deadline; unlike paused focus,
            // it needs a foreground reconciliation even though work time is frozen.
            seconds = breakStarted.addingTimeInterval(300).timeIntervalSinceNow
            guard seconds > 0 else { return }
        } else { return }
        expiryWatch = Task { [weak self] in
            if seconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(min(seconds, 86400) * 1_000_000_000))
            }
            guard !Task.isCancelled, let self, self.session?.id == sessionID else { return }
            await self.refresh()
        }
    }

    func refresh() async {
        if isRefreshing { refreshQueued = true; return }
        isRefreshing = true
        repeat {
            refreshQueued = false
            await performRefresh()
        } while refreshQueued
        isRefreshing = false
    }
    private func performRefresh() async {
        do {
            let prior = session
            let state = try await engine.snapshot()
            journal = state.events
            sessionsHistory = state.sessions
            session = state.ongoingSession()
            // On a cold relaunch, continue the person's saved focus sound only if
            // the restored session is actively running. An ordinary foreground
            // refresh never restarts a sound they deliberately stopped.
            if prior == nil, let session, session.phase == .active {
                audio.resumeForSession()
            }
            // Restore selection after relaunch, including the block that launched focus.
            if let current = session {
                if let id = current.blockID, work.block(id) != nil { chooseBlock(id) }
                else if selectedTaskID == nil { selectedTaskID = current.taskID }
            }
            lastEnded = state.sessions.last(where: { $0.phase == .ended })
            protection.reconcile(session: session)
            await live.sync(session: session, tasks: liveTasks(for: session))
            liveActivityStatus = live.lastStatus
            updateWidget()
            if let session, session.phase == .active { notices.scheduleCompletion(session: session) }
            else { notices.cancelCompletion() }
            armDeadlineWatch()
            if session == nil, let ended = lastEnded {
                if prior != nil { audio.stop() }
                if ended.endReason != .emergencyExit && ended.reviewAcknowledgedAt == nil {
                    if showFocus {
                        pendingReviewAfterFocus = true
                        showFocus = false
                    } else if !pendingReviewAfterFocus {
                        showClose = true
                    }
                } else {
                    pendingReviewAfterFocus = false
                    showFocus = false
                    showClose = false
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }
    /// Called after fullScreenCover has actually dismissed, avoiding a sheet
    /// competing with the fullscreen Focus presentation in the same update.
    func presentReviewAfterFocusDismissal() {
        guard pendingReviewAfterFocus else { return }
        pendingReviewAfterFocus = false
        if let ended = lastEnded, ended.reviewAcknowledgedAt == nil,
           ended.endReason != .emergencyExit, session == nil {
            showClose = true
        }
    }

    private func updateWidget() {
        guard let session else {
            let next = work.upcoming().first
            SharedConfiguration.widgetSummary = WidgetSummary(task: next?.title ?? "Ready to focus?", detail: next?.nextStep ?? "Open Ignition to start", sessionStart: nil, expectedEnd: nil, isActive: false)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        SharedConfiguration.widgetSummary = WidgetSummary(
            task: session.title, detail: session.nextStep ?? "Stay with your task",
            sessionStart: session.startedAt,
            expectedEnd: session.phase == .active ? Date().addingTimeInterval(session.remainingSeconds(asOf: Date())) : nil,
            isActive: session.phase == .active
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
    private var startingSession = false
    @Published private(set) var isStartingFocus = false

    /// The completion alert is how the person is pulled back when the timer ends. Permission used to be
    /// requested only from a Settings button, so most people never granted it. Ask once, at the first lock-in.
    private func requestNotificationsOnce() async {
        let key = "ignition.askedNotificationPermission"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        _ = await notices.authorize()
    }
    func lockIn(minutes: Int? = nil, small: Bool = false, blockID: UUID? = nil) async {
        guard !startingSession else { return }
        startingSession = true
        isStartingFocus = true
        defer {
            startingSession = false
            isStartingFocus = false
        }
        if let existing = session {
            if existing.phase == .paused || existing.phase == .onBreak { await resume(); return }
            if existing.phase == .active { showFocus = true; return }
        }
        await requestNotificationsOnce()
        // A block is a time reservation with multiple tasks. Never mark the
        // first task complete simply because the block focus timer ended.
        let block = work.block(blockID ?? selectedBlockID)
        let item = block == nil ? selectedTask : nil
        let firstUnfinished = block.flatMap { block in
            work.tasks(in: block).first(where: { !$0.isComplete })
        }
        let focusTitle = block?.title ?? item?.title ?? "Quick focus"
        let next = firstUnfinished.map { $0.nextStep.isEmpty ? $0.title : $0.nextStep }
            ?? (item?.nextStep.isEmpty == false ? item?.nextStep : nil)
        do {
            let created = try await engine.start(
                taskID: item?.id, blockID: block?.id,
                title: focusTitle,
                nextStep: next,
                duration: TimeInterval((small ? 2 : (minutes ?? defaultMinutes)) * 60)
            )
            session = created
            if let block { chooseBlock(block.id) }
            pendingReviewAfterFocus = false
            showClose = false
            showFocus = true  // Present promptly; shielding status remains truthful.
            showStartSmall = false
            await Task.yield()
            notices.cancelRescue(taskID: item?.id)
            _ = protection.activate(sessionID: created.id, duration: created.targetSeconds)
            await refresh()
            audio.resumeForSession()
        } catch { errorMessage = error.localizedDescription }
    }
    func restart(_ previous: FocusSession, small: Bool = false) async {
        if let blockID = previous.blockID, work.block(blockID) != nil {
            chooseBlock(blockID)
            await lockIn(small: small, blockID: blockID)
            return
        }
        if let saved = work.item(previous.taskID) {
            selectedTaskID = saved.id
            await lockIn(small: small)
            return
        }
        guard session == nil else { return }
        do {
            let created = try await engine.start(taskID: previous.taskID, blockID: previous.blockID,
                title: previous.title, nextStep: previous.nextStep,
                duration: TimeInterval((small ? 2 : defaultMinutes) * 60))
            session = created
            _ = protection.activate(sessionID: created.id, duration: created.targetSeconds)
            await refresh()
            pendingReviewAfterFocus = false
            showClose = false
            showFocus = true
            audio.resumeForSession()
        } catch { errorMessage = error.localizedDescription }
    }

    /// Replace an intentionally paused session with a new short one without
    /// briefly presenting Close over an already active full-screen focus view.
    func restartPausedSmall() async {
        guard let prior = session, prior.phase == .paused || prior.phase == .onBreak else { return }
        do {
            let ended = try await engine.end()
            _ = try await engine.recordReview(outcome: nil, nextStep: nil, sessionID: ended.id)
            protection.deactivate()
            notices.cancelCompletion()
            notices.cancelBreakReminder()
            let created = try await engine.start(taskID: prior.taskID, blockID: prior.blockID, title: prior.title,
                                                 nextStep: prior.nextStep, duration: 120)
            session = created
            _ = protection.activate(sessionID: created.id, duration: 120)
            await refresh()
            pendingReviewAfterFocus = false
            showClose = false
            showFocus = true
        } catch {
            errorMessage = error.localizedDescription
            await refresh()
        }
    }

    func pause() async {
        do {
            let paused = try await engine.pause()
            session = paused
            audio.pauseForSession()
            protection.deactivate()
            await refresh()
        }
        catch { errorMessage = error.localizedDescription }
    }
    func startBreak() async {
        do {
            let paused = try await engine.startBreak()
            session = paused
            audio.pauseForSession()
            notices.cancelCompletion()
            notices.scheduleBreakReminder(after: 300)
            // Do NOT call protection.activate here. A 5-minute schedule is below the 16-minute safe-release
            // minimum, and activate() always starts with deactivate(), so doing so removed the shield.
            // ProtectionService.reconcile() keeps an unexpired lease through .onBreak; the existing
            // release backstop still ends it at the original lease expiry.
            await refresh()
        } catch { errorMessage = error.localizedDescription }
    }
    func resume() async {
        do {
            let changed = try await engine.resume()
            notices.cancelBreakReminder()
            session = changed
            _ = protection.activate(sessionID: changed.id, duration: changed.remainingSeconds(asOf: Date()))
            await refresh()
            audio.resumeForSession()
            showFocus = true
        } catch { errorMessage = error.localizedDescription }
    }
    func end(emergency: Bool = false) async {
        if emergency { protection.deactivate() }
        do {
            _ = try await engine.end(emergency: emergency)
            protection.deactivate()
            notices.cancelCompletion()
            notices.cancelBreakReminder()
            audio.stop()
            await refresh()
            if emergency { pendingReviewAfterFocus = false; showFocus = false; showClose = false }
        } catch IgnitionSessionError.noOngoingSession {
            protection.deactivate()
            notices.cancelCompletion()
            notices.cancelBreakReminder()
            audio.stop()
            await refresh()
            if emergency { pendingReviewAfterFocus = false; showFocus = false; showClose = false }
        } catch {
            if emergency { protection.deactivate() }
            errorMessage = error.localizedDescription
        }
    }
    func record(outcome: FocusOutcome?, nextStep: String?) async {
        guard let ended = lastEnded else { showClose = false; return }
        do {
            let reviewed = try await engine.recordReview(outcome: outcome, nextStep: nextStep, sessionID: ended.id)
            if reviewed.outcome == .finished, reviewed.blockID == nil, let id = reviewed.taskID {
                work.setComplete(id, true)
                notices.cancelForItem(id)
            }
            if let step = reviewed.nextStep, var task = work.item(reviewed.taskID) {
                task.nextStep = step
                work.upsert(task)
                notices.scheduleReminder(for: task)
            }
            showClose = false
            await refresh()
        } catch { errorMessage = error.localizedDescription }
    }
    func save(_ item: WorkItem) {
        if let old = work.item(item.id), old.calendarEventIdentifier != nil,
           item.scheduledStart == nil {
            errorMessage = "The external calendar event still exists. Move it instead of unscheduling locally."
            return
        }
        var pending = item
        // Never run two calendar writers for one record.
        if pending.externalProvider == "google" { pending.syncToAppleCalendar = false }
        if item.externalProvider == "google" {
            pending.syncState = "pending"
        } else if item.syncToAppleCalendar && item.scheduledStart != nil {
            pending.syncState = "pending"
        }
        work.upsert(pending)
        notices.scheduleReminder(for: pending)
        updateWidget()
        if pending.externalProvider == "google" {
            syncGoogleItem(pending.id)
        } else if pending.syncToAppleCalendar && pending.scheduledStart != nil {
            synchronizeCalendar(id: pending.id)
        }
    }

    /// A pending sync state is persisted BEFORE network or EventKit work.
    /// Multiple quick edits serialize by task ID; don't create duplicate events.
    private func synchronizeCalendar(id: UUID) {
        guard !calendarSyncingIDs.contains(id) else { return }
        calendarSyncingIDs.insert(id)
        Task {
            defer { calendarSyncingIDs.remove(id) }
            for _ in 0..<8 {
                guard let submitted = work.item(id), submitted.syncToAppleCalendar,
                      submitted.scheduledStart != nil else { break }
                do {
                    let externalID = try await events.save(task: submitted)
                    guard var latest = work.item(id) else { break }
                    if let externalID {
                        latest.calendarEventIdentifier = externalID
                        latest.externalEventID = externalID
                        latest.externalProvider = "eventkit"
                    }
                    let unchanged = latest.title == submitted.title &&
                        latest.notes == submitted.notes &&
                        latest.scheduledStart == submitted.scheduledStart &&
                        latest.durationMinutes == submitted.durationMinutes
                    // A user may delete this event while creation is in
                    // flight. Preserve the tombstone and delete the just-
                    // created provider event instead of resurrecting it.
                    let deleteRequested = latest.syncState == "deleting" || latest.syncState == "delete-failed"
                    latest.syncState = deleteRequested ? "deleting" : (unchanged ? "synced" : "pending")
                    work.upsert(latest)
                    if deleteRequested { await deleteExternalItem(id); break }
                    if unchanged { break }
                } catch {
                    if var pending = work.item(id) {
                        pending.syncState = "failed"
                        work.upsert(pending)
                    }
                    calendarSyncStatus = "Calendar write failed · Tap refresh to retry"
                    errorMessage = "Saved locally, but Apple Calendar sync failed: \(error.localizedDescription)"
                    break
                }
            }
        }
    }

    private func syncGoogleItem(_ id: UUID) {
        guard !googleSyncingIDs.contains(id) else { return }
        googleSyncingIDs.insert(id)
        Task {
            defer { googleSyncingIDs.remove(id) }
            for _ in 0..<5 {
                guard let submitted = work.item(id), submitted.externalProvider == "google" else { break }
                do {
                    let updated = try await google.save(task: submitted)
                    guard var latest = work.item(id) else { break }
                    let unchanged = latest.title == submitted.title &&
                        latest.notes == submitted.notes &&
                        latest.scheduledStart == submitted.scheduledStart &&
                        latest.durationMinutes == submitted.durationMinutes
                    latest.externalETag = updated.etag
                    latest.externalEventID = updated.id
                    latest.externalUniversalID = updated.iCalUID
                    let deleteRequested = latest.syncState == "deleting" || latest.syncState == "delete-failed"
                    latest.syncState = deleteRequested ? "deleting" : (unchanged ? "synced" : "pending")
                    work.upsert(latest)
                    if deleteRequested { await deleteExternalItem(id); break }
                    if unchanged { break }
                } catch GoogleCalendarService.GoogleError.conflict {
                    if let submitted = work.item(id),
                       let calendarID = submitted.externalCalendarID,
                       let eventID = submitted.externalEventID {
                        do {
                            let remote = try await google.fetchCurrent(calendarID: calendarID, eventID: eventID)
                            var pending = submitted
                            pending.syncState = "conflicted"
                            work.upsert(pending)
                            calendarConflict = CalendarConflict(localID: id, remote: remote)
                            calendarSyncStatus = "Google event changed elsewhere · Choose a version"
                        } catch {
                            errorMessage = "Could not retrieve the changed Google event: \(error.localizedDescription)"
                        }
                    }
                    break
                } catch {
                    if var pending = work.item(id) {
                        pending.syncState = "failed"
                        work.upsert(pending)
                    }
                    calendarSyncStatus = "Google Calendar write failed · Retry"
                    errorMessage = "Saved locally; Google Calendar could not be updated: \(error.localizedDescription)"
                    break
                }
            }
        }
    }
    /// Two-way deletion: retain a persistent tombstone until the provider
    /// acknowledges it. Never delete a cached event locally and then hope
    /// its remote copy disappears on the next refresh.
    func deleteTask(_ id: UUID) {
        guard let existing = work.item(id) else { return }
        guard !existing.isFixed else {
            errorMessage = "This calendar is read-only. Delete the event from its original calendar."
            return
        }
        if existing.externalProvider == "google" || existing.externalProvider == "eventkit" || existing.syncToAppleCalendar {
            let googleCreating = existing.externalProvider == "google" && googleSyncingIDs.contains(id)
            let appleCreating = existing.syncToAppleCalendar && calendarSyncingIDs.contains(id)
            // No remote event exists and no creation request is outstanding.
            if existing.externalEventID == nil && existing.calendarEventIdentifier == nil &&
               !googleCreating && !appleCreating {
                work.remove(id)
                notices.cancelForItem(id)
                return
            }
            var deleting = existing
            deleting.syncState = "deleting"
            work.upsert(deleting)
            if deleting.externalEventID != nil || deleting.calendarEventIdentifier != nil {
                Task { await deleteExternalItem(id) }
            }
            // Otherwise wait for the in-flight insert to return its provider ID.
            return
        }
        work.remove(id)
        notices.cancelForItem(id)
        if selectedTaskID == id { selectedTaskID = nil }
        updateWidget()
    }

    private func deleteExternalItem(_ id: UUID) async {
        guard let item = work.item(id), item.syncState == "deleting" || item.syncState == "delete-failed" else { return }
        do {
            if item.externalProvider == "google" {
                try await google.delete(task: item)
            } else {
                try await events.delete(task: item)
            }
            work.remove(id)
            notices.cancelForItem(id)
            if selectedTaskID == id { selectedTaskID = nil }
            updateWidget()
        } catch {
            if var failed = work.item(id) {
                failed.syncState = "delete-failed"
                work.upsert(failed)
            }
            calendarSyncStatus = "Calendar deletion not synced · Retry"
            errorMessage = "The event still exists in its calendar. Saved deletion for retry: \(error.localizedDescription)"
        }
    }
    func setComplete(_ id: UUID, _ complete: Bool) {
        work.setComplete(id, complete)
        if complete { notices.cancelForItem(id) }
        else if let item = work.item(id) { notices.scheduleReminder(for: item) }
        updateWidget()
    }

    func importCalendar(for day: Date, promptForPermission: Bool = true) async {
        do {
            if !events.isAuthorized && !promptForPermission { return }
            let imported = try await events.load(day: day, requestPermission: promptForPermission)
            guard events.isAuthorized else { return }
            work.reconcileEventKit(imported, for: day)
            importedCalendar = true
            calendarSyncStatus = "Apple Calendar updated · \(Date().formatted(date: .omitted, time: .shortened))"
        } catch {
            calendarSyncStatus = "Apple Calendar unavailable"
            errorMessage = "Calendar unavailable: \(error.localizedDescription)"
        }
    }

    /// Import only the viewed month from a previously authorized iOS Calendar.
    /// Day view remains unchanged; no external event is scheduled by merely
    /// opening the month. Calendar-math increments handle DST transitions.
    func importCalendarMonth(containing date: Date) async {
        guard events.isAuthorized,
              let interval = Calendar.current.dateInterval(of: .month, for: date) else { return }
        do {
            let imported = try await events.load(from: interval.start, to: interval.end,
                                                 requestPermission: false)
            work.reconcileEventKit(imported, in: interval)
            calendarSyncStatus = "Apple Calendar month updated · \(Date().formatted(date: .omitted, time: .shortened))"
        } catch {
            calendarSyncStatus = "Apple Calendar unavailable"
            errorMessage = "Calendar unavailable: \(error.localizedDescription)"
        }
    }

    /// Called when Plan opens, on pull-to-refresh, and approximately every
    /// 60 seconds WHILE Plan is visible. iOS does not promise background polls.
    func refreshCalendars() async {
        guard !calendarRefreshInProgress else { return }
        calendarRefreshInProgress = true
        defer { calendarRefreshInProgress = false }
        if events.isAuthorized { await importCalendar(for: selectedDate, promptForPermission: false) }
        for item in work.items {
            if item.syncState == "deleting" || item.syncState == "delete-failed" {
                if item.externalProvider != "google" || google.connected {
                    await deleteExternalItem(item.id)
                }
                continue
            }
            guard item.syncState == "failed" || item.syncState == "pending" else { continue }
            if item.externalProvider == "google" && google.connected { syncGoogleItem(item.id) }
            else if item.syncToAppleCalendar && events.isAuthorized { synchronizeCalendar(id: item.id) }
        }
        if google.connected {
            do {
                let all = try await google.listCalendars()
                for calendar in all {
                    let delta = try await google.fetchChanges(calendar: calendar)
                    // Commit the Google cursor ONLY if the local cache was
                    // durably persisted. Otherwise repeat the same delta.
                    guard work.applyGoogle(delta) else {
                        throw NSError(domain: "IgnitionSync", code: 8,
                            userInfo: [NSLocalizedDescriptionKey: "Local calendar data could not be written; Google cursor was not advanced"])
                    }
                    google.commit(delta)
                }
                calendarSyncStatus = "Google Calendar updated · \(Date().formatted(date: .omitted, time: .shortened))"
            } catch {
                calendarSyncStatus = "Google sync failed · Retry"
                errorMessage = "Google Calendar: \(error.localizedDescription)"
            }
        }
    }
    func resize(_ id: UUID, by minutes: Int) async {
        guard var task = work.item(id), !task.isFixed else { return }
        task.durationMinutes = max(5, min(360, task.durationMinutes + minutes))
        save(task) // Single local persistence, reminder, and external-sync route.
    }
    func move(_ id: UUID, to date: Date) async {
        guard var task = work.item(id), !task.isFixed else { return }
        task.scheduledStart = date
        save(task)
    }
}
