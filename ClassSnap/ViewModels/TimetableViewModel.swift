import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class TimetableViewModel {
    private var modelContext: ModelContext

    var schedules: [ClassSchedule] = []
    var errorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchSchedules()
    }

    func fetchSchedules() {
        let descriptor = FetchDescriptor<ClassSchedule>(
            sortBy: [SortDescriptor(\.startTimeSeconds)]
        )
        do {
            schedules = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "時間割の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func addSchedule(subjectName: String, professor: String, room: String,
                     daysOfWeek: [Int], startTimeSeconds: Int, endTimeSeconds: Int,
                     firstClassDate: Date? = nil,
                     breakStartSeconds: Int? = nil, breakEndSeconds: Int? = nil) {
        let schedule = ClassSchedule(
            subjectName: subjectName,
            professor: professor,
            room: room,
            daysOfWeek: daysOfWeek,
            startTimeSeconds: startTimeSeconds,
            endTimeSeconds: endTimeSeconds,
            firstClassDate: firstClassDate,
            breakStartSeconds: breakStartSeconds,
            breakEndSeconds: breakEndSeconds
        )
        modelContext.insert(schedule)
        try? modelContext.save()
        fetchSchedules()
    }

    func updateSchedule(_ schedule: ClassSchedule, subjectName: String, professor: String,
                        room: String, daysOfWeek: [Int],
                        startTimeSeconds: Int, endTimeSeconds: Int,
                        firstClassDate: Date? = nil,
                        breakStartSeconds: Int? = nil, breakEndSeconds: Int? = nil) {
        schedule.subjectName = subjectName
        schedule.professor = professor
        schedule.room = room
        schedule.daysOfWeek = daysOfWeek
        schedule.startTimeSeconds = startTimeSeconds
        schedule.endTimeSeconds = endTimeSeconds
        schedule.firstClassDate = firstClassDate
        schedule.breakStartSeconds = breakStartSeconds
        schedule.breakEndSeconds = breakEndSeconds
        try? modelContext.save()
        fetchSchedules()
    }

    func deleteSchedule(_ schedule: ClassSchedule) {
        modelContext.delete(schedule)
        try? modelContext.save()
        fetchSchedules()
    }

    /// 今日の授業を時間順で返す
    func todaySchedules(now: Date = Date()) -> [ClassSchedule] {
        let cal = Calendar(identifier: .gregorian)
        let weekday = cal.component(.weekday, from: now)
        let appDay = weekday - 1
        guard appDay >= 1 && appDay <= 5 else { return [] }
        return schedules.filter { $0.daysOfWeek.contains(appDay) }
    }

    /// 次に始まる授業（現在時刻以降）
    func nextClass(now: Date = Date()) -> ClassSchedule? {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.hour, .minute], from: now)
        let nowSec = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60
        return todaySchedules(now: now).first { $0.startTimeSeconds > nowSec }
    }

    /// 次の授業開始までの秒数
    func secondsUntilNextClass(now: Date = Date()) -> Int? {
        guard let next = nextClass(now: now) else { return nil }
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.hour, .minute, .second], from: now)
        let nowSec = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)
        let diff = next.startTimeSeconds - nowSec
        return diff > 0 ? diff : nil
    }
}
