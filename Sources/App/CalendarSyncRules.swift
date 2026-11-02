import Foundation

/// Foundation-only rules shared by Apple/Google reconciliation and exercised
/// without the iOS SDK. No account token, calendar identifier, or user data is
/// embedded in the app binary.
enum CalendarSyncRules {
    static func stableGoogleEventID(_ id: UUID) -> String {
        "ig" + id.uuidString.lowercased().replacingOccurrences(of: "-", with: "")
    }

    static func protectsLocalEdit(_ state: String?) -> Bool {
        switch state ?? "" {
        case "pending", "failed", "deleting", "delete-failed", "conflicted": return true
        default: return false
        }
    }

    static func writableGoogleCalendar(_ role: String?) -> Bool {
        role == "owner" || role == "writer"
    }

    /// A remote cursor is safe to advance only after an atomic local write.
    static func mayCommitRemoteCursor(localDataPersisted: Bool) -> Bool {
        localDataPersisted
    }

    static func allDayDate(_ value: String, calendar: Calendar = .current) -> Date? {
        let components = value.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 3,
              let year = Int(components[0]), let month = Int(components[1]), let day = Int(components[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        guard let parsed = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 0)) else { return nil }
        let result = calendar.dateComponents([.year, .month, .day], from: parsed)
        return result.year == year && result.month == month && result.day == day ? parsed : nil
    }
}
