import Photos
import Foundation

struct ClassAlbum {
    let schedule: ClassSchedule
    var assets: [PHAsset]

    /// 除外されていない写真の枚数
    var activeCount: Int {
        let store = PhotoExclusionStore.shared
        return assets.filter { !store.isExcluded(assetID: $0.localIdentifier, scheduleID: schedule.id) }.count
    }

    /// 写真を第N回ごとにグループ化して返す（除外済み写真はスキップ）
    func sessionAlbums() -> [SessionAlbum] {
        let store = PhotoExclusionStore.shared
        let active = assets.filter { !store.isExcluded(assetID: $0.localIdentifier, scheduleID: schedule.id) }

        guard let fcd = schedule.firstClassDate else {
            return [SessionAlbum(sessionNumber: nil, assets: active, schedule: schedule)]
        }
        let grouped = Dictionary(grouping: active) { $0.sessionNumber(firstClassDate: fcd, daysOfWeek: schedule.daysOfWeek) }
        return grouped.map { num, list in
            SessionAlbum(
                sessionNumber: num,
                assets: list.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) },
                schedule: schedule
            )
        }.sorted { ($0.sessionNumber ?? 0) < ($1.sessionNumber ?? 0) }
    }
}

struct SessionAlbum: Identifiable {
    let sessionNumber: Int?
    var assets: [PHAsset]
    let schedule: ClassSchedule

    var id: String { "\(schedule.id.uuidString)-\(sessionNumber ?? -1)" }

    var displayTitle: String {
        sessionNumber.map { "第\($0)回" } ?? "全写真"
    }

    var dateRangeDisplay: String {
        let dates = assets.compactMap(\.creationDate).sorted()
        guard let first = dates.first else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M月d日"
        guard let last = dates.last, !Calendar.current.isDate(first, inSameDayAs: last) else {
            return fmt.string(from: first)
        }
        return "\(fmt.string(from: first)) 〜 \(fmt.string(from: last))"
    }
}

extension PHAsset {
    /// 撮影日時を "YYYY年M月d日 HH:mm" 形式で返す
    var creationDateDisplay: String {
        guard let date = creationDate else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "yyyy年M月d日 HH:mm"
        return fmt.string(from: date)
    }

    /// 初回授業日から何回目の授業日かを返す（第N回）
    /// daysOfWeek を元に実際の授業日を1日ずつカウントする
    func sessionNumber(firstClassDate: Date, daysOfWeek: [Int]) -> Int {
        guard let photoDate = creationDate else { return 1 }
        let cal = Calendar(identifier: .gregorian)
        let startDay = cal.startOfDay(for: firstClassDate)
        let photoDay = cal.startOfDay(for: photoDate)
        guard photoDay >= startDay else { return 1 }

        var count = 0
        var current = startDay
        while current <= photoDay {
            // Calendar.weekday: 1=日,2=月...6=金,7=土 → appDay: 1=月...5=金
            let weekday = cal.component(.weekday, from: current)
            let appDay = weekday - 1
            if daysOfWeek.contains(appDay) { count += 1 }
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }
        return max(1, count)
    }
}

final class PhotoMatcher {
    var bufferSeconds: Int = 10 * 60

    func match(assets: [PHAsset], schedules: [ClassSchedule]) -> [ClassAlbum] {
        var albums: [UUID: ClassAlbum] = Dictionary(
            uniqueKeysWithValues: schedules.map { ($0.id, ClassAlbum(schedule: $0, assets: [])) }
        )

        for asset in assets {
            guard let creationDate = asset.creationDate else { continue }
            for schedule in schedules {
                if photoFallsInClass(date: creationDate, schedule: schedule) {
                    albums[schedule.id]?.assets.append(asset)
                }
            }
        }

        return albums.values
            .filter { !$0.assets.isEmpty }
            .sorted { $0.schedule.subjectName < $1.schedule.subjectName }
    }

    func photoFallsInClass(date: Date, schedule: ClassSchedule) -> Bool {
        // 学期チェック：scheduleにtermIDが設定されている場合、撮影日がその学期の範囲内にある必要がある
        if let termID = schedule.termID,
           let term = TermStore.shared.term(forID: termID) {
            guard term.contains(date: date) else { return false }
        }

        // 初回授業日が設定されている場合、それより前の写真は除外
        if let firstClassDate = schedule.firstClassDate,
           date < firstClassDate {
            return false
        }

        // Gregorian カレンダーを明示指定（ロケール依存を避ける）
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)

        guard let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute else { return false }

        // Calendar.weekday: 1=日, 2=月, ..., 6=金, 7=土
        // appDayOfWeek: 1=月, ..., 5=金
        let appDayOfWeek = weekday - 1
        guard appDayOfWeek >= 1 && appDayOfWeek <= 5 else { return false }
        guard schedule.daysOfWeek.contains(appDayOfWeek) else { return false }

        let photoSeconds = hour * 3600 + minute * 60
        let windowStart = schedule.startTime(for: appDayOfWeek) - bufferSeconds
        let windowEnd   = schedule.endTime(for: appDayOfWeek) + bufferSeconds

        guard photoSeconds >= windowStart && photoSeconds <= windowEnd else { return false }

        // 昼休み除外: 設定された休憩時間帯の写真はスキップ
        if let breakStart = schedule.breakStartSeconds,
           let breakEnd = schedule.breakEndSeconds,
           photoSeconds >= breakStart && photoSeconds <= breakEnd {
            return false
        }

        return true
    }
}
