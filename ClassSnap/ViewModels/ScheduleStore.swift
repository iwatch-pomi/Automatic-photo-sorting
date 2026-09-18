import Foundation
import SwiftData
import Observation
import WidgetKit

/// 授業（時間割）の単一情報源。CRUD・学期絞り込み・今日/次の授業・
/// 保存写真の整理を担当する。旧 TimetableViewModel から schedule 関連の責務を分離したもの。
@MainActor
@Observable
final class ScheduleStore {
    private let modelContext: ModelContext

    /// 学期絞り込み（selectedTermID）の参照用。AppStores が注入。
    @ObservationIgnored weak var termStore: TermStore?
    /// 補講の削除・再マッチ用。AppStores が注入。
    @ObservationIgnored weak var makeupStore: MakeupStore?

    var schedules: [ClassSchedule] = []
    var errorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchSchedules()
    }

    // MARK: - CRUD

    func fetchSchedules() {
        let descriptor = FetchDescriptor<ClassSchedule>()
        do {
            schedules = try modelContext.fetch(descriptor)
                .sorted { ($0.startTimesSeconds.first ?? 0) < ($1.startTimesSeconds.first ?? 0) }
        } catch {
            errorMessage = "時間割の読み込みに失敗しました: \(error.localizedDescription)"
        }
        // 時間割が変わるたびにウィジェット用スナップショットを更新する。
        // （fetchSchedules は追加・更新・削除いずれの後にも呼ばれる合流点）
        publishWidgetSnapshot()
    }

    // MARK: - Widget snapshot

    /// ホーム画面ウィジェット用に、現在選択中の学期の授業を App Group へ書き出して再描画を促す。
    /// 色は保存時に実インデックスへ解決し（colorIndex ?? 並び順）、ウィジェット側は引くだけにする。
    func publishWidgetSnapshot() {
        let list = schedulesForSelectedTerm
        var entries: [ClassEntry] = []
        for (index, s) in list.enumerated() {
            let resolvedColor: Int = {
                if let ci = s.colorIndex, (0..<WidgetPalette.colorCount).contains(ci) { return ci }
                return index % WidgetPalette.colorCount
            }()
            for day in s.daysOfWeek where (1...5).contains(day) {
                entries.append(ClassEntry(
                    appDay: day,
                    startSeconds: s.startTime(for: day),
                    endSeconds: s.endTime(for: day),
                    subject: s.subjectName,
                    room: s.room,
                    colorIndex: resolvedColor
                ))
            }
        }
        // 時限（何時間目）定義。アプリの TimetableView と同じロジック：
        // ClassPeriodStore があればそれを使い、無ければ授業の開始時刻から導出する。
        let periods: [PeriodSnapshot]
        if ClassPeriodStore.shared.hasPeriods {
            periods = ClassPeriodStore.shared.periods.map {
                PeriodSnapshot(number: $0.id, startSeconds: $0.startSeconds, endSeconds: $0.endSeconds)
            }
        } else {
            let uniqueStarts = Set(list.flatMap { s in
                s.daysOfWeek.filter { (1...5).contains($0) }.map { s.startTime(for: $0) }
            }).sorted()
            periods = uniqueStarts.enumerated().map { (idx, startSec) in
                let endSec = list.flatMap { s in
                    s.daysOfWeek.compactMap { d -> Int? in
                        guard (1...5).contains(d), s.startTime(for: d) == startSec else { return nil }
                        return s.endTime(for: d)
                    }
                }.max() ?? (startSec + 5400)
                return PeriodSnapshot(number: idx + 1, startSeconds: startSec, endSeconds: endSec)
            }
        }

        let termName = termStore?.selectedTermID.flatMap { termStore?.term(forID: $0)?.name }
        WidgetDataStore.save(TimetableSnapshot(classes: entries, periods: periods, termName: termName))
        WidgetCenter.shared.reloadAllTimelines()
    }

    func addSchedule(subjectName: String, professor: String, room: String,
                     daysOfWeek: [Int], startTimesSeconds: [Int], endTimesSeconds: [Int],
                     firstClassDate: Date? = nil,
                     breakStartSeconds: Int? = nil, breakEndSeconds: Int? = nil,
                     termIDs: [UUID] = [], savePhotosEnabled: Bool = false,
                     colorIndex: Int? = nil) {
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
            savePhotosEnabled: savePhotosEnabled,
            colorIndex: colorIndex
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
                        termIDs: [UUID] = [], savePhotosEnabled: Bool = false,
                        colorIndex: Int? = nil) {
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
        schedule.colorIndex = colorIndex
        modelContext.saveChanges()

        // 時間割の変更に合わせて、保存写真を新しい授業条件で再マッチング。
        // 一致しなくなった写真は削除（手動追加した写真は残す）。
        // 新しく一致するライブ写真は次回アルバム読み込み時に自動保存される。
        // 補講リストが不完全（フェッチ失敗）だと補講日の保存写真を誤削除するため、
        // その場合は整理をスキップする。
        if SavedPhotoStore.shared.hasSavedPhotos(for: schedule.id),
           makeupStore?.lastFetchFailed != true {
            let matcher = PhotoMatcher()
            matcher.bufferSeconds = AppSettings.shared.bufferMinutes * 60
            let manualIDs = Set(PhotoInclusionStore.shared.includedIDs(for: schedule.id))
            let scheduleMakeups = makeupStore?.makeups(for: schedule.id) ?? []
            let allTerms = termStore?.terms ?? []
            SavedPhotoStore.shared.deleteStaleMatches(
                for: schedule.id,
                keepIdentifiers: manualIDs
            ) { date in
                matcher.photoFallsInClass(date: date, schedule: schedule,
                                          terms: allTerms, makeups: scheduleMakeups)
            }
        }

        fetchSchedules()
    }

    func deleteSchedule(_ schedule: ClassSchedule) {
        makeupStore?.deleteMakeups(forScheduleID: schedule.id)
        SavedPhotoStore.shared.deleteAll(for: schedule.id)
        // UserDefaults 系ストアの掃除（残すと無制限に肥大する）
        PhotoExclusionStore.shared.removeAll(forScheduleID: schedule.id)
        PhotoInclusionStore.shared.removeAll(forScheduleID: schedule.id)
        SessionTitleStore.shared.removeTitles(forScheduleID: schedule.id)
        TestRangeStore.shared.removeAll(forScheduleID: schedule.id)
        modelContext.delete(schedule)
        modelContext.saveChanges()
        fetchSchedules()
    }

    /// 指定授業のアプリ内保存写真をすべて削除（保存OFF切替時に使用）
    func deleteSavedPhotos(for scheduleID: UUID) {
        SavedPhotoStore.shared.deleteAll(for: scheduleID)
    }

    /// 学期削除時に、各授業から該当 termID を取り除く（TermStore から呼ばれる）
    func removeTermID(_ termID: UUID) {
        schedules.forEach { $0.termIDs.removeAll { $0 == termID } }
    }

    /// 全学期削除時に、各授業の termIDs をクリアする（TermStore から呼ばれる）
    func clearAllTermIDs() {
        schedules.forEach { $0.termIDs.removeAll() }
    }

    // MARK: - Filtering

    /// 現在選択中の学期で絞り込んだ授業（selectedTermID は TermStore が保持）
    var schedulesForSelectedTerm: [ClassSchedule] {
        schedules(forTermID: termStore?.selectedTermID)
    }

    func schedules(forTermID termID: UUID?) -> [ClassSchedule] {
        guard let termID else { return schedules }
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
