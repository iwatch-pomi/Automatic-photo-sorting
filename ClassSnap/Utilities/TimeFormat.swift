import Foundation

/// Centralised time-of-day formatting and conversion utilities.
enum TimeFormat {
    /// "H:mm" — e.g. "9:00", "13:30"
    static func hm(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 3600, (seconds % 3600) / 60)
    }

    /// "HH:mm" — e.g. "09:00", "13:30"
    static func hmPadded(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 3600, (seconds % 3600) / 60)
    }
}

extension Calendar {
    /// Seconds elapsed since midnight for the hour+minute portion of `date`.
    func secondsFromMidnight(for date: Date) -> Int {
        let c = dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60
    }

    /// A Date on the same calendar day as `ref` positioned at `seconds` from midnight.
    func date(secondsFromMidnight seconds: Int, on ref: Date = Date()) -> Date {
        startOfDay(for: ref).addingTimeInterval(TimeInterval(seconds))
    }
}
