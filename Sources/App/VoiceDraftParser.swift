import Foundation

/// Speech recognition and parsing are deliberately separate. Drafts are never
/// persisted until the user confirms the parsed title, date, time and type.
struct VoiceDraft: Identifiable, Equatable {
    enum Kind: String, CaseIterable { case task = "Task", block = "Focus block", event = "Calendar event" }
    var id = UUID()
    var sourceText: String
    var title: String
    var kind: Kind
    var start: Date?
    var durationMinutes: Int
    var needsTimeConfirmation: Bool
}

enum VoiceDraftParser {
    private static func match(_ pattern: String, in text: String) -> (String, NSRange)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let hit = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(hit.range, in: text) else { return nil }
        return (String(text[range]), hit.range)
    }
    private static func replaceMatch(_ match: NSRange, in text: String, with replacement: String = " ") -> String {
        guard let range = Range(match, in: text) else { return text }
        var copy = text
        copy.replaceSubrange(range, with: replacement)
        return copy
    }
    static func parse(_ raw: String, now: Date = Date(), calendar: Calendar = .current) -> VoiceDraft {
        let source = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var title = source
        let lower = source.lowercased()
        // Distinguish scheduling a FOCUS BLOCK from placing a calendar event.
        // Natural speech such as "Can you add cardiology to my schedule tomorrow at 5"
        // is a calendar request, not a task titled "Can you add...".
        let hasCalendarDestination = lower.range(
            of: "\\b(?:to|on|in)\\s+(?:(?:my|the)\\s+)?(?:calendar|schedule)\\b",
            options: .regularExpression
        ) != nil
        let isExplicitEvent = lower.hasPrefix("create event") || lower.hasPrefix("add event") ||
            lower.hasPrefix("calendar event") || lower.hasPrefix("new event") || hasCalendarDestination
        let kind: VoiceDraft.Kind = isExplicitEvent ? .event :
            (lower.hasPrefix("schedule") || lower.hasPrefix("focus block") || lower.hasPrefix("block ") ? .block : .task)
        title = title.replacingOccurrences(
            of: "^(?:(?:hey|hi)\\s+)?(?:(?:can|could|would)\\s+you\\s+|please\\s+)?(?:add|put|create|schedule)\\s+",
            with: "", options: [.regularExpression, .caseInsensitive]
        )
        title = title.replacingOccurrences(
            of: "^(?:task|event|calendar event|focus block)\\s+",
            with: "", options: [.regularExpression, .caseInsensitive]
        )
        title = title.replacingOccurrences(
            of: "^(?:remind me to|focus block|block)\\s+",
            with: "", options: [.regularExpression, .caseInsensitive]
        )
        if hasCalendarDestination {
            title = title.replacingOccurrences(
                of: "\\b(?:to|on|in)\\s+(?:(?:my|the)\\s+)?(?:calendar|schedule)\\b",
                with: " ", options: [.regularExpression, .caseInsensitive]
            )
        }
        // Speech often returns "seven pm" rather than "7 PM".
        // Normalize ONLY a time following "at", never duration phrases.
        let words = ["one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
                     "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10",
                     "eleven": "11", "twelve": "12"]
        for (word, number) in words {
            title = title.replacingOccurrences(of: "\\bat\\s+" + word + "\\b", with: "at " + number,
                                               options: [.regularExpression, .caseInsensitive])
        }

        var duration = 30
        if let (text, range) = match("\\bfor\\s+(\\d{1,3}|one|two|half)\\s*(hour|hours|hr|hrs|minute|minutes|min|mins)\\b", in: title) {
            let token = text.lowercased()
            let minutes = token.contains("half") ? 30 : token.contains("one") ? 1 : token.contains("two") ? 2 :
                (Int(token.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 30)
            duration = token.contains("hour") || token.contains("hr") ? minutes * 60 : minutes
            title = replaceMatch(range, in: title)
        }
        var date: Date? = nil
        var needsTimeConfirmation = false
        let dayStart = calendar.startOfDay(for: now)
        if let (_, range) = match("\\btomorrow\\b", in: title) {
            date = calendar.date(byAdding: .day, value: 1, to: dayStart)
            title = replaceMatch(range, in: title)
        } else if let (_, range) = match("\\btoday\\b", in: title) {
            date = dayStart
            title = replaceMatch(range, in: title)
        }
        if let (timeText, range) = match("\\b(?:at\\s+)?(?:1[0-2]|0?[1-9])(?:[:.]([0-5][0-9]))?\\s*(?:a\\.?m\\.?|p\\.?m\\.?)\\b", in: title) {
            let normalized = timeText.lowercased().replacingOccurrences(of: " ", with: "")
            let isPM = normalized.contains("p")
            let nums = normalized.replacingOccurrences(of: "[^0-9:]", with: "", options: .regularExpression)
            let parts = nums.components(separatedBy: ":")
            var hour = Int(parts.first ?? "") ?? 9
            let minute = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
            hour = hour % 12 + (isPM ? 12 : 0)
            if date == nil { date = dayStart }
            date = date.flatMap { calendar.date(bySettingHour: hour, minute: minute, second: 0, of: $0) }
            title = replaceMatch(range, in: title)
        } else if let (hitText, range) = match("\\bat\\s+(\\d{1,2})\\b", in: title) {
            // AM/PM was not spoken: the draft stays flagged for confirmation. But it must still carry the hour
            // the person SAID. It used to drop it and default to 12:00 AM. Everyday heuristic for the pre-fill
            // only: 1-6 afternoon, 7-11 morning, 12 noon, 13-23 as a 24-hour time.
            needsTimeConfirmation = true
            let spoken = Int(hitText.filter { $0.isNumber }) ?? 0
            let hour24 = (1...6).contains(spoken) ? spoken + 12 : spoken
            if date == nil { date = dayStart }
            if (1...23).contains(spoken) {
                date = date.flatMap { calendar.date(bySettingHour: hour24, minute: 0, second: 0, of: $0) }
            }
            title = replaceMatch(range, in: title)
        }
        // "for tomorrow 5 PM" should not leave the preposition "for" in the title.
        title = title.replacingOccurrences(
            of: "\\b(?:for|on|at)\\s*$", with: "", options: [.regularExpression, .caseInsensitive]
        )
        title = title.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        return VoiceDraft(sourceText: source, title: title.isEmpty ? source : title,
                          kind: kind, start: date,
                          durationMinutes: min(480, max(5, duration)),
                          needsTimeConfirmation: needsTimeConfirmation)
    }
}
