import Photos
import Foundation

struct ClassAlbum {
    let schedule: ClassSchedule
    var assets: [PHAsset]
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
        guard appDayOfWeek == schedule.dayOfWeek else { return false }

        let photoSeconds = hour * 3600 + minute * 60
        let windowStart = schedule.startTimeSeconds - bufferSeconds
        let windowEnd   = schedule.endTimeSeconds + bufferSeconds

        return photoSeconds >= windowStart && photoSeconds <= windowEnd
    }
}
