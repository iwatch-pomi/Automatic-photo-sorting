import WidgetKit
import SwiftUI

/// 授業の色番号 → 実際の色（範囲外は淡いグレー）。
private func classColor(_ index: Int) -> Color {
    guard index >= 0 && index < ClassColorPalette.colors.count else { return Color.gray.opacity(0.3) }
    return ClassColorPalette.colors[index]
}

/// appDay(1=月〜5=金) の日本語曜日名。WeekdayHelper は Photos 依存のためここに最小限を持つ。
private func weekdayName(_ appDay: Int) -> String {
    switch appDay {
    case 1: return "月曜日"; case 2: return "火曜日"; case 3: return "水曜日"
    case 4: return "木曜日"; case 5: return "金曜日"; default: return ""
    }
}

// MARK: - 全サイズ共通：次の授業カウントダウン

struct NextClassCountdown: View {
    let entry: TimetableEntry
    var compact = false

    var body: some View {
        if let next = entry.nextClass, let start = entry.nextClassStart {
            VStack(alignment: .leading, spacing: 1) {
                Text("次の授業まで")
                    .font(.caption2)
                    .foregroundStyle(Color.appTextSecondary)
                HStack(spacing: 6) {
                    // .timer は毎秒自動更新される残り時間カウントダウン
                    Text(start, style: .timer)
                        .font(compact ? .headline : .title3)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(Color.appGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !compact {
                        Text(next.subject)
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(1)
                    }
                }
                if compact {
                    Text(next.subject)
                        .font(.caption)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
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

private struct LargeView: View {
    let entry: TimetableEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                let appDay = Calendar(identifier: .gregorian).component(.weekday, from: entry.date) - 1
                Text(weekdayName(appDay).isEmpty ? "今日" : weekdayName(appDay))
                    .font(.headline).foregroundStyle(Color.appTextPrimary)
                if let term = entry.termName {
                    Text(term).font(.caption).foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Text("コマフォト").font(.caption2).fontWeight(.bold).foregroundStyle(Color.appGreen)
            }

            NextClassCountdown(entry: entry, compact: false)

            Divider()

            if entry.todayClasses.isEmpty {
                Spacer()
                Text("今日は授業がありません")
                    .font(.subheadline).foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entry.todayClasses.prefix(7)) { c in
                        ClassRow(entry: c, highlighted: c.id == entry.nextClass?.id)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
