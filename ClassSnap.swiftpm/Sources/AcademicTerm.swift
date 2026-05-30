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
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var displayRange: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M月d日"
        return "\(fmt.string(from: startDate)) 〜 \(fmt.string(from: endDate))"
    }

    func contains(date: Date) -> Bool {
        return date >= startDate && date <= endDate
    }

    init(name: String, startDate: Date, endDate: Date, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.sortOrder = sortOrder
    }
}
