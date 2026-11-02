import SwiftUI
import UIKit

// Focus retains the approved starry-night identity. The timer and action dock
// are a single glanceable surface, so controls don't float far from time.
struct FocusView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var audio: FocusAudioPlayer
    @ObservedObject private var protection: ProtectionService
    @State private var showingBlockTasks = false
    @State private var showingExit = false
    @State private var showingReturn = false
    @State private var actionPending = false
    @State private var pendingLabel = ""

    init(model: AppModel) {
        self.model = model
        _audio = ObservedObject(wrappedValue: model.audio)
        _protection = ObservedObject(wrappedValue: model.protection)
    }

    var body: some View {
        ZStack {
            nightScene
            VStack(spacing: 0) {
                header
                if let session = model.session {
                    Spacer().frame(height: 58)
                    VStack(spacing: 14) {
                        Text(session.phase == .active ? "IN FOCUS" :
                             session.phase == .onBreak ? "ON BREAK" : "PAUSED")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(2.5)
                            .foregroundStyle(.white.opacity(0.70))
                        Text(session.title)
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.75)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                        if let next = session.nextStep, !next.isEmpty {
                            HStack(spacing: 9) {
                                Image(systemName: "arrow.turn.down.right")
                                    .foregroundStyle(IgnitionDesign.teal)
                                Text(next)
                                    .font(IgnitionDesign.bodyText())
                                    .foregroundStyle(.white.opacity(0.87))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 12)
                        }
                        if let block = model.focusBlock {
                            let tasks = model.work.tasks(in: block)
                            Button {
                                IgnitionFeedback.selection()
                                showingBlockTasks = true
                            } label: {
                                Label("TASKS · \(tasks.filter(\.isComplete).count)/\(tasks.count)",
                                      systemImage: "checklist")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 9)
                                    .background(.white.opacity(0.15), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Review the block tasks without ending focus")
                        }
                    }
                    Spacer(minLength: 24)
                    focusDock(session)
                    Button {
                        runAction("Exiting…", heavy: true) {
                            await model.end(emergency: true)
                        }
                    } label: {
                        Text("Emergency exit")
                            .font(.system(size: 12))
                            .underline()
                            .foregroundStyle(.white.opacity(0.74))
                            .frame(minHeight: 44)
                    }
                    .disabled(actionPending)
                    .accessibilityIdentifier("focus.emergencyExit")
                    Spacer().frame(height: 8)
                } else {
                    Spacer()
                    Text("Focus session finished")
                        .foregroundStyle(.white)
                    Button("Return to Now") { model.showFocus = false }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
            .padding(.horizontal, 22)
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("End this focus session?", isPresented: $showingExit) {
            Button("End and save my place") {
                runAction("Ending…", heavy: true) { await model.end() }
            }
            Button("Keep focusing", role: .cancel) {}
        } message: {
            Text("Your actual focus time will be saved. Ending releases app protection.")
        }
        .sheet(isPresented: $showingReturn) {
            ReturnView(model: model).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingBlockTasks) {
            if let block = model.focusBlock {
                FocusBlockTasksSheet(model: model, blockID: block.id)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var nightScene: some View {
        ZStack {
            LinearGradient(colors: [IgnitionDesign.focusTop,
                                    IgnitionDesign.focusBottom],
                           startPoint: .top, endPoint: .bottom)
            // Restrained illumination: atmospheric depth, not an animated reward.
            GeometryReader { sky in
                Circle()
                    .fill(Color(red: 0.97, green: 0.92, blue: 0.75).opacity(0.85))
                    .frame(width: 32, height: 32)
                    .shadow(color: Color(red: 0.98, green: 0.89, blue: 0.68).opacity(0.38), radius: 26)
                    .position(x: sky.size.width * 0.79, y: sky.size.height * 0.25)
                Ellipse()
                    .fill(IgnitionDesign.action.opacity(0.16))
                    .frame(width: sky.size.width * 1.2, height: sky.size.height * 0.26)
                    .blur(radius: 38)
                    .position(x: sky.size.width * 0.45, y: sky.size.height * 0.73)
            }
            Canvas { ctx, size in
                for index in 0..<52 {
                    let x = size.width * CGFloat((index * 47 + 11) % 101) / 101
                    let y = size.height * CGFloat((index * 31 + 9) % 77) / 100
                    let diameter = CGFloat(index % 3 + 1)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                             with: .color(.white.opacity(index % 4 == 0 ? 0.75 : 0.32)))
                }
                var silhouette = Path()
                silhouette.move(to: CGPoint(x: 0, y: size.height * 0.78))
                silhouette.addLines([
                    CGPoint(x: size.width * 0.17, y: size.height * 0.67),
                    CGPoint(x: size.width * 0.33, y: size.height * 0.74),
                    CGPoint(x: size.width * 0.58, y: size.height * 0.61),
                    CGPoint(x: size.width * 0.81, y: size.height * 0.76),
                    CGPoint(x: size.width, y: size.height * 0.65),
                    CGPoint(x: size.width, y: size.height),
                    CGPoint(x: 0, y: size.height)
                ])
                silhouette.closeSubpath()
                ctx.fill(silhouette, with: .color(Color(red: 0.10, green: 0.21, blue: 0.42)))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                IgnitionFeedback.selection()
                showingReturn = true
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Return options")
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                Circle()
                    .fill(protection.status == .active ? Color.mint : .white.opacity(0.55))
                    .frame(width: 7, height: 7)
                Text(protection.status.title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white.opacity(0.82))
            Spacer(minLength: 4)
            Menu {
                ForEach(audio.tracks, id: \.self) { name in
                    Button(name) { audio.play(name) }
                }
                Button("Stop audio") { audio.choosePreferredTrack("Silence", sessionActive: true) }
            } label: {
                Image(systemName: audio.isPlaying ? "music.note.list" : "music.note")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Focus sounds")
        }
        .foregroundStyle(.white)
        .padding(.top, 12)
    }

    private func focusDock(_ session: FocusSession) -> some View {
        VStack(spacing: 12) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int(ceil(session.remainingSeconds(asOf: context.date))))
                let progress = min(1, session.activeSeconds(asOf: context.date) /
                                      max(1, session.targetSeconds))
                VStack(spacing: 8) {
                    GeometryReader { bar in
                        Capsule().fill(.white.opacity(0.18))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color(red: 0.61, green: 0.79, blue: 1))
                                    .frame(width: bar.size.width * progress)
                            }
                    }
                    .frame(height: 4)
                    Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                        .font(.system(size: 58, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .accessibilityLabel("Focus time remaining")
                    Text(actionPending ? pendingLabel :
                         session.phase == .active ? "FOCUS · \(Int(session.targetSeconds / 60)) MIN" :
                         session.phase == .onBreak ? "BREAK · FOCUS TIMER PAUSED" :
                         "PAUSED · READY TO RETURN")
                        .font(IgnitionDesign.metadata())
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.73))
                }
            }
            HStack(spacing: 14) {
                Button {
                    runAction("Starting break…") { await model.startBreak() }
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: "cup.and.saucer")
                            .font(.system(size: 19, weight: .regular))
                        Text("Break").font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity, minHeight: 55)
                    .contentShape(Rectangle())
                }
                .disabled(actionPending || session.phase != .active)
                .accessibilityIdentifier("focus.break")

                Button {
                    let playing = session.phase == .active
                    runAction(playing ? "Pausing…" : "Resuming…") {
                        if playing { await model.pause() }
                        else { await model.resume() }
                    }
                } label: {
                    ZStack {
                        Circle().fill(Color(red: 0.23, green: 0.43, blue: 0.92))
                        if actionPending { ProgressView().tint(.white) }
                        else {
                            Image(systemName: session.phase == .active ? "pause.fill" : "play.fill")
                                .font(.system(size: 21, weight: .bold))
                        }
                    }
                    .frame(width: 62, height: 62)
                    .shadow(color: IgnitionDesign.action.opacity(0.34), radius: 12, y: 4)
                }
                .disabled(actionPending)
                .buttonStyle(IgnitionPressStyle())
                .accessibilityLabel(session.phase == .active ? "Pause focus" : "Resume focus")
                .accessibilityIdentifier("focus.togglePause")

                Button {
                    IgnitionFeedback.selection()
                    showingExit = true
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16))
                        Text("End").font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity, minHeight: 55)
                    .contentShape(Rectangle())
                }
                .disabled(actionPending)
                .accessibilityIdentifier("focus.end")
            }
            .foregroundStyle(.white)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color(red: 0.19, green: 0.29, blue: 0.48).opacity(0.65),
                    in: RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous)
            .strokeBorder(.white.opacity(0.19), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.16), radius: 14, y: 7)
    }

    private func runAction(_ label: String, heavy: Bool = false,
                           operation: @escaping @MainActor () async -> Void) {
        guard !actionPending else { return }
        actionPending = true
        pendingLabel = label
        if heavy { IgnitionFeedback.action() } else { IgnitionFeedback.selection() }
        Task {
            await operation()
            actionPending = false
            pendingLabel = ""
        }
    }
}

/// Task completion is a separate action from finishing a timer.
/// The checklist edits existing task IDs; it never copies tasks or marks the
/// parent focus reservation complete on behalf of the user.
private struct FocusBlockTasksSheet: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var work: WorkRepository
    @Environment(\.dismiss) private var dismiss
    let blockID: UUID

    init(model: AppModel, blockID: UUID) {
        self.model = model
        self.blockID = blockID
        _work = ObservedObject(wrappedValue: model.work)
    }

    var body: some View {
        NavigationStack {
            List {
                if let block = work.block(blockID) {
                    Section("\(block.durationMinutes) min reservation") {
                        if block.taskIDs.isEmpty {
                            Text("No tasks assigned. Add them from Plan.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(block.taskIDs, id: \.self) { id in
                            if let item = work.item(id) {
                                Button {
                                    model.completeBlockTask(item.id, completed: !item.isComplete)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(item.isComplete ? Color.green : IgnitionStyle.blue)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.title)
                                                .foregroundStyle(IgnitionStyle.navy)
                                            if !item.nextStep.isEmpty {
                                                Text(item.nextStep)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Text("This focus block was removed. Your timer is still running.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Block tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ReturnView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            LinearGradient(colors:[Color(red:0.10,green:0.21,blue:0.42),Color(red:0.06,green:0.13,blue:0.29)],startPoint:.top,endPoint:.bottom)
                .ignoresSafeArea()
            VStack(spacing:19) {
                Spacer()
                Image(systemName:"circle.dotted.circle.fill").font(.system(size:52)).foregroundStyle(.white.opacity(0.8))
                if let session = model.session {
                    if session.phase == .active {
                        Text("Back to \(session.title)").font(.title2.bold()).multilineTextAlignment(.center)
                        Text("Your session is still running").font(.subheadline)
                        if let step = session.nextStep { Text("Next: \(step)").font(.caption) }
                        PrimaryPill(text:"Back to focus") { dismiss();model.showFocus = true }
                    } else {
                        Text("Pick up where you left off").font(.title2.bold()).multilineTextAlignment(.center)
                        Text(session.title).font(.headline)
                        if let step = session.nextStep { Text("Next: \(step)").font(.caption) }
                        PrimaryPill(text:"Resume focus") { Task { await model.resume();dismiss() } }
                        Button("Start small (2 minutes)") {
                            Task {
                                await model.restartPausedSmall()
                                dismiss()
                            }
                        }.foregroundStyle(.white)
                    }
                } else if let last = model.lastEnded {
                    Text("Ready to return?").font(.title2.bold())
                    Text(last.title)
                    if let step = last.nextStep { Text("Next: \(step)") }
                    PrimaryPill(text:"Start again") {
                        Task { await model.restart(last); dismiss() }
                    }
                    Button("Start small (2 min)") {
                        Task { await model.restart(last, small:true); dismiss() }
                    }.foregroundStyle(.white)
                } else {
                    Text("Ready when you are").font(.title2.bold())
                    PrimaryPill(text:"Start quick focus") { Task { await model.lockIn();dismiss() } }
                }
                Button("Not now") { dismiss() }.font(.caption).underline()
                Spacer()
            }
            .foregroundStyle(.white).padding(24)
        }
    }
}

struct StartSmallView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing:18) {
            Image(systemName:"bolt.fill").font(.largeTitle).foregroundStyle(.orange)
            Text("Start small").font(.title.bold())
            Text(model.selectedTask?.nextStep.isEmpty == false ? model.selectedTask!.nextStep : "You can begin with just two minutes. No first step is required.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            PrimaryPill(text:"Start · 2 min") { Task { await model.lockIn(small:true);dismiss() } }
            Button("Skip for now") {dismiss()}
        }.padding(25)
    }
}

struct CloseView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var outcome: FocusOutcome?
    @State private var nextStep = ""
    var body: some View {
        VStack(alignment:.leading,spacing:17) {
            Text(model.lastEnded?.title ?? "Focus session").font(.caption).foregroundStyle(.secondary)
            Text("How did it go?").font(.title.bold())
            ForEach([FocusOutcome.finished,.madeProgress,.notFinished],id:\.self) { choice in
                Button { outcome = choice } label: {
                    HStack {
                        Text(choice == .finished ? "Finished" : choice == .madeProgress ? "Made progress" : "Not finished")
                        Spacer()
                        Image(systemName:outcome == choice ? "checkmark.circle.fill" : "circle")
                    }.padding(12).background(.white,in:RoundedRectangle(cornerRadius:12))
                        .overlay(RoundedRectangle(cornerRadius:12).stroke(outcome == choice ? IgnitionStyle.blue : Color.gray.opacity(0.25)))
                }.buttonStyle(.plain)
            }
            Text("Where will you begin next?").font(.subheadline.bold())
            TextField("Optional next step",text:$nextStep).textFieldStyle(.roundedBorder)
            PrimaryPill(text: outcome == .finished ? "Finish session" : "Save my place") {
                Task { await model.record(outcome:outcome,nextStep:nextStep) }
            }
            Button("Skip for now") { Task { await model.record(outcome:nil,nextStep:nil) } }
                .frame(maxWidth:.infinity).font(.caption)
            Spacer()
        }
        .padding(22)
        .background(Color(red:0.92,green:0.95,blue:1))
        .onAppear { nextStep = model.lastEnded?.nextStep ?? "" }
        .interactiveDismissDisabled(true)
    }
}
