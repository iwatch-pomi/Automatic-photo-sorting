import SwiftUI

struct TimetableView: View {
    var viewModel: TimetableViewModel
    @State private var showAddClass = false
    @State private var showSettings = false
    @State private var editingSchedule: ClassSchedule?

    private var schedulesByDay: [(day: Int, schedules: [ClassSchedule])] {
        return (1...5).compactMap { day in
            let entries = viewModel.schedulesForSelectedTerm
                .filter { $0.daysOfWeek.contains(day) }
                .sorted { $0.startTime(for: day) < $1.startTime(for: day) }
            return entries.isEmpty ? nil : (day: day, schedules: entries)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if !viewModel.terms.isEmpty {
                        termPicker
                    }

                    Group {
                        if viewModel.schedules.isEmpty {
                            ContentUnavailableView(
                                "授業が登録されていません",
                                systemImage: "calendar.badge.plus",
                                description: Text("右上の + ボタンから授業を追加してください。")
                            )
                        } else {
                            List {
                                ForEach(schedulesByDay, id: \.day) { group in
                                    Section {
                                        ForEach(group.schedules, id: \.id) { schedule in
                                            ClassRowView(schedule: schedule, day: group.day)
                                                .listRowBackground(Color.appCard)
                                                .onTapGesture { editingSchedule = schedule }
                                        }
                                        .onDelete { indexSet in
                                            for index in indexSet {
                                                viewModel.deleteSchedule(group.schedules[index])
                                            }
                                        }
                                    } header: {
                                        Text(WeekdayHelper.name(for: group.day))
                                            .foregroundStyle(Color.appGreen)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showAddClass = true } label: {
                        Image(systemName: "plus").foregroundStyle(Color.appTextPrimary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("黒板フォト同期")
                        .font(.headline).foregroundStyle(Color.appTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape").foregroundStyle(Color.appTextPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddClass) {
                AddClassView(viewModel: viewModel)
            }
            .sheet(item: $editingSchedule) { schedule in
                EditClassView(viewModel: viewModel, schedule: schedule)
            }
            .sheet(isPresented: $showSettings) {
                ProfileView(viewModel: viewModel)
            }
        }
    }

    private var termPicker: some View {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.appBackground)
    }
}

struct ClassRowView: View {
    let schedule: ClassSchedule
    let day: Int

    private func fmt(_ s: Int) -> String { String(format: "%02d:%02d", s / 3600, (s % 3600) / 60) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(fmt(schedule.startTime(for: day)))
                    .font(.caption).fontWeight(.semibold).foregroundStyle(Color.appTextSecondary)
                Text(fmt(schedule.endTime(for: day)))
                    .font(.caption).foregroundStyle(Color.appTextSecondary)
            }
            .frame(width: 44)

            Rectangle()
                .fill(Color.appAccent.opacity(0.5))
                .frame(width: 2)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.subjectName)
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.appTextPrimary)
                if schedule.daysOfWeek.count > 1 {
                    Text(schedule.daysDisplay)
                        .font(.caption).foregroundStyle(Color.appAccent)
                }
                if !schedule.professor.isEmpty {
                    Text(schedule.professor)
                        .font(.caption).foregroundStyle(Color.appTextSecondary)
                }
                if !schedule.room.isEmpty {
                    Text(schedule.room)
                        .font(.caption).foregroundStyle(Color.appTextSecondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

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
