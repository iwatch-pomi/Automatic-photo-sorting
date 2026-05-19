import SwiftUI

struct AddClassView: View {
    var viewModel: TimetableViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var className: String = ""
    @State private var selectedDay: Int = 1
    @State private var startTime: Date = {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var endTime: Date = {
        Calendar.current.date(bySettingHour: 10, minute: 30, second: 0, of: Date()) ?? Date()
    }()

    private var isValid: Bool {
        !className.trimmingCharacters(in: .whitespaces).isEmpty && startTime < endTime
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("授業情報") {
                    TextField("授業名（例: 微生物学）", text: $className)

                    Picker("曜日", selection: $selectedDay) {
                        ForEach(1...5, id: \.self) { day in
                            Text(WeekdayHelper.name(for: day)).tag(day)
                        }
                    }
                }

                Section("時間") {
                    DatePicker("開始時刻", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("終了時刻", selection: $endTime, displayedComponents: .hourAndMinute)

                    if startTime >= endTime {
                        Label("終了時刻は開始時刻より後に設定してください", systemImage: "exclamationmark.triangle.fill")
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
                    Button("保存") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let cal = Calendar.current
        let startComps = cal.dateComponents([.hour, .minute], from: startTime)
        let endComps   = cal.dateComponents([.hour, .minute], from: endTime)
        let startSec = (startComps.hour ?? 0) * 3600 + (startComps.minute ?? 0) * 60
        let endSec   = (endComps.hour   ?? 0) * 3600 + (endComps.minute   ?? 0) * 60

        viewModel.addSchedule(
            className: className.trimmingCharacters(in: .whitespaces),
            dayOfWeek: selectedDay,
            startTimeSeconds: startSec,
            endTimeSeconds: endSec
        )
    }
}
