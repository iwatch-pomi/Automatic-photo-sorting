import SwiftUI

/// 補講日の新規追加と編集を兼ねるフォーム。`makeup == nil` で新規、非nilで編集。
/// AddMakeupClassView / EditMakeupClassView は本ビューの薄いラッパー。
struct MakeupClassFormView: View {
    var viewModel: TimetableViewModel
    let makeup: MakeupClass?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedScheduleID: UUID?
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var room: String
    @State private var note: String

    private var isEditing: Bool { makeup != nil }

    init(viewModel: TimetableViewModel, makeup: MakeupClass?) {
        self.viewModel = viewModel
        self.makeup = makeup
        let cal = Calendar.current
        if let makeup {
            _selectedScheduleID = State(initialValue: makeup.scheduleID)
            _date = State(initialValue: makeup.date)
            _startTime = State(initialValue: cal.date(secondsFromMidnight: makeup.startSeconds, on: makeup.date))
            _endTime   = State(initialValue: cal.date(secondsFromMidnight: makeup.endSeconds, on: makeup.date))
            _room = State(initialValue: makeup.room)
            _note = State(initialValue: makeup.note)
        } else {
            _selectedScheduleID = State(initialValue: nil)
            _date = State(initialValue: Date())
            _startTime = State(initialValue: cal.date(secondsFromMidnight: 9 * 3600))
            _endTime   = State(initialValue: cal.date(secondsFromMidnight: 9 * 3600 + 90 * 60))
            _room = State(initialValue: "")
            _note = State(initialValue: "")
        }
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
                        if !isEditing {
                            Text("選択してください").tag(Optional<UUID>.none)
                        }
                        ForEach(viewModel.schedules, id: \.id) { s in
                            Text(s.subjectName).tag(Optional(s.id))
                        }
                    }
                }

                Section("日時") {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                        .id("makeupDate")
                    DatePicker("開始時刻", selection: $startTime, displayedComponents: .hourAndMinute)
                        .id("makeupStartTime")
                    DatePicker("終了時刻", selection: $endTime,   displayedComponents: .hourAndMinute)
                        .id("makeupEndTime")
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
            .navigationTitle(isEditing ? "補講日を編集" : "補講日を追加")
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
            // 新規時のみ、授業選択で時刻・教室をその授業のデフォルトに合わせる
            .onChange(of: selectedScheduleID) {
                if !isEditing { applyScheduleDefaults() }
            }
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
        let startSeconds = cal.secondsFromMidnight(for: startTime)
        let endSeconds   = cal.secondsFromMidnight(for: endTime)
        let trimmedRoom = room.trimmingCharacters(in: .whitespaces)
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)
        if let makeup {
            viewModel.updateMakeupClass(
                makeup, scheduleID: scheduleID, date: cal.startOfDay(for: date),
                startSeconds: startSeconds, endSeconds: endSeconds,
                room: trimmedRoom, note: trimmedNote
            )
        } else {
            viewModel.addMakeupClass(
                scheduleID: scheduleID, date: cal.startOfDay(for: date),
                startSeconds: startSeconds, endSeconds: endSeconds,
                room: trimmedRoom, note: trimmedNote
            )
        }
    }
}

// MARK: - 薄いラッパー（呼び出し側の互換性のため）

struct AddMakeupClassView: View {
    var viewModel: TimetableViewModel
    var body: some View { MakeupClassFormView(viewModel: viewModel, makeup: nil) }
}

struct EditMakeupClassView: View {
    var viewModel: TimetableViewModel
    let makeup: MakeupClass
    var body: some View { MakeupClassFormView(viewModel: viewModel, makeup: makeup) }
}
