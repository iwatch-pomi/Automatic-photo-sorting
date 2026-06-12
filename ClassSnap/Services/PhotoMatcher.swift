import Photos
import Foundation

struct ClassAlbum {
    let schedule: ClassSchedule
    /// 自動マッチ＋（アプリ保存のみの）写真を統合したリスト。AlbumViewModel が構築して渡す。
    var assets: [AlbumPhoto]
    /// 手動で追加された写真（事前解決済み）。
    var manualAssets: [AlbumPhoto] = []
    /// この授業の補講日（第N回計算に使用）。AlbumViewModel が SwiftData から注入する。
    var makeupDates: [Date] = []

    /// 除外を除いた、自動マッチ＋手動追加のマージ済み写真（撮影日昇順）。
    /// activePhotos / activeCount / thumbnailPhoto / sessionAlbums で共有し、重複計算を防ぐ。
    private var mergedAssets: [AlbumPhoto] {
        let exclusionStore = PhotoExclusionStore.shared
        let active = assets.filter { !exclusionStore.isExcluded(assetID: $0.id, scheduleID: schedule.id) }
        let autoIDs = Set(active.map { $0.id })
        let manual = manualAssets.filter {
            !autoIDs.contains($0.id) && !exclusionStore.isExcluded(assetID: $0.id, scheduleID: schedule.id)
        }
        return (active + manual).sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    /// 除外されていない写真一覧（手動追加分を含む、撮影日昇順）
    var activePhotos: [AlbumPhoto] { mergedAssets }

    /// 除外されていない写真の枚数
    var activeCount: Int { mergedAssets.count }

    /// サムネイル用：除外済みを除いた中で最も新しい写真
    var thumbnailPhoto: AlbumPhoto? { mergedAssets.last }

    /// 写真を第N回ごとにグループ化して返す（除外済み写真はスキップ、手動追加分を含む）
    func sessionAlbums() -> [SessionAlbum] {
        let inclusionStore = PhotoInclusionStore.shared
        let active = mergedAssets

        let grouped = Dictionary(grouping: active) { photo -> Int? in
            // Manual session override (N > 0) takes priority over date-based calculation
            if let override = inclusionStore.sessionOverride(for: photo.id, scheduleID: schedule.id),
               override > 0 {
                return override
            }
            guard let fcd = schedule.firstClassDate else { return nil }
            return computeSessionNumber(creationDate: photo.creationDate, firstClassDate: fcd,
                                        daysOfWeek: schedule.daysOfWeek, makeupDates: makeupDates)
        }
        return grouped.map { num, list in
            SessionAlbum(
                sessionNumber: num,
                assets: list.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) },
                schedule: schedule,
                makeupDates: makeupDates
            )
        }.sorted { ($0.sessionNumber ?? 0) < ($1.sessionNumber ?? 0) }
    }
}

struct SessionAlbum: Identifiable {
    let sessionNumber: Int?
    var assets: [AlbumPhoto]
    let schedule: ClassSchedule
    /// 親アルバムから引き継いだ補講日（PhotoGridView などで第N回計算に使用）。
    var makeupDates: [Date] = []

    var id: String { "\(schedule.id.uuidString)-\(sessionNumber ?? -1)" }

    /// セッション名（カスタム名称）の保存キー。回番号は初回日変更・補講追加で
    /// ズレて別の回に名前が付け替わるため、授業日（最初の写真の日付）で固定する。
    /// 旧データ（回番号キー）は SessionTitleStore 側で読み替え移行する。
    var titleKey: String {
        if let earliest = assets.compactMap(\.creationDate).min() {
            return "\(schedule.id.uuidString)-d\(AppDateFormatters.dayKey.string(from: earliest))"
        }
        return id
    }

    var displayTitle: String {
        sessionNumber.map { "第\($0)回" } ?? "全写真"
    }

    var dateRangeDisplay: String {
        let dates = assets.compactMap(\.creationDate).sorted()
        guard let first = dates.first else { return "" }
        let fmt = AppDateFormatters.mdJP
        guard let last = dates.last, !Calendar.current.isDate(first, inSameDayAs: last) else {
            return fmt.string(from: first)
        }
        return "\(fmt.string(from: first)) 〜 \(fmt.string(from: last))"
    }
}

/// 撮影日時を "YYYY年M月d日 HH:mm" 形式で返す（日付ベース・PHAsset/保存写真共通）
func photoCreationDateDisplay(_ date: Date?) -> String {
    guard let date else { return "" }
    return AppDateFormatters.ymdHmJP.string(from: date)
}

/// 初回授業日から何回目の授業日かを返す（第N回）。撮影日（creationDate）ベースで計算する。
/// 通常の daysOfWeek に加えて補講日 makeupDates も授業回数としてカウントする。
/// 撮影日が不明、または初回授業日より前の場合は nil（未分類）を返す。
func computeSessionNumber(creationDate: Date?, firstClassDate: Date,
                         daysOfWeek: [Int], makeupDates: [Date] = []) -> Int? {
    guard let photoDate = creationDate else { return nil }
    let cal = Calendar(identifier: .gregorian)
    let startDay = cal.startOfDay(for: firstClassDate)
    let photoDay = cal.startOfDay(for: photoDate)
    guard photoDay >= startDay else { return nil }

    // 通常の授業日を収集
    var classDays: Set<Date> = []
    var current = startDay
    while current <= photoDay {
        let weekday = cal.component(.weekday, from: current)
        let appDay = weekday - 1
        if daysOfWeek.contains(appDay) { classDays.insert(current) }
        guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
        current = next
    }

    // 補講日を追加（初回授業日以降・撮影日以前のもののみ）
    for makeup in makeupDates {
        let d = cal.startOfDay(for: makeup)
        if d >= startDay && d <= photoDay { classDays.insert(d) }
    }

    return max(1, classDays.count)
}

extension PHAsset {
    /// 撮影日時を "YYYY年M月d日 HH:mm" 形式で返す
    var creationDateDisplay: String { photoCreationDateDisplay(creationDate) }

    /// 初回授業日から何回目の授業日かを返す（第N回）。判定不能なら nil
    func sessionNumber(firstClassDate: Date, daysOfWeek: [Int], makeupDates: [Date] = []) -> Int? {
        computeSessionNumber(creationDate: creationDate, firstClassDate: firstClassDate,
                             daysOfWeek: daysOfWeek, makeupDates: makeupDates)
    }
}

// MARK: - Matching snapshots

// SwiftData の @Model はメインスレッド外からの読み取りが安全でないため、
// マッチングに必要な値だけを値型に写し取り、バックグラウンドで判定できるようにする。

struct ScheduleMatchSnapshot: Sendable {
    let id: UUID
    let daysOfWeek: [Int]
    let startSecondsByDay: [Int: Int]
    let endSecondsByDay: [Int: Int]
    let firstClassDate: Date?
    let breakStartSeconds: Int?
    let breakEndSeconds: Int?
    let termIDs: [UUID]

    init(_ schedule: ClassSchedule) {
        id = schedule.id
        daysOfWeek = schedule.daysOfWeek
        var starts: [Int: Int] = [:]
        var ends: [Int: Int] = [:]
        for day in schedule.daysOfWeek {
            starts[day] = schedule.startTime(for: day)
            ends[day] = schedule.endTime(for: day)
        }
        startSecondsByDay = starts
        endSecondsByDay = ends
        firstClassDate = schedule.firstClassDate
        breakStartSeconds = schedule.breakStartSeconds
        breakEndSeconds = schedule.breakEndSeconds
        termIDs = schedule.termIDs
    }
}

struct TermSnapshot: Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date

    init(_ term: AcademicTerm) {
        id = term.id
        startDate = term.startDate
        endDate = term.endDate
    }

    /// AcademicTerm.contains(date:) と同じ日単位の判定
    func contains(date: Date) -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        guard let endExclusive = cal.date(byAdding: .day, value: 1,
                                          to: cal.startOfDay(for: endDate)) else {
            return date >= start && date <= endDate
        }
        return date >= start && date < endExclusive
    }
}

struct MakeupSnapshot: Sendable {
    let date: Date
    let startSeconds: Int
    let endSeconds: Int

    init(_ makeup: MakeupClass) {
        date = makeup.date
        startSeconds = makeup.startSeconds
        endSeconds = makeup.endSeconds
    }
}

final class PhotoMatcher {
    var bufferSeconds: Int = 10 * 60

    /// 各授業に時間帯マッチしたライブ PHAsset を scheduleID 別に返す（保存写真のマージは呼び出し側）。
    /// グローバル状態に依存せず、学期・補講は引数で受け取る（純関数・テスト可能）。
    func matchLiveAssets(assets: [PHAsset], schedules: [ClassSchedule],
                         terms: [AcademicTerm],
                         makeupsBySchedule: [UUID: [MakeupClass]]) -> [UUID: [PHAsset]] {
        Self.matchLiveAssets(assets: assets,
                             schedules: schedules.map(ScheduleMatchSnapshot.init),
                             terms: terms.map(TermSnapshot.init),
                             makeupsBySchedule: makeupsBySchedule.mapValues { $0.map(MakeupSnapshot.init) },
                             bufferSeconds: bufferSeconds)
    }

    /// 単一授業へのマッチ判定。学期・補講は引数で受け取る（純関数）。
    func photoFallsInClass(date: Date, schedule: ClassSchedule,
                           terms: [AcademicTerm], makeups: [MakeupClass]) -> Bool {
        let snaps = terms.map(TermSnapshot.init)
        let termByID = Dictionary(snaps.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return Self.photoFallsInClass(date: date,
                                      schedule: ScheduleMatchSnapshot(schedule),
                                      termByID: termByID,
                                      makeups: makeups.map(MakeupSnapshot.init),
                                      bufferSeconds: bufferSeconds)
    }

    // MARK: - Snapshot-based core（バックグラウンド実行可能）

    static func matchLiveAssets(assets: [PHAsset], schedules: [ScheduleMatchSnapshot],
                                terms: [TermSnapshot],
                                makeupsBySchedule: [UUID: [MakeupSnapshot]],
                                bufferSeconds: Int) -> [UUID: [PHAsset]] {
        let termByID = Dictionary(terms.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var result: [UUID: [PHAsset]] = Dictionary(uniqueKeysWithValues: schedules.map { ($0.id, []) })
        for asset in assets {
            guard let creationDate = asset.creationDate else { continue }
            for schedule in schedules {
                if photoFallsInClass(date: creationDate, schedule: schedule,
                                     termByID: termByID,
                                     makeups: makeupsBySchedule[schedule.id] ?? [],
                                     bufferSeconds: bufferSeconds) {
                    result[schedule.id, default: []].append(asset)
                }
            }
        }
        return result
    }

    /// 授業ウィンドウを「授業日の0:00 + 秒数」の絶対時刻で判定する。
    /// バッファが深夜0時を跨ぐ場合も取りこぼさないよう、撮影日の前日・翌日の
    /// 授業ウィンドウも候補に含める（通常の日中授業では従来と同一の結果になる）。
    static func photoFallsInClass(date: Date, schedule: ScheduleMatchSnapshot,
                                  termByID: [UUID: TermSnapshot],
                                  makeups: [MakeupSnapshot],
                                  bufferSeconds: Int) -> Bool {
        let cal = Calendar(identifier: .gregorian)
        let photoDay = cal.startOfDay(for: date)
        let candidateDays = [-1, 0, 1].compactMap {
            cal.date(byAdding: .day, value: $0, to: photoDay)
        }

        // 補講日チェック：補講日の時間帯に撮影された写真は対象に含める
        for makeup in makeups {
            let makeupDay = cal.startOfDay(for: makeup.date)
            guard candidateDays.contains(makeupDay) else { continue }
            let windowStart = makeupDay.addingTimeInterval(TimeInterval(makeup.startSeconds - bufferSeconds))
            let windowEnd = makeupDay.addingTimeInterval(TimeInterval(makeup.endSeconds + bufferSeconds))
            if date >= windowStart && date <= windowEnd { return true }
        }

        // 学期チェック：termIDsが設定されている場合、いずれかの学期の範囲内にある必要がある
        if !schedule.termIDs.isEmpty {
            let inAnyTerm = schedule.termIDs
                .compactMap { termByID[$0] }
                .contains { $0.contains(date: date) }
            guard inAnyTerm else { return false }
        }

        // 初回授業日が設定されている場合、それより前の写真は除外
        if let firstClassDate = schedule.firstClassDate, date < firstClassDate {
            return false
        }

        for classDay in candidateDays {
            // Calendar.weekday: 1=日, 2=月, ..., 6=金, 7=土 / appDay: 1=月, ..., 5=金
            let appDay = cal.component(.weekday, from: classDay) - 1
            guard appDay >= 1 && appDay <= 5,
                  schedule.daysOfWeek.contains(appDay),
                  let startSec = schedule.startSecondsByDay[appDay],
                  let endSec = schedule.endSecondsByDay[appDay] else { continue }

            let windowStart = classDay.addingTimeInterval(TimeInterval(startSec - bufferSeconds))
            let windowEnd = classDay.addingTimeInterval(TimeInterval(endSec + bufferSeconds))
            guard date >= windowStart && date <= windowEnd else { continue }

            // 昼休み除外: 設定された休憩時間帯の写真はスキップ
            if let breakStart = schedule.breakStartSeconds,
               let breakEnd = schedule.breakEndSeconds {
                let bStart = classDay.addingTimeInterval(TimeInterval(breakStart))
                let bEnd = classDay.addingTimeInterval(TimeInterval(breakEnd))
                if date >= bStart && date <= bEnd { continue }
            }
            return true
        }
        return false
    }
}
