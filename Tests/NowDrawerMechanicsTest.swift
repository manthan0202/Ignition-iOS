import Foundation

@main
struct NowDrawerMechanicsTest {
    static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let compact = 220.0
        let full = 645.0
        check(NowDrawerMath.visibleHeight(rest: compact, drag: 0,
                                          compact: compact, full: full) == compact,
              "compact height stable")
        check(NowDrawerMath.visibleHeight(rest: compact, drag: -80,
                                          compact: compact, full: full) == 300,
              "drawer follows upward drag without relaying out the content")
        check(NowDrawerMath.visibleHeight(rest: full, drag: 65,
                                          compact: compact, full: full) == full - 65,
              "drawer follows downward drag")
        check(NowDrawerMath.visibleHeight(rest: compact, drag: 9999,
                                          compact: compact, full: full) == compact,
              "lower clamp")
        check(NowDrawerMath.visibleHeight(rest: compact, drag: -9999,
                                          compact: compact, full: full) == full,
              "upper clamp")
        check(NowDrawerMath.destination(at: .compact, translation: -100,
                     predictedTranslation: -120, compact: compact, full: full) == .open,
              "deliberate upward pull opens")
        check(NowDrawerMath.destination(at: .open, translation: 100,
                     predictedTranslation: 125, compact: compact, full: full) == .compact,
              "deliberate downward pull closes")
        check(NowDrawerMath.destination(at: .compact, translation: -5,
                     predictedTranslation: -1000, compact: compact, full: full) == .compact,
              "tiny accidental nudge does not launch drawer")
        check(NowDrawerMath.destination(at: .compact, translation: -22,
                     predictedTranslation: -220, compact: compact, full: full) == .open,
              "deliberate fast flick opens")
        check(NowDrawerMath.destination(at: .open, translation: 22,
                     predictedTranslation: 250, compact: compact, full: full) == .compact,
              "deliberate fast flick closes")
        check(NowDrawerMath.destination(at: .open, translation: -20,
                     predictedTranslation: -50, compact: compact, full: full) == .open,
              "upward scroll movement does not close drawer")
        for index in 0..<2500 {
            let translation = Double(index % 600) - 300
            let rest = index % 2 == 0 ? compact : full
            let height = NowDrawerMath.visibleHeight(rest: rest, drag: translation,
                                                     compact: compact, full: full)
            check(height >= compact && height <= full, "height in bounds")
            let stop = NowDrawerMath.destination(
                at: index % 2 == 0 ? .compact : .open,
                translation: translation,
                predictedTranslation: translation + (index % 3 == 0 ? 70 : -70),
                compact: compact, full: full)
            check(NowDrawerDetent.allCases.contains(stop), "valid detent")
        }
        print("PASS: \(checks) Now drawer geometry assertions")
    }
}
