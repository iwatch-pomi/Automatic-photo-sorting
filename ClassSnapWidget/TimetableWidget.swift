import WidgetKit
import SwiftUI

/// タイムライン1点分のデータ。`date` 時点での「今日の授業」と「次の授業」を持つ。
struct TimetableEntry: TimelineEntry {
    let date: Date
    let termName: String?
    /// その日の授業（開始時刻昇順）。
    let todayClasses: [ClassEntry]
    /// 月〜金すべての授業（大サイズの週間表示用。曜日ごとに開始時刻昇順で引ける）。
    let weekClasses: [ClassEntry]
    /// 時限定義（大サイズのグリッド左列＝何時間目＋時刻）。
    let weekPeriods: [PeriodSnapshot]
    /// `date` より後に始まる最初の授業。
    let nextClass: ClassEntry?
    /// 次の授業の開始時刻（絶対時刻。カウントダウン用）。
    let nextClassStart: Date?
}

struct TimetableProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimetableEntry {
        Self.makeEntry(date: Date(), snapshot: Self.sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimetableEntry) -> Void) {
        let snap = WidgetDataStore.load() ?? Self.sampleSnapshot
        completion(Self.makeEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableEntry>) -> Void) {
        let snapshot = WidgetDataStore.load()
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let startOfDay = cal.startOfDay(for: now)
        let appDay = cal.component(.weekday, from: now) - 1
        let today = (snapshot?.classes ?? [])
            .filter { $0.appDay == appDay }
            .sorted { $0.startSeconds < $1.startSeconds }

        // 「次の授業」が切り替わる境界（各授業の開始・終了）でエントリを作る。
        // カウントダウン自体は Text(_, style: .timer) が秒単位で自動更新するため、
        // ここでは分刻みの大量エントリは不要。
        var dates: Set<Date> = [now]
        for c in today {
            let s = startOfDay.addingTimeInterval(TimeInterval(c.startSeconds))
            let e = startOfDay.addingTimeInterval(TimeInterval(c.endSeconds))
            if s > now { dates.insert(s) }
            if e > now { dates.insert(e) }
        }
        let nextMidnight = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? now.addingTimeInterval(86_400)
        dates.insert(nextMidnight)

        let sorted = dates.sorted().prefix(40)
        let entries = sorted.map { Self.makeEntry(date: $0, snapshot: snapshot) }
        // 翌0時に必ず作り直して日付をロールする
        completion(Timeline(entries: entries, policy: .after(nextMidnight)))
    }

    /// `date` 時点のエントリを構築する。
    static func makeEntry(date: Date, snapshot: TimetableSnapshot?) -> TimetableEntry {
        let cal = Calendar(identifier: .gregorian)
        let startOfDay = cal.startOfDay(for: date)
        let appDay = cal.component(.weekday, from: date) - 1
        let comps = cal.dateComponents([.hour, .minute, .second], from: date)
        let nowSec = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)

        let today = (snapshot?.classes ?? [])
            .filter { $0.appDay == appDay }
            .sorted { $0.startSeconds < $1.startSeconds }
        let next = today.first { $0.startSeconds > nowSec }
        let nextStart = next.map { startOfDay.addingTimeInterval(TimeInterval($0.startSeconds)) }

        return TimetableEntry(
            date: date,
            termName: snapshot?.termName,
            todayClasses: today,
            weekClasses: snapshot?.classes ?? [],
            weekPeriods: snapshot?.periods ?? [],
            nextClass: next,
            nextClassStart: nextStart
        )
    }

    /// プレビュー/プレースホルダ用のダミーデータ。
    static let sampleSnapshot = TimetableSnapshot(
        classes: [
            ClassEntry(appDay: 1, startSeconds: 9 * 3600, endSeconds: 10 * 3600 + 1800,
                       subject: "微分積分学", room: "A201", colorIndex: 0),
            ClassEntry(appDay: 1, startSeconds: 10 * 3600 + 2400, endSeconds: 12 * 3600,
                       subject: "英語コミュニケーション", room: "B105", colorIndex: 2),
            ClassEntry(appDay: 1, startSeconds: 13 * 3600, endSeconds: 14 * 3600 + 1800,
                       subject: "プログラミング演習", room: "情報センター", colorIndex: 5),
        ],
        periods: [
            PeriodSnapshot(number: 1, startSeconds: 9 * 3600, endSeconds: 10 * 3600 + 1800),
            PeriodSnapshot(number: 2, startSeconds: 10 * 3600 + 2400, endSeconds: 12 * 3600 + 600),
            PeriodSnapshot(number: 3, startSeconds: 13 * 3600, endSeconds: 14 * 3600 + 1800),
        ],
        termName: "前期"
    )
}

struct TimetableWidget: Widget {
    let kind = "TimetableWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimetableProvider()) { entry in
            TimetableWidgetView(entry: entry)
                .containerBackground(Color.white, for: .widget)
        }
        .configurationDisplayName("時間割")
        .description("今日の授業と、次の授業までの残り時間を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
