import Foundation

@main
struct JourneyViewportRegressionTest {
    static func main() {
        var assertions = 0
        func require(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            assertions += 1
        }
        let anchor = Date(timeIntervalSince1970: 1_800_000_000)
        let h = 700.0
        for scale in JourneyScale.allCases {
            let pph = scale.pointsPerHour
            for minute in 0..<240 {
                let now = anchor.addingTimeInterval(Double(minute) * 60)
                let y = JourneyViewportGeometry.screenY(for: now, centeredAt: now,
                                                          viewportHeight: h, pointsPerHour: pph)
                require(abs(y - h * 0.62) < 0.0001, "Now must remain visible with no events")
            }
            let future = anchor.addingTimeInterval(3600)
            let past = anchor.addingTimeInterval(-3600)
            require(JourneyViewportGeometry.screenY(for: future, centeredAt: anchor,
                        viewportHeight: h, pointsPerHour: pph) < h * 0.62,
                    "Future events must be above Now")
            require(JourneyViewportGeometry.screenY(for: past, centeredAt: anchor,
                        viewportHeight: h, pointsPerHour: pph) > h * 0.62,
                    "Past events must be below Now")
            let displaced = JourneyViewportGeometry.centerAfterDrag(anchor,
                                    translationPoints: 100, pointsPerHour: pph)
            let movedY = JourneyViewportGeometry.screenY(for: anchor, centeredAt: displaced,
                                                          viewportHeight: h, pointsPerHour: pph)
            require(abs(movedY - (h * 0.62 + 100)) < 0.0001,
                    "Dragging the scene down must shift the current marker down")
            let centerPastMidnight = anchor.addingTimeInterval(24 * 3600)
            let midnightY = JourneyViewportGeometry.screenY(for: centerPastMidnight,
                         centeredAt: centerPastMidnight, viewportHeight: h, pointsPerHour: pph)
            require(abs(midnightY - h * 0.62) < 0.0001,
                    "Crossing midnight must not move the centered Now marker")
        }
        print("PASS: \(assertions) Journey viewport assertions: empty day, future/past, drag, midnight, zoom")
    }
}
