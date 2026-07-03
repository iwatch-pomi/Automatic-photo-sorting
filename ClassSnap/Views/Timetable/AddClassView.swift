import SwiftUI

/// 授業の新規追加と編集を兼ねるフォーム。`schedule == nil` で新規、非nilで編集。
/// AddClassView / EditClassView は本ビューの薄いラッパー。
struct ClassFormView: View {
    let stores: AppStores
    let schedule: ClassSchedule?
    @Environment(\.dismiss) private var dismiss

    @State private var className: String
    @State private var professor: String
    @State private var room: String
    @State private var selectedDays: Set<Int>
    @State private var selectedTermIDs: Set<UUID>
    @State private var selectedPeriodIDs: Set<Int>
    @State private var usePerDayTime: Bool
    @State private var uniformStartTime: Date
    @State private var uniformEndTime: Date
    @State private var perDayStartTimes: [Int: Date]
    @State private var perDayEndTimes: [Int: Date]
    @State private var setFirstClassDate: Bool
    @State private var firstClassDate: Date
    @State private var savePhotosEnabled: Bool
    @State private var colorIndex: Int?
    @State private var showPaywall: Bool = false
    @State private var excludeBreak: Bool
    @State private var breakStart: Date
    @State private var breakEnd: Date

    // 編集時のみ：保存OFF切替時の保存写真削除確認
    @State private var showDeleteSavedConfirm = false
    private let wasSavingEnabled: Bool

    private var isEditing: Bool { schedule != nil }

    init(stores: AppStores, schedule: ClassSchedule?) {
        self.stores = stores
        self.schedule = schedule
        let cal = Calendar.current

        if let schedule {
            // 編集：既存の値を復元
            _className = State(initialValue: schedule.subjectName)
            _professor = State(initialValue: schedule.professor)
            _room = State(initialValue: schedule.room)
            _selectedDays = State(initialValue: Set(schedule.daysOfWeek))
            _selectedTermIDs = State(initialValue: Set(schedule.termIDs))
            let isUniform = schedule.hasUniformTime
            _usePerDayTime = State(initialValue: !isUniform)
            let firstStart = schedule.startTimesSeconds.first ?? 32400
            let firstEnd   = schedule.endTimesSeconds.first ?? 37800
            _uniformStartTime = State(initialValue: cal.date(secondsFromMidnight: firstStart))
            _uniformEndTime   = State(initialValue: cal.date(secondsFromMidnight: firstEnd))
            // 保存済みの時間帯に収まるコマ群を復元（単一・連続コマ両対応）。一致しなければカスタム。
            var matchedIDs: Set<Int> = []
            if isUniform {
                let spanned = ClassPeriodStore.shared.periods.filter {
                    $0.startSeconds >= firstStart && $0.endSeconds <= firstEnd
                }
                if let mn = spanned.map(\.startSeconds).min(),
                   let mx = spanned.map(\.endSeconds).max(),
                   mn == firstStart, mx == firstEnd {
                    matchedIDs = Set(spanned.map(\.id))
                }
            }
            _selectedPeriodIDs = State(initialValue: matchedIDs)
            var starts: [Int: Date] = [:]
            var ends: [Int: Date] = [:]
            for (i, day) in schedule.daysOfWeek.enumerated() {
                let s = i < schedule.startTimesSeconds.count ? schedule.startTimesSeconds[i] : firstStart
                let e = i < schedule.endTimesSeconds.count   ? schedule.endTimesSeconds[i]   : firstEnd
                starts[day] = cal.date(secondsFromMidnight: s)
                ends[day]   = cal.date(secondsFromMidnight: e)
            }
            _perDayStartTimes = State(initialValue: starts)
            _perDayEndTimes   = State(initialValue: ends)
            _setFirstClassDate = State(initialValue: schedule.firstClassDate != nil)
            _firstClassDate = State(initialValue: schedule.firstClassDate ?? Date())
            _savePhotosEnabled = State(initialValue: schedule.savePhotosEnabled)
            _colorIndex = State(initialValue: schedule.colorIndex)
            wasSavingEnabled = schedule.savePhotosEnabled
            _excludeBreak = State(initialValue: schedule.breakStartSeconds != nil)
            _breakStart = State(initialValue: cal.date(secondsFromMidnight: schedule.breakStartSeconds ?? AppSettings.shared.lunchBreakStartSeconds))
            _breakEnd   = State(initialValue: cal.date(secondsFromMidnight: schedule.breakEndSeconds   ?? AppSettings.shared.lunchBreakEndSeconds))
        } else {
            // 新規：デフォルト値
            _className = State(initialValue: "")
            _professor = State(initialValue: "")
            _room = State(initialValue: "")
            _selectedDays = State(initialValue: [1])
            // 表示中（選択中）の学期を優先。未選択（全期間）のときのみ現在学期にフォールバック。
            // currentTerm をデフォルトにすると、別学期を表示中に追加した授業が直後に見えなくなる。
            let defaultTermID = stores.term.selectedTermID ?? stores.term.currentTerm?.id
            _selectedTermIDs = State(initialValue: defaultTermID.map { [$0] } ?? [])
            _selectedPeriodIDs = State(initialValue: ClassPeriodStore.shared.periods.first.map { [$0.id] } ?? [])
            _usePerDayTime = State(initialValue: false)
            let p = ClassPeriodStore.shared.periods.first
            _uniformStartTime = State(initialValue: cal.date(secondsFromMidnight: p?.startSeconds ?? 9 * 3600))
            _uniformEndTime   = State(initialValue: cal.date(secondsFromMidnight: p?.endSeconds ?? (9 * 3600 + 90 * 60)))
            _perDayStartTimes = State(initialValue: [:])
            _perDayEndTimes   = State(initialValue: [:])
            _setFirstClassDate = State(initialValue: false)
            _firstClassDate = State(initialValue: Date())
            _savePhotosEnabled = State(initialValue: false)
            _colorIndex = State(initialValue: nil)
            wasSavingEnabled = false
            _excludeBreak = State(initialValue: false)
            _breakStart = State(initialValue: cal.date(secondsFromMidnight: AppSettings.shared.lunchBreakStartSeconds))
            _breakEnd   = State(initialValue: cal.date(secondsFromMidnight: AppSettings.shared.lunchBreakEndSeconds))
        }
    }

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
                classInfoSection
                firstClassDateSection
                savePhotosSection
                timingSection
                breakSection
            }
            .navigationTitle(isEditing ? "授業を編集" : "授業を追加")
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
                    if let schedule { stores.schedule.deleteSavedPhotos(for: schedule.id) }
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

    // MARK: - Sections

    /// 授業セルの色を8色パレットから選ぶ行。未選択時は自動割当（複数授業で同じ色も選択可）。
    private var colorPickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("色")
                .foregroundStyle(Color.appTextPrimary)
            HStack(spacing: 12) {
                ForEach(ClassColorPalette.colors.indices, id: \.self) { i in
                    let isSelected = colorIndex == i
                    Circle()
                        .fill(ClassColorPalette.colors[i])
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.appGreen, lineWidth: isSelected ? 3 : 0)
                        )
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.caption).fontWeight(.bold)
                                .foregroundStyle(Color.appGreen)
                                .opacity(isSelected ? 1 : 0)
                        )
                        .contentShape(Circle())
                        .onTapGesture { colorIndex = i }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var classInfoSection: some View {
        Section {
            TextField("授業名（例: 微生物学）", text: $className)
            TextField("担当教員（例: J. グライアン教授）", text: $professor)
            TextField("教室（例: Room 302）", text: $room)
            colorPickerRow
            if !stores.term.terms.isEmpty {
                ForEach(stores.term.terms, id: \.id) { term in
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
            if !stores.term.terms.isEmpty {
                Text("複数の学期にまたがる授業は対象学期をすべてオンにしてください。選択なしの場合は全学期で表示されます。")
                    .font(.caption)
            }
        }
    }

    private var firstClassDateSection: some View {
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
    }

    private var savePhotosSection: some View {
        Section {
            ProFeatureToggle("写真をアプリ内に保存", isOn: $savePhotosEnabled, showPaywall: $showPaywall)
        } header: {
            Text("アプリ内保存")
        } footer: {
            Text("オン：この授業に一致した写真をアプリ内にコピーします。iPhoneの写真アプリから削除しても、アプリ内に残り続けます（端末の保存容量を使用します）。\nオフ：アプリ内には保存しません。写真アプリから写真を削除すると、アプリのアルバムからも見られなくなります。")
                .font(.caption)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var timingSection: some View {
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
                // 複数曜日が選ばれたとき、per-day設定の存在を常にヒントで伝える
                if selectedDays.count > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.caption2)
                            .foregroundStyle(Color.appGreen)
                        Text("曜日ごとに異なる時間を個別に設定することもできます")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
            .padding(.vertical, 4)

            if ClassPeriodStore.shared.hasPeriods {
                PeriodSelectorView(selectedPeriodIDs: $selectedPeriodIDs,
                                   periods: ClassPeriodStore.shared.periods)
                    .onChange(of: selectedPeriodIDs) { applyPeriods() }
                // コマ選択中 + 複数曜日：解除すれば per-day 設定できることを案内
                if selectedDays.count > 1 && !selectedPeriodIDs.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.turn.down.left")
                            .font(.caption2)
                            .foregroundStyle(Color.appGreen.opacity(0.7))
                        Text("コマの選択を解除すると、曜日ごとに時間を個別入力できます")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }

            if selectedPeriodIDs.isEmpty {
                if selectedDays.count > 1 {
                    Toggle("曜日ごとに異なる時間を設定", isOn: $usePerDayTime)
                        .tint(Color.appGreen)
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
    }

    private var breakSection: some View {
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

    // MARK: - Helpers

    private var savedSizeText: String {
        guard let schedule else { return "" }
        return ByteCountFormatter.string(fromByteCount: SavedPhotoStore.shared.totalBytes(for: schedule.id),
                                         countStyle: .file)
    }

    /// 編集時、保存をオフにした際に保存写真があれば確認ダイアログを出す。それ以外は即保存。
    private func attemptSave() {
        if let schedule, wasSavingEnabled, !savePhotosEnabled,
           SavedPhotoStore.shared.hasSavedPhotos(for: schedule.id) {
            showDeleteSavedConfirm = true
        } else {
            save()
            dismiss()
        }
    }

    private func applyPeriods() {
        let selected = ClassPeriodStore.shared.periods.filter { selectedPeriodIDs.contains($0.id) }
        guard let minStart = selected.map(\.startSeconds).min(),
              let maxEnd   = selected.map(\.endSeconds).max() else { return }
        let cal = Calendar.current
        uniformStartTime = cal.date(secondsFromMidnight: minStart)
        uniformEndTime   = cal.date(secondsFromMidnight: maxEnd)
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
            starts.append(cal.secondsFromMidnight(for: sDate))
            ends.append(cal.secondsFromMidnight(for: eDate))
        }
        let trimmedName = className.trimmingCharacters(in: .whitespaces)
        let trimmedProf = professor.trimmingCharacters(in: .whitespaces)
        let trimmedRoom = room.trimmingCharacters(in: .whitespaces)
        let fcd = setFirstClassDate ? cal.startOfDay(for: firstClassDate) : nil
        let bStart = excludeBreak ? cal.secondsFromMidnight(for: breakStart) : nil
        let bEnd   = excludeBreak ? cal.secondsFromMidnight(for: breakEnd) : nil
        let termIDs = Array(selectedTermIDs)

        if let schedule {
            stores.schedule.updateSchedule(
                schedule,
                subjectName: trimmedName, professor: trimmedProf, room: trimmedRoom,
                daysOfWeek: sortedDays,
                startTimesSeconds: starts, endTimesSeconds: ends,
                firstClassDate: fcd,
                breakStartSeconds: bStart, breakEndSeconds: bEnd,
                termIDs: termIDs, savePhotosEnabled: savePhotosEnabled,
                colorIndex: colorIndex
            )
        } else {
            stores.schedule.addSchedule(
                subjectName: trimmedName, professor: trimmedProf, room: trimmedRoom,
                daysOfWeek: sortedDays,
                startTimesSeconds: starts, endTimesSeconds: ends,
                firstClassDate: fcd,
                breakStartSeconds: bStart, breakEndSeconds: bEnd,
                termIDs: termIDs, savePhotosEnabled: savePhotosEnabled,
                colorIndex: colorIndex
            )
        }
    }
}

// MARK: - 薄いラッパー（呼び出し側の互換性のため）

struct AddClassView: View {
    let stores: AppStores
    var body: some View { ClassFormView(stores: stores, schedule: nil) }
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
            if !selectedPeriodIDs.isEmpty {
                Text("設定時間: \(spanDisplay)")
                    .font(.caption)
                    .foregroundStyle(Color.appGreen)
            }
            Text("コマを選択しない場合は、下で時刻を手動で設定できます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var spanDisplay: String {
        let selected = periods.filter { selectedPeriodIDs.contains($0.id) }
        guard let minStart = selected.map(\.startSeconds).min(),
              let maxEnd   = selected.map(\.endSeconds).max() else { return "-" }
        return "\(TimeFormat.hm(minStart))〜\(TimeFormat.hm(maxEnd))"
    }
}
