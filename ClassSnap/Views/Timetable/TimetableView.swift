import SwiftUI

struct TimetableView: View {
    var viewModel: TimetableViewModel
    @State private var showAddClass = false
    @State private var showSettings = false
    @State private var editingSchedule: ClassSchedule?

    // MARK: - Layout constants
    private let periodColumnWidth: CGFloat = 46
    private let periodRowHeight: CGFloat = 88

    // MARK: - Card color palette
    private let palette: [Color] = [
        Color(red: 0.73, green: 0.88, blue: 0.98),
        Color(red: 0.99, green: 0.76, blue: 0.76),
        Color(red: 0.79, green: 0.95, blue: 0.82),
        Color(red: 1.00, green: 0.93, blue: 0.76),
        Color(red: 0.90, green: 0.80, blue: 0.97),
        Color(red: 0.77, green: 0.94, blue: 0.95),
        Color(red: 1.00, green: 0.87, blue: 0.76),
        Color(red: 0.83, green: 0.86, blue: 0.99),
    ]

    // MARK: - Period row model

    private struct PeriodRow: Identifiable {
        let id: Int
        let label: String
        let startSeconds: Int
        let endSeconds: Int

        var startDisplay: String { TimeFormat.hm(startSeconds) }
        var endDisplay: String   { TimeFormat.hm(endSeconds) }
    }

    // MARK: - Computed helpers

    private var allSchedules: [ClassSchedule] { viewModel.schedulesForSelectedTerm }

    private var periodRows: [PeriodRow] {
        if ClassPeriodStore.shared.hasPeriods {
            return ClassPeriodStore.shared.periods.map { p in
                PeriodRow(id: p.id, label: "\(p.id)", startSeconds: p.startSeconds, endSeconds: p.endSeconds)
            }
        }
        // Auto-derive from schedule start times when no periods are configured
        let uniqueStarts = Set(allSchedules.flatMap { sch in
            sch.daysOfWeek.map { sch.startTime(for: $0) }
        }).sorted()
        return uniqueStarts.enumerated().map { (idx, startSec) in
            let endSec = allSchedules.flatMap { sch in
                sch.daysOfWeek.compactMap { day -> Int? in
                    guard sch.startTime(for: day) == startSec else { return nil }
                    return sch.endTime(for: day)
                }
            }.max() ?? (startSec + 5400)
            return PeriodRow(id: idx + 1, label: "\(idx + 1)", startSeconds: startSec, endSeconds: endSec)
        }
    }

    private func colorFor(_ schedule: ClassSchedule) -> Color {
        let idx = allSchedules.firstIndex(where: { $0.id == schedule.id }) ?? 0
        return palette[idx % palette.count]
    }

    private var todayAppDay: Int {
        Calendar(identifier: .gregorian).component(.weekday, from: Date()) - 1
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !viewModel.terms.isEmpty {
                    termPickerView
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                    Divider().opacity(0.3)
                }

                dayHeader
                Divider().opacity(0.3)

                if viewModel.schedules.isEmpty {
                    ContentUnavailableView(
                        "授業が登録されていません",
                        systemImage: "calendar.badge.plus",
                        description: Text("右上の + ボタンから授業を追加してください。")
                    )
                } else if allSchedules.isEmpty {
                    ContentUnavailableView(
                        "この学期には授業がありません",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("授業登録時に学期を選択してください。")
                    )
                } else {
                    periodGrid
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.appTextPrimary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("時間割")
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddClass = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.appTextPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddClass) { AddClassView(viewModel: viewModel) }
            .sheet(item: $editingSchedule) { EditClassView(viewModel: viewModel, schedule: $0) }
            .sheet(isPresented: $showSettings) { ProfileView(viewModel: viewModel) }
        }
    }

    // MARK: - Term chip picker

    private var termPickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TermChipButton(label: "全期間", isSelected: viewModel.selectedTermID == nil, isActive: false) {
                    viewModel.selectedTermID = nil
                }
                ForEach(viewModel.terms, id: \.id) { term in
                    TermChipButton(label: term.name,
                                   isSelected: viewModel.selectedTermID == term.id,
                                   isActive: term.isActive) {
                        viewModel.selectedTermID = term.id
                    }
                }
            }
        }
    }

    // MARK: - Day header row

    private var dayHeader: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: periodColumnWidth)
            ForEach(1...5, id: \.self) { day in
                Text(WeekdayHelper.shortName(for: day))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(day == todayAppDay ? Color.appGreen : Color.appTextSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(day == todayAppDay ? Color.appGreen.opacity(0.07) : Color.clear)
            }
        }
        .frame(height: 36)
        .background(Color.appBackground)
    }

    // MARK: - Period grid

    private let dividerWidth: CGFloat = 0.5
    private let rowDividerHeight: CGFloat = 0.5

    private var periodGrid: some View {
        GeometryReader { geo in
            let colWidth = (geo.size.width - periodColumnWidth - dividerWidth * 5) / 5
            let rowStride = periodRowHeight + rowDividerHeight
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // ベースのグリッド（時限ラベル・今日の列の色・罫線）
                    VStack(spacing: 0) {
                        ForEach(periodRows) { row in
                            HStack(spacing: 0) {
                                periodLabelView(row)
                                    .frame(width: periodColumnWidth, height: periodRowHeight)
                                ForEach(1...5, id: \.self) { day in
                                    Rectangle()
                                        .fill(Color.appTextSecondary.opacity(0.15))
                                        .frame(width: dividerWidth, height: periodRowHeight)
                                    ZStack {
                                        if day == todayAppDay {
                                            Color.appGreen.opacity(0.04)
                                        }
                                    }
                                    .frame(width: colWidth, height: periodRowHeight)
                                }
                            }
                            Rectangle()
                                .fill(Color.appTextSecondary.opacity(0.15))
                                .frame(height: rowDividerHeight)
                        }
                    }
                    // 授業カード（複数コマにまたがって配置）
                    ForEach(gridCards(colWidth: colWidth, rowStride: rowStride)) { card in
                        periodClassCard(card.schedule)
                            .frame(width: colWidth - 6, height: card.height - 6)
                            .offset(x: card.x + 3, y: card.y + 3)
                    }
                }
            }
        }
    }

    // MARK: - Spanning card layout

    private struct GridCard: Identifiable {
        let id: String
        let schedule: ClassSchedule
        let x: CGFloat
        let y: CGFloat
        let height: CGFloat
    }

    private func gridCards(colWidth: CGFloat, rowStride: CGFloat) -> [GridCard] {
        let rows = periodRows
        let hasPeriods = ClassPeriodStore.shared.hasPeriods
        var result: [GridCard] = []
        for sch in allSchedules {
            for day in sch.daysOfWeek where (1...5).contains(day) {
                let s = sch.startTime(for: day)
                let e = sch.endTime(for: day)
                let spannedIndices = rows.indices.filter { i in
                    if hasPeriods {
                        // この時限が授業時間と重なるか
                        return rows[i].startSeconds < e && rows[i].endSeconds > s
                    } else {
                        return rows[i].startSeconds == s
                    }
                }
                guard let first = spannedIndices.first, let last = spannedIndices.last else { continue }
                let count = last - first + 1
                let y = CGFloat(first) * rowStride
                let height = CGFloat(count) * periodRowHeight + CGFloat(count - 1) * rowDividerHeight
                let x = periodColumnWidth + CGFloat(day - 1) * (colWidth + dividerWidth) + dividerWidth
                result.append(GridCard(id: "\(sch.id.uuidString)_\(day)",
                                       schedule: sch, x: x, y: y, height: height))
            }
        }
        return result
    }

    // MARK: - Period label (left column)

    private func periodLabelView(_ row: PeriodRow) -> some View {
        VStack(spacing: 2) {
            Text(row.startDisplay)
                .font(.system(size: 9))
                .foregroundStyle(Color.appTextSecondary)
            Text(row.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appTextSecondary)
            Text(row.endDisplay)
                .font(.system(size: 9))
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    // MARK: - Class card

    private func periodClassCard(_ schedule: ClassSchedule) -> some View {
        let color = colorFor(schedule)
        return Button { editingSchedule = schedule } label: {
            RoundedRectangle(cornerRadius: 5)
                .fill(color)
                .overlay(alignment: .topLeading) {
                    Text(schedule.subjectName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.75))
                        .lineLimit(4)
                        .padding(.horizontal, 5)
                        .padding(.top, 5)
                }
                .overlay(alignment: .bottomTrailing) {
                    if !schedule.room.isEmpty {
                        Text(schedule.room)
                            .font(.system(size: 9))
                            .foregroundStyle(.black.opacity(0.55))
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .padding(.bottom, 5)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TermChipButton (also used by AlbumListView)

struct TermChipButton: View {
    let label: String
    let isSelected: Bool
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isActive {
                    Circle()
                        .fill(isSelected ? Color.white : Color.appGreen)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.subheadline).fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.appGreen : Color.appCard)
            .foregroundStyle(isSelected ? .white : Color.appTextPrimary)
            .clipShape(Capsule())
        }
    }
}
