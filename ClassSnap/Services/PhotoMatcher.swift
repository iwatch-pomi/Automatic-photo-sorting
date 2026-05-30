import Photos
import Foundation

struct ClassAlbum {
    let schedule: ClassSchedule
    var assets: [PHAsset]

    /// 除外されていない写真一覧（手動追加分を含む、撮影日昇順）
    var activeAssets: [PHAsset] {
        let exclusionStore = PhotoExclusionStore.shared
        var active = assets.filter { !exclusionStore.isExcluded(assetID: $0.localIdentifier, scheduleID: schedule.id) }
        let autoIDs = Set(active.map { $0.localIdentifier })
        let manual = PhotoInclusionStore.shared.fetchAssets(for: schedule.id)
            .filter { !autoIDs.contains($0.localIdentifier) && !exclusionStore.isExcluded(assetID: $0.localIdentifier, scheduleID: schedule.id) }
        active += manual
        return active.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    /// 除外されていない写真の枚数
    var activeCount: Int { activeAssets.count }

    /// サムネイル用：除外済みを除いた中で最も新しい写真
    var thumbnailAsset: PHAsset? { activeAssets.last }

    /// 写真を第N回ごとにグループ化して返す（除外済み写真はスキップ、手動追加分を含む）
    func sessionAlbums() -> [SessionAlbum] {
        let exclusionStore = PhotoExclusionStore.shared
        let inclusionStore = PhotoInclusionStore.shared
        var active = assets.filter { !exclusionStore.isExcluded(assetID: $0.localIdentifier, scheduleID: schedule.id) }
        let autoIDs = Set(active.map { $0.localIdentifier })
        let manual = inclusionStore.fetchAssets(for: schedule.id)
            .filter { !autoIDs.contains($0.localIdentifier) && !exclusionStore.isExcluded(assetID: $0.localIdentifier, scheduleID: schedule.id) }
        active += manual

        let makeupDates = MakeupClassStore.shared.makeupClasses(for: schedule.id).map { $0.date }

        let grouped = Dictionary(grouping: active) { asset -> Int? in
            // Manual session override (N > 0) takes priority over date-based calculation
            if let override = inclusionStore.sessionOverride(for: asset.localIdentifier, scheduleID: schedule.id),
               override > 0 {
                return override
            }
            guard let fcd = schedule.firstClassDate else { return nil }
            return asset.sessionNumber(firstClassDate: fcd, daysOfWeek: schedule.daysOfWeek, makeupDates: makeupDates)
        }
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
    /// 通常の daysOfWeek に加えて補講日 makeupDates も授業回数としてカウントする
    func sessionNumber(firstClassDate: Date, daysOfWeek: [Int], makeupDates: [Date] = []) -> Int {
        guard let photoDate = creationDate else { return 1 }
        let cal = Calendar(identifier: .gregorian)
        let startDay = cal.startOfDay(for: firstClassDate)
        let photoDay = cal.startOfDay(for: photoDate)
        guard photoDay >= startDay else { return 1 }

        // 通常の授業日を収集
        var classDays: Set<Date> = []
        var current = startDay
        while current <= photoDay {
            let weekday = cal.component(.weekday, from: current)
            let appDay = weekday - 1
            if daysOfWeek.contains(appDay) { classDays.insert(current) }
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }

        // 補講日を追加（初回授業日以降・撮影日以前のもののみ）
        for makeup in makeupDates {
            let d = cal.startOfDay(for: makeup)
            if d >= startDay && d <= photoDay { classDays.insert(d) }
        }

        return max(1, classDays.count)
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
        // 補講日チェック：補講日の時間帯に撮影された写真は対象に含める
        let cal = Calendar(identifier: .gregorian)
        let photoDay = cal.startOfDay(for: date)
        let photoComps = cal.dateComponents([.hour, .minute], from: date)
        let photoSec = (photoComps.hour ?? 0) * 3600 + (photoComps.minute ?? 0) * 60
        for makeup in MakeupClassStore.shared.makeupClasses(for: schedule.id) {
            if cal.startOfDay(for: makeup.date) == photoDay {
                if photoSec >= makeup.startSeconds - bufferSeconds &&
                   photoSec <= makeup.endSeconds + bufferSeconds {
                    return true
                }
            }
        }

        // 学期チェック：termIDsが設定されている場合、いずれかの学期の範囲内にある必要がある
        if !schedule.termIDs.isEmpty {
            let inAnyTerm = schedule.termIDs
                .compactMap { TermStore.shared.term(forID: $0) }
                .contains { $0.contains(date: date) }
            guard inAnyTerm else { return false }
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
