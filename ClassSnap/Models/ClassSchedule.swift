import Foundation
import SwiftData

@Model
final class ClassSchedule {
    var id: UUID
    var className: String
    // 1=月曜, 2=火曜, 3=水曜, 4=木曜, 5=金曜
    var dayOfWeek: Int
    // 深夜0時からの秒数（例: 9:30 AM → 34200）
    var startTimeSeconds: Int
    var endTimeSeconds: Int

    var startTimeComponents: DateComponents {
        DateComponents(hour: startTimeSeconds / 3600, minute: (startTimeSeconds % 3600) / 60)
    }

    var endTimeComponents: DateComponents {
        DateComponents(hour: endTimeSeconds / 3600, minute: (endTimeSeconds % 3600) / 60)
    }

    var startTimeDisplay: String {
        let h = startTimeSeconds / 3600
        let m = (startTimeSeconds % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }

    var endTimeDisplay: String {
        let h = endTimeSeconds / 3600
        let m = (endTimeSeconds % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }

    init(className: String, dayOfWeek: Int, startTimeSeconds: Int, endTimeSeconds: Int) {
        self.id = UUID()
        self.className = className
        self.dayOfWeek = dayOfWeek
        self.startTimeSeconds = startTimeSeconds
        self.endTimeSeconds = endTimeSeconds
    }
}
