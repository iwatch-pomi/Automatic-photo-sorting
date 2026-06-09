import Foundation

/// Shared, reused DateFormatter instances for Japanese locale date strings.
/// Creating a DateFormatter is expensive; these static instances are allocated once.
enum AppDateFormatters {
    /// "M月d日" — e.g. "4月1日"
    static let mdJP: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日"
        return f
    }()

    /// "M月d日(E)" — e.g. "4月1日(月)"
    static let mdEJP: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日(E)"
        return f
    }()

    /// "yyyy年M月d日 HH:mm" — e.g. "2025年4月1日 09:00"
    static let ymdHmJP: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月d日 HH:mm"
        return f
    }()
}
