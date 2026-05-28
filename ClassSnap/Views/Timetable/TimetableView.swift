import SwiftUI

struct TimetableView: View {
    var viewModel: TimetableViewModel
    @State private var showAddClass = false
    @State private var showSettings = false
    @State private var editingSchedule: ClassSchedule?

    // MARK: - Layout constants
    private let timeColumnWidth: CGFloat = 38
    private let pixelsPerMinute: CGFloat = 1.5
    private var rowsPerHour: CGFloat { pixelsPerMinute * 60 }
    private let minCardHeight: CGFloat = 36

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

    // MARK: - Computed helpers

    private var allSchedules: [ClassSchedule] { viewModel.schedulesForSelectedTerm }

    private var startHour: Int {
        let s = allSchedules.flatMap { sch in sch.daysOfWeek.map { sch.startTime(for: $0) } }.min()
            ?? (9 * 3600)
        return max(s / 3600 - 1, 7)
    }

    private var endHour: Int {
        let e = allSchedules.flatMap { sch in sch.daysOfWeek.map { sch.endTime(for: $0) } }.max()
            ?? (18 * 3600)
        return min(e / 3600 + 2, 22)
    }

    private var hours: [Int] { Array(startHour...max(endHour, startHour + 2)) }
    private var totalHeight: CGFloat { CGFloat(endHour - startHour) * rowsPerHour }

    private func yFor(_ seconds: Int) -> CGFloat {
        CGFloat(seconds - startHour * 3600) / 60.0 * pixelsPerMinute
    }

    private func cardHeight(start: Int, end: Int) -> CGFloat {
        max(CGFloat(end - start) / 60.0 * pixelsPerMinute - 2, minCardHeight)
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
                    grid
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
            Color.clear.frame(width: timeColumnWidth)
            ForEach(1...5, id: \.self) { day in
                Text(WeekdayHelper.shortName(for: day))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(day == todayAppDay ? Color.appGreen : Color.appTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(day == todayAppDay ? Color.appGreen.opacity(0.07) : Color.clear)
            }
        }
        .background(Color.appBackground)
    }

    // MARK: - Main grid

    private var grid: some View {
        GeometryReader { geo in
            let colWidth = (geo.size.width - timeColumnWidth) / 5
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    timeLabels
                    ForEach(1...5, id: \.self) { day in
                        dayColumn(day: day, width: colWidth)
                    }
                }
            }
        }
    }

    // MARK: - Time label column

    private var timeLabels: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear.frame(width: timeColumnWidth, height: totalHeight)
            ForEach(hours, id: \.self) { hour in
                Text(String(format: "%d:00", hour))
                    .font(.system(size: 9))
                    .foregroundStyle(Color.appTextSecondary)
                    .offset(x: -2, y: yFor(hour * 3600) - 6)
            }
        }
    }

    // MARK: - Day column

    private func dayColumn(day: Int, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Base height anchor
            Color.clear.frame(width: width, height: totalHeight)

            // Today tint
            if day == todayAppDay {
                Color.appGreen.opacity(0.04).frame(width: width, height: totalHeight)
            }

            // Hourly grid lines
            ForEach(hours, id: \.self) { hour in
                Color.appTextSecondary.opacity(0.15)
                    .frame(width: width, height: 0.5)
                    .offset(y: yFor(hour * 3600))
            }

            // Class cards
            ForEach(allSchedules.filter { $0.daysOfWeek.contains(day) }, id: \.id) { sch in
                let s = sch.startTime(for: day)
                let e = sch.endTime(for: day)
                classCard(sch)
                    .frame(width: width - 4, height: cardHeight(start: s, end: e))
                    .offset(x: 2, y: yFor(s) + 1)
            }
        }
        .frame(width: width)
    }

    // MARK: - Class card

    private func classCard(_ schedule: ClassSchedule) -> some View {
        let color = colorFor(schedule)
        return Button { editingSchedule = schedule } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4).fill(color)
                RoundedRectangle(cornerRadius: 4).strokeBorder(color.opacity(0.5), lineWidth: 0.5)
                VStack(alignment: .leading, spacing: 1) {
                    Text(schedule.subjectName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.75))
                        .lineLimit(4)
                    if !schedule.room.isEmpty {
                        Text(schedule.room)
                            .font(.system(size: 9))
                            .foregroundStyle(.black.opacity(0.50))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 3)
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
