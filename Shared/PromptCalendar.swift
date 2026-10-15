import Foundation

/// The day's prompt and the clock time it opens.
///
/// Both phones derive this from the invite code and the calendar day, so the
/// pair doesn't need a server just to agree on the prompt. The hash is FNV-1a
/// rather than `Hasher`, which is salted differently in every process.
enum PromptCalendar {
    struct Schedule: Equatable {
        var dayKey: String
        var prompt: String
        var opensAt: Date
        var onTimeUntil: Date
        var closesAt: Date
        var timeZone: TimeZone
    }

    /// Minutes after 8:00, covering 8:00 through 21:29.
    static let windowMinutes = 13 * 60 + 30
    static let onTimeLengthMinutes = 10

    static let prompts: [String] = [
        "Show the view from where you are.",
        "What are you doing right this second?",
        "Something within arm's reach.",
        "The sky where you are.",
        "Your current drink or snack.",
        "A corner of the room you're in.",
        "What your hands are up to.",
        "The way outside looks right now.",
        "Your shoes and the ground.",
        "Whoever or whatever is keeping you company.",
        "The mess you haven't dealt with.",
        "A color that's near you.",
        "What's on the table.",
        "The light in the room.",
        "Something you just used.",
        "Out the nearest window.",
        "A detail you'd usually walk past.",
        "Proof you're awake.",
        "What dinner might become.",
        "The seat you chose.",
        "Something soft.",
        "Where you'll be in an hour.",
        "The bag you carried today.",
        "A plant, or the lack of one.",
        "The most ordinary thing in front of you.",
        "What you wore today.",
        "A tool of your day.",
        "Something that can wait until tomorrow.",
        "Your kind of weather.",
        "The page, tab, or paper you're on.",
        "A shadow.",
        "The last thing you opened.",
        "Where you set your keys.",
        "Something red.",
        "The quietest thing you can see.",
        "A bite, a sip, or an empty plate.",
        "The chair, the bench, or the floor.",
        "Hold up what you were just holding.",
        "What \"right now\" looks like.",
        "The path you took to get here."
    ]

    static func dayKey(for date: Date, timeZone: TimeZone) -> String {
        var calendar = gregorian(timeZone)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func schedule(code: String, now: Date, timeZone: TimeZone) -> Schedule {
        schedule(code: code, dayKey: dayKey(for: now, timeZone: timeZone), timeZone: timeZone)
    }

    static func schedule(code: String, dayKey: String, timeZone: TimeZone) -> Schedule {
        let calendar = gregorian(timeZone)
        let promptIndex = Int(stableHash("prompt|\(code)|\(dayKey)") % UInt64(prompts.count))
        let minuteOffset = Int(stableHash("time|\(code)|\(dayKey)") % UInt64(windowMinutes))
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }

        var start = DateComponents()
        start.calendar = calendar
        start.timeZone = timeZone
        if parts.count == 3 {
            start.year = parts[0]
            start.month = parts[1]
            start.day = parts[2]
        }
        start.hour = 8
        start.minute = 0
        start.second = 0

        let eight = calendar.date(from: start) ?? Date()
        let opens = calendar.date(byAdding: .minute, value: minuteOffset, to: eight) ?? eight
        let onTimeUntil = calendar.date(byAdding: .minute, value: onTimeLengthMinutes, to: opens) ?? opens

        var end = start
        end.hour = 23
        end.minute = 59
        end.second = 59
        let closes = calendar.date(from: end) ?? onTimeUntil

        return Schedule(
            dayKey: dayKey,
            prompt: prompts[promptIndex],
            opensAt: opens,
            onTimeUntil: onTimeUntil,
            closesAt: closes,
            timeZone: timeZone
        )
    }

    static func dayKeys(from start: Date, through end: Date, timeZone: TimeZone) -> [String] {
        let calendar = gregorian(timeZone)
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        var keys: [String] = []
        while cursor <= last && keys.count < 400 {
            keys.append(dayKey(for: cursor, timeZone: timeZone))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return keys.reversed()
    }

    static func date(for dayKey: String, timeZone: TimeZone) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 12
        return gregorian(timeZone).date(from: components)
    }

    /// FNV-1a 64-bit. Stable across launches, phones, and Swift versions.
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func gregorian(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
