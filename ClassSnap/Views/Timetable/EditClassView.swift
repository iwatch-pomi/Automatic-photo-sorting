import SwiftUI

struct EditClassView: View {
    var viewModel: TimetableViewModel
    let schedule: ClassSchedule
    @Environment(\.dismiss) private var dismiss

    @State private var className: String
    @State private var professor: String
    @State private var room: String
    @State private var selectedDay: Int
    @State private var startTime: Date
    @State private var endTime: Date

    init(viewModel: TimetableViewModel, schedule: ClassSchedule) {
        self.viewModel = viewModel
        self.schedule = schedule
        _className = State(initialValue: schedule.subjectName)
        _professor = State(initialValue: schedule.professor)
        _room = State(initialValue: schedule.room)
        _selectedDay = State(initialValue: schedule.dayOfWeek)
        let base = Calendar.current.startOfDay(for: Date())
        _startTime = State(initialValue: base.addingTimeInterval(TimeInterval(schedule.startTimeSeconds)))
        _endTime   = State(initialValue: base.addingTimeInterval(TimeInterval(schedule.endTimeSeconds)))
    }

    private var isValid: Bool {
        !className.trimmingCharacters(in: .whitespaces).isEmpty && startTime < endTime
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("授業情報") {
                    TextField("授業名（例: 微生物学）", text: $className)
                    TextField("担当教員（例: J. グライアン教授）", text: $professor)
                    TextField("教室（例: Room 302）", text: $room)
                }

                Section("曜日・時間") {
                    Picker("曜日", selection: $selectedDay) {
                        ForEach(1...5, id: \.self) { day in
                            Text(WeekdayHelper.name(for: day)).tag(day)
                        }
                    }
                    DatePicker("開始時刻", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("終了時刻", selection: $endTime,   displayedComponents: .hourAndMinute)

                    if startTime >= endTime {
                        Label("終了時刻は開始時刻より後に設定してください",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("授業を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save(); dismiss() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let cal = Calendar.current
        let sc = cal.dateComponents([.hour, .minute], from: startTime)
        let ec = cal.dateComponents([.hour, .minute], from: endTime)
        viewModel.updateSchedule(
            schedule,
            subjectName: className.trimmingCharacters(in: .whitespaces),
            professor: professor.trimmingCharacters(in: .whitespaces),
            room: room.trimmingCharacters(in: .whitespaces),
            dayOfWeek: selectedDay,
            startTimeSeconds: (sc.hour ?? 0) * 3600 + (sc.minute ?? 0) * 60,
            endTimeSeconds:   (ec.hour ?? 0) * 3600 + (ec.minute ?? 0) * 60
        )
    }
}
