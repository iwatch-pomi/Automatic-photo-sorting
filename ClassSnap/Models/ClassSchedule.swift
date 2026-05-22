import Foundation
import SwiftData

@Model
final class ClassSchedule: Identifiable {
    var id: UUID
    var subjectName: String
    var professor: String
    var room: String
    // 1=月曜〜5=金曜（複数曜日対応）
    var daysOfWeek: [Int]
    // 深夜0時からの秒数（例: 9:30 → 34200）
    var startTimeSeconds: Int
    var endTimeSeconds: Int
    // 初回授業日（nil の場合は第N回を計算しない）
    var firstClassDate: Date?

    var startTimeDisplay: String { formatSeconds(startTimeSeconds) }
    var endTimeDisplay: String   { formatSeconds(endTimeSeconds) }

    var daysDisplay: String {
        daysOfWeek.sorted().map { WeekdayHelper.shortName(for: $0) }.joined(separator: "・")
    }

    private func formatSeconds(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 3600, (s % 3600) / 60)
    }

    init(subjectName: String, professor: String = "", room: String = "",
         daysOfWeek: [Int], startTimeSeconds: Int, endTimeSeconds: Int,
         firstClassDate: Date? = nil) {
        self.id = UUID()
        self.subjectName = subjectName
        self.professor = professor
        self.room = room
        self.daysOfWeek = daysOfWeek
        self.startTimeSeconds = startTimeSeconds
        self.endTimeSeconds = endTimeSeconds
        self.firstClassDate = firstClassDate
    }
}
