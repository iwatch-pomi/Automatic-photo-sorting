import Foundation
import Observation

struct ClassPeriod: Codable, Identifiable {
    var id: Int
    var startSeconds: Int
    var endSeconds: Int

    var startDisplay: String { TimeFormat.hm(startSeconds) }
    var endDisplay: String   { TimeFormat.hm(endSeconds) }
    var timeRange: String { "\(startDisplay)〜\(endDisplay)" }
    var label: String { "\(id)コマ目　\(timeRange)" }
}

/// コマ時刻の変更（旧→新）を表す。既存の時間割の時刻追従に使う。
struct PeriodTimeRemap {
    let oldStart: Int
    let oldEnd: Int
    let newStart: Int
    let newEnd: Int
}

@Observable
final class ClassPeriodStore {
    static let shared = ClassPeriodStore()

    var periods: [ClassPeriod] = []

    /// コマ時刻が変更されたときに呼ばれる。登録済み時間割の時刻を追従させるために
    /// ScheduleStore 側で配線する（コマ時間を変えても授業のコマ対応・時刻が外れないようにする）。
    @ObservationIgnored var onPeriodTimesRemapped: (([PeriodTimeRemap]) -> Void)?

    private let key = "classPeriods"

    private init() { load() }

    var hasPeriods: Bool { !periods.isEmpty }

    func period(id: Int) -> ClassPeriod? {
        periods.first { $0.id == id }
    }

    func matchingPeriodID(startSeconds: Int, endSeconds: Int) -> Int? {
        periods.first { $0.startSeconds == startSeconds && $0.endSeconds == endSeconds }?.id
    }

    func addPeriod(startSeconds: Int, endSeconds: Int) {
        let nextID = (periods.map(\.id).max() ?? 0) + 1
        periods.append(ClassPeriod(id: nextID, startSeconds: startSeconds, endSeconds: endSeconds))
        save()
    }

    func updatePeriod(_ period: ClassPeriod) {
        guard let idx = periods.firstIndex(where: { $0.id == period.id }) else { return }
        let old = periods[idx]
        periods[idx] = period
        save()
        // コマ時刻が変わったら、そのコマに乗っている授業の時刻を追従させる
        if old.startSeconds != period.startSeconds || old.endSeconds != period.endSeconds {
            onPeriodTimesRemapped?([PeriodTimeRemap(
                oldStart: old.startSeconds, oldEnd: old.endSeconds,
                newStart: period.startSeconds, newEnd: period.endSeconds)])
        }
    }

    func deletePeriod(id: Int) {
        periods.removeAll { $0.id == id }
        renumber()
        save()
    }

    func applyUniversityPreset() {
        let oldPeriods = periods
        periods = [
            ClassPeriod(id: 1, startSeconds:  9*3600,            endSeconds:  9*3600 + 90*60),
            ClassPeriod(id: 2, startSeconds: 10*3600 + 40*60,    endSeconds: 12*3600 + 10*60),
            ClassPeriod(id: 3, startSeconds: 13*3600,            endSeconds: 14*3600 + 30*60),
            ClassPeriod(id: 4, startSeconds: 14*3600 + 40*60,    endSeconds: 16*3600 + 10*60),
            ClassPeriod(id: 5, startSeconds: 16*3600 + 20*60,    endSeconds: 17*3600 + 50*60),
        ]
        save()
        // 同じコマ番号の時刻が変わったものについては、授業の時刻を追従させる
        let remaps: [PeriodTimeRemap] = periods.compactMap { new in
            guard let old = oldPeriods.first(where: { $0.id == new.id }),
                  old.startSeconds != new.startSeconds || old.endSeconds != new.endSeconds
            else { return nil }
            return PeriodTimeRemap(oldStart: old.startSeconds, oldEnd: old.endSeconds,
                                   newStart: new.startSeconds, newEnd: new.endSeconds)
        }
        if !remaps.isEmpty { onPeriodTimesRemapped?(remaps) }
    }

    func deleteAll() {
        periods = []
        save()
    }

    private func renumber() {
        periods = periods.enumerated().map { i, p in
            ClassPeriod(id: i + 1, startSeconds: p.startSeconds, endSeconds: p.endSeconds)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ClassPeriod].self, from: data)
        else { return }
        periods = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(periods) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
