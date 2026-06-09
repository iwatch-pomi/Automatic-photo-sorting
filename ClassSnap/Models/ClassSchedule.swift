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
    // 各曜日の開始・終了秒数（daysOfWeek と同じインデックスで対応）
    var startTimesSeconds: [Int]
    var endTimesSeconds: [Int]
    // 初回授業日（nil の場合は第N回を計算しない）
    var firstClassDate: Date?
    // 昼休み除外（nil の場合は除外しない）
    var breakStartSeconds: Int?
    var breakEndSeconds: Int?
    var termIDs: [UUID]
    // この授業の写真をアプリ内に保存するか（写真アプリから削除しても残る）
    var savePhotosEnabled: Bool = false

    // 代表表示（最初の曜日の時間）
    var startTimeDisplay: String { TimeFormat.hmPadded(startTimesSeconds.first ?? 0) }
    var endTimeDisplay: String   { TimeFormat.hmPadded(endTimesSeconds.first ?? 0) }

    var hasUniformTime: Bool {
        guard startTimesSeconds.count > 1 else { return true }
        return startTimesSeconds.dropFirst().allSatisfy { $0 == startTimesSeconds[0] }
            && endTimesSeconds.dropFirst().allSatisfy { $0 == endTimesSeconds[0] }
    }

    var daysDisplay: String {
        daysOfWeek.sorted().map { WeekdayHelper.shortName(for: $0) }.joined(separator: "・")
    }

    func startTime(for day: Int) -> Int {
        guard let idx = daysOfWeek.firstIndex(of: day) else { return startTimesSeconds.first ?? 0 }
        return idx < startTimesSeconds.count ? startTimesSeconds[idx] : (startTimesSeconds.first ?? 0)
    }

    func endTime(for day: Int) -> Int {
        guard let idx = daysOfWeek.firstIndex(of: day) else { return endTimesSeconds.first ?? 0 }
        return idx < endTimesSeconds.count ? endTimesSeconds[idx] : (endTimesSeconds.first ?? 0)
    }

    init(subjectName: String, professor: String = "", room: String = "",
         daysOfWeek: [Int], startTimesSeconds: [Int], endTimesSeconds: [Int],
         firstClassDate: Date? = nil,
         breakStartSeconds: Int? = nil, breakEndSeconds: Int? = nil,
         termIDs: [UUID] = [], savePhotosEnabled: Bool = false) {
        self.id = UUID()
        self.subjectName = subjectName
        self.professor = professor
        self.room = room
        self.daysOfWeek = daysOfWeek
        self.startTimesSeconds = startTimesSeconds
        self.endTimesSeconds = endTimesSeconds
        self.firstClassDate = firstClassDate
        self.breakStartSeconds = breakStartSeconds
        self.breakEndSeconds = breakEndSeconds
        self.termIDs = termIDs
        self.savePhotosEnabled = savePhotosEnabled
    }
}
