import Foundation
@main struct JourneyMechanicsStressTest {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let dense = (0..<100).map { i in JourneyStopTime(id: UUID(), date: now.addingTimeInterval(Double(i * 120))) }
        for scale in JourneyScale.allCases {
            let clusters = JourneyGeometry.cluster(dense, scale: scale)
            precondition(clusters.flatMap(\.ids).count == dense.count)
            precondition(Set(clusters.flatMap(\.ids)).count == dense.count)
            precondition(clusters.count < dense.count)
            precondition(zip(clusters, clusters.dropFirst()).allSatisfy { $0.time <= $1.time })
            let end = now.addingTimeInterval(12 * 3600)
            precondition(JourneyGeometry.worldY(for: now, dayEnd: end, pointsPerHour: scale.pointsPerHour) > JourneyGeometry.worldY(for: end, dayEnd: end, pointsPerHour: scale.pointsPerHour))
            precondition(JourneyGeometry.isVisible(now, relativeTo: now, scale: scale))
            let follow = JourneyGeometry.camera(nowWorldY: 800, viewHeight: 700, worldHeight: 1600)
            precondition(follow <= 0 && follow >= -900)
        }
        let many = (0..<4000).map { i in JourneyStopTime(id: UUID(), date: now.addingTimeInterval(Double(i * 55))) }
        precondition(JourneyGeometry.cluster(many, scale: .balanced).flatMap(\.ids).count == many.count)
        // Regression: consecutive 40-minute gaps must never chain into a
        // single 2h40m cluster at balanced zoom.
        let chain = (0..<5).map { i in JourneyStopTime(id: UUID(), date: now.addingTimeInterval(Double(i * 2400))) }
        let chained = JourneyGeometry.cluster(chain, scale: .balanced)
        precondition(chained.count > 1, "Clustering must not chain arbitrarily distant events")
        for scale in JourneyScale.allCases {
            for group in JourneyGeometry.cluster(dense, scale: scale) {
                let times = dense.filter { group.ids.contains($0.id) }.map(\.date)
                if let first = times.min(), let last = times.max() {
                    precondition(last.timeIntervalSince(first) <= scale.minimumSeparationMinutes * 60 + 0.001,
                                 "Cluster span cannot exceed the visual window")
                }
            }
        }
        precondition(JourneyGeometry.apparentScale(hoursFromNow: 1) > JourneyGeometry.apparentScale(hoursFromNow: 9))
        print("PASS: Journey geometry, bounded grouping, 4,000 dense events, no lost IDs")
    }
}
