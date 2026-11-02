import SwiftUI
import UIKit

// Decode scene textures once per process instead of resolving them on every
// geometry or time change. The source still needs clean replacement artwork
// for a genuinely high-resolution final visual.
private enum JourneyTextures {
    static let scene = UIImage(named: "JourneyScenery")
}

/// The Living Day is a viewport, NOT a 72-hour-tall SwiftUI view.
/// Its images, time markers, and gestures all use coordinates in this viewport.
/// The underlying source timestamps remain immutable during camera movement.
struct LivingLandscape: View {
    let tasks: [WorkItem]
    let blocks: [FocusBlock]
    let sessions: [FocusSession]
    let selected: UUID?
    let selectedBlockID: UUID?
    let choose: (UUID) -> Void
    let chooseBlock: (UUID) -> Void

    @State private var zoom: JourneyScale = .balanced
    // Nil means follow the actual present. Otherwise this Date is the fixed
    // time at the center of the camera, so the scene cannot jump on minute ticks.
    @State private var exploredAt: Date?
    @GestureState private var verticalDrag: CGFloat = 0
    @State private var expandedStops: [Stop] = []
    @State private var showingCluster = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum StopKind { case task, block }
    private struct Stop: Identifiable {
        let id: UUID
        let date: Date
        let title: String
        let subtitle: String
        let tint: Color
        let kind: StopKind
    }

    private func clamp(_ x: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
        min(max(low, x), high)
    }

    /// Time always moves in the same direction: future above, past below.
    /// Never place UI into a huge offscreen canvas or offset the entire canvas.
    private func screenY(for date: Date, centeredAt center: Date,
                         viewportHeight: CGFloat, pph: CGFloat) -> CGFloat {
        CGFloat(JourneyViewportGeometry.screenY(for: date, centeredAt: center,
               viewportHeight: Double(viewportHeight), pointsPerHour: Double(pph)))
    }

    /// Marker positions are sampled in SCENE coordinates, not screen coordinates.
    /// Without this, the image could scroll while its dots skated across it.
    private func routeX(at screenY: CGFloat, scenePhase: CGFloat,
                        tileHeight: CGFloat, width: CGFloat) -> CGFloat {
        let t = CGFloat(JourneyWorldGeometry.textureProgress(
            screenY: Double(screenY), phase: Double(scenePhase),
            tileHeight: Double(tileHeight)))
        // These are approximate points along the approved winding river.
        // The first and last x match so texture transitions do not jump.
        let anchors: [(CGFloat, CGFloat)] = [
            (0, 0.51), (0.12, 0.64), (0.25, 0.60), (0.37, 0.70),
            (0.51, 0.56), (0.64, 0.73), (0.76, 0.56),
            (0.88, 0.40), (1, 0.51)
        ]
        for idx in 0..<(anchors.count - 1) {
            let a = anchors[idx]
            let b = anchors[idx + 1]
            if t <= b.0 {
                let fraction = (t - a.0) / max(0.0001, b.0 - a.0)
                let eased = fraction * fraction * (3 - 2 * fraction)
                return width * (a.1 + (b.1 - a.1) * eased)
            }
        }
        return width * anchors[0].1
    }

    private func nearbyStops(center: Date, scale: JourneyScale) -> [Stop] {
        let from = center.addingTimeInterval(-max(24, scale.pastHours) * 3600)
        let until = center.addingTimeInterval(max(24, scale.futureHours) * 3600)
        let relevantBlocks = blocks.filter { $0.start >= from && $0.start <= until }
        let contained = Set(relevantBlocks.flatMap(\.taskIDs))
        let blockStops = relevantBlocks.map { block in
            Stop(id: block.id, date: block.start, title: block.title,
                 subtitle: "\(block.start.formatted(date: .omitted, time: .shortened)) · \(block.taskIDs.count) tasks",
                 tint: IgnitionStyle.blue, kind: .block)
        }
        let taskStops: [Stop] = tasks.compactMap { item in
            guard let date = item.scheduledStart,
                  date >= from && date <= until,
                  !contained.contains(item.id) else { return nil }
            return Stop(id: item.id, date: date, title: item.title,
                        subtitle: date.formatted(date: .omitted, time: .shortened),
                        tint: item.tint.color, kind: .task)
        }
        return (blockStops + taskStops).sorted { a, b in
            a.date == b.date ? a.id.uuidString < b.id.uuidString : a.date < b.date
        }
    }

    private func select(_ stop: Stop) {
        switch stop.kind {
        case .task: choose(stop.id)
        case .block: chooseBlock(stop.id)
        }
        showingCluster = false
        IgnitionFeedback.selection()
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let now = context.date
                let center = exploredAt ?? now
                let height = geometry.size.height
                let width = geometry.size.width
                let pph = CGFloat(zoom.pointsPerHour)
                let shiftingScene = clamp(verticalDrag, -height, height)
                let tileHeight = CGFloat(JourneyWorldGeometry.tileHeight(
                    viewportHeight: Double(height)))
                let scenePhase = CGFloat(JourneyWorldGeometry.scenePhase(
                    center: center, now: now, viewportHeight: Double(height),
                    pointsPerHour: Double(pph), drag: Double(shiftingScene)))
                let nowY = screenY(for: now, centeredAt: center,
                                   viewportHeight: height, pph: pph) + shiftingScene
                let exploring = exploredAt != nil
                let stops = nearbyStops(center: center, scale: zoom)
                let inViewport = stops.filter {
                    let y = screenY(for: $0.date, centeredAt: center,
                                    viewportHeight: height, pph: pph) + shiftingScene
                    return y >= 125 && y <= height - 16
                }
                let stopsByID = Dictionary(uniqueKeysWithValues: inViewport.map { ($0.id, $0) })
                let clusters = JourneyGeometry.cluster(inViewport.map {
                    JourneyStopTime(id: $0.id, date: $0.date)
                }, scale: zoom)
                let footprints = sessions.filter {
                    let y = screenY(for: $0.startedAt, centeredAt: center,
                                    viewportHeight: height, pph: pph) + shiftingScene
                    return y > 125 && y < height - 12
                }

                ZStack(alignment: .topLeading) {
                    // Scenery is deliberately bounded to the VISIBLE frame.
                    // No huge world-height frame, offset, or unbounded image render.
                    artwork(viewWidth: width, viewHeight: height,
                            tileHeight: tileHeight, phase: scenePhase)

                    ForEach(footprints) { session in
                        let y = screenY(for: session.startedAt, centeredAt: center,
                                        viewportHeight: height, pph: pph) + shiftingScene
                        let x = routeX(at: y, scenePhase: scenePhase,
                                       tileHeight: tileHeight, width: width)
                        Circle()
                            .fill(session.outcome == .finished ? Color.green :
                                  session.phase == .active ? IgnitionStyle.blue : .orange)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .position(x: x, y: y)
                            .allowsHitTesting(false)
                    }

                    ForEach(clusters) { cluster in
                        if let stop = stopsByID[cluster.ids[0]] {
                            let y = screenY(for: cluster.time, centeredAt: center,
                                            viewportHeight: height, pph: pph) + shiftingScene
                            let x = routeX(at: y, scenePhase: scenePhase,
                                       tileHeight: tileHeight, width: width)
                            let left = x > width * 0.52
                            let cardX = width * (left ? 0.25 : 0.75)
                            let isSelected = cluster.ids.contains {
                                $0 == selected || $0 == selectedBlockID
                            }
                            let depth = CGFloat(JourneyGeometry.apparentScale(
                                hoursFromNow: cluster.time.timeIntervalSince(now) / 3600))

                            Circle()
                                .fill(stop.tint)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                                .shadow(color: .black.opacity(0.2), radius: 4)
                                .position(x: x, y: y)
                                .allowsHitTesting(false)

                            Button {
                                if cluster.count == 1 { select(stop) }
                                else {
                                    IgnitionFeedback.selection()
                                    expandedStops = cluster.ids.compactMap { stopsByID[$0] }
                                    showingCluster = true
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    Circle().fill(stop.tint).frame(width: 9, height: 9)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(cluster.count == 1 ? stop.title : "\(cluster.count) nearby")
                                            .font(.system(size: 13, weight: .semibold))
                                            .lineLimit(1)
                                        Text(cluster.count == 1 ? stop.subtitle : "Tap to see events")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(IgnitionStyle.navy.opacity(0.7))
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(IgnitionStyle.navy)
                                .padding(.horizontal, 10)
                                .frame(width: min(174, width * 0.45), height: 53)
                                .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 15)
                                    .stroke(isSelected ? IgnitionStyle.blue : .clear, lineWidth: 2))
                                .shadow(color: IgnitionDesign.ink.opacity(0.13), radius: 9, y: 3)
                            }
                            .buttonStyle(.plain)
                            .scaleEffect(depth)
                            .position(x: cardX, y: y)
                            .zIndex(isSelected ? 2 : 1)
                        }
                    }

                    // The Now marker is independent of task availability.
                    // An empty day MUST still render this anchor.
                    if nowY >= -35 && nowY <= height + 35 {
                        HStack(spacing: 7) {
                            Circle().fill(IgnitionStyle.blue)
                                .frame(width: 13, height: 13)
                                .overlay(Circle().stroke(.white, lineWidth: 3))
                            Text("Now · \(now.formatted(date: .omitted, time: .shortened))")
                                .font(IgnitionDesign.metadata())
                        }
                        .foregroundStyle(IgnitionStyle.navy)
                        .padding(.horizontal, 12)
                        .frame(height: 41)
                        .background(.white, in: Capsule())
                        .shadow(color: .black.opacity(0.14), radius: 7, y: 2)
                        .position(x: clamp(routeX(at: nowY, scenePhase: scenePhase,
                                                  tileHeight: tileHeight, width: width),
                                           min(100, width / 2), max(width - 100, width / 2)),
                                  y: nowY)
                        .zIndex(4)
                    }

                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Button {
                                IgnitionFeedback.selection()
                                withAnimation(reduceMotion ? nil : IgnitionMotion.quick) {
                                    zoom = zoom.closer
                                    exploredAt = nil
                                }
                            } label: { Image(systemName: "plus.magnifyingglass") }
                                .disabled(zoom == .near)
                            Text(zoom.title).font(.caption2.bold()).frame(minWidth: 38)
                            Button {
                                IgnitionFeedback.selection()
                                withAnimation(reduceMotion ? nil : IgnitionMotion.quick) {
                                    zoom = zoom.wider
                                    exploredAt = nil
                                }
                            } label: { Image(systemName: "minus.magnifyingglass") }
                                .disabled(zoom == .day)
                        }
                        .font(.caption)
                        .foregroundStyle(IgnitionStyle.navy)
                        .padding(.horizontal, 11)
                        .frame(height: 35)
                        .background(.regularMaterial, in: Capsule())
                        if exploring {
                            Button {
                                IgnitionFeedback.selection()
                                withAnimation(reduceMotion ? nil : IgnitionMotion.settle) {
                                    exploredAt = nil
                                }
                            } label: {
                                Label("Back to Now", systemImage: "location.fill")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(IgnitionStyle.navy)
                            .padding(.horizontal, 12)
                            .frame(height: 35)
                            .background(Color.white.opacity(0.96), in: Capsule())
                        }
                    }
                    .position(x: width / 2, y: 145)
                    .zIndex(8)
                }
                .frame(width: width, height: height)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .updating($verticalDrag) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            let desired = JourneyViewportGeometry.centerAfterDrag(center,
                                translationPoints: Double(value.translation.height),
                                pointsPerHour: Double(pph))
                            // Bound exploration to the surrounding three days.
                            let low = now.addingTimeInterval(-24 * 3600)
                            let high = now.addingTimeInterval(48 * 3600)
                            let bounded = min(max(desired, low), high)
                            exploredAt = abs(bounded.timeIntervalSince(now)) < 180 ? nil : bounded
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture().onEnded { ratio in
                        guard ratio > 1.18 || ratio < 0.82 else { return }
                        IgnitionFeedback.selection()
                        withAnimation(reduceMotion ? nil : IgnitionMotion.quick) {
                            zoom = ratio > 1 ? zoom.closer : zoom.wider
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingCluster) {
            NavigationStack {
                List(expandedStops) { stop in
                    Button { select(stop) } label: {
                        HStack(spacing: 12) {
                            Circle().fill(stop.tint).frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stop.title).font(.headline)
                                Text(stop.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Nearby events")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingCluster = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.significantTimeChangeNotification)) { _ in
                exploredAt = nil
                showingCluster = false
            }
    }

    /// Three scene tiles are rendered only inside the current screen. They
    /// are translated by exactly the same camera delta as pins and footprints.
    /// This is a genuine moving illustrated world (with bounded memory), not
    /// the previous nearly static wallpaper using 0.10x drag and hard clamps.
    @ViewBuilder
    private func artwork(viewWidth: CGFloat, viewHeight: CGFloat,
                         tileHeight: CGFloat, phase: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(red: 0.92, green: 0.96, blue: 0.99),
                         Color(red: 0.76, green: 0.88, blue: 0.84)],
                startPoint: .top, endPoint: .bottom
            )
            if let scene = JourneyTextures.scene {
                // Exactly one time transform. Each tile is placed at a world
                // coordinate, then projected into this bounded viewport.
                // No separate foreground motion that leaves pins behind.
                ForEach(-1...1, id: \.self) { tileIndex in
                    Image(uiImage: scene)
                        .resizable()
                        .scaledToFill()
                        .frame(width: viewWidth, height: tileHeight)
                        .clipped()
                        .position(
                            x: viewWidth / 2,
                            y: CGFloat(JourneyWorldGeometry.tileTop(
                                phase: Double(phase),
                                tileHeight: Double(tileHeight),
                                tileIndex: tileIndex)) + tileHeight / 2
                        )
                }
            } else {
                // If the asset is missing, keep a visible moving route and
                // time markers instead of showing an empty blue screen.
                ForEach(-1...1, id: \.self) { tileIndex in
                    Path { path in
                        let top = CGFloat(JourneyWorldGeometry.tileTop(
                            phase: Double(phase),
                            tileHeight: Double(tileHeight),
                            tileIndex: tileIndex))
                        path.move(to: CGPoint(x: viewWidth * 0.51, y: top))
                        path.addCurve(
                            to: CGPoint(x: viewWidth * 0.51, y: top + tileHeight),
                            control1: CGPoint(x: viewWidth * 0.94,
                                              y: top + tileHeight * 0.34),
                            control2: CGPoint(x: viewWidth * 0.12,
                                              y: top + tileHeight * 0.70)
                        )
                    }
                    .stroke(Color.cyan.opacity(0.75),
                            style: StrokeStyle(lineWidth: 22, lineCap: .round))
                }
            }
            // A subtle overlay preserves contrast; it does not move apart from
            // the world or introduce extra, mismatched parallax coordinates.
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.10), location: 0),
                    .init(color: .clear, location: 0.48),
                    .init(color: IgnitionDesign.ink.opacity(0.08), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
        .frame(width: viewWidth, height: viewHeight)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}
