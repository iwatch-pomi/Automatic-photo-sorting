import Foundation
import SwiftData
import Observation

/// 学期プリセット。データ生成は TimetableViewModel.applyTermPreset(_:) が担う。
enum TermPreset { case semesterJP, quarterJP }

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
        modelContext.saveChanges()
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
        modelContext.saveChanges()

        // 時間割の変更に合わせて、保存写真を新しい授業条件で再マッチング。
        // 一致しなくなった写真は削除（手動追加した写真は残す）。
        // 新しく一致するライブ写真は次回アルバム読み込み時に自動保存される。
        if SavedPhotoStore.shared.hasSavedPhotos(for: schedule.id) {
            let matcher = PhotoMatcher()
            matcher.bufferSeconds = AppSettings.shared.bufferMinutes * 60
            let manualIDs = Set(PhotoInclusionStore.shared.includedIDs(for: schedule.id))
            let scheduleMakeups = makeups(for: schedule.id)
            SavedPhotoStore.shared.deleteStaleMatches(
                for: schedule.id,
                keepIdentifiers: manualIDs
            ) { date in
                matcher.photoFallsInClass(date: date, schedule: schedule,
                                          terms: terms, makeups: scheduleMakeups)
            }
        }

        fetchSchedules()
    }

    func deleteSchedule(_ schedule: ClassSchedule) {
        makeupClasses.filter { $0.scheduleID == schedule.id }.forEach { modelContext.delete($0) }
        SavedPhotoStore.shared.deleteAll(for: schedule.id)
        modelContext.delete(schedule)
        modelContext.saveChanges()
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
        modelContext.saveChanges()
        fetchMakeupClasses()
    }

    func deleteMakeupClass(_ makeup: MakeupClass) {
        modelContext.delete(makeup)
        modelContext.saveChanges()
        fetchMakeupClasses()
    }

    func updateMakeupClass(_ makeup: MakeupClass, scheduleID: UUID, date: Date,
                           startSeconds: Int, endSeconds: Int,
                           room: String = "", note: String = "") {
        makeup.scheduleID = scheduleID
        makeup.date = date
        makeup.startSeconds = startSeconds
        makeup.endSeconds = endSeconds
        makeup.room = room
        makeup.note = note
        modelContext.saveChanges()
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

    /// scheduleID 別の補講（PhotoMatcher / AlbumViewModel へ注入用）
    func makeups(for scheduleID: UUID) -> [MakeupClass] {
        makeupClasses.filter { $0.scheduleID == scheduleID }
    }

    /// scheduleID をキーにした補講辞書（AlbumViewModel.loadAlbums へ渡す）
    var makeupsBySchedule: [UUID: [MakeupClass]] {
        Dictionary(grouping: makeupClasses, by: \.scheduleID)
    }

    // MARK: - Term CRUD

    /// 現在進行中の学期（旧 TermStore.shared.currentTerm の代替）
    var currentTerm: AcademicTerm? { terms.first { $0.isActive } }

    /// ID から学期を引く（旧 TermStore.shared.term(forID:) の代替）
    func term(forID id: UUID) -> AcademicTerm? { terms.first { $0.id == id } }

    func fetchTerms() {
        let descriptor = FetchDescriptor<AcademicTerm>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        do {
            terms = try modelContext.fetch(descriptor)
            if selectedTermID == nil {
                selectedTermID = currentTerm?.id
            }
        } catch {
            errorMessage = "学期の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func addTerm(name: String, startDate: Date, endDate: Date) {
        let order = terms.count
        let term = AcademicTerm(name: name, startDate: startDate, endDate: endDate, sortOrder: order)
        modelContext.insert(term)
        modelContext.saveChanges()
        fetchTerms()
    }

    func updateTerm(_ term: AcademicTerm, name: String, startDate: Date, endDate: Date) {
        term.name = name
        term.startDate = startDate
        term.endDate = endDate
        modelContext.saveChanges()
        fetchTerms()
    }

    func deleteTerm(_ term: AcademicTerm) {
        schedules.forEach { $0.termIDs.removeAll { $0 == term.id } }
        modelContext.delete(term)
        // 選択中の学期を削除した場合は選択を解除し、fetchTerms で現在の学期を選び直す
        if selectedTermID == term.id { selectedTermID = nil }
        modelContext.saveChanges()
        fetchTerms()
        fetchSchedules()
    }

    func deleteAllTerms() {
        terms.forEach { modelContext.delete($0) }
        schedules.forEach { $0.termIDs.removeAll() }
        selectedTermID = nil
        modelContext.saveChanges()
        fetchTerms()
        fetchSchedules()
    }

    /// プリセットの学期一式を作成する（既存学期は削除）。ビジネスロジックは View ではなくここに集約。
    func applyTermPreset(_ preset: TermPreset) {
        deleteAllTerms()
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let specs: [(String, DateComponents, DateComponents)]
        switch preset {
        case .semesterJP:
            specs = [
                ("前期", DateComponents(year: year, month: 4, day: 1),
                         DateComponents(year: year, month: 9, day: 30)),
                ("後期", DateComponents(year: year, month: 10, day: 1),
                         DateComponents(year: year + 1, month: 3, day: 31)),
            ]
        case .quarterJP:
            specs = [
                ("1T", DateComponents(year: year, month: 4, day: 1),
                       DateComponents(year: year, month: 6, day: 30)),
                ("2T", DateComponents(year: year, month: 7, day: 1),
                       DateComponents(year: year, month: 9, day: 30)),
                ("3T", DateComponents(year: year, month: 10, day: 1),
                       DateComponents(year: year, month: 12, day: 31)),
                ("4T", DateComponents(year: year + 1, month: 1, day: 1),
                       DateComponents(year: year + 1, month: 3, day: 31)),
            ]
        }
        for (i, (name, startDC, endDC)) in specs.enumerated() {
            guard let start = cal.date(from: startDC), let end = cal.date(from: endDC) else { continue }
            modelContext.insert(AcademicTerm(name: name, startDate: start, endDate: end, sortOrder: i))
        }
        modelContext.saveChanges()
        fetchTerms()
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
        let nowSec = cal.secondsFromMidnight(for: now)
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

extension ModelContext {
    /// 変更を保存する。失敗を握りつぶす `try? save()` の代替。
    /// 失敗時は DEBUG ではアサート、本番ではログに残す。保存成否を返す。
    @discardableResult
    func saveChanges(_ caller: String = #function) -> Bool {
        do {
            try save()
            return true
        } catch {
            #if DEBUG
            assertionFailure("ModelContext.save() failed in \(caller): \(error)")
            #else
            print("⚠️ ModelContext.save() failed in \(caller): \(error)")
            #endif
            return false
        }
    }
}
