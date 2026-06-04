import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class TimetableViewModel {
    private var modelContext: ModelContext

    var schedules: [ClassSchedule] = []
    var terms: [AcademicTerm] = []
    var makeupClasses: [MakeupClass] = []
    var selectedTermID: UUID? = nil
    var errorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchSchedules()
        fetchTerms()
        fetchMakeupClasses()
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
                     termIDs: [UUID] = [], savePhotosEnabled: Bool = false) {
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
            termIDs: termIDs,
            savePhotosEnabled: savePhotosEnabled
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
                        termIDs: [UUID] = [], savePhotosEnabled: Bool = false) {
        schedule.subjectName = subjectName
        schedule.professor = professor
        schedule.room = room
        schedule.daysOfWeek = daysOfWeek
        schedule.startTimesSeconds = startTimesSeconds
        schedule.endTimesSeconds = endTimesSeconds
        schedule.firstClassDate = firstClassDate
        schedule.breakStartSeconds = breakStartSeconds
        schedule.breakEndSeconds = breakEndSeconds
        schedule.termIDs = termIDs
        schedule.savePhotosEnabled = savePhotosEnabled
        try? modelContext.save()

        // 時間割の変更に合わせて、保存写真を新しい授業条件で再マッチング。
        // 一致しなくなった写真は削除（手動追加した写真は残す）。
        // 新しく一致するライブ写真は次回アルバム読み込み時に自動保存される。
        if SavedPhotoStore.shared.hasSavedPhotos(for: schedule.id) {
            let matcher = PhotoMatcher()
            matcher.bufferSeconds = AppSettings.shared.bufferMinutes * 60
            let manualIDs = Set(PhotoInclusionStore.shared.includedIDs(for: schedule.id))
            SavedPhotoStore.shared.deleteStaleMatches(
                for: schedule.id,
                keepIdentifiers: manualIDs
            ) { date in
                matcher.photoFallsInClass(date: date, schedule: schedule)
            }
        }

        fetchSchedules()
    }

    func deleteSchedule(_ schedule: ClassSchedule) {
        makeupClasses.filter { $0.scheduleID == schedule.id }.forEach { modelContext.delete($0) }
        SavedPhotoStore.shared.deleteAll(for: schedule.id)
        modelContext.delete(schedule)
        try? modelContext.save()
        fetchSchedules()
        fetchMakeupClasses()
    }

    /// 指定授業のアプリ内保存写真をすべて削除（保存OFF切替時に使用）
    func deleteSavedPhotos(for scheduleID: UUID) {
        SavedPhotoStore.shared.deleteAll(for: scheduleID)
    }

    // MARK: - MakeupClass CRUD

    func fetchMakeupClasses() {
        let descriptor = FetchDescriptor<MakeupClass>(
            sortBy: [SortDescriptor(\.date)]
        )
        do {
            makeupClasses = try modelContext.fetch(descriptor)
            MakeupClassStore.shared.sync(makeupClasses: makeupClasses)
        } catch {
            // silent fail
        }
    }

    func addMakeupClass(scheduleID: UUID, date: Date, startSeconds: Int, endSeconds: Int,
                        room: String = "", note: String = "") {
        let makeup = MakeupClass(scheduleID: scheduleID, date: date,
                                  startSeconds: startSeconds, endSeconds: endSeconds,
                                  room: room, note: note)
        modelContext.insert(makeup)
        try? modelContext.save()
        fetchMakeupClasses()
    }

    func deleteMakeupClass(_ makeup: MakeupClass) {
        modelContext.delete(makeup)
        try? modelContext.save()
        fetchMakeupClasses()
    }

    var upcomingMakeupClasses: [MakeupClass] {
        let today = Calendar.current.startOfDay(for: Date())
        return makeupClasses
            .filter { Calendar.current.startOfDay(for: $0.date) >= today }
            .sorted { $0.date < $1.date }
    }

    func makeupClassesForSchedule(_ schedule: ClassSchedule) -> [MakeupClass] {
        makeupClasses.filter { $0.scheduleID == schedule.id }
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
        schedules.forEach { $0.termIDs.removeAll { $0 == term.id } }
        modelContext.delete(term)
        // 選択中の学期を削除した場合は選択を解除し、fetchTerms で現在の学期を選び直す
        if selectedTermID == term.id { selectedTermID = nil }
        try? modelContext.save()
        fetchTerms()
        fetchSchedules()
    }

    func deleteAllTerms() {
        terms.forEach { modelContext.delete($0) }
        schedules.forEach { $0.termIDs.removeAll() }
        selectedTermID = nil
        try? modelContext.save()
        fetchTerms()
        fetchSchedules()
    }

    // MARK: - Filtering

    var schedulesForSelectedTerm: [ClassSchedule] {
        guard let termID = selectedTermID else { return schedules }
        return schedules.filter { $0.termIDs.contains(termID) || $0.termIDs.isEmpty }
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
