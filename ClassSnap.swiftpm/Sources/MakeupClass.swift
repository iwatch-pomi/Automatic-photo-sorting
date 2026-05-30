import Foundation
import SwiftData

@Model final class MakeupClass: Identifiable {
    var id: UUID
    var scheduleID: UUID
    var date: Date
    var startSeconds: Int
    var endSeconds: Int
    var room: String
    var note: String

    init(scheduleID: UUID, date: Date, startSeconds: Int, endSeconds: Int,
         room: String = "", note: String = "") {
        self.id = UUID()
        self.scheduleID = scheduleID
        self.date = date
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.room = room
        self.note = note
    }

    var startDisplay: String {
        String(format: "%d:%02d", startSeconds / 3600, (startSeconds % 3600) / 60)
    }

    var endDisplay: String {
        String(format: "%d:%02d", endSeconds / 3600, (endSeconds % 3600) / 60)
    }

    var dateDisplay: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M月d日(E)"
        return fmt.string(from: date)
    }

    var isPast: Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}
