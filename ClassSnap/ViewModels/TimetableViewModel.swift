import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class TimetableViewModel {
    private var modelContext: ModelContext

    var schedules: [ClassSchedule] = []
    var terms: [AcademicTerm] = []
    var selectedTermID: UUID? = nil
    var errorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchSchedules()
        fetchTerms()
    }

    // MARK: - Schedule CRUD

    func fetchSchedules() {
        let descriptor = FetchDescriptor<ClassSchedule>()
        do {
            schedules = try modelContext.fetch(descriptor)
                .sorted { ($0.startTimesSeconds.first ?? 0) < ($1.startTimesSeconds.first ?? 0) }
        } catch {
            errorMessage = "時間割の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func addSchedule(subjectName: String, professor: String, room: String,
                     daysOfWeek: [Int], startTimesSeconds: [Int], endTimesSeconds: [Int],
                     firstClassDate: Date? = nil,
                     breakStartSeconds: Int? = nil, breakEndSeconds: Int? = nil,
                     termID: UUID? = nil) {
        let schedule = ClassSchedule(
            subjectName: subjectName,
            professor: professor,
            room: room,
            daysOfWeek: daysOfWeek,
            startTimesSeconds: startTimesSeconds,
            endTimesSeconds: endTimesSeconds,
            firstClassDate: firstClassDate,
            breakStartSeconds: breakStartSeconds,
            breakEndSeconds: breakEndSeconds,
            termID: termID
        )
        modelContext.insert(schedule)
        try? modelContext.save()
        fetchSchedules()
    }

    func updateSchedule(_ schedule: ClassSchedule, subjectName: String, professor: String,
                        room: String, daysOfWeek: [Int],
                        startTimesSeconds: [Int], endTimesSeconds: [Int],
                        firstClassDate: Date? = nil,
                        breakStartSeconds: Int? = nil, breakEndSeconds: Int? = nil,
                        termID: UUID? = nil) {
        schedule.subjectName = subjectName
        schedule.professor = professor
        schedule.room = room
        schedule.daysOfWeek = daysOfWeek
        schedule.startTimesSeconds = startTimesSeconds
        schedule.endTimesSeconds = endTimesSeconds
        schedule.firstClassDate = firstClassDate
        schedule.breakStartSeconds = breakStartSeconds
        schedule.breakEndSeconds = breakEndSeconds
        schedule.termID = termID
        try? modelContext.save()
        fetchSchedules()
    }

    func deleteSchedule(_ schedule: ClassSchedule) {
        modelContext.delete(schedule)
        try? modelContext.save()
        fetchSchedules()
    }

    // MARK: - Term CRUD

    func fetchTerms() {
        let descriptor = FetchDescriptor<AcademicTerm>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        do {
            terms = try modelContext.fetch(descriptor)
            TermStore.shared.sync(terms: terms)
            if selectedTermID == nil {
                selectedTermID = TermStore.shared.currentTerm?.id
            }
        } catch {
            errorMessage = "学期の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func addTerm(name: String, startDate: Date, endDate: Date) {
        let order = terms.count
        let term = AcademicTerm(name: name, startDate: startDate, endDate: endDate, sortOrder: order)
        modelContext.insert(term)
        try? modelContext.save()
        fetchTerms()
    }

    func updateTerm(_ term: AcademicTerm, name: String, startDate: Date, endDate: Date) {
        term.name = name
        term.startDate = startDate
        term.endDate = endDate
        try? modelContext.save()
        fetchTerms()
    }

    func deleteTerm(_ term: AcademicTerm) {
        schedules.filter { $0.termID == term.id }.forEach { $0.termID = nil }
        modelContext.delete(term)
        try? modelContext.save()
        fetchTerms()
        fetchSchedules()
    }

    func deleteAllTerms() {
        terms.forEach { modelContext.delete($0) }
        schedules.forEach { $0.termID = nil }
        try? modelContext.save()
        fetchTerms()
        fetchSchedules()
    }

    // MARK: - Filtering

    var schedulesForSelectedTerm: [ClassSchedule] {
        guard let termID = selectedTermID else { return schedules }
        return schedules.filter { $0.termID == termID || $0.termID == nil }
    }

    // MARK: - Today / Next Class

    func todaySchedules(now: Date = Date()) -> [ClassSchedule] {
        let cal = Calendar(identifier: .gregorian)
        let weekday = cal.component(.weekday, from: now)
        let appDay = weekday - 1
        guard appDay >= 1 && appDay <= 5 else { return [] }
        return schedulesForSelectedTerm
            .filter { $0.daysOfWeek.contains(appDay) }
            .sorted { $0.startTime(for: appDay) < $1.startTime(for: appDay) }
    }

    func todayAppDay(now: Date = Date()) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let weekday = cal.component(.weekday, from: now)
        return weekday - 1
    }

    func nextClass(now: Date = Date()) -> ClassSchedule? {
        let appDay = todayAppDay(now: now)
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.hour, .minute], from: now)
        let nowSec = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60
        return todaySchedules(now: now).first { $0.startTime(for: appDay) > nowSec }
    }

    func secondsUntilNextClass(now: Date = Date()) -> Int? {
        let appDay = todayAppDay(now: now)
        guard let next = nextClass(now: now) else { return nil }
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.hour, .minute, .second], from: now)
        let nowSec = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)
        let diff = next.startTime(for: appDay) - nowSec
        return diff > 0 ? diff : nil
    }
}
