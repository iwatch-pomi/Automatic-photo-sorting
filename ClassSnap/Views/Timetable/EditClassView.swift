import SwiftUI

struct EditClassView: View {
    var viewModel: TimetableViewModel
    let schedule: ClassSchedule
    @Environment(\.dismiss) private var dismiss

    @State private var className: String
    @State private var professor: String
    @State private var room: String
    @State private var selectedDays: Set<Int>
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var setFirstClassDate: Bool
    @State private var firstClassDate: Date
    @State private var excludeBreak: Bool
    @State private var breakStart: Date
    @State private var breakEnd: Date

    init(viewModel: TimetableViewModel, schedule: ClassSchedule) {
        self.viewModel = viewModel
        self.schedule = schedule
        _className = State(initialValue: schedule.subjectName)
        _professor = State(initialValue: schedule.professor)
        _room = State(initialValue: schedule.room)
        _selectedDays = State(initialValue: Set(schedule.daysOfWeek))
        let base = Calendar.current.startOfDay(for: Date())
        _startTime = State(initialValue: base.addingTimeInterval(TimeInterval(schedule.startTimeSeconds)))
        _endTime   = State(initialValue: base.addingTimeInterval(TimeInterval(schedule.endTimeSeconds)))
        _setFirstClassDate = State(initialValue: schedule.firstClassDate != nil)
        _firstClassDate = State(initialValue: schedule.firstClassDate ?? Date())
        _excludeBreak = State(initialValue: schedule.breakStartSeconds != nil)
        let defaultBreakStart = base.addingTimeInterval(TimeInterval(schedule.breakStartSeconds ?? 43200)) // 12:00
        let defaultBreakEnd   = base.addingTimeInterval(TimeInterval(schedule.breakEndSeconds   ?? 46800)) // 13:00
        _breakStart = State(initialValue: defaultBreakStart)
        _breakEnd   = State(initialValue: defaultBreakEnd)
    }

    private var isValid: Bool {
        !className.trimmingCharacters(in: .whitespaces).isEmpty
            && startTime < endTime
            && !selectedDays.isEmpty
            && (!excludeBreak || breakStart < breakEnd)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("授業情報") {
                    TextField("授業名（例: 微生物学）", text: $className)
                    TextField("担当教員（例: J. グライアン教授）", text: $professor)
                    TextField("教室（例: Room 302）", text: $room)
                }

                Section {
                    Toggle("初回授業日を設定", isOn: $setFirstClassDate)
                    if setFirstClassDate {
                        DatePicker("初回日付", selection: $firstClassDate,
                                   displayedComponents: .date)
                    }
                } header: {
                    Text("第N回の表示")
                } footer: {
                    Text("設定すると写真に「第1回」「第2回」…と表示されます")
                        .font(.caption)
                }

                Section("曜日・時間") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("曜日（複数選択可）")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { day in
                                let isSelected = selectedDays.contains(day)
                                Button(WeekdayHelper.shortName(for: day)) {
                                    if isSelected {
                                        selectedDays.remove(day)
                                    } else {
                                        selectedDays.insert(day)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.borderedProminent)
                                .tint(isSelected ? Color.appGreen : Color.gray.opacity(0.25))
                            }
                        }
                        if selectedDays.isEmpty {
                            Label("曜日を1つ以上選択してください",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 4)

                    DatePicker("開始時刻", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("終了時刻", selection: $endTime,   displayedComponents: .hourAndMinute)

                    if startTime >= endTime {
                        Label("終了時刻は開始時刻より後に設定してください",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Toggle("昼休みの写真を除外する", isOn: $excludeBreak)
                    if excludeBreak {
                        DatePicker("休憩開始", selection: $breakStart, displayedComponents: .hourAndMinute)
                        DatePicker("休憩終了", selection: $breakEnd,   displayedComponents: .hourAndMinute)
                        if breakStart >= breakEnd {
                            Label("休憩終了は開始より後に設定してください",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text("昼休み除外")
                } footer: {
                    Text("授業時間が昼休みを跨ぐ場合、指定した時間帯の写真をアルバムから除外します")
                        .font(.caption)
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
        let sc  = cal.dateComponents([.hour, .minute], from: startTime)
        let ec  = cal.dateComponents([.hour, .minute], from: endTime)
        let bsc = cal.dateComponents([.hour, .minute], from: breakStart)
        let bec = cal.dateComponents([.hour, .minute], from: breakEnd)
        viewModel.updateSchedule(
            schedule,
            subjectName: className.trimmingCharacters(in: .whitespaces),
            professor: professor.trimmingCharacters(in: .whitespaces),
            room: room.trimmingCharacters(in: .whitespaces),
            daysOfWeek: selectedDays.sorted(),
            startTimeSeconds: (sc.hour ?? 0) * 3600 + (sc.minute ?? 0) * 60,
            endTimeSeconds:   (ec.hour ?? 0) * 3600 + (ec.minute ?? 0) * 60,
            firstClassDate: setFirstClassDate ? Calendar.current.startOfDay(for: firstClassDate) : nil,
            breakStartSeconds: excludeBreak ? (bsc.hour ?? 0) * 3600 + (bsc.minute ?? 0) * 60 : nil,
            breakEndSeconds:   excludeBreak ? (bec.hour ?? 0) * 3600 + (bec.minute ?? 0) * 60 : nil
        )
    }
}
