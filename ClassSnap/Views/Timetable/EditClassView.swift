import SwiftUI

struct EditClassView: View {
    var viewModel: TimetableViewModel
    let schedule: ClassSchedule
    @Environment(\.dismiss) private var dismiss

    @State private var className: String
    @State private var professor: String
    @State private var room: String
    @State private var selectedDays: Set<Int>
    @State private var selectedTermIDs: Set<UUID>
    @State private var selectedPeriodID: Int?
    @State private var usePerDayTime: Bool
    @State private var uniformStartTime: Date
    @State private var uniformEndTime: Date
    @State private var perDayStartTimes: [Int: Date]
    @State private var perDayEndTimes: [Int: Date]
    @State private var setFirstClassDate: Bool
    @State private var firstClassDate: Date
    @State private var savePhotosEnabled: Bool
    @State private var excludeBreak: Bool
    @State private var breakStart: Date
    @State private var breakEnd: Date

    // OFF 切替時の保存写真削除確認
    @State private var showDeleteSavedConfirm = false
    private let wasSavingEnabled: Bool

    init(viewModel: TimetableViewModel, schedule: ClassSchedule) {
        self.viewModel = viewModel
        self.schedule = schedule
        _className = State(initialValue: schedule.subjectName)
        _professor = State(initialValue: schedule.professor)
        _room = State(initialValue: schedule.room)
        _selectedDays = State(initialValue: Set(schedule.daysOfWeek))
        _selectedTermIDs = State(initialValue: Set(schedule.termIDs))
        let isUniform = schedule.hasUniformTime
        _usePerDayTime = State(initialValue: !isUniform)
        let base = Calendar.current.startOfDay(for: Date())
        let firstStart = schedule.startTimesSeconds.first ?? 32400
        let firstEnd   = schedule.endTimesSeconds.first ?? 37800
        _uniformStartTime = State(initialValue: base.addingTimeInterval(TimeInterval(firstStart)))
        _uniformEndTime   = State(initialValue: base.addingTimeInterval(TimeInterval(firstEnd)))
        let matchedID = ClassPeriodStore.shared.matchingPeriodID(startSeconds: firstStart, endSeconds: firstEnd)
        _selectedPeriodID = State(initialValue: matchedID)
        var starts: [Int: Date] = [:]
        var ends: [Int: Date] = [:]
        for (i, day) in schedule.daysOfWeek.enumerated() {
            let s = i < schedule.startTimesSeconds.count ? schedule.startTimesSeconds[i] : firstStart
            let e = i < schedule.endTimesSeconds.count   ? schedule.endTimesSeconds[i]   : firstEnd
            starts[day] = base.addingTimeInterval(TimeInterval(s))
            ends[day]   = base.addingTimeInterval(TimeInterval(e))
        }
        _perDayStartTimes = State(initialValue: starts)
        _perDayEndTimes   = State(initialValue: ends)
        _setFirstClassDate = State(initialValue: schedule.firstClassDate != nil)
        _firstClassDate = State(initialValue: schedule.firstClassDate ?? Date())
        _savePhotosEnabled = State(initialValue: schedule.savePhotosEnabled)
        wasSavingEnabled = schedule.savePhotosEnabled
        _excludeBreak = State(initialValue: schedule.breakStartSeconds != nil)
        let defaultBreakStart = base.addingTimeInterval(TimeInterval(schedule.breakStartSeconds ?? AppSettings.shared.lunchBreakStartSeconds))
        let defaultBreakEnd   = base.addingTimeInterval(TimeInterval(schedule.breakEndSeconds   ?? AppSettings.shared.lunchBreakEndSeconds))
        _breakStart = State(initialValue: defaultBreakStart)
        _breakEnd   = State(initialValue: defaultBreakEnd)
    }

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
            .navigationTitle("授業を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { attemptSave() }
                        .disabled(!isValid)
                }
            }
            .confirmationDialog(
                "保存した写真を削除しますか？",
                isPresented: $showDeleteSavedConfirm,
                titleVisibility: .visible
            ) {
                Button("保存した写真を削除（\(savedSizeText)）", role: .destructive) {
                    viewModel.deleteSavedPhotos(for: schedule.id)
                    save()
                    dismiss()
                }
                Button("アプリ内に残す（保存はオンのまま）") {
                    savePhotosEnabled = true
                    save()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("「アプリ内に保存」をオフにしました。この授業のためにアプリ内へ保存した写真を削除すると、写真アプリから削除済みの写真はアプリでも見られなくなります。")
            }
        }
    }

    private var savedSizeText: String {
        ByteCountFormatter.string(fromByteCount: SavedPhotoStore.shared.totalBytes(for: schedule.id),
                                  countStyle: .file)
    }

    /// 保存をオフにした際、保存写真があれば確認ダイアログを出す。それ以外は即保存。
    private func attemptSave() {
        if wasSavingEnabled && !savePhotosEnabled && SavedPhotoStore.shared.hasSavedPhotos(for: schedule.id) {
            showDeleteSavedConfirm = true
        } else {
            save()
            dismiss()
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
        viewModel.updateSchedule(
            schedule,
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
