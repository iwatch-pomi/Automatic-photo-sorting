import Photos
import Foundation

struct ClassAlbum {
    let schedule: ClassSchedule
    var assets: [PHAsset]

    /// 写真を第N回ごとにグループ化して返す
    func sessionAlbums() -> [SessionAlbum] {
        guard let fcd = schedule.firstClassDate else {
            return [SessionAlbum(sessionNumber: nil, assets: assets, schedule: schedule)]
        }
        let grouped = Dictionary(grouping: assets) { $0.sessionNumber(firstClassDate: fcd) }
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

    /// 初回授業日から何週目かを返す（第N回）
    func sessionNumber(firstClassDate: Date) -> Int {
        guard let photoDate = creationDate else { return 1 }
        let cal = Calendar(identifier: .gregorian)
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: firstClassDate),
            to: cal.startOfDay(for: photoDate)
        ).day ?? 0
        return max(1, (days / 7) + 1)
    }
}

final class PhotoMatcher {
    // 授業時間前後のバッファ（±10分）
    let bufferSeconds: Int = 10 * 60

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
        let windowStart = schedule.startTimeSeconds - bufferSeconds
        let windowEnd   = schedule.endTimeSeconds + bufferSeconds

        return photoSeconds >= windowStart && photoSeconds <= windowEnd
    }
}
