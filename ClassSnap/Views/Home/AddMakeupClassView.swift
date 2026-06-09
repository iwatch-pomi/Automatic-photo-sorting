import SwiftUI

struct AddMakeupClassView: View {
    var viewModel: TimetableViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedScheduleID: UUID?
    @State private var date = Date()
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var room = ""
    @State private var note = ""

    init(viewModel: TimetableViewModel) {
        self.viewModel = viewModel
        let base = Calendar.current.startOfDay(for: Date())
        _startTime = State(initialValue: base.addingTimeInterval(9 * 3600))
        _endTime   = State(initialValue: base.addingTimeInterval(10.5 * 3600))
    }

    private var selectedSchedule: ClassSchedule? {
        viewModel.schedules.first { $0.id == selectedScheduleID }
    }

    private var isValid: Bool {
        selectedScheduleID != nil && startTime < endTime
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("授業") {
                    Picker("授業を選択", selection: $selectedScheduleID) {
                        Text("選択してください").tag(Optional<UUID>.none)
                        ForEach(viewModel.schedules, id: \.id) { s in
                            Text(s.subjectName).tag(Optional(s.id))
                        }
                    }
                }

                Section("日時") {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    DatePicker("開始時刻", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("終了時刻", selection: $endTime,   displayedComponents: .hourAndMinute)
                    if startTime >= endTime {
                        Label("終了時刻は開始時刻より後にしてください",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                Section("詳細（任意）") {
                    TextField("教室", text: $room)
                    TextField("メモ", text: $note)
                }
            }
            .navigationTitle("補講日を追加")
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
            .onChange(of: selectedScheduleID) { applyScheduleDefaults() }
        }
    }

    private func applyScheduleDefaults() {
        guard let sch = selectedSchedule else { return }
        let cal = Calendar.current
        startTime = cal.date(secondsFromMidnight: sch.startTimesSeconds.first ?? 32400)
        endTime   = cal.date(secondsFromMidnight: sch.endTimesSeconds.first ?? 37800)
        room = sch.room
    }

    private func save() {
        guard let scheduleID = selectedScheduleID else { return }
        let cal = Calendar.current
        viewModel.addMakeupClass(
            scheduleID: scheduleID,
            date: cal.startOfDay(for: date),
            startSeconds: cal.secondsFromMidnight(for: startTime),
            endSeconds:   cal.secondsFromMidnight(for: endTime),
            room: room.trimmingCharacters(in: .whitespaces),
            note: note.trimmingCharacters(in: .whitespaces)
        )
    }
}

// MARK: - 補講日編集

struct EditMakeupClassView: View {
    var viewModel: TimetableViewModel
    let makeup: MakeupClass
    @Environment(\.dismiss) private var dismiss

    @State private var selectedScheduleID: UUID
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var room: String
    @State private var note: String

    init(viewModel: TimetableViewModel, makeup: MakeupClass) {
        self.viewModel = viewModel
        self.makeup = makeup
        _selectedScheduleID = State(initialValue: makeup.scheduleID)
        _date = State(initialValue: makeup.date)
        let base = Calendar.current.startOfDay(for: makeup.date)
        _startTime = State(initialValue: base.addingTimeInterval(TimeInterval(makeup.startSeconds)))
        _endTime   = State(initialValue: base.addingTimeInterval(TimeInterval(makeup.endSeconds)))
        _room = State(initialValue: makeup.room)
        _note = State(initialValue: makeup.note)
    }

    private var isValid: Bool { startTime < endTime }

    var body: some View {
        NavigationStack {
            Form {
                Section("授業") {
                    Picker("授業を選択", selection: $selectedScheduleID) {
                        ForEach(viewModel.schedules, id: \.id) { s in
                            Text(s.subjectName).tag(s.id)
                        }
                    }
                }

                Section("日時") {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    DatePicker("開始時刻", selection: $startTime, displayedComponents: .hourAndMinute)
                        .id("editStartTime")
                    DatePicker("終了時刻", selection: $endTime,   displayedComponents: .hourAndMinute)
                        .id("editEndTime")
                    if startTime >= endTime {
                        Label("終了時刻は開始時刻より後にしてください",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                Section("詳細（任意）") {
                    TextField("教室", text: $room)
                    TextField("メモ", text: $note)
                }
            }
            .navigationTitle("補講日を編集")
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
        viewModel.updateMakeupClass(
            makeup,
            scheduleID: selectedScheduleID,
            date: cal.startOfDay(for: date),
            startSeconds: cal.secondsFromMidnight(for: startTime),
            endSeconds:   cal.secondsFromMidnight(for: endTime),
            room: room.trimmingCharacters(in: .whitespaces),
            note: note.trimmingCharacters(in: .whitespaces)
        )
    }
}
