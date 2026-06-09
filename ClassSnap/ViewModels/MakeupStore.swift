import Foundation
import SwiftData
import Observation

/// 補講（MakeupClass）の単一情報源。CRUD と派生コレクションを担当する。
/// 旧 TimetableViewModel から makeup 関連の責務を分離したもの。
@MainActor
@Observable
final class MakeupStore {
    private let modelContext: ModelContext

    var makeupClasses: [MakeupClass] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchMakeupClasses()
    }

    // MARK: - CRUD

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

    /// 指定授業に紐づく補講をすべて削除（ScheduleStore.deleteSchedule から呼ばれる）
    func deleteMakeups(forScheduleID scheduleID: UUID) {
        makeupClasses.filter { $0.scheduleID == scheduleID }.forEach { modelContext.delete($0) }
        modelContext.saveChanges()
        fetchMakeupClasses()
    }

    // MARK: - Derived collections

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
}
