import SwiftUI

struct AddClassView: View {
    var viewModel: TimetableViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var className: String = ""
    @State private var professor: String = ""
    @State private var room: String = ""
    @State private var selectedDay: Int = 1
    @State private var startTime: Date = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime: Date = Calendar.current.date(
        bySettingHour: 10, minute: 30, second: 0, of: Date()) ?? Date()

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
            .navigationTitle("授業を追加")
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
        viewModel.addSchedule(
            className: className.trimmingCharacters(in: .whitespaces),
            professor: professor.trimmingCharacters(in: .whitespaces),
            room: room.trimmingCharacters(in: .whitespaces),
            dayOfWeek: selectedDay,
            startTimeSeconds: (sc.hour ?? 0) * 3600 + (sc.minute ?? 0) * 60,
            endTimeSeconds:   (ec.hour ?? 0) * 3600 + (ec.minute ?? 0) * 60
        )
    }
}
