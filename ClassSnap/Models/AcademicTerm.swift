import Foundation
import SwiftData

@Model
final class AcademicTerm: Identifiable {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var sortOrder: Int

    var isActive: Bool {
        contains(date: Date())
    }

    var displayRange: String {
        let f = AppDateFormatters.mdJP
        return "\(f.string(from: startDate)) 〜 \(f.string(from: endDate))"
    }

    /// 開始日の0:00〜終了日の23:59:59 を含む（時刻成分に依存しない日単位の判定）。
    /// endDate が 0:00 で保存されていても終了日当日の写真がマッチするようにする。
    func contains(date: Date) -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        guard let endExclusive = cal.date(byAdding: .day, value: 1,
                                          to: cal.startOfDay(for: endDate)) else {
            return date >= start && date <= endDate
        }
        return date >= start && date < endExclusive
    }

    init(name: String, startDate: Date, endDate: Date, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.sortOrder = sortOrder
    }
}
