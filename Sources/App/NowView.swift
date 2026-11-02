import SwiftUI

// MARK: - Now: one action, one persistent sheet, two predictable positions.
// The CTA and selection never swap layouts during dragging. The whole hero
// remains a 220+pt drag target, while the scrollable list lives below it.
struct LegacyNowView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var work: WorkRepository

    @State private var stop: NowDrawerDetent = .compact
    @GestureState private var drag: CGFloat = 0
    @State private var showingEditor = false
    @State private var showingReturn = false
    @State private var showingPath = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(model: AppModel) {
        self.model = model
        _work = ObservedObject(wrappedValue: model.work)
    }

    var body: some View {
        GeometryReader { proxy in
            let compact: CGFloat = dynamicTypeSize.isAccessibilitySize ? 290 : 220
            let full = max(compact + 110, min(proxy.size.height * 0.90, proxy.size.height - 8))
            let rest = stop == .compact ? compact : full
            let visible = CGFloat(NowDrawerMath.visibleHeight(
                rest: Double(rest), drag: Double(drag),
                compact: Double(compact), full: Double(full)
            ))

            ZStack(alignment: .bottom) {
                Group {
                    if showingPath {
                        ShortPathView(
                            items: work.upcoming(), blocks: work.blocks,
                            choose: { model.chooseTask($0) },
                            chooseBlock: { model.chooseBlock($0) }
                        )
                    } else {
                        LivingLandscape(
                            tasks: work.items,
                            blocks: work.blocks,
                            sessions: model.sessionsHistory,
                            selected: model.selectedTaskID,
                            selectedBlockID: model.selectedBlockID,
                            choose: { model.chooseTask($0) },
                            chooseBlock: { model.chooseBlock($0) }
                        )
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .ignoresSafeArea(edges: .top)

                LinearGradient(colors: [.white.opacity(0.43), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 112)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                drawer(fullHeight: full, compactHeight: compact,
                       restingHeight: rest, visibleHeight: visible)
            }
            .overlay(alignment: .top) { compactHeader }
        }
        .background(IgnitionDesign.canvas)
        .sheet(isPresented: $showingEditor) {
            TaskEditor(googleCalendars: model.google.calendars, onSave: { model.save($0) })
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingReturn) {
            ReturnView(model: model).presentationDetents([.medium, .large])
        }
    }

    private var compactHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Ignition.")
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .tracking(-0.85)
                .foregroundStyle(IgnitionDesign.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Button {
                IgnitionFeedback.selection()
                withAnimation(reduceMotion ? nil : IgnitionMotion.quick) {
                    showingPath.toggle()
                }
            } label: {
                Image(systemName: showingPath ? "map.fill" : "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 39, height: 39)
                    .foregroundStyle(IgnitionDesign.action)
                    .background(.white.opacity(0.92), in: Circle())
            }
            .accessibilityLabel(showingPath ? "Show scenic day" : "Show next hours")
            Button { model.settingsOpen = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 39, height: 39)
                    .foregroundStyle(IgnitionDesign.action)
                    .background(.white.opacity(0.92), in: Circle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func drawer(fullHeight: CGFloat, compactHeight: CGFloat,
                        restingHeight: CGFloat, visibleHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Only one hero. The entire hero can be swiped; no 34pt-only grip trap.
            VStack(spacing: 0) {
                Button {
                    changeStop(stop == .compact ? .open : .compact)
                } label: {
                    Capsule()
                        .fill(Color(red: 0.72, green: 0.78, blue: 0.86))
                        .frame(width: 43, height: 5)
                        .frame(maxWidth: .infinity)
                        .frame(height: 29)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(stop == .compact ? "Expand tasks" : "Collapse tasks")

                NowLockButton(
                    minutes: model.defaultMinutes, active: model.session != nil,
                    busy: model.isStartingFocus, action: startFocus
                )

                focusSelection
                    .padding(.top, 9)
                optionsLine
                    .padding(.top, 8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .frame(height: compactHeight, alignment: .top)
            .contentShape(Rectangle())
            .simultaneousGesture(drawerPan(compact: compactHeight,
                                           full: fullHeight, rest: restingHeight))

            Rectangle().fill(NowPalette.line.opacity(0.55)).frame(height: 1)
                .padding(.horizontal, 20)
            NowTodayList(model: model, work: work,
                         showEditor: { showingEditor = true },
                         showReturn: { showingReturn = true },
                         chooseTask: { id in model.chooseTask(id); changeStop(.compact) },
                         chooseBlock: { id in model.chooseBlock(id); changeStop(.compact) })
                .frame(height: max(0, fullHeight - compactHeight - 1))
                .scrollDisabled(stop != .open)
                .accessibilityHidden(stop != .open)
        }
        .frame(maxWidth: .infinity)
        .frame(height: fullHeight, alignment: .top)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .fill(NowPalette.surface)
                .shadow(color: IgnitionDesign.ink.opacity(0.13), radius: 17, y: -3)
        }
        .offset(y: fullHeight - visibleHeight)
        .accessibilityIdentifier("ignition.now.drawer")
    }

    private func drawerPan(compact: CGFloat, full: CGFloat, rest: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 7)
            .updating($drag) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let next = NowDrawerMath.destination(
                    at: stop,
                    translation: Double(value.translation.height),
                    predictedTranslation: Double(value.predictedEndTranslation.height),
                    compact: Double(compact), full: Double(full)
                )
                changeStop(next)
            }
    }

    private func changeStop(_ newStop: NowDrawerDetent) {
        guard stop != newStop else { return }
        IgnitionFeedback.selection()
        withAnimation(reduceMotion ? nil : IgnitionMotion.sheet) { stop = newStop }
    }

    private func startFocus() {
        if model.session != nil { model.showFocus = true }
        else { Task { await model.lockIn(blockID: model.selectedBlockID) } }
    }

    private var chosenTitle: String {
        model.selectedBlock?.title ?? model.selectedTask?.title ?? "Quick focus"
    }

    private var shortProtection: String {
        switch model.protection.status {
        case .active: return "Protected"
        case .ready: return "Blocking ready"
        case .off: return "Timer only"
        case .unavailable: return "Blocking unavailable"
        }
    }

    private var focusSelection: some View {
        Menu {
            Button("Quick focus") { model.chooseTask(nil) }
            ForEach(work.blocks.sorted { $0.start < $1.start }) { block in
                Button(block.title) { model.chooseBlock(block.id) }
            }
            ForEach(work.items.filter { !$0.isComplete }) { task in
                Button(task.title) { model.chooseTask(task.id) }
            }
            Button("New task", systemImage: "plus") { showingEditor = true }
        } label: {
            HStack(spacing: 9) {
                Text("Focus on")
                    .foregroundStyle(IgnitionDesign.muted)
                    .font(.system(size: 13, weight: .medium))
                Text(chosenTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(IgnitionDesign.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IgnitionDesign.muted)
            }
            .frame(minHeight: 41)
            .padding(.horizontal, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(NowPalette.line.opacity(0.6), lineWidth: 0.7))
        }
        .accessibilityLabel("Focus on: \(chosenTitle). Choose a task")
    }

    private var optionsLine: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach([2, 10, 15, 25, 45, 60], id: \.self) { minutes in
                    Button("\(minutes) minutes") { model.defaultMinutes = minutes }
                }
            } label: {
                Text("\(model.defaultMinutes) min")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IgnitionDesign.action)
                    .padding(.horizontal, 11)
                    .frame(height: 29)
                    .background(NowPalette.chip, in: Capsule())
            }
            .accessibilityLabel("Focus duration")

            HStack(spacing: 5) {
                Circle()
                    .fill(model.protection.status == .active ? NowPalette.success : IgnitionDesign.muted)
                    .frame(width: 6, height: 6)
                Text(shortProtection)
                    .lineLimit(1)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(IgnitionDesign.muted)

            Spacer(minLength: 2)
            Button { model.showStartSmall = true } label: {
                Text("2-min start")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IgnitionDesign.action)
                    .frame(minHeight: 30)
            }
            .accessibilityLabel("Start small with two minutes")
        }
        .buttonStyle(.plain)
    }
}

private enum NowPalette {
    static let surface = Color(red: 0.975, green: 0.981, blue: 0.988)
    static let chip = Color(red: 0.914, green: 0.943, blue: 0.984)
    static let selected = Color(red: 0.90, green: 0.937, blue: 0.996)
    static let success = Color(red: 0.24, green: 0.65, blue: 0.48)
    static let violet = Color(red: 0.53, green: 0.40, blue: 0.79)
    static let teal = Color(red: 0.20, green: 0.58, blue: 0.57)
    static let line = Color(red: 0.85, green: 0.88, blue: 0.92)
}

private struct NowLockButton: View {
    let minutes: Int
    let active: Bool
    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard !busy else { return }
            IgnitionFeedback.action()
            action()
        } label: {
            HStack(spacing: 8) {
                if busy { ProgressView().tint(.white) }
                else { Image(systemName: active ? "arrow.uturn.forward" : "play.fill")
                        .font(.system(size: 13, weight: .semibold)) }
                Text(busy ? "STARTING…" : active ? "RETURN TO FOCUS" : "LOCK IN")
                    .tracking(0.2)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(IgnitionDesign.action, in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(IgnitionPressStyle())
        .disabled(busy)
        .accessibilityIdentifier("ignition.lockIn")
        .accessibilityHint("Starts a \(minutes) minute focus session")
    }
}

private struct TodayEntry: Identifiable {
    enum Content { case task(WorkItem), block(FocusBlock) }
    let id: UUID
    let start: Date
    let content: Content
}

private struct NowTodayList: View {
    @ObservedObject var model: AppModel
    @ObservedObject var work: WorkRepository
    let showEditor: () -> Void
    let showReturn: () -> Void
    let chooseTask: (UUID) -> Void
    let chooseBlock: (UUID) -> Void

    private var entries: [TodayEntry] {
        let blocks = work.blocksForDay(Date())
        let assigned = Set(blocks.flatMap(\.taskIDs))
        let blockEntries = blocks.map { TodayEntry(id: $0.id, start: $0.start, content: .block($0)) }
        let tasks = work.forDay(Date()).filter { !assigned.contains($0.id) }
        let taskEntries: [TodayEntry] = tasks.compactMap { item in
            guard let date = item.scheduledStart else { return nil }
            return TodayEntry(id: item.id, start: date, content: .task(item))
        }
        return (blockEntries + taskEntries).sorted { $0.start < $1.start }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Today")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .tracking(-0.5)
                        .foregroundStyle(IgnitionDesign.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    Button(action: showEditor) {
                        Label("New", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(IgnitionDesign.action)
                            .frame(minHeight: 44)
                    }
                }
                .padding(.bottom, 1)

                if let last = model.lastEnded, model.session == nil {
                    Button(action: showReturn) {
                        HStack(spacing: 9) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .foregroundStyle(IgnitionDesign.action)
                            Text("Pick up \(last.title)")
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(IgnitionDesign.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(NowPalette.chip, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(entries) { entry in
                    switch entry.content {
                    case .task(let item):
                        NowTaskCard(item: item, selected: model.selectedTaskID == item.id,
                                    onSelect: { chooseTask(item.id) })
                    case .block(let block):
                        Button { chooseBlock(block.id) } label: {
                            NowWorkRow(icon: "square.stack.3d.up",
                                       tint: IgnitionDesign.action,
                                       title: block.title,
                                       subtitle: "\(block.start.formatted(date: .omitted, time: .shortened)) · \(block.durationMinutes) min",
                                       selected: model.selectedBlockID == block.id)
                        }
                        .buttonStyle(.plain)
                    }
                }

                let assignedToday = Set(work.blocksForDay(Date()).flatMap(\.taskIDs))
                let unscheduled = work.items.filter { $0.scheduledStart == nil && !$0.isComplete && !assignedToday.contains($0.id) }
                ForEach(unscheduled) { item in
                    NowTaskCard(item: item, selected: model.selectedTaskID == item.id,
                                onSelect: { chooseTask(item.id) })
                }
                if entries.isEmpty && unscheduled.isEmpty {
                    Text("Your day is clear. Start a quick focus or add a task.")
                        .font(.system(size: 14))
                        .foregroundStyle(IgnitionDesign.muted)
                        .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 9)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(NowPalette.surface)
    }
}

private struct NowTaskCard: View {
    let item: WorkItem
    let selected: Bool
    let onSelect: () -> Void
    var body: some View {
        Button(action: onSelect) {
            NowWorkRow(icon: item.isFixed ? "calendar" : "checkmark",
                       tint: item.isFixed ? NowPalette.violet : NowPalette.teal,
                       title: item.title,
                       subtitle: item.scheduledStart?.formatted(date: .omitted, time: .shortened) ?? "Anytime",
                       selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), \(item.isFixed ? "calendar event" : "task")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct NowWorkRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(IgnitionDesign.ink)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(IgnitionDesign.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(IgnitionDesign.action)
            }
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 65)
        .background(selected ? NowPalette.selected : .white,
                    in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15)
            .strokeBorder(selected ? IgnitionDesign.action.opacity(0.55)
                          : NowPalette.line.opacity(0.58), lineWidth: 0.8))
        .contentShape(RoundedRectangle(cornerRadius: 15))
    }
}

struct ShortPathView: View {
    let items: [WorkItem]
    let blocks: [FocusBlock]
    let choose: (UUID) -> Void
    let chooseBlock: (UUID) -> Void

    private struct PathEntry: Identifiable {
        var id: String
        var title: String
        var time: Date
        var tint: Color
        var blockID: UUID?
        var taskID: UUID?
    }

    private var entries: [PathEntry] {
        let from = Date().addingTimeInterval(-1800)
        let to = Date().addingTimeInterval(6 * 3600)
        let tasks = items.compactMap { task -> PathEntry? in
            guard let date = task.scheduledStart, date >= from, date < to else { return nil }
            return PathEntry(id: "task-\(task.id)", title: task.title, time: date,
                             tint: task.tint.color, blockID: nil, taskID: task.id)
        }
        let reservations = blocks.compactMap { block -> PathEntry? in
            guard block.start >= from, block.start < to else { return nil }
            return PathEntry(id: "block-\(block.id)", title: "\(block.title) · \(block.taskIDs.count) tasks",
                             time: block.start, tint: IgnitionStyle.blue,
                             blockID: block.id, taskID: nil)
        }
        return (tasks + reservations).sorted { $0.time < $1.time }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.89, green: 0.95, blue: 0.97),
                                    Color(red: 0.78, green: 0.91, blue: 0.85)],
                           startPoint: .top, endPoint: .bottom)
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Next few hours").font(.title2.bold()).padding(.top, 164)
                    Label("Now", systemImage: "location.circle.fill")
                        .foregroundStyle(IgnitionStyle.blue)
                    ForEach(entries.prefix(8)) { entry in
                        Button {
                            if let id = entry.blockID { chooseBlock(id) }
                            else if let id = entry.taskID { choose(id) }
                        } label: {
                            HStack {
                                RoundedRectangle(cornerRadius: 6).fill(entry.tint)
                                    .frame(width: 5, height: 45)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title).font(.subheadline.bold())
                                    Text(entry.time, format: .dateTime.hour().minute())
                                        .font(.caption)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(IgnitionStyle.navy)
                            .padding(10)
                            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    if entries.isEmpty {
                        Text("Your next few hours are clear. You can still focus.")
                            .font(.caption)
                    }
                }
                .padding(20)
            }
        }
    }
}


// MARK: - Circular Home · 2026-11-02
// The existing landscape implementation is retained above as LegacyNowView
// for rollback, while MainTabs continues to instantiate NowView.
// Single local-time transform for all clock events and the Now marker.
struct NowView: View {
    @State private var clockNow = Date()
    @ObservedObject var model: AppModel
    @ObservedObject private var work: WorkRepository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var chosenDuration: Int? = nil
    @State private var expandedClock = false
    @State private var expandedTasks = false
    @State private var showingEditor = false

    init(model: AppModel) {
        self.model = model
        _work = ObservedObject(wrappedValue: model.work)
    }

    private var upcoming: [WorkItem] {
        work.items.filter { !$0.isComplete && $0.scheduledStart != nil && ($0.scheduledEnd ?? .distantPast) > clockNow }
            .sorted { ($0.scheduledStart ?? .distantFuture) < ($1.scheduledStart ?? .distantFuture) }
    }
    private var nextEvent: WorkItem? { upcoming.first }
    private var name: String { model.selectedBlock?.title ?? model.selectedTask?.title ?? "Quick focus" }
    private var step: String? {
        if let text = model.selectedTask?.nextStep, !text.isEmpty { return text }
        if let block = model.selectedBlock,
           let task = work.tasks(in: block).first(where: { !$0.isComplete }),
           !task.nextStep.isEmpty { return task.nextStep }
        return nil
    }
    private var recommendedMinutes: Int {
        guard let start = nextEvent?.scheduledStart else { return model.defaultMinutes }
        let free = Int(start.timeIntervalSince(clockNow) / 60) - 5
        if free < 5 { return 2 }
        if free < 15 { return 5 }
        if free < 25 { return 15 }
        return min(model.defaultMinutes, min(60, (free / 5) * 5))
    }
    private var minutes: Int { chosenDuration ?? recommendedMinutes }
    private var themeIsNight: Bool {
        let hour = Calendar.current.component(.hour, from: clockNow)
        return hour >= 20 || hour < 6
    }
    private var skyText: Color { themeIsNight ? .white : Color(red: 0.07, green: 0.15, blue: 0.31) }
    private var footerItems: [WorkItem] {
        let upcomingThree = Array(upcoming.prefix(3))
        if !upcomingThree.isEmpty { return upcomingThree }
        return Array(work.items.filter { !$0.isComplete && $0.scheduledStart == nil }.prefix(3))
    }

    var body: some View {
        GeometryReader { viewport in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    skyHeader
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 310 : min(315, max(235, viewport.size.height * 0.37)))
                    focusSurface
                        .padding(.horizontal, 16)
                        .padding(.top, -19)
                    upcomingSurface
                        .padding(.horizontal, 17)
                        .padding(.top, 19)
                        .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: viewport.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .background(Color(red: 0.979, green: 0.983, blue: 0.993))
        }
        .sheet(isPresented: $showingEditor) {
            TaskEditor(googleCalendars: model.google.calendars, onSave: { model.save($0) })
                .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $expandedClock) {
            CircularDayExpanded(model: model, close: { expandedClock = false })
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { clockNow = $0 }
        .accessibilityIdentifier("ignition.now.circular-home")
    }

    private var skyHeader: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                CircularSkyBackground(night: themeIsNight)
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ignition.")
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .tracking(-0.9)
                            Text(clockNow.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                 + " · \(model.sessionsHistory.filter { $0.outcome == .finished && Calendar.current.isDate($0.startedAt, inSameDayAs: clockNow) }.count) finished")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(skyText.opacity(0.7))
                        }
                        Spacer()
                        Button {
                            IgnitionFeedback.selection()
                            expandedClock = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(themeIsNight ? 0.18 : 0.9), in: Circle())
                        }
                        .accessibilityLabel("Explore the full day")
                        Button { model.settingsOpen = true } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 18))
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(themeIsNight ? 0.18 : 0.9), in: Circle())
                        }
                        .accessibilityLabel("Settings")
                    }
                    .foregroundStyle(skyText)
                    .padding(.horizontal, 23)
                    .padding(.top, 18)

                    Spacer(minLength: 6)
                    CircularDayClock(
                        tasks: work.items, blocks: work.blocks, sessions: model.sessionsHistory,
                        now: clockNow, diameter: min(geo.size.width * 0.59, max(138, geo.size.height * 0.60)),
                        extended: false, onSelect: { id in model.chooseTask(id) },
                        onSelectBlock: { id in model.chooseBlock(id) }
                    )
                    .accessibilityLabel("Day clock showing completed focus sessions and upcoming events")
                    Spacer(minLength: 15)
                }
            }
        }
    }

    private var focusSurface: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(model.session == nil ? "READY TO FOCUS" : "FOCUS IN PROGRESS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Color(red: 0.37, green: 0.46, blue: 0.61))
                Spacer(minLength: 6)
                Text(model.protection.status == .active ? "PROTECTED" : "TIMER ONLY")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(model.protection.status == .active ? Color.green : .secondary)
            }
            Menu {
                Button("Quick focus") { model.chooseTask(nil) }
                ForEach(work.blocks.sorted { $0.start < $1.start }) { block in
                    Button(block.title) { model.chooseBlock(block.id) }
                }
                ForEach(work.items.filter { !$0.isComplete }) { item in
                    Button(item.title) { model.chooseTask(item.id) }
                }
                Button("Add a task", systemImage: "plus") { showingEditor = true }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Text(name)
                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 19 : 20,
                                      weight: .semibold, design: .rounded))
                        .tracking(-0.5)
                        .foregroundStyle(Color(red: 0.075, green: 0.14, blue: 0.28))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 24, minHeight: 28)
                }
            }
            .accessibilityLabel("Focus task: \(name). Tap to change")

            if let step { Label(step, systemImage: "arrow.turn.down.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary).lineLimit(2) }
            if let event = nextEvent, let start = event.scheduledStart, model.session == nil {
                let free = max(0, Int(start.timeIntervalSince(clockNow) / 60))
                Text(free <= 10 ? "\(event.title) in \(free) min · take a small start" :
                        "\(free) min until \(event.title)")
                    .font(.system(size: 12))
                    .foregroundStyle(free <= 10 ? Color(red: 0.70, green: 0.36, blue: 0.09) : .secondary)
                    .lineLimit(2)
            }

            if model.session == nil {
                HStack(spacing: 7) {
                    ForEach(Array(Set([2,15,25,35,45,60,minutes])).sorted().filter { $0 == minutes || [15,25,35,45,60].contains($0) }.prefix(5), id: \.self) { value in
                        Button { chosenDuration = value; IgnitionFeedback.selection() } label: {
                            Text("\(value)m")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 31)
                                .foregroundStyle(value == minutes ? .white : Color(red: 0.30, green: 0.38, blue: 0.54))
                                .background(value == minutes ? Color(red: 0.19, green: 0.37, blue: 0.84) : Color(red: 0.93, green: 0.95, blue: 0.99), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Choose focus duration")
            }
            HStack(spacing: 17) {
                Button(action: start) {
                    VStack(spacing: 3) {
                        Image(systemName: model.session == nil ? "bolt.fill" : "arrow.uturn.backward")
                            .font(.system(size: 20))
                        Text(model.session == nil ? "Lock In" : "Return")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text(model.session == nil ? "\(minutes) min" : "to focus")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 112, height: 112)
                    .background {
                        Circle().fill(LinearGradient(colors: [Color(red: 0.29, green: 0.53, blue: 1.0), Color(red: 0.13, green: 0.32, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .overlay { Circle().stroke(Color(red: 0.84, green: 0.90, blue: 1.0), lineWidth: 7).padding(-5) }
                    .shadow(color: Color.blue.opacity(0.20), radius: 16, y: 6)
                }
                .buttonStyle(IgnitionPressStyle())
                .disabled(model.isStartingFocus)
                .accessibilityIdentifier("ignition.now.lock-in")
                .accessibilityLabel(model.session == nil ? "Lock in for \(minutes) minutes" : "Return to focus")
                VStack(alignment: .leading, spacing: 7) {
                    if let active = model.session {
                        TimelineView(.periodic(from: .now, by: 1)) { tick in
                            Text("\(max(0, Int(active.remainingSeconds(asOf: tick.date) / 60))) min left")
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                        }
                        Text("Your session is still here")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    } else {
                        Text("Start now")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("\(minutes) minutes. One clear next move.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(Color(red: 0.07, green: 0.15, blue: 0.3))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 17)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(.white, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .shadow(color: Color(red: 0.19, green: 0.35, blue: 0.60).opacity(0.10), radius: 19, y: 7)
    }

    private var upcomingSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Up next").font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
                Button(expandedTasks ? "Less" : "See all") {
                    IgnitionFeedback.selection()
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.83)) {
                        expandedTasks.toggle()
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.16, green: 0.39, blue: 0.82))
            }
            .padding(.bottom, 4)
            if footerItems.isEmpty {
                Text("Nothing scheduled. Start a quick focus or add a task in Plan.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .padding(.vertical, 15)
            } else {
                ForEach(expandedTasks ? Array((upcoming + work.items.filter { !$0.isComplete && $0.scheduledStart == nil }).prefix(12)) : footerItems) { item in
                    Button {
                        model.chooseTask(item.id)
                        IgnitionFeedback.selection()
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { expandedTasks = false }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.isFixed ? "calendar" : (item.scheduledStart == nil ? "circle.dotted" : "circle"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(item.tint.color)
                                .frame(width: 21)
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .foregroundStyle(Color(red: 0.08, green: 0.14, blue: 0.28))
                            Spacer(minLength: 4)
                            Text(item.scheduledStart?.formatted(date: .omitted, time: .shortened) ?? "Anytime")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 38)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(item.isFixed)
                    if item.id != (expandedTasks ? (upcoming + work.items.filter { !$0.isComplete && $0.scheduledStart == nil }).prefix(12).last?.id : footerItems.last?.id) {
                        Divider().opacity(0.5)
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func start() {
        if model.session != nil { model.showFocus = true }
        else { Task { await model.lockIn(minutes: minutes, blockID: model.selectedBlockID) } }
    }
}

private struct CircularSkyBackground: View {
    let night: Bool
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                LinearGradient(colors: night ? [Color(red: 0.09, green: 0.14, blue: 0.33), Color(red: 0.24, green: 0.33, blue: 0.56)] :
                                [Color(red: 0.43, green: 0.70, blue: 0.95), Color(red: 0.83, green: 0.91, blue: 1)], startPoint: .top, endPoint: .bottom)
                Canvas { context, size in
                    if night {
                        for i in 0..<27 {
                            let x = CGFloat((i * 59 + 9) % 101) / 101 * size.width
                            let y = CGFloat((i * 37 + 8) % 83) / 100 * size.height
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.7, height: 1.7)), with: .color(.white.opacity(0.56)))
                        }
                    }
                    var ridge = Path()
                    ridge.move(to: CGPoint(x: 0, y: size.height * 0.84))
                    ridge.addCurve(to: CGPoint(x: size.width, y: size.height * 0.82), control1: CGPoint(x: size.width * 0.34, y: size.height * 0.70), control2: CGPoint(x: size.width * 0.63, y: size.height * 0.92))
                    ridge.addLine(to: CGPoint(x: size.width, y: size.height))
                    ridge.addLine(to: CGPoint(x: 0, y: size.height))
                    ridge.closeSubpath()
                    context.fill(ridge, with: .color(night ? Color(red: 0.13, green: 0.26, blue: 0.31) : Color(red: 0.61, green: 0.76, blue: 0.82)))
                    var hill = Path()
                    hill.move(to: CGPoint(x: 0, y: size.height * 0.93))
                    hill.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.91), control: CGPoint(x: size.width * 0.46, y: size.height * 0.81))
                    hill.addLine(to: CGPoint(x: size.width, y: size.height))
                    hill.addLine(to: CGPoint(x: 0, y: size.height))
                    hill.closeSubpath()
                    context.fill(hill, with: .color(night ? Color(red: 0.07, green: 0.19, blue: 0.24) : Color(red: 0.42, green: 0.66, blue: 0.53)))
                    var stream = Path()
                    stream.move(to: CGPoint(x: size.width * 0.47, y: size.height))
                    stream.addQuadCurve(to: CGPoint(x: size.width * 0.51, y: size.height * 0.90), control: CGPoint(x: size.width * 0.43, y: size.height * 0.95))
                    stream.addLine(to: CGPoint(x: size.width * 0.54, y: size.height * 0.90))
                    stream.addQuadCurve(to: CGPoint(x: size.width * 0.56, y: size.height), control: CGPoint(x: size.width * 0.50, y: size.height * 0.95))
                    stream.closeSubpath()
                    context.fill(stream, with: .color(night ? Color(red: 0.19, green: 0.42, blue: 0.60) : Color(red: 0.22, green: 0.63, blue: 0.91)))
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .accessibilityHidden(true)
    }
}

/// Shared 24-hour coordinates. 6 AM is left, noon top, 6 PM right, midnight bottom.
/// Each event and footprint comes from its actual date, never a hand-tuned x value.
private struct CircularDayClock: View {
    let tasks: [WorkItem]
    let blocks: [FocusBlock]
    let sessions: [FocusSession]
    let now: Date
    let diameter: CGFloat
    let extended: Bool
    let onSelect: (UUID) -> Void
    let onSelectBlock: (UUID) -> Void

    private var dateClock: Calendar { Calendar.current }
    private func point(at date: Date, r: CGFloat, center: CGPoint) -> CGPoint {
        let c = dateClock.dateComponents([.hour, .minute, .second], from: date)
        let minutes = CGFloat((c.hour ?? 0) * 60 + (c.minute ?? 0)) + CGFloat(c.second ?? 0) / 60
        let angle = CGFloat.pi + ((minutes - 360) / 1440) * 2 * CGFloat.pi
        return CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
    }
    private var stops: [WorkItem] {
        tasks.filter { $0.scheduledStart != nil && dateClock.isDate($0.scheduledStart!, inSameDayAs: now) }
            .sorted { ($0.scheduledStart ?? now) < ($1.scheduledStart ?? now) }
    }
    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.45
                        for i in 0..<96 {
                    let angle = CGFloat.pi + (CGFloat(i) / 96) * 2 * CGFloat.pi
                    let p1 = CGPoint(x: center.x + (radius - (i % 4 == 0 ? 7 : 3)) * cos(angle),
                                     y: center.y + (radius - (i % 4 == 0 ? 7 : 3)) * sin(angle))
                    let p2 = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                    var tick = Path(); tick.move(to: p1); tick.addLine(to: p2)
                    context.stroke(tick, with: .color(.white.opacity(0.40)), lineWidth: i % 4 == 0 ? 1.2 : 0.6)
                }
                for i in 0..<144 {
                    let a = CGFloat(i) / 144
                    let angle = CGFloat.pi + a * 2 * CGFloat.pi
                    let p1 = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                    let endAngle = CGFloat.pi + CGFloat(i + 1) / 144 * 2 * CGFloat.pi
                    let p2 = CGPoint(x: center.x + radius * cos(endAngle), y: center.y + radius * sin(endAngle))
                    var segment = Path(); segment.move(to: p1); segment.addLine(to: p2)
                    let nowMinutes = dateClock.component(.hour, from: now) * 60 + dateClock.component(.minute, from: now)
                    // Map the 6 AM-left visual origin back onto a real calendar day.
                    // After midnight, only 12 AM -> Now is past (not the prior day).
                    let segmentClockMinutes = (360 + i * 1440 / 144) % 1440
                    let past = segmentClockMinutes <= nowMinutes
                    context.stroke(segment, with: .color(.white.opacity(past ? 0.90 : 0.40)),
                                   style: StrokeStyle(lineWidth: 2.4, lineCap: .round,
                                                      dash: past ? [] : [1, 4]))
                }
                for block in blocks where dateClock.isDate(block.start, inSameDayAs: now) {
                    let start = block.start
                    let end = block.end
                    let p1 = point(at: start, r: radius, center: center)
                    let p2 = point(at: end, r: radius, center: center)
                    var arc = Path(); arc.move(to: p1)
                    let total = max(2, block.durationMinutes / 4)
                    for i in 1...total {
                        let t = start.addingTimeInterval(Double(i) / Double(total) * end.timeIntervalSince(start))
                        arc.addLine(to: point(at: t, r: radius, center: center))
                    }
                    context.stroke(arc, with: .color(Color(red: 0.47, green: 0.38, blue: 0.77)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }
            }
            ForEach(Array(sessions.filter { dateClock.isDate($0.startedAt, inSameDayAs: now) }.prefix(15))) { session in
                let p = markerPosition(at: session.startedAt)
                Image(systemName: sessionIcon(session))
                    .font(.system(size: extended ? 17 : 13, weight: .semibold))
                    .foregroundStyle(sessionColor(session))
                    .background(Circle().fill(.white).padding(2))
                    .position(p)
                    .accessibilityLabel("\(sessionStatus(session)) focus session at \(session.startedAt.formatted(date: .omitted, time: .shortened))")
            }
            ForEach(Array(stops.prefix(12))) { item in
                let p = markerPosition(at: item.scheduledStart ?? now)
                Button { onSelect(item.id) } label: {
                    Circle().fill(.white).frame(width: extended ? 15 : 12, height: extended ? 15 : 12)
                        .overlay(Circle().stroke(item.tint.color, lineWidth: 2.5))
                }
                .position(p)
                .accessibilityLabel("\(item.title), \((item.scheduledStart ?? now).formatted(date: .omitted, time: .shortened))")
            }
            ForEach(Array(blocks.filter { dateClock.isDate($0.start, inSameDayAs: now) }.prefix(10))) { block in
                let p = markerPosition(at: block.start)
                Button { onSelectBlock(block.id) } label: {
                    Circle().fill(.white).frame(width: extended ? 15 : 12, height: extended ? 15 : 12)
                        .overlay(Circle().stroke(Color(red: 0.47, green: 0.38, blue: 0.77), lineWidth: 2.5))
                }
                .position(p)
                .accessibilityLabel("Focus block \(block.title)")
            }
            if dateClock.component(.hour, from: now) >= 20 || dateClock.component(.hour, from: now) < 6 {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: extended ? 19 : 16))
                    .foregroundStyle(Color(red: 0.93, green: 0.96, blue: 1))
                    .frame(width: extended ? 37 : 32, height: extended ? 37 : 32)
                    .background(Color(red: 0.34, green: 0.47, blue: 0.74), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 2))
                    .shadow(color: Color.white.opacity(0.25), radius: 13)
                    .position(markerPosition(at: now))
                    .accessibilityLabel("Now \(now.formatted(date: .omitted, time: .shortened))")
            } else {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.97, blue: 0.76), Color(red: 1.0, green: 0.75, blue: 0.37)], startPoint: .top, endPoint: .bottom))
                    .frame(width: extended ? 35 : 31, height: extended ? 35 : 31)
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 3))
                    .shadow(color: Color(red: 1, green: 0.82, blue: 0.40).opacity(0.8), radius: 14)
                    .position(markerPosition(at: now))
                    .accessibilityLabel("Now \(now.formatted(date: .omitted, time: .shortened))")
            }
            if extended {
                VStack(spacing: 4) {
                    Text(now.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text("Your day in motion")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color(red: 0.12, green: 0.23, blue: 0.43))
            }
        }
        .frame(width: diameter, height: diameter)
    }
    private func sessionStatus(_ session: FocusSession) -> String {
        switch session.phase {
        case .active: return "Active"
        case .onBreak: return "On break"
        case .paused: return "Paused"
        case .ended:
            switch session.outcome {
            case .finished: return "Finished"
            case .madeProgress: return "Made progress"
            case .notFinished: return "Ended early"
            case nil: return "Ended, not reviewed"
            }
        }
    }
    private func sessionIcon(_ session: FocusSession) -> String {
        switch session.phase {
        case .active: return "circle.inset.filled"
        case .onBreak, .paused: return "pause.circle.fill"
        case .ended:
            switch session.outcome {
            case .finished: return "checkmark.circle.fill"
            case .madeProgress: return "circle.lefthalf.filled"
            case .notFinished: return "circle.dashed"
            case nil: return "circle.dashed"
            }
        }
    }
    private func sessionColor(_ session: FocusSession) -> Color {
        switch session.phase {
        case .active, .paused, .onBreak: return Color(red: 0.19, green: 0.42, blue: 0.90)
        case .ended:
            switch session.outcome {
            case .finished: return Color(red: 0.18, green: 0.57, blue: 0.39)
            case .madeProgress: return Color(red: 0.20, green: 0.55, blue: 0.56)
            case .notFinished: return Color(red: 0.87, green: 0.48, blue: 0.17)
            case nil: return Color(red: 0.60, green: 0.66, blue: 0.75)
            }
        }
    }
    private func markerPosition(at date: Date) -> CGPoint {
        point(at: date, r: diameter * 0.45, center: CGPoint(x: diameter / 2, y: diameter / 2))
    }
}

private struct CircularDayExpanded: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var work: WorkRepository
    let close: () -> Void
    @State private var previewTime: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(model: AppModel, close: @escaping () -> Void) {
        self.model = model
        self.close = close
        _work = ObservedObject(wrappedValue: model.work)
    }
    var body: some View {
        GeometryReader { geo in
            let dial = min(geo.size.width * 0.82, 355)
            ZStack {
                CircularSkyBackground(night: false)
                VStack(spacing: 20) {
                    HStack {
                        Text("Your day").font(.system(size: 25, weight: .bold, design: .rounded))
                        Spacer()
                        Button("Done", action: close).fontWeight(.semibold)
                    }
                    .padding(.horizontal, 22)
                    CircularDayClock(tasks: work.items, blocks: work.blocks,
                                     sessions: model.sessionsHistory,
                                     now: previewTime ?? Date(), diameter: dial, extended: true,
                                     onSelect: { model.chooseTask($0); close() },
                                     onSelectBlock: { model.chooseBlock($0); close() })
                        .gesture(DragGesture(minimumDistance: 12).onEnded { value in
                            let hourDelta = Int((value.translation.width / max(150, dial) * 12).rounded())
                            guard hourDelta != 0 else { return }
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                                previewTime = (previewTime ?? Date()).addingTimeInterval(Double(hourDelta) * 3600)
                            }
                        })
                    HStack {
                        Text(previewTime == nil ? "Now" : "Previewing \((previewTime ?? Date()).formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        if previewTime != nil {
                            Button("Back to Now") { previewTime = nil }
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 22)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TODAY'S PLAN")
                            .font(.system(size: 11, weight: .bold)).tracking(1)
                        ForEach(Array(work.upcoming(after: Calendar.current.startOfDay(for: previewTime ?? Date())).prefix(5))) { item in
                            HStack {
                                Circle().fill(item.tint.color).frame(width: 7, height: 7)
                                Text(item.title).lineLimit(1)
                                Spacer()
                                Text(item.scheduledStart?.formatted(date: .omitted, time: .shortened) ?? "")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 13))
                        }
                    }
                    .padding(19)
                    .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 23))
                    .padding(.horizontal, 16)
                    Spacer(minLength: 0)
                    Button { close(); model.showFocus = model.session != nil } label: {
                        Text(model.session == nil ? "Return to Lock In" : "Return to Focus")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 22)
                }
                .padding(.top, 25)
            }
        }
        .preferredColorScheme(.light)
    }
}
