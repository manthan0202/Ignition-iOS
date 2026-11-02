import Foundation

@main
struct JourneyWorldMotionTests {
    static func main() {
        var checks = 0
        func verify(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        let epoch = Date(timeIntervalSince1970: 1_799_997_000)
        let viewports = [540.0, 700.0, 852.0, 1100.0]
        let drags = [-650.0, -240.0, -98.0, 0, 82.0, 170.0, 580.0]
        for viewport in viewports {
            let tile = JourneyWorldGeometry.tileHeight(viewportHeight: viewport)
            verify(tile >= viewport, "texture tiles must cover the visible screen")
            let sceneAtNow = JourneyScale.allCases.map {
            JourneyWorldGeometry.scenePhase(center: epoch, now: epoch,
                viewportHeight: viewport, pointsPerHour: $0.pointsPerHour)
        }
        verify(sceneAtNow.allSatisfy { abs($0 - sceneAtNow[0]) < 0.000001 },
               "zooming at Now must not teleport the background")
        for scale in JourneyScale.allCases {
                for hour in -48...48 {
                    let center = epoch.addingTimeInterval(TimeInterval(hour * 3600))
                    let base = JourneyWorldGeometry.scenePhase(center: center, now: epoch,
                        viewportHeight: viewport, pointsPerHour: scale.pointsPerHour)
                    for drag in drags {
                        let shifted = JourneyWorldGeometry.scenePhase(center: center, now: epoch,
                            viewportHeight: viewport, pointsPerHour: scale.pointsPerHour,
                            drag: drag)
                        let expected = JourneyWorldGeometry.positiveRemainder(
                            base + drag, modulus: tile)
                        verify(abs(shifted - expected) < 0.00001,
                            "background must follow a finger at exactly 1:1 speed")

                        let event = center.addingTimeInterval(40 * 60)
                        let pinBase = JourneyViewportGeometry.screenY(for: event,
                            centeredAt: center, viewportHeight: viewport,
                            pointsPerHour: scale.pointsPerHour)
                        let before = JourneyWorldGeometry.textureProgress(
                            screenY: pinBase, phase: base, tileHeight: tile)
                        let after = JourneyWorldGeometry.textureProgress(
                            screenY: pinBase + drag, phase: shifted, tileHeight: tile)
                        verify(abs(before - after) < 0.00001,
                            "pin must stay fixed against its background during drag")

                        let movedCenter = JourneyViewportGeometry.centerAfterDrag(center,
                            translationPoints: drag, pointsPerHour: scale.pointsPerHour)
                        let committed = JourneyWorldGeometry.scenePhase(center: movedCenter, now: epoch,
                            viewportHeight: viewport, pointsPerHour: scale.pointsPerHour)
                        verify(abs(committed - shifted) < 0.00001,
                            "ending pan must not make the scenery snap backward")
                        let pinAfterCommit = JourneyViewportGeometry.screenY(for: event,
                            centeredAt: movedCenter, viewportHeight: viewport,
                            pointsPerHour: scale.pointsPerHour)
                        verify(abs(pinAfterCommit - (pinBase + drag)) < 0.00001,
                            "ending pan must not make an event dot snap backward")

                        let phase = shifted
                        let tops = (-1...1).map {
                            JourneyWorldGeometry.tileTop(phase: phase,
                                tileHeight: tile, tileIndex: $0)
                        }
                        verify(tops[0] <= 0 && tops[2] + tile >= viewport,
                            "3 repeating image tiles must cover viewport at every pan position")
                    }
                }
            }
        }
        print("PASS: \(checks) world-motion assertions: scenery/pins unified, pan commitment, zoom scales, tile coverage, midnight and 96-hour exploration")
    }
}
