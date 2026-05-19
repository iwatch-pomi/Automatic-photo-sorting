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
            sortBy: [
                SortDescriptor(\.dayOfWeek),
                SortDescriptor(\.startTimeSeconds)
            ]
        )
        do {
            schedules = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "時間割の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func addSchedule(className: String, dayOfWeek: Int,
                     startTimeSeconds: Int, endTimeSeconds: Int) {
        let schedule = ClassSchedule(
            className: className,
            dayOfWeek: dayOfWeek,
            startTimeSeconds: startTimeSeconds,
            endTimeSeconds: endTimeSeconds
        )
        modelContext.insert(schedule)
        try? modelContext.save()
        fetchSchedules()
    }

    func deleteSchedule(_ schedule: ClassSchedule) {
        modelContext.delete(schedule)
        try? modelContext.save()
        fetchSchedules()
    }
}
