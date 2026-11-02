import ActivityKit
import SwiftUI
import WidgetKit

@main
struct IgnitionWidgets: WidgetBundle {
    var body: some Widget {
        IgnitionHomeWidget()
        LiveActivityExperience()
    }
}

struct HomeEntry: TimelineEntry {
    var date: Date
    var summary: WidgetSummary
}

struct HomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomeEntry {
        HomeEntry(date: Date(), summary: .empty)
    }
    func getSnapshot(in context: Context, completion: @escaping (HomeEntry) -> Void) {
        completion(HomeEntry(date:Date(),summary:SharedConfiguration.widgetSummary))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeEntry>) -> Void) {
        let now = Date()
        let summary = SharedConfiguration.widgetSummary
        var entries = [HomeEntry(date: now, summary: summary)]
        if summary.isActive, let end = summary.expectedEnd, end > now {
            // WidgetKit can transition the Home Screen widget to "time reached"
            // without the main app waking up in the background.
            entries.append(HomeEntry(date: end, summary: WidgetSummary(
                task: summary.task, detail: "Time reached · open Ignition to review",
                sessionStart: summary.sessionStart, expectedEnd: nil, isActive: false)))
        }
        let reload = max(now.addingTimeInterval(15*60), summary.expectedEnd ?? now)
        completion(Timeline(entries: entries, policy:.after(reload)))
    }
}

struct IgnitionHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind:"IgnitionHome", provider:HomeProvider()) { entry in
            VStack(alignment:.leading,spacing:8) {
                Label("Ignition",systemImage:"bolt.fill").font(.caption.bold()).foregroundStyle(Color(red:0.23,green:0.43,blue:0.89))
                Text(entry.summary.task).font(.headline).lineLimit(2)
                Text(entry.summary.detail).font(.caption).lineLimit(2).foregroundStyle(.secondary)
                if entry.summary.isActive, let end = entry.summary.expectedEnd {
                    Text(timerInterval:min(Date(),end)...end,countsDown:true)
                        .font(.headline.monospacedDigit())
                }
                Spacer(minLength:0)
                Text("Tap to open").font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
            .widgetURL(URL(string:"ignition://focus"))
            .containerBackground(.fill.tertiary,for:.widget)
        }
        .configurationDisplayName("Your next focus")
        .description("See your current focus or next step.")
        .supportedFamilies([.systemSmall,.systemMedium])
    }
}


// Shared visual language in the two independently signed widget extensions.
// Keep previews and the full app visually identical. There are intentionally
// no fake controls: tapping the activity opens the running Ignition session.
private enum LiveColors {
    static let navy = Color(red: 0.035, green: 0.095, blue: 0.18)
    static let raised = Color(red: 0.075, green: 0.17, blue: 0.27)
    static let cyan = Color(red: 0.26, green: 0.77, blue: 0.76)
    static let soft = Color(red: 0.71, green: 0.81, blue: 0.88)
}

private struct LiveCountdown: View {
    let state: IgnitionLiveAttributes.ContentState
    let stale: Bool

    var body: some View {
        Group {
            if stale { Text("00:00") }
            else if state.isRunning {
                Text(timerInterval: min(Date(), state.deadline)...state.deadline,
                     countsDown: true, showsHours: false)
            } else {
                Text(String(format: "%02d:%02d", state.secondsAtPause / 60,
                            state.secondsAtPause % 60))
            }
        }
        .monospacedDigit()
        .contentTransition(.numericText())
        .accessibilityLabel(stale ? "Session time reached" : state.phaseLabel)
    }
}

private struct LiveTimeProgress: View {
    let attributes: IgnitionLiveAttributes
    let state: IgnitionLiveAttributes.ContentState
    let stale: Bool

    var body: some View {
        Group {
            if stale {
                ProgressView(value: 1.0)
            } else if state.isRunning {
                // System-driven animation works while Ignition is suspended.
                // Deadline minus total duration also accounts for time focused
                // before a pause/resume, without adding paused time.
                ProgressView(timerInterval: state.deadline.addingTimeInterval(
                    -TimeInterval(max(1, attributes.totalSeconds)))...state.deadline,
                    countsDown: false)
            } else {
                ProgressView(value: min(1, Double(state.activeSecondsAtUpdate) /
                                       Double(max(1, attributes.totalSeconds))))
            }
        }
        .tint(LiveColors.cyan)
    }
}

private struct LiveTaskRow: View {
    let task: IgnitionLiveTask
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(task.isComplete ? LiveColors.cyan : LiveColors.soft)
            Text(task.title)
                .font(.system(size: 11, weight: task.isComplete ? .regular : .medium))
                .foregroundStyle(task.isComplete ? LiveColors.soft : .white)
                .strikethrough(task.isComplete)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

private struct LiveActivityLockCard: View {
    let context: ActivityViewContext<IgnitionLiveAttributes>
    private var state: IgnitionLiveAttributes.ContentState { context.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().fill(LiveColors.raised)
                    Circle().stroke(LiveColors.soft.opacity(0.27), lineWidth: 2.5)
                        .padding(2.5)
                    if state.totalTaskCount > 0 {
                        Circle()
                            .trim(from: 0, to: min(1, CGFloat(state.completedTaskCount) / CGFloat(max(1, state.totalTaskCount))))
                            .stroke(LiveColors.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .padding(2.5)
                    }
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LiveColors.cyan)
                }
                .frame(width: 39, height: 39)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.task)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(context.isStale ? "Time reached" : state.phaseLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LiveColors.soft)
                }
                Spacer(minLength: 4)
                LiveCountdown(state: state, stale: context.isStale)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 75, alignment: .trailing)
            }
            LiveTimeProgress(attributes: context.attributes, state: state, stale: context.isStale)
                .progressViewStyle(.linear)
                .frame(height: 5)
            if state.totalTaskCount > 0 {
                HStack {
                    Text("TASKS")
                        .tracking(1.3)
                    Spacer()
                    Text("\(state.completedTaskCount)/\(state.totalTaskCount)")
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(LiveColors.soft)
                ForEach(Array(state.visibleTasks.prefix(2).enumerated()), id: \.offset) { _, task in
                    LiveTaskRow(task: task)
                }
            } else if let next = state.nextStep, !next.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.turn.down.right")
                    Text(next).lineLimit(1)
                }
                .font(.system(size: 11))
                .foregroundStyle(LiveColors.soft)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [LiveColors.navy, LiveColors.raised],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .widgetURL(URL(string: "ignition://focus"))
        .activityBackgroundTint(LiveColors.navy)
        .activitySystemActionForegroundColor(.white)
    }
}

private struct LiveExpandedBottom: View {
    let context: ActivityViewContext<IgnitionLiveAttributes>
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            LiveTimeProgress(attributes: context.attributes, state: context.state,
                             stale: context.isStale)
                .progressViewStyle(.linear)
            if context.state.totalTaskCount > 0 {
                HStack {
                    Text("\(context.state.completedTaskCount) OF \(context.state.totalTaskCount) TASKS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(LiveColors.cyan)
                    Spacer()
                    Text("Tap to open")
                        .font(.system(size: 9))
                        .foregroundStyle(LiveColors.soft)
                }
                ForEach(Array(context.state.visibleTasks.prefix(2).enumerated()), id: \.offset) { _, task in
                    LiveTaskRow(task: task)
                }
            } else if let next = context.state.nextStep, !next.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.turn.down.right")
                    Text(next).lineLimit(1)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LiveColors.soft)
            } else {
                Text("Tap to return to focus")
                    .font(.system(size: 11))
                    .foregroundStyle(LiveColors.soft)
            }
        }
        .padding(.top, 4)
    }
}

private struct LiveActivityExperience: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IgnitionLiveAttributes.self) { context in
            LiveActivityLockCard(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(LiveColors.cyan)
                        Text(context.state.phaseLabel.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LiveColors.soft)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveCountdown(state: context.state, stale: context.isStale)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 68, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.task)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveExpandedBottom(context: context)
                }
            } compactLeading: {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LiveColors.cyan)
            } compactTrailing: {
                LiveCountdown(state: context.state, stale: context.isStale)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 55, alignment: .trailing)
            } minimal: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(LiveColors.cyan)
            }
            .widgetURL(URL(string: "ignition://focus"))
            .keylineTint(LiveColors.cyan)
        }
    }
}
