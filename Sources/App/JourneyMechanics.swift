import Foundation

/// Pure, testable time geometry shared by the Journey's pins, clusters, camera and footprints.
/// Dates are never stored as screen coordinates: changing zoom cannot change event times.
enum JourneyScale: Int, CaseIterable, Codable {
    case near, balanced, day
    var pointsPerHour: Double {
        switch self { case .near: return 135; case .balanced: return 88; case .day: return 48 }
    }
    var pastHours: Double {
        switch self { case .near: return 1.5; case .balanced: return 2.5; case .day: return 12 }
    }
    var futureHours: Double {
        switch self { case .near: return 3.5; case .balanced: return 7; case .day: return 24 }
    }
    var title: String {
        switch self { case .near: return "Near"; case .balanced: return "Hours"; case .day: return "Day" }
    }
    /// Cards are ~47pt high; projected distance determines clustering, not arbitrary gaps in clock time.
    var minimumSeparationMinutes: Double { 70 / pointsPerHour * 60 }
    var visibleWindow: TimeInterval { (pastHours + futureHours) * 3600 }
    var wider: JourneyScale { JourneyScale(rawValue: min(Self.day.rawValue, rawValue + 1)) ?? self }
    var closer: JourneyScale { JourneyScale(rawValue: max(Self.near.rawValue, rawValue - 1)) ?? self }
}

struct JourneyStopTime: Identifiable, Equatable {
    let id: UUID
    let date: Date
}

struct JourneyCluster: Identifiable, Equatable {
    let ids: [UUID]
    let time: Date
    var id: UUID { ids[0] }
    var count: Int { ids.count }
}

enum JourneyGeometry {
    static func worldY(for time: Date, dayEnd: Date, pointsPerHour: Double, topInset: Double = 120) -> Double {
        topInset + dayEnd.timeIntervalSince(time) / 3600 * pointsPerHour
    }
    static func camera(nowWorldY: Double, viewHeight: Double, worldHeight: Double,
                       fractionFromTop: Double = 0.64) -> Double {
        let lowerBound = min(0, viewHeight - worldHeight)
        return min(0, max(lowerBound, viewHeight * fractionFromTop - nowWorldY))
    }
    static func isVisible(_ date: Date, relativeTo now: Date, scale: JourneyScale) -> Bool {
        let hours = date.timeIntervalSince(now) / 3600
        return hours >= -scale.pastHours && hours <= scale.futureHours
    }
    /// Cluster by the total projected span from the *first* member.
    /// Do not single-link consecutive neighbors: 6:00/6:40/7:20 must
    /// never silently become one cluster covering several hours.
    /// The anchor is stable and ties sort by UUID to avoid shuffle on refresh.
    static func cluster(_ stops: [JourneyStopTime], scale: JourneyScale) -> [JourneyCluster] {
        let sorted = stops.sorted { a, b in
            a.date == b.date ? a.id.uuidString < b.id.uuidString : a.date < b.date
        }
        var groups: [[JourneyStopTime]] = []
        let maxSpan: TimeInterval = scale.minimumSeparationMinutes * 60
        for stop in sorted {
            if let index = groups.indices.last,
               let anchor = groups[index].first,
               stop.date.timeIntervalSince(anchor.date) <= maxSpan {
                groups[index].append(stop)
            } else {
                groups.append([stop])
            }
        }
        return groups.map { group in
            JourneyCluster(ids: group.map(\.id), time: group[group.count / 2].date)
        }
    }

    /// Depth affects only the artwork's apparent size and alpha; it does not
    /// affect world coordinates, which remain absolute timestamps.
    static func apparentScale(hoursFromNow: Double) -> Double {
        let forward = max(0, hoursFromNow)
        return max(0.72, 1 - forward * 0.055)
    }
}

/// Pure viewport math for Living Day. Keeping these calculations outside SwiftUI
/// makes empty-day visibility, panning, and midnight transitions testable.
enum JourneyViewportGeometry {
    static func screenY(for event: Date, centeredAt center: Date,
                        viewportHeight: Double, pointsPerHour: Double,
                        anchorFraction: Double = 0.62) -> Double {
        viewportHeight * anchorFraction -
            event.timeIntervalSince(center) / 3600 * pointsPerHour
    }

    static func centerAfterDrag(_ center: Date, translationPoints: Double,
                                pointsPerHour: Double) -> Date {
        center.addingTimeInterval(translationPoints / max(1, pointsPerHour) * 3600)
    }

    static func visible(_ coordinate: Double, height: Double,
                        topExclusion: Double = 125,
                        bottomExclusion: Double = 16) -> Bool {
        coordinate >= topExclusion && coordinate <= height - bottomExclusion
    }
}


// MARK: - Shared scene/camera geometry
/// A time-anchored scene, not a screen-fixed wallpaper. Every world element uses
/// the same camera translation. Keeping this Foundation-only lets us prove that
/// an event pin and its underlying scene move together during a pan.
///
/// Repeating the illustration is a deliberate bounded-rendering fallback until
/// the approved artwork is exported as a genuinely long, layered world texture.
/// Do not scale or offset the image with a different drag coefficient.
enum JourneyWorldGeometry {
    static func positiveRemainder(_ value: Double, modulus: Double) -> Double {
        let length = max(1, modulus)
        let remainder = value.truncatingRemainder(dividingBy: length)
        return remainder < 0 ? remainder + length : remainder
    }

    /// One scene tile is at least one full screen tall so three tiles always
    /// cover the visible viewport without building a multi-day SwiftUI view.
    static func tileHeight(viewportHeight: Double) -> Double {
        max(1, viewportHeight * 1.17)
    }

    /// The same signed translation in points is applied to the scenery and to
    /// every event/footprint/Now marker. Its periodic phase is only an internal
    /// texture address, NOT a different camera speed.
    static func scenePhase(center: Date, now: Date, viewportHeight: Double,
                           pointsPerHour: Double, drag: Double = 0) -> Double {
        let tile = tileHeight(viewportHeight: viewportHeight)
        let anchor = viewportHeight * 0.62
        // Base scenery progresses with the clock at a gentle fixed rate.
        // Changing zoom while following Now must NOT cause an arbitrary texture
        // jump from multiplying an epoch-sized timestamp by the zoom scale.
        let dailySceneTravel = now.timeIntervalSinceReferenceDate / 3600 * 60
        // Camera exploration has EXACTLY the same 1:1 panning translation as
        // every time marker, at the active zoom's points-per-hour scale.
        let cameraTravel = center.timeIntervalSince(now) / 3600 * pointsPerHour
        return positiveRemainder(anchor + dailySceneTravel + cameraTravel + drag,
                                 modulus: tile)
    }

    static func tileTop(phase: Double, tileHeight: Double, tileIndex: Int) -> Double {
        phase + Double(tileIndex) * tileHeight
    }

    /// Samples the same tile coordinate that the user sees behind a marker.
    /// Moving the camera never changes a pin's location relative to the artwork.
    static func textureProgress(screenY: Double, phase: Double,
                                tileHeight: Double) -> Double {
        positiveRemainder(screenY - phase, modulus: tileHeight) / max(1, tileHeight)
    }
}

// MARK: - Two-detent drawer. Pull from its entire 220pt action area.
// The user's actual drag is not artificially clipped; velocity only nudges
// the decision to open or close, never creates an intermediate trap.
enum NowDrawerDetent: Int, CaseIterable {
    case compact, open
}

enum NowDrawerMath {
    static func visibleHeight(rest: Double, drag: Double,
                              compact: Double, full: Double) -> Double {
        min(full, max(compact, rest - drag))
    }

    static func destination(at current: NowDrawerDetent,
                            translation: Double, predictedTranslation: Double,
                            compact: Double, full: Double) -> NowDrawerDetent {
        let distance = max(1, full - compact)
        let trigger = min(90, max(45, distance * 0.19))
        // A quick flick can settle a sheet without needing a long swipe,
        // but a tiny accidental nudge cannot launch it across the screen.
        let momentum = predictedTranslation - translation
        let flick = abs(translation) >= 12 && abs(momentum) > 72
        if current == .compact {
            return (translation < -trigger || (flick && momentum < -72)) ? .open : .compact
        }
        return (translation > trigger || (flick && momentum > 72)) ? .compact : .open
    }
}
