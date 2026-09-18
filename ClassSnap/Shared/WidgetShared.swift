import Foundation

/// アプリ本体とウィジェット拡張で共有するコード。
/// 依存は Foundation のみ（SwiftData / RevenueCat / AdMob を持ち込まない）。
/// このファイルは **アプリターゲットとウィジェットターゲットの両方**に所属させる。

enum AppGroup {
    /// App Group ID。Apple Developer で登録し、両ターゲットの entitlements に設定する。
    static let id = "group.com.iwatchsan.komaphoto"
}

/// 授業セルのパレット色数。`ClassColorPalette.colors.count`（AppColors.swift）と必ず一致させる。
/// 色の実体（SwiftUI Color）に依存させないため、色数だけをここ（Foundation側）に置く。
enum WidgetPalette {
    static let colorCount = 8
}

/// ウィジェットが描画に使う「今日/次の授業」用の軽量スナップショット。
/// アプリ側が時間割変更のたびに書き出し、ウィジェットはこれだけを読む
/// （SwiftData ストアをウィジェットから直接開かないための共有フォーマット）。
struct TimetableSnapshot: Codable {
    /// 現在選択中の学期の授業を、曜日ごとに1件ずつ展開したもの。
    var classes: [ClassEntry]
    /// 時限（何時間目）の定義。大サイズのグリッド表示で左列に使う。
    /// アプリ側で ClassPeriodStore を優先し、未設定なら授業の開始時刻から導出して埋める。
    var periods: [PeriodSnapshot]
    /// 表示中の学期名（無ければ nil）。
    var termName: String?
    /// 書き出した時刻（デバッグ・鮮度確認用）。
    var generatedAt: Date

    init(classes: [ClassEntry], periods: [PeriodSnapshot], termName: String?, generatedAt: Date = Date()) {
        self.classes = classes
        self.periods = periods
        self.termName = termName
        self.generatedAt = generatedAt
    }
}

/// 1時限（コマ）の定義。
struct PeriodSnapshot: Codable, Identifiable {
    var id: Int { number }
    /// 何時間目か（1始まり）。
    let number: Int
    let startSeconds: Int
    let endSeconds: Int
}

/// 1コマ分の授業（特定の曜日）。
struct ClassEntry: Codable, Identifiable {
    var id: String { "\(appDay)-\(startSeconds)-\(subject)" }
    /// 1=月 〜 5=金（アプリ内の appDay = weekday - 1 と同じ）。
    let appDay: Int
    let startSeconds: Int
    let endSeconds: Int
    let subject: String
    let room: String
    /// ClassColorPalette.colors のインデックス（0..<8）。書き出し時に実値へ解決済み。
    let colorIndex: Int
}

/// App Group 上の UserDefaults にスナップショットを JSON 保存/読込するストア。
/// データは小さいため UserDefaults で十分。
enum WidgetDataStore {
    private static let key = "timetable_snapshot_v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.id)
    }

    static func save(_ snapshot: TimetableSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> TimetableSnapshot? {
        guard let defaults, let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TimetableSnapshot.self, from: data)
    }
}
