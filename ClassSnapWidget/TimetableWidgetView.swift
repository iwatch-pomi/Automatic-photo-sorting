import WidgetKit
import SwiftUI

/// 授業の色番号 → 実際の色（範囲外は淡いグレー）。
private func classColor(_ index: Int) -> Color {
    guard index >= 0 && index < ClassColorPalette.colors.count else { return Color.gray.opacity(0.3) }
    return ClassColorPalette.colors[index]
}

/// appDay(1=月〜5=金) の日本語曜日名（短縮）。WeekdayHelper は Photos 依存のためここに最小限を持つ。
private func weekdayShort(_ appDay: Int) -> String {
    switch appDay {
    case 1: return "月"; case 2: return "火"; case 3: return "水"
    case 4: return "木"; case 5: return "金"; default: return ""
    }
}

// MARK: - 全サイズ共通：次の授業カウントダウン

struct NextClassCountdown: View {
    let entry: TimetableEntry
    var compact = false

    var body: some View {
        if let next = entry.nextClass, let start = entry.nextClassStart {
            VStack(alignment: .leading, spacing: 2) {
                Text("次の授業まで")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                HStack(spacing: 6) {
                    // .timer は毎秒自動更新される残り時間カウントダウン
                    Text(start, style: .timer)
                        .font(compact ? .title2 : .largeTitle)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(Color.appGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !compact {
                        Text(next.subject)
                            .font(.title3).fontWeight(.semibold)
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                if compact {
                    Text(next.subject)
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        } else {
            Text(entry.todayClasses.isEmpty ? "今日は授業がありません" : "今日の授業は終了しました")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .lineLimit(2)
        }
    }
}

// MARK: - 1コマ行

struct ClassRow: View {
    let entry: ClassEntry
    var highlighted = false

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(classColor(entry.colorIndex))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.subject)
                    .font(.caption).fontWeight(highlighted ? .bold : .semibold)
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(TimeFormat.hm(entry.startSeconds))–\(TimeFormat.hm(entry.endSeconds))")
                    if !entry.room.isEmpty { Text(entry.room).lineLimit(1) }
                }
                .font(.caption2)
                .foregroundStyle(Color.appTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - サイズ分岐

struct TimetableWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimetableEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallView(entry: entry)
        case .systemLarge: LargeView(entry: entry)
        default:           MediumView(entry: entry)
        }
    }
}

private struct SmallView: View {
    let entry: TimetableEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("コマフォト").font(.caption2).fontWeight(.bold)
                    .foregroundStyle(Color.appGreen)
                Spacer()
            }
            Spacer(minLength: 0)
            NextClassCountdown(entry: entry, compact: true)
            if let next = entry.nextClass {
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.caption2)
                    Text(TimeFormat.hm(next.startSeconds))
                    if !next.room.isEmpty { Text("・\(next.room)").lineLimit(1) }
                }
                .font(.caption2)
                .foregroundStyle(Color.appTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MediumView: View {
    let entry: TimetableEntry
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                NextClassCountdown(entry: entry, compact: false)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text("今日の授業").font(.caption2).foregroundStyle(Color.appTextSecondary)
                if entry.todayClasses.isEmpty {
                    Text("なし").font(.caption).foregroundStyle(Color.appTextSecondary)
                } else {
                    ForEach(entry.todayClasses.prefix(4)) { c in
                        ClassRow(entry: c, highlighted: c.id == entry.nextClass?.id)
                    }
                    if entry.todayClasses.count > 4 {
                        Text("ほか\(entry.todayClasses.count - 4)コマ")
                            .font(.caption2).foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 大サイズ用：アプリの時間割と同じ「時限（何時間目）＋時刻」の左列＋月〜金カラムのグリッド。
/// コマをまたぐ授業は縦に結合したカードとして配置し、今日の列を淡く強調する。
private struct TimetableGrid: View {
    let periods: [PeriodSnapshot]
    let classes: [ClassEntry]
    let todayAppDay: Int
    /// 枠線でハイライトする授業（＝いま進行中の授業）。
    let currentClassID: String?

    private let periodColWidth: CGFloat = 32

    private struct GCard: Identifiable {
        let id: String
        let entry: ClassEntry
        let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat
    }

    var body: some View {
        let rows = periods.sorted { $0.startSeconds < $1.startSeconds }
        GeometryReader { geo in
            let headerH: CGFloat = 16
            let count = max(rows.count, 1)
            let rowH = (geo.size.height - headerH) / CGFloat(count)
            let colW = (geo.size.width - periodColWidth) / 5

            ZStack(alignment: .topLeading) {
                // 曜日ヘッダ
                HStack(spacing: 0) {
                    Color.clear.frame(width: periodColWidth, height: headerH)
                    ForEach(1...5, id: \.self) { day in
                        Text(weekdayShort(day))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(day == todayAppDay ? Color.appGreen : Color.appTextSecondary)
                            .frame(width: colW, height: headerH)
                            .background(day == todayAppDay ? Color.appGreen.opacity(0.08) : Color.clear)
                    }
                }

                // 時限行（左ラベル＝開始/番号/終了、今日の列を淡く、罫線）
                ForEach(Array(rows.enumerated()), id: \.element.number) { idx, row in
                    HStack(spacing: 0) {
                        VStack(spacing: 1) {
                            Text(TimeFormat.hm(row.startSeconds)).font(.system(size: 7)).foregroundStyle(Color.appTextSecondary)
                            Text("\(row.number)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.appTextSecondary)
                            Text(TimeFormat.hm(row.endSeconds)).font(.system(size: 7)).foregroundStyle(Color.appTextSecondary)
                        }
                        .frame(width: periodColWidth, height: rowH)
                        ForEach(1...5, id: \.self) { day in
                            (day == todayAppDay ? Color.appGreen.opacity(0.05) : Color.clear)
                                .frame(width: colW, height: rowH)
                                .overlay(alignment: .leading) {
                                    Rectangle().fill(Color.appTextSecondary.opacity(0.15)).frame(width: 0.5)
                                }
                        }
                    }
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.appTextSecondary.opacity(0.15)).frame(height: 0.5)
                    }
                    .offset(y: headerH + CGFloat(idx) * rowH)
                }

                // 授業カード（コマをまたいで配置）
                ForEach(cards(rows: rows, colW: colW, rowH: rowH, headerH: headerH)) { card in
                    classCard(card.entry)
                        .frame(width: card.w - 3, height: card.h - 3)
                        .offset(x: card.x + 1.5, y: card.y + 1.5)
                }
            }
        }
    }

    private func cards(rows: [PeriodSnapshot], colW: CGFloat, rowH: CGFloat, headerH: CGFloat) -> [GCard] {
        guard !rows.isEmpty else { return [] }
        var result: [GCard] = []
        for c in classes where (1...5).contains(c.appDay) {
            let spanned = rows.indices.filter { rows[$0].startSeconds < c.endSeconds && rows[$0].endSeconds > c.startSeconds }
            let first: Int
            let last: Int
            if let f = spanned.first, let l = spanned.last {
                first = f; last = l
            } else {
                // どの時限とも重ならない時刻は最も近い行に置く（アプリと同じ挙動）
                let nearest = rows.indices.min {
                    abs(rows[$0].startSeconds - c.startSeconds) < abs(rows[$1].startSeconds - c.startSeconds)
                } ?? 0
                first = nearest; last = nearest
            }
            let n = last - first + 1
            let x = periodColWidth + CGFloat(c.appDay - 1) * colW
            let y = headerH + CGFloat(first) * rowH
            result.append(GCard(id: "\(c.id)-\(c.appDay)", entry: c, x: x, y: y, w: colW, h: CGFloat(n) * rowH))
        }
        return result
    }

    private func classCard(_ e: ClassEntry) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(classColor(e.colorIndex))
            .overlay(alignment: .topLeading) {
                Text(e.subject)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.75))
                    .lineLimit(3)
                    .padding(.horizontal, 3).padding(.top, 3)
            }
            .overlay(alignment: .bottomTrailing) {
                if !e.room.isEmpty {
                    Text(e.room)
                        .font(.system(size: 7))
                        .foregroundStyle(.black.opacity(0.55))
                        .lineLimit(1)
                        .padding(.horizontal, 3).padding(.bottom, 2)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(e.id == currentClassID ? Color.appGreen : Color.clear, lineWidth: 2)
            )
    }
}

private struct LargeView: View {
    let entry: TimetableEntry

    private var todayAppDay: Int {
        Calendar(identifier: .gregorian).component(.weekday, from: entry.date) - 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("時間割").font(.subheadline).fontWeight(.bold).foregroundStyle(Color.appTextPrimary)
                if let term = entry.termName {
                    Text(term).font(.caption2).foregroundStyle(Color.appTextSecondary)
                }
                Spacer(minLength: 8)
                // 次の授業の名前＋カウントダウンを1行で
                if let next = entry.nextClass, let start = entry.nextClassStart {
                    HStack(spacing: 4) {
                        Text("次: \(next.subject)")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text(start, style: .timer)
                            .font(.caption).fontWeight(.bold).monospacedDigit()
                            .foregroundStyle(Color.appGreen)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }

            if entry.weekPeriods.isEmpty {
                Spacer()
                Text("授業が登録されていません")
                    .font(.subheadline).foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                TimetableGrid(
                    periods: entry.weekPeriods,
                    classes: entry.weekClasses,
                    todayAppDay: todayAppDay,
                    currentClassID: entry.currentClass?.id
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
