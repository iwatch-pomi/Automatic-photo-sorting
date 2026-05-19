import SwiftUI

struct TimetableView: View {
    var viewModel: TimetableViewModel
    @State private var showAddClass = false

    private var schedulesByDay: [(day: Int, schedules: [ClassSchedule])] {
        let grouped = Dictionary(grouping: viewModel.schedules, by: \.dayOfWeek)
        return (1...5).compactMap { day in
            guard let entries = grouped[day], !entries.isEmpty else { return nil }
            return (day: day, schedules: entries)
        }
    }

    var body: some View {
        NavigationStack {
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
                            Section(WeekdayHelper.name(for: group.day)) {
                                ForEach(group.schedules, id: \.id) { schedule in
                                    ClassRowView(schedule: schedule)
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        viewModel.deleteSchedule(group.schedules[index])
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("時間割")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddClass = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddClass) {
                AddClassView(viewModel: viewModel)
            }
        }
    }
}

struct ClassRowView: View {
    let schedule: ClassSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(schedule.className)
                .font(.headline)
            Text("\(schedule.startTimeDisplay) – \(schedule.endTimeDisplay)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
