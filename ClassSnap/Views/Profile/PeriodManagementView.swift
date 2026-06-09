import SwiftUI

struct PeriodManagementView: View {
    @State private var store = ClassPeriodStore.shared
    @State private var showAddSheet = false
    @State private var editingPeriod: ClassPeriod?
    @State private var showPresetConfirm = false
    @State private var showDeleteAllConfirm = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if store.periods.isEmpty {
                emptyView
            } else {
                periodList
            }
        }
        .navigationTitle("コマ時間の設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.appGreen)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddEditPeriodSheet(store: store, existingPeriod: nil)
        }
        .sheet(item: $editingPeriod) { period in
            AddEditPeriodSheet(store: store, existingPeriod: period)
        }
        .confirmationDialog(
            "大学標準のコマ時間に置き換えますか？",
            isPresented: $showPresetConfirm,
            titleVisibility: .visible
        ) {
            Button("置き換える", role: .destructive) { store.applyUniversityPreset() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("1〜5コマ（9:00〜17:50）が設定されます。現在の設定は削除されます。")
        }
        .confirmationDialog(
            "すべてのコマ設定を削除しますか？",
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button("すべて削除", role: .destructive) { store.deleteAll() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "コマが設定されていません",
                systemImage: "clock.badge.questionmark",
                description: Text("授業登録時にコマを選択できるようになります")
            )
            Button {
                showPresetConfirm = true
            } label: {
                Label("大学標準のコマを追加", systemImage: "wand.and.stars")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.appGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var periodList: some View {
        List {
            Section {
                ForEach(store.periods) { period in
                    Button {
                        editingPeriod = period
                    } label: {
                        HStack {
                            Text("\(period.id)コマ目")
                                .font(.headline)
                                .foregroundStyle(Color.appTextPrimary)
                            Spacer()
                            Text(period.timeRange)
                                .foregroundStyle(Color.appTextSecondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Color.appTextSecondary.opacity(0.5))
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.deletePeriod(id: period.id)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
                .listRowBackground(Color.appCard)
            }

            Section {
                Button {
                    showPresetConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(Color.appGreen)
                            .frame(width: 24)
                        Text("大学標準に置き換え")
                            .foregroundStyle(Color.appTextPrimary)
                    }
                }
                .listRowBackground(Color.appCard)

                Button(role: .destructive) {
                    showDeleteAllConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .frame(width: 24)
                        Text("すべて削除")
                    }
                }
                .listRowBackground(Color.appCard)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

private struct AddEditPeriodSheet: View {
    let store: ClassPeriodStore
    let existingPeriod: ClassPeriod?

    @Environment(\.dismiss) private var dismiss

    @State private var startTime: Date
    @State private var endTime: Date

    private var isEditing: Bool { existingPeriod != nil }

    init(store: ClassPeriodStore, existingPeriod: ClassPeriod?) {
        self.store = store
        self.existingPeriod = existingPeriod
        let base = Calendar.current.startOfDay(for: Date())
        let start = existingPeriod?.startSeconds ?? 9 * 3600
        let end   = existingPeriod?.endSeconds   ?? (9 * 3600 + 90 * 60)
        _startTime = State(initialValue: base.addingTimeInterval(TimeInterval(start)))
        _endTime   = State(initialValue: base.addingTimeInterval(TimeInterval(end)))
    }

    private var isValid: Bool { startTime < endTime }

    private var startSeconds: Int { Calendar.current.secondsFromMidnight(for: startTime) }
    private var endSeconds: Int   { Calendar.current.secondsFromMidnight(for: endTime) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("開始時刻", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("終了時刻", selection: $endTime,   displayedComponents: .hourAndMinute)
                    if !isValid {
                        Label("終了時刻は開始時刻より後に設定してください",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(isEditing ? "コマを編集" : "コマを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let p = existingPeriod {
                            store.updatePeriod(ClassPeriod(id: p.id,
                                                           startSeconds: startSeconds,
                                                           endSeconds: endSeconds))
                        } else {
                            store.addPeriod(startSeconds: startSeconds, endSeconds: endSeconds)
                        }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
