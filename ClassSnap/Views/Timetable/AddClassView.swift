import SwiftUI

struct AddClassView: View {
    var viewModel: TimetableViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var className: String = ""
    @State private var professor: String = ""
    @State private var room: String = ""
    @State private var selectedDays: Set<Int> = [1]
    @State private var selectedTermIDs: Set<UUID> = {
        if let current = TermStore.shared.currentTerm { return [current.id] }
        return []
    }()
    @State private var selectedPeriodIDs: Set<Int> = {
        if let first = ClassPeriodStore.shared.periods.first { return [first.id] }
        return []
    }()
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
    @State private var savePhotosEnabled: Bool = false
    @State private var excludeBreak: Bool = false
    @State private var breakStart: Date = Calendar.current.startOfDay(for: Date())
        .addingTimeInterval(TimeInterval(AppSettings.shared.lunchBreakStartSeconds))
    @State private var breakEnd: Date = Calendar.current.startOfDay(for: Date())
        .addingTimeInterval(TimeInterval(AppSettings.shared.lunchBreakEndSeconds))

    private var isValid: Bool {
        guard !className.trimmingCharacters(in: .whitespaces).isEmpty && !selectedDays.isEmpty else { return false }
        if selectedPeriodIDs.isEmpty {
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
                Section {
                    TextField("授業名（例: 微生物学）", text: $className)
                    TextField("担当教員（例: J. グライアン教授）", text: $professor)
                    TextField("教室（例: Room 302）", text: $room)
                    if !TermStore.shared.terms.isEmpty {
                        ForEach(TermStore.shared.terms, id: \.id) { term in
                            Toggle(isOn: Binding(
                                get: { selectedTermIDs.contains(term.id) },
                                set: { if $0 { selectedTermIDs.insert(term.id) } else { selectedTermIDs.remove(term.id) } }
                            )) {
                                HStack(spacing: 6) {
                                    if term.isActive {
                                        Circle().fill(Color.appGreen).frame(width: 6, height: 6)
                                    }
                                    Text(term.name)
                                }
                            }
                            .tint(Color.appGreen)
                        }
                    }
                } header: {
                    Text("授業情報")
                } footer: {
                    if !TermStore.shared.terms.isEmpty {
                        Text("複数の学期にまたがる授業は対象学期をすべてオンにしてください。選択なしの場合は全学期で表示されます。")
                            .font(.caption)
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

                Section {
                    Toggle("写真をアプリ内に保存", isOn: $savePhotosEnabled)
                        .tint(Color.appGreen)
                } header: {
                    Text("アプリ内保存")
                } footer: {
                    Text("オン：この授業に一致した写真をアプリ内にコピーします。iPhoneの写真アプリから削除しても、アプリ内に残り続けます（端末の保存容量を使用します）。\nオフ：アプリ内には保存しません。写真アプリから写真を削除すると、アプリのアルバムからも見られなくなります。")
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
                        PeriodSelectorView(selectedPeriodIDs: $selectedPeriodIDs,
                                           periods: ClassPeriodStore.shared.periods)
                            .onChange(of: selectedPeriodIDs) { applyPeriods() }
                    }

                    if selectedPeriodIDs.isEmpty {
                        if selectedDays.count > 1 {
                            Toggle("曜日ごとに異なる時間を設定", isOn: $usePerDayTime)
                        }

                        if !usePerDayTime || selectedDays.count == 1 {
                            DatePicker("開始時刻", selection: $uniformStartTime, displayedComponents: .hourAndMinute)
                                .id("uniformStartTime")
                            DatePicker("終了時刻", selection: $uniformEndTime,   displayedComponents: .hourAndMinute)
                                .id("uniformEndTime")
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
                                        .id("\(day)_startTime")
                                    DatePicker("終了", selection: endBinding,   displayedComponents: .hourAndMinute)
                                        .id("\(day)_endTime")
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

    private func applyPeriods() {
        let selected = ClassPeriodStore.shared.periods.filter { selectedPeriodIDs.contains($0.id) }
        guard let minStart = selected.map(\.startSeconds).min(),
              let maxEnd   = selected.map(\.endSeconds).max() else { return }
        let base = Calendar.current.startOfDay(for: Date())
        uniformStartTime = base.addingTimeInterval(TimeInterval(minStart))
        uniformEndTime   = base.addingTimeInterval(TimeInterval(maxEnd))
    }

    private func save() {
        let cal = Calendar.current
        let sortedDays = selectedDays.sorted()
        var starts: [Int] = []
        var ends: [Int] = []
        let usePerDay = selectedPeriodIDs.isEmpty && usePerDayTime && selectedDays.count > 1
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
            termIDs: Array(selectedTermIDs),
            savePhotosEnabled: savePhotosEnabled
        )
    }
}

// MARK: - コマ複数選択

/// コマ（時限）を複数選択できるビュー。連続コマ授業は開始＝最も早いコマ、終了＝最も遅いコマで扱う。
struct PeriodSelectorView: View {
    @Binding var selectedPeriodIDs: Set<Int>
    let periods: [ClassPeriod]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("コマ（連続する複数コマを選択できます）")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(periods) { period in
                        let isSelected = selectedPeriodIDs.contains(period.id)
                        Button {
                            if isSelected { selectedPeriodIDs.remove(period.id) }
                            else { selectedPeriodIDs.insert(period.id) }
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(period.id)")
                                    .font(.system(size: 15, weight: .bold))
                                Text(period.timeRange)
                                    .font(.system(size: 9))
                            }
                            .frame(minWidth: 66)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 6)
                            .background(isSelected ? Color.appGreen : Color.gray.opacity(0.15))
                            .foregroundStyle(isSelected ? .white : Color.appTextPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if selectedPeriodIDs.isEmpty {
                Text("コマを選択しない場合は、下で時刻を手動で設定できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("設定時間: \(spanDisplay)")
                    .font(.caption)
                    .foregroundStyle(Color.appGreen)
            }
        }
        .padding(.vertical, 4)
    }

    private var spanDisplay: String {
        let selected = periods.filter { selectedPeriodIDs.contains($0.id) }
        guard let minStart = selected.map(\.startSeconds).min(),
              let maxEnd   = selected.map(\.endSeconds).max() else { return "-" }
        func fmt(_ s: Int) -> String { String(format: "%d:%02d", s / 3600, (s % 3600) / 60) }
        return "\(fmt(minStart))〜\(fmt(maxEnd))"
    }
}
