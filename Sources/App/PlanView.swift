import SwiftUI
import EventKit
import UIKit

/// Small shared motion/haptic vocabulary for Plan. These are intentional,
/// not decorations: one lift, one tick per 15-minute boundary, one commit.
private enum PlanMotion {
    static let settle = IgnitionMotion.settle
    static let quick = IgnitionMotion.quick
}

private enum PlanFeedback {
    static func lift() { IgnitionFeedback.lift() }
    static func tick() { IgnitionFeedback.selection() }
    static func committed() { IgnitionFeedback.success() }
}

/// A restrained Plan palette. Shared with the rest of Ignition where practical;
/// these surface colors have deliberately different calendar/drawer roles.
private enum PlanPalette {
    static let ink = Color(red: 0.092, green: 0.160, blue: 0.279)
    static let canvas = Color(red: 0.950, green: 0.960, blue: 0.975)
    static let calendar = Color(red: 0.995, green: 0.997, blue: 1.000)
    static let drawer = Color(red: 0.106, green: 0.161, blue: 0.239)
    static let row = Color(red: 0.145, green: 0.215, blue: 0.309)
    static let secondary = Color(red: 0.680, green: 0.756, blue: 0.840)
    static let white = Color(red: 0.980, green: 0.988, blue: 1.000)
    static let grid = Color(red: 0.874, green: 0.899, blue: 0.938)
    static let coral = Color(red: 0.906, green: 0.335, blue: 0.381)
    static let block = Color(red: 0.834, green: 0.900, blue: 0.997)
}

/// Day keeps the existing scrollable hour grid and dark task drawer.
/// Month is an overview and date chooser; dropped tasks are staged until
/// the person explicitly selects a time in Day view.
private enum PlanCalendarMode: String, CaseIterable {
    case day = "Day"
    case month = "Month"
}

/// The Plan tab has two independently scrolling surfaces:
/// a calendar that can be expanded by pulling its divider downward, and
/// a persistent task drawer below it. The Now/Journey and Focus views are unchanged.
struct PlanView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var work: WorkRepository

    @State private var editing: WorkItem?
    @State private var scheduling: WorkItem?
    @State private var editingBlock: FocusBlock?
    @State private var assigningTask: WorkItem?
    @State private var showNew = false
    @State private var showNewEvent = false
    @State private var showAllDayPicker = false
    @State private var taskToDelete: UUID?
    @State private var showDeleteConfirmation = false
    @State private var showVoice = false
    @State private var showCalendarMenu = false
    @State private var calendarFraction: CGFloat = 0.56
    @State private var dayCalendarFraction: CGFloat = 0.56
    @State private var calendarMode: PlanCalendarMode = .day
    @State private var displayedMonth: Date = Date()
    /// An unsaved handoff from Month → Day. A date drop never schedules a
    /// 9 AM block or modifies an external appointment without choosing a time.
    @State private var pendingPlacement: String?
    @State private var placementClock: Date = Date()
    @State private var showPlacementTimePicker = false
    @GestureState private var resizeTranslation: CGFloat = 0
    @State private var hoveredQuarter: Int?
    @State private var showScheduledTasks = false
    @State private var syncRefreshing = false
    @State private var recentBlockID: UUID?
    @State private var recentMessage: String = ""
    @State private var recentConfirmationToken = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let hourHeight: CGFloat = 76
    private let timeGutter: CGFloat = 72
    private let calendar = Calendar.current
    private let detents: [CGFloat] = [0.32, 0.56, 0.79]

    init(model: AppModel) {
        self.model = model
        _work = ObservedObject(wrappedValue: model.work)
    }

    private var unscheduledTasks: [WorkItem] {
        // Keep task identity independent of block assignments. A task can
        // appear in tomorrow's block yet still be available to drag today.
        work.items.filter { !$0.isComplete && $0.scheduledStart == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var dayTasks: [WorkItem] {
        let inBlockIDs = Set(dayBlocks.flatMap(\.taskIDs))
        let scheduledIDs = Set(work.forDay(model.selectedDate).map(\.id))
        return work.items.filter { !$0.isComplete && !$0.isFixed &&
            (inBlockIDs.contains($0.id) || scheduledIDs.contains($0.id)) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
    private var dayBlocks: [FocusBlock] { work.blocksForDay(model.selectedDate) }
    // Imported appointments must appear on the timeline, never as editable
    // checklist tasks in the drawer. Keep timed events independent of Today.
    private var timedEvents: [WorkItem] {
        work.forDay(model.selectedDate).filter { $0.scheduledStart != nil && $0.isAllDay != true }
    }
    private var allDayEvents: [WorkItem] {
        work.forDay(model.selectedDate).filter { $0.isAllDay == true }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                // Fixed shell: the header and tab bar never participate in drag
                // geometry. Only the divider changes the two content regions.
                let available = max(300, geometry.size.height - 150)
                let calendarHeight = min(max(available * calendarFraction + resizeTranslation, 135), available - 122)

                VStack(spacing: 0) {
                    planHeader
                    dateHeader
                    if calendarMode == .day { weekPicker }

                    Group {
                        if calendarMode == .day { calendarSurface }
                        else { monthCalendarSurface }
                    }
                        .overlay(alignment: .bottom) {
                            if let blockID = recentBlockID {
                                scheduleConfirmation(for: blockID)
                                    .padding(.horizontal, 18)
                                    .padding(.bottom, 12)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .frame(height: calendarHeight)
                        .clipped()
                        .accessibilityIdentifier("plan.calendar")

                    resizeHandle(available: available)
                    taskDrawer
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("plan.tasks")
                }
                .background(PlanPalette.canvas)
            }
            .toolbar(.hidden, for: .navigationBar)
        }


        .sheet(isPresented: $showNew) {
            TaskEditor(googleCalendars: model.google.calendars, onSave: { model.save($0) }).presentationDetents([.large])
        }
        .sheet(isPresented: $showNewEvent) {
            TaskEditor(
                existing: WorkItem(
                    title: "",
                    scheduledStart: calendar.date(bySettingHour: 10, minute: 0, second: 0,
                                                   of: model.selectedDate) ?? model.selectedDate,
                    durationMinutes: 30,
                    tint: .purple
                ),
                googleCalendars: model.google.calendars,
                isNewEvent: true,
                onSave: { model.save($0) }
            ).presentationDetents([.large])
        }
        .sheet(item: $editing) { item in
            TaskEditor(existing: item, googleCalendars: model.google.calendars, onSave: { model.save($0) }, onDelete: { model.deleteTask($0) })
                .presentationDetents([.large])
        }
        .sheet(item: $scheduling) { item in
            PlanScheduleSheet(item: item, selectedDay: model.selectedDate) { date in
                _ = work.createBlock(at: date, taskID: item.id)
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $editingBlock) { selected in
            FocusBlockEditor(
                initial: selected,
                work: work,
                onSave: { work.upsertBlock($0) },
                onDelete: { work.deleteBlock($0) },
                onStart: { id in
                    Task { await model.lockIn(blockID: id) }
                }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $assigningTask) { task in
            BlockPickerSheet(task: task, blocks: work.blocks) { blockID in
                work.assign(task.id, to: blockID)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showVoice) {
            VoiceEntryView(model: model).presentationDetents([.large])
        }
        .sheet(isPresented: $showPlacementTimePicker) {
            NavigationStack {
                Form {
                    Section("Placing in calendar") {
                        Text(pendingTitle)
                            .font(.headline)
                        Text(model.selectedDate.formatted(date: .complete, time: .omitted))
                            .foregroundStyle(.secondary)
                        DatePicker("Start time", selection: $placementClock,
                                   displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                        Text("Focus blocks snap to the nearest 15 minutes. Calendar events keep their existing duration.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Choose a time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showPlacementTimePicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Place") {
                            placePending(at: placementClock)
                            showPlacementTimePicker = false
                        }
                        .fontWeight(.semibold)
                        .disabled(pendingPlacement == nil)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Calendar", isPresented: $showCalendarMenu) {
            Button("Connect / refresh Apple Calendar") {
                Task { await model.importCalendar(for: model.selectedDate) }
            }
            Button("Refresh all connected calendars") {
                Task { await model.refreshCalendars() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("All-day events", isPresented: $showAllDayPicker) {
            ForEach(allDayEvents) { event in
                Button(event.title) { editing = event }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Delete task?", isPresented: $showDeleteConfirmation) {
            Button("Delete task", role: .destructive) {
                if let id = taskToDelete { model.deleteTask(id) }
                taskToDelete = nil
            }
            Button("Cancel", role: .cancel) { taskToDelete = nil }
        } message: {
            Text("The task will also be removed from any focus blocks that contain it.")
        }
        .task {
            // SwiftUI cancels this task when Plan is no longer on screen.
            await model.refreshCalendars()
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 60_000_000_000) }
                catch { break }
                guard !Task.isCancelled else { break }
                await model.refreshCalendars()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            Task { await model.refreshCalendars() }
        }
        .onChange(of: model.selectedDate) { _, newDate in
            displayedMonth = calendar.dateInterval(of: .month, for: newDate)?.start ?? newDate
            Task { await model.refreshCalendars() }
        }
        .onAppear {
            displayedMonth = calendar.dateInterval(of: .month, for: model.selectedDate)?.start
                ?? model.selectedDate
        }
    }

    private var planHeader: some View {
        HStack(spacing: 7) {
            Text("Plan")
                .font(.system(size: 30, weight: .semibold, design: .default))
                .tracking(-0.7)
                .foregroundStyle(PlanPalette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 2)
            HStack(spacing: 2) {
                ForEach(PlanCalendarMode.allCases, id: \.self) { mode in
                    Button {
                        setCalendarMode(mode)
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(calendarMode == mode ? Color.white : PlanPalette.ink.opacity(0.7))
                            .frame(width: 51, height: 29)
                            .background(calendarMode == mode ? IgnitionStyle.blue : Color.clear,
                                        in: Capsule())
                    }
                    .accessibilityLabel("\(mode.rawValue) calendar view")
                    .accessibilityAddTraits(calendarMode == mode ? [.isSelected] : [])
                }
            }
            .padding(3)
            .background(PlanPalette.grid.opacity(0.65), in: Capsule())
            .accessibilityElement(children: .contain)
            Menu {
                Button("New task", systemImage: "plus.circle") { showNew = true }
                Button("Calendar event", systemImage: "calendar") { showNewEvent = true }
                Button("Focus block", systemImage: "rectangle.stack") { createFocusBlock() }
                Button("Speak to add", systemImage: "mic") { showVoice = true }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Add task, calendar event, focus block, or by voice")
            Menu {
                Button("Calendars", systemImage: "calendar") { showCalendarMenu = true }
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await model.refreshCalendars() }
                }
                Button("Settings", systemImage: "slider.horizontal.3") { model.settingsOpen = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("More Plan options")
        }
        .foregroundStyle(PlanPalette.ink)
        .buttonStyle(.plain)
        .padding(.horizontal, 19)
        .frame(height: 50)
        .background(PlanPalette.canvas)
    }

    private func createFocusBlock() {
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0,
                                  of: model.selectedDate) ?? model.selectedDate
        if let id = work.createBlock(at: start) { editingBlock = work.block(id) }
    }

    private var dateHeader: some View {
        HStack(spacing: 8) {
            Text(calendarMode == .day
                 ? model.selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
                 : displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 20, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(PlanPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 5)
            if !calendar.isDateInToday(model.selectedDate) {
                Button("Today") {
                    PlanFeedback.tick()
                    choose(Date())
                    if calendarMode == .month { displayedMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date() }
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(IgnitionStyle.blue.opacity(0.10), in: Capsule())
                .foregroundStyle(IgnitionStyle.blue)
            }
            Button { PlanFeedback.tick(); shiftVisibleDate(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(calendarMode == .day ? "Previous day" : "Previous month")
            Button { PlanFeedback.tick(); shiftVisibleDate(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(calendarMode == .day ? "Next day" : "Next month")
        }
        .buttonStyle(.plain)
        .foregroundStyle(PlanPalette.ink)
        .padding(.horizontal, 19)
        .frame(height: 43)
        .background(PlanPalette.canvas)
    }

    private var weekPicker: some View {
        HStack(spacing: 1) {
            ForEach(0..<7, id: \.self) { offset in
                let first = calendar.dateInterval(of: .weekOfYear, for: model.selectedDate)?.start
                    ?? calendar.startOfDay(for: model.selectedDate)
                let day = calendar.date(byAdding: .day, value: offset, to: first) ?? model.selectedDate
                let selected = calendar.isDate(day, inSameDayAs: model.selectedDate)
                Button {
                    if !selected { PlanFeedback.tick() }
                    withAnimation(reduceMotion ? PlanMotion.quick : PlanMotion.settle) { choose(day) }
                } label: {
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(selected ? Color.white.opacity(0.9) : PlanPalette.ink.opacity(0.6))
                        Text(day.formatted(.dateTime.day()))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selected ? Color.white : PlanPalette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(selected ? IgnitionStyle.blue : Color.clear,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
        .background(PlanPalette.canvas)
    }


    private var calendarSurface: some View {
        VStack(spacing: 0) {
            if pendingPlacement != nil {
                pendingPlacementBanner
                    .padding(.horizontal, 12)
                    .padding(.top, 7)
                    .padding(.bottom, 8)
            }

            if !allDayEvents.isEmpty {
                HStack(spacing: 7) {
                    Text("All day")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PlanPalette.ink.opacity(0.55))
                        .frame(width: timeGutter, alignment: .leading)
                    ForEach(Array(allDayEvents.prefix(2))) { event in
                        Button { editing = event } label: {
                            Text(event.title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                                .padding(.horizontal, 9)
                                .frame(height: 27)
                                .background(event.tint.color.opacity(0.13), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(PlanPalette.ink)
                    }
                    if allDayEvents.count > 2 {
                        Button("+\(allDayEvents.count - 2)") { showAllDayPicker = true }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(IgnitionStyle.blue)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 13)
                .frame(height: 34)
            }


            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    calendarGrid
                        .padding(.horizontal, 12)
                }
                .scrollIndicators(.hidden)
                .background(PlanPalette.calendar)
                .onAppear { scrollToUsefulTime(proxy) }
                .onChange(of: calendar.startOfDay(for: model.selectedDate)) { _ in
                    scrollToUsefulTime(proxy)
                }
            }
        }
        .background(PlanPalette.calendar)
    }

    /// Scroll only when the user changes the date or first enters Plan; never
    /// keep recentering while they are exploring or dragging an event.
    private func scrollToUsefulTime(_ proxy: ScrollViewProxy) {
        let hour = calendar.isDateInToday(model.selectedDate)
            ? max(0, calendar.component(.hour, from: Date()) - 1) : 8
        DispatchQueue.main.async {
            proxy.scrollTo("hour-\(hour)", anchor: .top)
        }
    }

    private var calendarGrid: some View {
        GeometryReader { geometry in
            // All-day items have their own lane; painting a 24-hour event
            // across the timeline would conceal every timed appointment.
            let events = timedEvents
            let entries: [PlanOverlapLayout.Entry] = events.compactMap { item in
                guard let start = item.scheduledStart else { return nil }
                return .init(id: item.id, start: start, end: item.scheduledEnd ?? start.addingTimeInterval(60))
            } + dayBlocks.map { .init(id: $0.id, start: $0.start, end: $0.end) }
            let slots = PlanOverlapLayout.calculate(for: entries)
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        VStack(spacing: 0) {
                            ForEach(0..<4, id: \.self) { quarter in
                                let slot = hour * 4 + quarter
                                HStack(spacing: 0) {
                                    Text(quarter == 0 ? hourLabel(hour) : "")
                                        .font(.system(size: 11, weight: quarter == 0 ? .medium : .regular))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.83)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .frame(width: timeGutter, alignment: .leading)
                                    Rectangle()
                                        .fill(quarter == 0 ? PlanPalette.grid : (quarter == 2 ? PlanPalette.grid.opacity(0.42) : Color.clear))
                                        .frame(height: 1)
                                }
                                .frame(height: hourHeight / 4, alignment: .top)
                                .background(hoveredQuarter == slot ? IgnitionStyle.blue.opacity(0.13) : Color.clear)
                                .overlay(alignment: .leading) {
                                    if hoveredQuarter == slot {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(IgnitionStyle.blue)
                                            .frame(width: 3)
                                            .padding(.leading, timeGutter)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { createAtQuarter(slot) }
                                .dropDestination(for: String.self) { payload, _ in
                                    scheduleDragged(payload, at: slot)
                                } isTargeted: { targeted in
                                    if targeted && hoveredQuarter != slot {
                                        hoveredQuarter = slot
                                        PlanFeedback.tick()
                                    } else if !targeted && hoveredQuarter == slot {
                                        hoveredQuarter = nil
                                    }
                                }
                            }
                        }
                        .id("hour-\(hour)")
                    }
                }

                ForEach(events) { item in
                    if let start = item.scheduledStart {
                        let position = slots[item.id] ?? PlanOverlapLayout.Position(lane: 0, lanes: 1)
                        let calendarStart = calendar.startOfDay(for: model.selectedDate)
                        let rawY = CGFloat(start.timeIntervalSince(calendarStart) / 3600) * hourHeight
                        let startY = max(0, rawY)
                        let wholeHeight = CGFloat(item.durationMinutes) / 60 * hourHeight
                        let clippedHeight = min(wholeHeight - max(0, -rawY), 24 * hourHeight - startY)
                        let eventHeight = max(0, clippedHeight - 3)
                        let contentWidth = max(1, geometry.size.width - timeGutter - 5)
                        let laneWidth = contentWidth / CGFloat(max(1, position.lanes))
                        if eventHeight > 2 {
                            eventCard(item, start: start, height: eventHeight)
                                .frame(width: max(1, laneWidth - 3), height: eventHeight)
                                .offset(x: timeGutter + CGFloat(position.lane) * laneWidth, y: startY)
                        }
                    }
                }

                focusBlockLayer(canvasWidth: geometry.size.width, slots: slots)

                if calendar.isDateInToday(model.selectedDate) {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        let now = context.date
                        let minutes = CGFloat(calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now))
                        let y = minutes / 60 * hourHeight
                        HStack(spacing: 0) {
                            Text(now.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .frame(width: timeGutter - 4, height: 23)
                                .background(PlanPalette.coral, in: Capsule())
                                .frame(width: timeGutter, alignment: .leading)
                            Rectangle().fill(PlanPalette.coral.opacity(0.88)).frame(height: 1)
                        }
                        .offset(y: y - 10)
                        .zIndex(10)
                        .allowsHitTesting(false)
                        .accessibilityLabel("Current time \(now.formatted(date: .omitted, time: .shortened))")
                    }
                }
            }
            .frame(width: geometry.size.width, height: 24 * hourHeight, alignment: .topLeading)
        }
        .frame(height: 24 * hourHeight)
        .accessibilityIdentifier("plan.timeline")
    }

    /// Separate builder keeps Xcode's SwiftUI type-checking workload small.
    @ViewBuilder
    private func focusBlockLayer(canvasWidth: CGFloat,
                                 slots: [UUID: PlanOverlapLayout.Position]) -> some View {
        ForEach(dayBlocks) { block in
            let position = slots[block.id] ?? PlanOverlapLayout.Position(lane: 0, lanes: 1)
            let calendarStart = calendar.startOfDay(for: model.selectedDate)
            let rawY = CGFloat(block.start.timeIntervalSince(calendarStart) / 3600) * hourHeight
            let startY = max(0, rawY)
            let wholeHeight = CGFloat(block.durationMinutes) / 60 * hourHeight
            let visibleHeight = min(wholeHeight - max(0, -rawY), 24 * hourHeight - startY)
            let eventHeight = max(0, visibleHeight - 3)
            let contentWidth = max(1, canvasWidth - timeGutter - 5)
            let laneWidth = contentWidth / CGFloat(max(1, position.lanes))
            if eventHeight > 2 {
                FocusBlockCalendarCard(
                    block: block,
                    tasks: work.tasks(in: block),
                    height: eventHeight,
                    hourHeight: hourHeight,
                    onOpen: { editingBlock = block },
                    onMove: { minutes in
                        work.moveBlock(block.id, to: block.start.addingTimeInterval(Double(minutes * 60)))
                    },
                    onResize: { minutes in work.resizeBlock(block.id, to: minutes) },
                    onDropTask: { id in
                        guard let task = work.item(id), !task.isFixed else { return false }
                        withAnimation(reduceMotion ? PlanMotion.quick : PlanMotion.settle) {
                            work.assign(id, to: block.id)
                        }
                        showConfirmation(blockID: block.id, message: "Added \(task.title) to \(block.title)")
                        return true
                    }
                )
                .frame(width: max(1, laneWidth - 3), height: eventHeight)
                .offset(x: timeGutter + CGFloat(position.lane) * laneWidth, y: startY)
                .zIndex(1)
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let minute = calendar.date(byAdding: .hour, value: hour, to: calendar.startOfDay(for: model.selectedDate)) ?? model.selectedDate
        return minute.formatted(date: .omitted, time: .shortened)
    }

    private func createAtQuarter(_ quarter: Int) {
        guard let start = calendar.date(byAdding: .minute, value: quarter * 15,
                                        to: calendar.startOfDay(for: model.selectedDate)) else { return }
        if let payload = pendingPlacement {
            if scheduleDragged([payload], at: quarter) { pendingPlacement = nil }
            return
        }
        if let id = work.createBlock(at: start) {
            PlanFeedback.committed()
            editingBlock = work.block(id)
        }
    }

    private func showConfirmation(blockID: UUID, message: String) {
        recentMessage = message
        let token = UUID()
        recentConfirmationToken = token
        withAnimation(reduceMotion ? PlanMotion.quick : PlanMotion.settle) {
            recentBlockID = blockID
        }
        PlanFeedback.committed()
        // A later confirmation must never be removed by an earlier dismissal.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard recentBlockID == blockID && recentConfirmationToken == token else { return }
            withAnimation(PlanMotion.quick) { recentBlockID = nil }
        }
    }

    @ViewBuilder
    private func scheduleConfirmation(for blockID: UUID) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
            Text(recentMessage)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Focus") {
                model.chooseBlock(blockID)
                recentBlockID = nil
                Task { await model.lockIn(blockID: blockID) }
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.borderedProminent)
            .tint(IgnitionStyle.blue)
            Button { withAnimation(PlanMotion.quick) { recentBlockID = nil } } label: {
                Image(systemName: "xmark")
            }
            .font(.caption2)
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss scheduling confirmation")
        }
        .padding(10)
        .foregroundStyle(IgnitionStyle.navy)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(Color.white.opacity(0.8)))
        .shadow(color: IgnitionStyle.navy.opacity(0.14), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
    }

    private func scheduleDragged(_ payload: [String], at quarter: Int) -> Bool {
        guard let raw = payload.first,
              let start = calendar.date(byAdding: .minute, value: quarter * 15,
                                        to: calendar.startOfDay(for: model.selectedDate)) else { return false }
        hoveredQuarter = nil
        if raw.hasPrefix("task:") {
            guard let id = UUID(uuidString: String(raw.dropFirst(5))),
                  work.item(id) != nil else { return false }
            guard let newBlockID = work.createBlock(at: start, taskID: id) else { return false }
            showConfirmation(blockID: newBlockID, message: "Scheduled \(work.item(id)?.title ?? "task") · \(start.formatted(date: .omitted, time: .shortened))")
            pendingPlacement = nil
            return true
        }
        if raw.hasPrefix("event:") {
            guard let id = UUID(uuidString: String(raw.dropFirst(6))),
                  let item = work.item(id), !item.isFixed else { return false }
            Task { await model.move(id, to: start) }
            pendingPlacement = nil
            PlanFeedback.committed()
            return true
        }
        return false
    }

    private func eventCard(_ item: WorkItem, start: Date, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ViewThatFits(in: .horizontal) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .fixedSize(horizontal: true, vertical: false)
                Text("Event")
                    .font(.system(size: 11, weight: .semibold))
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "calendar")
            }
            .lineLimit(1)
            if height >= 58 {
                Text(start.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(PlanPalette.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(item.tint.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(item.tint.color).frame(width: 3)
        }
        .overlay(alignment: .bottom) {
            if !item.isFixed && height >= 50 {
                CalendarDurationHandle(minutes: item.durationMinutes, hourHeight: hourHeight) { value in
                    Task { await model.resize(item.id, by: value - item.durationMinutes) }
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture {
            model.selectedTaskID = item.id
            editing = item
        }
        .planDragIfEditable(item, start: start)
        .dropDestination(for: String.self) { payload, location in
            let dayStart = calendar.startOfDay(for: model.selectedDate)
            let minuteOffset = max(0, Int(start.timeIntervalSince(dayStart) / 60))
            let quarter = min(95, (minuteOffset + Int(location.y / (hourHeight / 4)) * 15) / 15)
            return scheduleDragged(payload, at: quarter)
        }
        .contextMenu {
            if !item.isFixed {
                Button("Move 15 minutes earlier") { Task { await model.move(item.id, to: start.addingTimeInterval(-900)) } }
                Button("Move 15 minutes later") { Task { await model.move(item.id, to: start.addingTimeInterval(900)) } }
                Button("Shorten by 15 minutes") { Task { await model.resize(item.id, by: -15) } }
                Button("Lengthen by 15 minutes") { Task { await model.resize(item.id, by: 15) } }
            }
            Button("Select for Focus") { model.selectedTaskID = item.id }
        }
        .accessibilityLabel(item.title + ", " + start.formatted(date: .omitted, time: .shortened))
        .accessibilityHint(item.isFixed ? "Read-only calendar event" : "Tap to edit; drag the bottom handle to resize")
    }


    private func resizeHandle(available: CGFloat) -> some View {
        Capsule()
            .fill(PlanPalette.secondary.opacity(0.65))
            .frame(width: 38, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(PlanPalette.drawer)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 3)
                .updating($resizeTranslation) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    let projected = value.predictedEndTranslation.height * 0.25
                        + value.translation.height * 0.75
                    let proposed = (available * calendarFraction + projected) / available
                    let best = detents.min(by: { abs($0 - proposed) < abs($1 - proposed) }) ?? 0.56
                    guard abs(best - calendarFraction) > 0.01 else { return }
                    PlanFeedback.tick()
                    withAnimation(reduceMotion ? PlanMotion.quick : PlanMotion.settle) {
                        calendarFraction = best
                    }
                })
            .onTapGesture {
                PlanFeedback.tick()
                withAnimation(reduceMotion ? PlanMotion.quick : PlanMotion.settle) {
                    calendarFraction = calendarFraction > 0.62 ? 0.56 : 0.79
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Resize calendar and task list")
            .accessibilityHint("Drag to resize, or double tap to expand calendar")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: calendarFraction = min(0.79, calendarFraction + 0.23)
                case .decrement: calendarFraction = max(0.32, calendarFraction - 0.23)
                @unknown default: break
                }
            }
    }


    private var taskDrawer: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Tasks")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PlanPalette.white)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Menu {
                    Button("New task", systemImage: "plus.circle") { showNew = true }
                    Button("Speak to add", systemImage: "mic") { showVoice = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PlanPalette.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Add a task or use voice")
            }
            .padding(.leading, 19)
            .padding(.trailing, 10)
            .frame(height: 48)

            HStack(spacing: 6) {
                taskFilter("Inbox", selected: !showScheduledTasks) { showScheduledTasks = false }
                taskFilter("Today", selected: showScheduledTasks) { showScheduledTasks = true }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 10)

            ScrollView(.vertical) {
                LazyVStack(spacing: 7) {
                    if !showScheduledTasks && unscheduledTasks.isEmpty {
                        emptyTasks("Nothing in Inbox", detail: "Add a task or speak one.")
                    }
                    if showScheduledTasks && dayTasks.isEmpty {
                        emptyTasks("Nothing planned today", detail: "Move a task onto the calendar when ready.")
                    }
                    ForEach(showScheduledTasks ? dayTasks : unscheduledTasks) { item in
                        taskRow(item)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .background(PlanPalette.drawer)
        .animation(reduceMotion ? nil : PlanMotion.quick, value: showScheduledTasks)
    }

    private func taskFilter(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            PlanFeedback.tick()
            withAnimation(reduceMotion ? PlanMotion.quick : PlanMotion.settle) { action() }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 15)
                .frame(height: 32)
                .foregroundStyle(selected ? Color.white : PlanPalette.secondary)
                .background(selected ? IgnitionStyle.blue : PlanPalette.row,
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func taskRow(_ item: WorkItem) -> some View {
        HStack(spacing: 11) {
            Button {
                withAnimation(reduceMotion ? PlanMotion.quick : PlanMotion.settle) {
                    model.setComplete(item.id, true)
                }
                PlanFeedback.committed()
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(item.tint.color)
                    .frame(width: 38, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(item.title)")

            Button { model.selectedTaskID = item.id; editing = item } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PlanPalette.white)
                        .lineLimit(2)
                    Text(taskStatus(item))
                        .font(.system(size: 12))
                        .foregroundStyle(PlanPalette.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Edit task", systemImage: "pencil") {
                    model.selectedTaskID = item.id
                    editing = item
                }
                if !item.isFixed {
                    Button("Schedule in new focus block", systemImage: "calendar.badge.plus") {
                        scheduling = item
                    }
                    Button("Add to existing block", systemImage: "rectangle.stack.badge.plus") {
                        assigningTask = item
                    }
                    Button("Delete task", systemImage: "trash", role: .destructive) {
                        taskToDelete = item.id
                        showDeleteConfirmation = true
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PlanPalette.secondary)
                    .frame(width: 42, height: 44)
            }
            .accessibilityLabel("More actions for \(item.title)")
        }
        .padding(.leading, 7)
        .padding(.trailing, 6)
        .padding(.vertical, 7)
        .background(PlanPalette.row, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 15))
        .draggable("task:\(item.id.uuidString)") {
            PlanTaskDragPreview(title: item.title, tint: item.tint.color)
        }
        .accessibilityHint("Double tap to edit, or long press and drag to a calendar time")
    }

    private func taskStatus(_ item: WorkItem) -> String {
        if let date = item.scheduledStart {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return showScheduledTasks ? "In today's focus blocks" : "Not scheduled"
    }


    private func emptyTasks(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .foregroundStyle(PlanPalette.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
    }

    // MARK: - Month overview + two-step drop handoff

    private var pendingTitle: String {
        guard let raw = pendingPlacement,
              let id = UUID(uuidString: String(raw.dropFirst(raw.hasPrefix("task:") ? 5 : 6))) else {
            return "Selected item"
        }
        return work.item(id)?.title ?? "Selected item"
    }

    private var pendingPlacementBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 16))
                .foregroundStyle(IgnitionStyle.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text("Place \(pendingTitle)")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text("Tap a time below, or choose an exact time")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 2)
            Button("Time") { showPlacementTimePicker = true }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(IgnitionStyle.blue)
            Button { pendingPlacement = nil } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(PlanPalette.ink.opacity(0.55))
            }
            .accessibilityLabel("Cancel placing task")
        }
        .padding(10)
        .background(IgnitionStyle.blue.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                 .strokeBorder(IgnitionStyle.blue.opacity(0.18)))
        .accessibilityIdentifier("plan.pending-month-drop")
    }

    private var monthCalendarSurface: some View {
        GeometryReader { geometry in
            let dates = monthDates
            let weeks = max(1, dates.count / 7)
            let cellHeight = min(66, max(43, (geometry.size.height - 80) / CGFloat(weeks)))
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(weekdayNames, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PlanPalette.ink.opacity(0.52))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 29)
                .padding(.horizontal, 11)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                          spacing: 3) {
                    ForEach(dates, id: \.self) { date in
                        monthCell(date, height: cellHeight)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 2)
                Spacer(minLength: 3)
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw")
                    Text("Drop a task onto a date · then place it at a time")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PlanPalette.ink.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 9)
            }
            .background(PlanPalette.calendar)
        }
        .background(PlanPalette.calendar)
        .accessibilityIdentifier("plan.month")
        .task(id: displayedMonth) {
            // Monthly EventKit import is read-only, permission-aware, and
            // never changes the selected day or creates an appointment.
            await model.importCalendarMonth(containing: displayedMonth)
        }
    }

    private func monthCell(_ date: Date, height: CGFloat) -> some View {
        let isInMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let selected = calendar.isDate(date, inSameDayAs: model.selectedDate)
        let today = calendar.isDateInToday(date)
        let dots: [Color] = work.blocksForDay(date).map { _ in IgnitionStyle.blue }
            + work.forDay(date).map(\.tint.color)
        return Button {
            PlanFeedback.tick()
            choose(date)
            setCalendarMode(.day)
        } label: {
            VStack(spacing: 5) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 14, weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? Color.white : (isInMonth ? PlanPalette.ink : PlanPalette.ink.opacity(0.3)))
                    .frame(width: 29, height: 29)
                    .background(selected ? IgnitionStyle.blue : Color.clear,
                                in: Circle())
                    .overlay(Circle().strokeBorder(today && !selected ? IgnitionStyle.blue : Color.clear, lineWidth: 1.5))
                HStack(spacing: 3) {
                    ForEach(0..<min(3, dots.count), id: \.self) { index in
                        Circle()
                            .fill(dots[index])
                            .frame(width: 5, height: 5)
                    }
                    if dots.count > 3 {
                        Text("+")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(PlanPalette.ink.opacity(0.55))
                    }
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(today && !selected ? IgnitionStyle.blue.opacity(0.05) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { strings, _ in
            stageMonthDrop(strings, on: date)
        } isTargeted: { targeting in
            if targeting { PlanFeedback.tick() }
        }
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted) +
                            ", \(dots.count) planned items")
        .accessibilityHint("Opens day timeline. Long press and drop a task here to choose its time.")
    }

    private var weekdayNames: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[($0 + calendar.firstWeekday - 1) % 7] }
    }

    private var monthDates: [Date] {
        let firstDay = calendar.dateInterval(of: .month, for: displayedMonth)?.start
            ?? calendar.startOfDay(for: displayedMonth)
        let start = calendar.dateInterval(of: .weekOfYear, for: firstDay)?.start ?? firstDay
        let range = calendar.range(of: .day, in: .month, for: firstDay)
        let dayOffset = calendar.dateComponents([.day], from: start, to: firstDay).day ?? 0
        let count = max(35, ((dayOffset + (range?.count ?? 30) + 6) / 7) * 7)
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func stageMonthDrop(_ payload: [String], on date: Date) -> Bool {
        guard let raw = payload.first,
              let id = UUID(uuidString: String(raw.dropFirst(raw.hasPrefix("task:") ? 5 : 6))),
              let item = work.item(id),
              !item.isFixed,
              raw.hasPrefix("task:") || raw.hasPrefix("event:") else { return false }
        pendingPlacement = raw
        placementClock = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        choose(date)
        setCalendarMode(.day)
        PlanFeedback.lift()
        return true
    }

    private func placePending(at time: Date) {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        guard let date = calendar.date(bySettingHour: components.hour ?? 9,
                                        minute: components.minute ?? 0, second: 0,
                                        of: model.selectedDate),
              let raw = pendingPlacement else { return }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let quarter = min(95, max(0, (minute + 7) / 15))
        _ = scheduleDragged([raw], at: quarter)
    }

    private func setCalendarMode(_ mode: PlanCalendarMode) {
        guard calendarMode != mode else { return }
        PlanFeedback.tick()
        withAnimation(reduceMotion ? nil : PlanMotion.settle) {
            if mode == .month {
                dayCalendarFraction = calendarFraction
                calendarFraction = 0.69
                displayedMonth = calendar.dateInterval(of: .month, for: model.selectedDate)?.start ?? model.selectedDate
            } else {
                calendarFraction = dayCalendarFraction
            }
            calendarMode = mode
        }
    }

    private func choose(_ day: Date) { model.selectedDate = day }
    private func shiftVisibleDate(_ amount: Int) {
        if calendarMode == .month {
            if let next = calendar.date(byAdding: .month, value: amount, to: displayedMonth) {
                displayedMonth = next
            }
        } else if let next = calendar.date(byAdding: .day, value: amount, to: model.selectedDate) {
            choose(next)
        }
    }
}

/// Put timed tasks and focus blocks in the SAME lane calculation; otherwise
/// overlapping blocks hide appointments behind them.
private enum PlanOverlapLayout {
    struct Entry { let id: UUID; let start: Date; let end: Date }
    struct Position { let lane: Int; let lanes: Int }
    static func calculate(for items: [Entry]) -> [UUID: Position] {
        let sorted = items.sorted { $0.start < $1.start }
        var result: [UUID: Position] = [:]
        var group: [Entry] = []
        var groupEnd = Date.distantPast
        func finish(_ entries: [Entry]) {
            var laneEnds: [Date] = []
            var positions: [UUID: Int] = [:]
            for entry in entries {
                if let lane = laneEnds.firstIndex(where: { $0 <= entry.start }) {
                    laneEnds[lane] = entry.end
                    positions[entry.id] = lane
                } else {
                    positions[entry.id] = laneEnds.count
                    laneEnds.append(entry.end)
                }
            }
            for (id, lane) in positions {
                result[id] = Position(lane: lane, lanes: max(1, laneEnds.count))
            }
        }
        for entry in sorted {
            if !group.isEmpty && entry.start >= groupEnd {
                finish(group); group = []; groupEnd = .distantPast
            }
            group.append(entry)
            groupEnd = max(groupEnd, entry.end)
        }
        finish(group)
        return result
    }
}

/// The accessible alternative to drag-and-drop: exact date and time are editable
/// before scheduling, and the existing WorkItem ID is preserved.
private struct PlanScheduleSheet: View {
    let item: WorkItem
    let selectedDay: Date
    let onSchedule: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var proposed: Date

    init(item: WorkItem, selectedDay: Date, onSchedule: @escaping (Date) -> Void) {
        self.item = item
        self.selectedDay = selectedDay
        self.onSchedule = onSchedule
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDay)
        _proposed = State(initialValue: item.scheduledStart ?? cal.date(byAdding: .hour, value: 9, to: start) ?? selectedDay)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(item.title).font(.headline)
                    DatePicker("Start", selection: $proposed, displayedComponents: [.date, .hourAndMinute])
                }
                Section {
                    Button("Create focus block with this task") {
                        onSchedule(proposed)
                        dismiss()
                    }
                    .font(.headline)
                }
            }
            .navigationTitle("Choose a time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    var existing: WorkItem?
    var googleCalendars: [GoogleCalendarService.CalendarInfo] = []
    var isNewEvent: Bool = false
    var onSave: (WorkItem) -> Void
    var onDelete: ((UUID) -> Void)?
    @State private var item: WorkItem
    @State private var scheduled: Bool
    @State private var destination: String
    init(existing:WorkItem?=nil,
         googleCalendars: [GoogleCalendarService.CalendarInfo] = [],
         isNewEvent: Bool = false,
         onSave:@escaping(WorkItem)->Void,onDelete:((UUID)->Void)?=nil) {
        self.existing=existing
        self.googleCalendars=googleCalendars
        self.isNewEvent=isNewEvent
        self.onSave=onSave
        self.onDelete=onDelete
        _item=State(initialValue:existing ?? WorkItem(title:""))
        _scheduled=State(initialValue:existing?.scheduledStart != nil)
        let initial = existing?.externalProvider == "google" ? "google:" + (existing?.externalCalendarID ?? "") :
            ((existing?.externalProvider == "eventkit" || existing?.syncToAppleCalendar == true) ? "apple" : "local")
        _destination=State(initialValue: initial)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    if item.isFixed {
                        Label("Read-only external calendar event", systemImage: "lock")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    TextField("What needs doing?",text:$item.title).disabled(item.isFixed)
                    TextField("First or next step (optional)",text:$item.nextStep,axis:.vertical).disabled(item.isFixed)
                    TextField("Notes",text:$item.notes,axis:.vertical).disabled(item.isFixed)
                    TextField("Related URL",text:$item.urlText).disabled(item.isFixed)
                }
                Section("Time") {
                    Toggle("Schedule on calendar",isOn:$scheduled).disabled(item.isFixed)
                    if scheduled {
                        if existing?.externalProvider != nil {
                            LabeledContent("Calendar", value: destination == "apple" ? "Apple / iOS Calendar" : "Connected Google")
                        } else {
                            Picker("Save event to", selection: $destination) {
                                Text("Ignition only").tag("local")
                                Text("Apple / iOS Calendar").tag("apple")
                                ForEach(googleCalendars.filter { $0.accessRole == "owner" || $0.accessRole == "writer" }) { calendar in
                                    Text("Google · " + (calendar.summary ?? calendar.id)).tag("google:" + calendar.id)
                                }
                            }
                        }
                        DatePicker("Start",selection:Binding(get:{item.scheduledStart ?? Date()},set:{item.scheduledStart=$0}),displayedComponents:[.date,.hourAndMinute]).disabled(item.isFixed)
                    }
                    Stepper("Duration · \(item.durationMinutes) min",value:$item.durationMinutes,in:5...360,step:5).disabled(item.isFixed)
                }
                if existing != nil, let onDelete {
                    Section {
                        Button(item.externalProvider != nil ? "Delete from calendar" : "Remove from Ignition", role: .destructive) {
                            onDelete(item.id)
                            dismiss()
                        }
                        .disabled(item.isFixed)
                    }
                }
                Section("Appearance") {
                    Picker("Color",selection:$item.tint) {
                        ForEach(ItemTint.allCases) { tint in Text(tint.rawValue.capitalized).tag(tint) }
                    }
                }
            }
            .navigationTitle(isNewEvent ? "New event" : (existing == nil ? "New task" : "Edit task"))
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement:.confirmationAction) {
                    Button("Save") {
                        item.title = item.title.trimmingCharacters(in:.whitespacesAndNewlines)
                        if !scheduled { item.scheduledStart = nil }
                        else if item.scheduledStart == nil { item.scheduledStart = Date() }
                        if existing?.externalProvider == nil {
                            if destination.hasPrefix("google:") && scheduled {
                                item.externalProvider = "google"
                                item.externalCalendarID = String(destination.dropFirst(7))
                                item.syncToAppleCalendar = false
                            } else {
                                item.externalProvider = nil
                                item.externalCalendarID = nil
                                item.syncToAppleCalendar = destination == "apple" && scheduled
                            }
                        }
                        onSave(item); dismiss()
                    }.disabled(item.isFixed || item.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct VoiceEntryView: View {
    @ObservedObject var model: AppModel
    @StateObject private var voice = VoiceCapture()
    @State private var draft: VoiceDraft?
    @State private var editedTitle = ""
    @State private var editedDate = Date()
    @State private var hasDate = false
    @State private var editedDuration = 30
    @State private var kind: VoiceDraft.Kind = .task
    @State private var calendarDestination = "apple"
    @State private var hasConfirmed = false
    @Environment(\.dismiss) private var dismiss

    private func makeDraft(from text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let candidate = VoiceDraftParser.parse(text)
        draft = candidate
        editedTitle = candidate.title
        editedDate = candidate.start ?? Date()
        hasDate = candidate.start != nil
        editedDuration = candidate.durationMinutes
        kind = candidate.kind
    }
    private func finishSpeech() {
        Task {
            let text = await voice.finish()
            makeDraft(from: text)
        }
    }
    private func commit() {
        guard !hasConfirmed, !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        hasConfirmed = true
        switch kind {
        case .task, .event:
            var item = WorkItem(title: editedTitle.trimmingCharacters(in: .whitespacesAndNewlines))
            item.scheduledStart = hasDate ? editedDate : nil
            item.durationMinutes = editedDuration
            // Explicit event choice means the user requests publication in
            // the device's selected Apple Calendar, including Google accounts
            // registered in iOS Calendar. Save locally first; sync may fail.
            if kind == .event && hasDate {
                if calendarDestination.hasPrefix("google:") {
                    item.externalProvider = "google"
                    item.externalCalendarID = String(calendarDestination.dropFirst(7))
                    item.syncToAppleCalendar = false
                } else {
                    item.syncToAppleCalendar = calendarDestination == "apple"
                }
            }
            model.save(item)
        case .block:
            let start = hasDate ? editedDate : Date()
            let id = model.work.createBlock(at: start)
            if let id, var block = model.work.block(id) {
                block.title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                block.durationMinutes = editedDuration
                model.work.upsertBlock(block)
            }
        }
        voice.discardAudio()
        dismiss()
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text(draft == nil ? "Speak or type an item" : "Review before adding")
                        .font(.title3.bold())
                    Text("Example: Study cardiology tomorrow at 7 PM for one hour")
                        .font(.caption).foregroundStyle(.secondary)
                    if draft == nil {
                        TextEditor(text: $voice.transcript)
                            .frame(minHeight: 105)
                            .padding(6)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                        if let error = voice.errorText { Text(error).font(.caption).foregroundStyle(.red) }
                        Button {
                            if voice.recording { finishSpeech() }
                            else { Task { await voice.begin() } }
                        } label: {
                            Label(voice.finalizing ? "Converting…" : (voice.recording ? "Done speaking" : "Start speaking"),
                                  systemImage: voice.recording ? "checkmark.circle.fill" : "mic.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(voice.finalizing)
                        Button("Convert text to draft") { makeDraft(from: voice.transcript) }
                            .disabled(voice.recording || voice.finalizing || voice.transcript.trimmingCharacters(in: .whitespaces).isEmpty)
                        Text("Tapping Done speaking keeps every recognized word and creates an editable draft. Nothing is saved until Confirm.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Picker("Add as", selection: $kind) {
                            ForEach(VoiceDraft.Kind.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        TextField("Title", text: $editedTitle)
                            .textFieldStyle(.roundedBorder)
                        Toggle("Set date and time", isOn: $hasDate)
                        if kind == .event && hasDate {
                            Picker("Calendar", selection: $calendarDestination) {
                                Text("Apple / iOS Calendar").tag("apple")
                                ForEach(model.google.calendars.filter { $0.accessRole == "owner" || $0.accessRole == "writer" }) { calendar in
                                    Text("Google · " + (calendar.summary ?? calendar.id)).tag("google:" + calendar.id)
                                }
                            }
                        }
                        if hasDate {
                            DatePicker("When", selection: $editedDate, displayedComponents: [.date, .hourAndMinute])
                        }
                        Stepper("Duration: \(editedDuration) min", value: $editedDuration, in: 5...480, step: 5)
                        if draft?.needsTimeConfirmation == true {
                            Label("Check AM or PM before confirming.", systemImage: "exclamationmark.circle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        Text("Heard: \(draft?.sourceText ?? "")")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Confirm and add") { commit() }
                            .buttonStyle(.borderedProminent)
                            .disabled(editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                      (kind == .event && !hasDate))
                        Button("Edit transcript") { draft = nil }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(19)
            }
            .background(Color(red: 0.94, green: 0.96, blue: 0.98))
            .navigationTitle("Voice capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { voice.discardAudio(); dismiss() }
                }
            }
        }
        .onAppear { voice.player = model.audio }
        .onDisappear { voice.discardAudio() }
    }
}

/// One focus reservation drawn inside the calendar. Unlike a legacy task card,
/// it holds references to many WorkItem IDs and does not own task completion.
private struct FocusBlockCalendarCard: View {
    let block: FocusBlock
    let tasks: [WorkItem]
    let height: CGFloat
    let hourHeight: CGFloat
    let onOpen: () -> Void
    let onMove: (Int) -> Void
    let onResize: (Int) -> Void
    let onDropTask: (UUID) -> Bool

    @State private var moveDelta: CGFloat = 0
    @State private var resizeDelta: CGFloat = 0
    @State private var isDropTarget = false
    @State private var moving = false
    @State private var resizing = false
    @State private var lastMoveStep = 0
    @State private var lastResizeStep = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func quarterMinutes(_ pixels: CGFloat) -> Int {
        Int((pixels / hourHeight * 4).rounded()) * 15
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    Text(block.title)
                        .font(.system(size: 12, weight: .semibold))
                        .fixedSize(horizontal: true, vertical: false)
                    Text("Focus · \(block.durationMinutes)m")
                        .font(.system(size: 11, weight: .semibold))
                        .fixedSize(horizontal: true, vertical: false)
                    Text("\(block.durationMinutes)m")
                        .font(.system(size: 11, weight: .semibold))
                        .fixedSize(horizontal: true, vertical: false)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .frame(height: min(31, max(18, height - 14)))
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .highPriorityGesture(DragGesture(minimumDistance: 8)
                .onChanged { value in
                    if !moving { moving = true; PlanFeedback.lift() }
                    let nextStep = quarterMinutes(value.translation.height)
                    if nextStep != lastMoveStep {
                        lastMoveStep = nextStep
                        PlanFeedback.tick()
                    }
                    moveDelta = value.translation.height
                }
                .onEnded { value in
                    let minutes = quarterMinutes(value.translation.height)
                    moving = false
                    lastMoveStep = 0
                    withAnimation(reduceMotion ? PlanMotion.quick : PlanMotion.settle) {
                        moveDelta = 0
                        if minutes != 0 { onMove(minutes) }
                    }
                    if minutes != 0 { PlanFeedback.committed() }
                }
            )
            .accessibilityLabel("Move \(block.title) to a different time")
            .accessibilityHint("Drag up or down in 15 minute increments")

            if height >= 74 {
                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(tasks.filter { $0.isComplete }.count)/\(tasks.count) tasks · \(block.durationMinutes)m")
                            .font(.system(size: 10)).lineLimit(1)
                        ForEach(Array(tasks.prefix(height > 130 ? 2 : 0))) { item in
                            HStack(spacing: 3) {
                                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                                Text(item.title).lineLimit(1)
                            }
                            .font(.system(size: 10))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 9)
            }

            Spacer(minLength: 0)
            // Very short blocks show title only. Duration remains editable
            // through the block sheet/context menu without obscuring the card.
            if height >= 54 {
            Capsule()
                .fill(Color(red: 0.25, green: 0.43, blue: 0.81).opacity(0.65))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .frame(height: 18)
                .contentShape(Rectangle())
                .highPriorityGesture(DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if !resizing { resizing = true; PlanFeedback.lift() }
                        let nextStep = quarterMinutes(value.translation.height)
                        if nextStep != lastResizeStep {
                            lastResizeStep = nextStep
                            PlanFeedback.tick()
                        }
                        resizeDelta = value.translation.height
                    }
                    .onEnded { value in
                        let proposed = FocusBlockPlan.validDuration(block.durationMinutes + quarterMinutes(value.translation.height))
                        resizing = false
                        lastResizeStep = 0
                        withAnimation(reduceMotion ? PlanMotion.quick : PlanMotion.settle) {
                            resizeDelta = 0
                            if proposed != block.durationMinutes { onResize(proposed) }
                        }
                        if proposed != block.durationMinutes { PlanFeedback.committed() }
                    }
                )
                .accessibilityLabel("Resize \(block.title)")
                .accessibilityHint("Drag to lengthen or shorten in 15 minute increments")
            }
        }
        .foregroundStyle(Color(red: 0.11, green: 0.22, blue: 0.43))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: max(23, height + resizeDelta), alignment: .top)
        .background(isDropTarget ? Color(red: 0.69, green: 0.83, blue: 1) : PlanPalette.block, in: RoundedRectangle(cornerRadius: 9))
        .overlay(alignment: .topTrailing) {
            if moving || resizing {
                Text(moving
                     ? block.start.addingTimeInterval(Double(lastMoveStep * 60)).formatted(date: .omitted, time: .shortened)
                     : "\(FocusBlockPlan.validDuration(block.durationMinutes + lastResizeStep)) min")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(IgnitionStyle.navy, in: Capsule())
                    .offset(y: -26)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.24, green: 0.43, blue: 0.88)).frame(width: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(isDropTarget ? Color.blue : Color.clear, lineWidth: 2)
        }
        .offset(y: moveDelta)
        .scaleEffect(moving ? 1.025 : 1)
        .shadow(color: IgnitionStyle.navy.opacity(moving ? 0.22 : 0.06), radius: moving ? 12 : 3, y: moving ? 7 : 2)
        .zIndex(moving || resizing ? 6 : 1)
        .dropDestination(for: String.self) { payload, _ in
            guard let first = payload.first, first.hasPrefix("task:"),
                  let id = UUID(uuidString: String(first.dropFirst(5))) else { return false }
            return onDropTask(id)
        } isTargeted: { targeted in
            guard isDropTarget != targeted else { return }
            withAnimation(reduceMotion ? nil : PlanMotion.quick) { isDropTarget = targeted }
            if targeted { PlanFeedback.tick() }
        }
        .contextMenu {
            Button("Edit block and tasks", action: onOpen)
            Button("Move 15 minutes later") { onMove(15) }
            Button("Move 15 minutes earlier") { onMove(-15) }
            Button("Lengthen 15 minutes") { onResize(block.durationMinutes + 15) }
            Button("Shorten 15 minutes") { onResize(block.durationMinutes - 15) }
        }
    }
}

/// A block editor keeps task identity and completion state in WorkRepository.
/// Adding/removing membership never deletes or duplicates the task itself.
private struct FocusBlockEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var work: WorkRepository
    @State private var block: FocusBlock
    @State private var newTaskTitle = ""
    @State private var pendingTaskNames: [String] = []
    let onSave: (FocusBlock) -> Void
    let onDelete: (UUID) -> Void
    let onStart: (UUID) -> Void

    init(initial: FocusBlock, work: WorkRepository,
         onSave: @escaping (FocusBlock) -> Void,
         onDelete: @escaping (UUID) -> Void,
         onStart: @escaping (UUID) -> Void) {
        self.work = work
        _block = State(initialValue: initial)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onStart = onStart
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Focus block") {
                    TextField("Block name", text: $block.title)
                    DatePicker("Start", selection: $block.start, displayedComponents: [.date, .hourAndMinute])
                    Stepper("Duration: \(block.durationMinutes) minutes", value: $block.durationMinutes, in: 15...360, step: 15)
                    Text("\(block.start.formatted(date: .omitted, time: .shortened)) – \(block.end.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
                }
                Section("Tasks assigned to this block") {
                    if block.taskIDs.isEmpty {
                        Text("No tasks yet. Add them below or drag tasks onto this block in Plan.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(block.taskIDs, id: \.self) { taskID in
                        if let task = work.item(taskID) {
                            HStack(spacing: 12) {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.secondary)
                                Text(task.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    work.setComplete(task.id, !task.isComplete)
                                } label: {
                                    Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.isComplete ? Color.green : Color.gray)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(task.isComplete ? "Mark incomplete" : "Complete task")
                                Menu {
                                    Button("Remove from this block") {
                                        block.taskIDs.removeAll { $0 == taskID }
                                    }
                                    ForEach(work.blocks.filter { $0.id != block.id }) { destination in
                                        Button("Move to \(destination.title)") {
                                            work.assign(taskID, to: destination.id)
                                            block.taskIDs.removeAll { $0 == taskID }
                                            onSave(block)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                                .accessibilityLabel("Task block options")
                            }
                        }
                    }
                    .onMove { indices, destination in
                        block.taskIDs.move(fromOffsets: indices, toOffset: destination)
                    }
                }
                Section("Add tasks") {
                    HStack {
                        TextField("New task title", text: $newTaskTitle)
                            .submitLabel(.done)
                            .onSubmit { addPendingTask() }
                        Button { addPendingTask() } label: { Image(systemName: "plus.circle.fill") }
                            .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityLabel("Add new task to this block")
                    }
                    ForEach(pendingTaskNames, id: \.self) { name in
                        Label(name, systemImage: "circle.dashed")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(work.items.filter { !$0.isFixed && !block.taskIDs.contains($0.id) }) { task in
                        Button {
                            block.taskIDs.append(task.id)
                        } label: {
                            Label(task.title, systemImage: "plus.circle")
                        }
                    }
                }
                Section {
                    Text("One task can be used in several blocks. Completion belongs to the task, not to the block. Use Edit to reorder tasks.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("LOCK IN · Start a timer inside this block") {
                        saveAndDismiss()
                        // Present focus after the editor has dismissed, so SwiftUI
                        // does not compete with the full-screen focus presentation.
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            onStart(block.id)
                        }
                    }
                    Button("Delete focus block", role: .destructive) {
                        onDelete(block.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Focus block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .disabled(block.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    private func addPendingTask() {
        let text = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        pendingTaskNames.append(text)
        newTaskTitle = ""
    }
    private func saveAndDismiss() {
        addPendingTask()
        for title in pendingTaskNames {
            let task = WorkItem(title: title)
            work.upsert(task)
            block.taskIDs.append(task.id)
        }
        pendingTaskNames = []
        block.start = FocusBlockPlan.snap(block.start)
        onSave(block)
        dismiss()
    }
}

private struct BlockPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let task: WorkItem
    let blocks: [FocusBlock]
    let onAssign: (UUID) -> Void
    var body: some View {
        NavigationStack {
            List {
                if blocks.isEmpty {
                    Text("Create a focus block first by tapping a time slot, then add tasks to it.")
                        .foregroundStyle(.secondary)
                }
                ForEach(blocks.sorted { $0.start < $1.start }) { block in
                    Button {
                        onAssign(block.id)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(block.title)
                            Text(block.start.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add to a focus block")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

/// This handle also works for legacy scheduled tasks and editable calendar items.
private struct CalendarDurationHandle: View {
    let minutes: Int
    let hourHeight: CGFloat
    let onCommit: (Int) -> Void
    @State private var translation: CGFloat = 0
    @State private var lastStep = 0
    var body: some View {
        Capsule()
            .fill(Color(red: 0.24, green: 0.43, blue: 0.88).opacity(0.7))
            .frame(width: 38, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 18)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        translation = value.translation.height
                        let step = Int((translation / hourHeight * 4).rounded()) * 15
                        if step != lastStep { lastStep = step; PlanFeedback.tick() }
                    }
                    .onEnded { value in
                        let delta = Int((value.translation.height / hourHeight * 4).rounded()) * 15
                        translation = 0
                        lastStep = 0
                        if delta != 0 {
                            onCommit(min(360, max(15, minutes + delta)))
                            PlanFeedback.committed()
                        }
                    }
            )
            .accessibilityLabel("Resize calendar event")
            .accessibilityHint("Drag to adjust duration in 15-minute steps")
    }
}

// Imported read-only events must never advertise a draggable move gesture.
// They can still be inspected, and writable events retain the native preview.
private extension View {
    @ViewBuilder
    func planDragIfEditable(_ item: WorkItem, start: Date) -> some View {
        if item.isFixed {
            self
        } else {
            self.draggable("event:\(item.id.uuidString)") {
                PlanEventDragPreview(title: item.title,
                                     time: start.formatted(date: .omitted, time: .shortened),
                                     tint: item.tint.color)
            }
        }
    }
}

// MARK: - Native drag previews
// System drag previews move with the user's finger. Unlike a fake overlay,
// they remain correct when dragging between independently scrolling surfaces.
private struct PlanTaskDragPreview: View {
    let title: String
    let tint: Color
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "circle.dotted.circle.fill")
                .foregroundStyle(tint)
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(2)
            Image(systemName: "arrow.down.to.line.compact")
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(IgnitionStyle.navy)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(minWidth: 160, maxWidth: 250, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.45)))
        .shadow(color: IgnitionStyle.navy.opacity(0.19), radius: 14, y: 8)
    }
}

private struct PlanEventDragPreview: View {
    let title: String
    let time: String
    let tint: Color
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: 4, height: 37)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(time).font(.caption).foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(IgnitionStyle.navy)
        .padding(12)
        .frame(width: 210, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: IgnitionStyle.navy.opacity(0.18), radius: 13, y: 7)
    }
}
