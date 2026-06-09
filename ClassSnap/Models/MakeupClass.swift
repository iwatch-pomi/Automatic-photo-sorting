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

    var startDisplay: String { TimeFormat.hm(startSeconds) }
    var endDisplay: String   { TimeFormat.hm(endSeconds) }
    var dateDisplay: String  { AppDateFormatters.mdEJP.string(from: date) }

    var isPast: Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}
