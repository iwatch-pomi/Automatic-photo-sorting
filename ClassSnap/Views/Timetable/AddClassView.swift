import SwiftUI

struct AddClassView: View {
    var viewModel: TimetableViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var className: String = ""
    @State private var professor: String = ""
    @State private var room: String = ""
    @State private var selectedDays: Set<Int> = [1]
    @State private var selectedTermID: UUID? = TermStore.shared.currentTerm?.id
    @State private var selectedPeriodID: Int? = ClassPeriodStore.shared.periods.first?.id
    @State private var usePerDayTime: Bool = false
    @State private var uniformStartTime: Date = {
        let p = ClassPeriodStore.shared.periods.first
        let base = Calendar.current.startOfDay(for: Date())
        return base.addingTimeInterval(TimeInterval(p?.startSeconds ?? 9 * 3600))
    }()
    @State private var uniformEndTime: Date = {
        let p = ClassPeriodStore.shared.periods.first
        let base = Calendar.current.startOfDay(for: Date())
        return base.addingTimeInterval(TimeInterval(p?.endSeconds ?? (9 * 3600 + 90 * 60)))
    }()
    @State private var perDayStartTimes: [Int: Date] = [:]
    @State private var perDayEndTimes: [Int: Date] = [:]
    @State private var setFirstClassDate: Bool = false
    @State private var firstClassDate: Date = Date()
    @State private var excludeBreak: Bool = false
    @State private var breakStart: Date = Calendar.current.startOfDay(for: Date())
        .addingTimeInterval(TimeInterval(AppSettings.shared.lunchBreakStartSeconds))
    @State private var breakEnd: Date = Calendar.current.startOfDay(for: Date())
        .addingTimeInterval(TimeInterval(AppSettings.shared.lunchBreakEndSeconds))

    private var isValid: Bool {
        guard !className.trimmingCharacters(in: .whitespaces).isEmpty && !selectedDays.isEmpty else { return false }
        if selectedPeriodID == nil {
            if usePerDayTime && selectedDays.count > 1 {
                for day in selectedDays {
                    let s = perDayStartTimes[day] ?? uniformStartTime
                    let e = perDayEndTimes[day] ?? uniformEndTime
                    if s >= e { return false }
                }
            } else {
                if uniformStartTime >= uniformEndTime { return false }
            }
        }
        return !excludeBreak || breakStart < breakEnd
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("授業情報") {
                    TextField("授業名（例: 微生物学）", text: $className)
                    TextField("担当教員（例: J. グライアン教授）", text: $professor)
                    TextField("教室（例: Room 302）", text: $room)
                    if !TermStore.shared.terms.isEmpty {
                        Picker("学期", selection: $selectedTermID) {
                            Text("指定なし").tag(Optional<UUID>.none)
                            ForEach(TermStore.shared.terms, id: \.id) { term in
                                Text(term.name).tag(Optional(term.id))
                            }
                        }
                    }
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
                                        if selectedDays.count > 1 { selectedDays.remove(day) }
                                    } else {
                                        selectedDays.insert(day)
                                        if perDayStartTimes[day] == nil {
                                            perDayStartTimes[day] = uniformStartTime
                                            perDayEndTimes[day] = uniformEndTime
                                        }
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

                    if ClassPeriodStore.shared.hasPeriods {
                        Picker("コマ", selection: $selectedPeriodID) {
                            ForEach(ClassPeriodStore.shared.periods) { period in
                                Text(period.label).tag(Optional(period.id))
                            }
                            Text("カスタム").tag(Optional<Int>.none)
                        }
                        .onChange(of: selectedPeriodID) { applyPeriod() }
                    }

                    if selectedPeriodID == nil {
                        if selectedDays.count > 1 {
                            Toggle("曜日ごとに異なる時間を設定", isOn: $usePerDayTime)
                        }

                        if !usePerDayTime || selectedDays.count == 1 {
                            DatePicker("開始時刻", selection: $uniformStartTime, displayedComponents: .hourAndMinute)
                            DatePicker("終了時刻", selection: $uniformEndTime,   displayedComponents: .hourAndMinute)
                            if uniformStartTime >= uniformEndTime {
                                Label("終了時刻は開始時刻より後に設定してください",
                                      systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        } else {
                            ForEach(selectedDays.sorted(), id: \.self) { day in
                                let startBinding = Binding(
                                    get: { perDayStartTimes[day] ?? uniformStartTime },
                                    set: { perDayStartTimes[day] = $0 }
                                )
                                let endBinding = Binding(
                                    get: { perDayEndTimes[day] ?? uniformEndTime },
                                    set: { perDayEndTimes[day] = $0 }
                                )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(WeekdayHelper.name(for: day))
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundStyle(Color.appGreen)
                                    DatePicker("開始", selection: startBinding, displayedComponents: .hourAndMinute)
                                    DatePicker("終了", selection: endBinding,   displayedComponents: .hourAndMinute)
                                    let s = perDayStartTimes[day] ?? uniformStartTime
                                    let e = perDayEndTimes[day] ?? uniformEndTime
                                    if s >= e {
                                        Label("終了時刻は開始時刻より後に設定してください",
                                              systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
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

    private func applyPeriod() {
        guard let id = selectedPeriodID,
              let period = ClassPeriodStore.shared.period(id: id) else { return }
        let base = Calendar.current.startOfDay(for: Date())
        uniformStartTime = base.addingTimeInterval(TimeInterval(period.startSeconds))
        uniformEndTime   = base.addingTimeInterval(TimeInterval(period.endSeconds))
    }

    private func save() {
        let cal = Calendar.current
        let sortedDays = selectedDays.sorted()
        var starts: [Int] = []
        var ends: [Int] = []
        let usePerDay = selectedPeriodID == nil && usePerDayTime && selectedDays.count > 1
        for day in sortedDays {
            let sDate = usePerDay ? (perDayStartTimes[day] ?? uniformStartTime) : uniformStartTime
            let eDate = usePerDay ? (perDayEndTimes[day] ?? uniformEndTime) : uniformEndTime
            let sc = cal.dateComponents([.hour, .minute], from: sDate)
            let ec = cal.dateComponents([.hour, .minute], from: eDate)
            starts.append((sc.hour ?? 0) * 3600 + (sc.minute ?? 0) * 60)
            ends.append((ec.hour ?? 0) * 3600 + (ec.minute ?? 0) * 60)
        }
        let bsc = cal.dateComponents([.hour, .minute], from: breakStart)
        let bec = cal.dateComponents([.hour, .minute], from: breakEnd)
        viewModel.addSchedule(
            subjectName: className.trimmingCharacters(in: .whitespaces),
            professor: professor.trimmingCharacters(in: .whitespaces),
            room: room.trimmingCharacters(in: .whitespaces),
            daysOfWeek: sortedDays,
            startTimesSeconds: starts,
            endTimesSeconds: ends,
            firstClassDate: setFirstClassDate ? Calendar.current.startOfDay(for: firstClassDate) : nil,
            breakStartSeconds: excludeBreak ? (bsc.hour ?? 0) * 3600 + (bsc.minute ?? 0) * 60 : nil,
            breakEndSeconds:   excludeBreak ? (bec.hour ?? 0) * 3600 + (bec.minute ?? 0) * 60 : nil,
            termID: selectedTermID
        )
    }
}
