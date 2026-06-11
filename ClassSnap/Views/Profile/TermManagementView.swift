import SwiftUI
import SwiftData

struct TermManagementView: View {
    let stores: AppStores

    @State private var showAddTerm = false
    @State private var editingTerm: AcademicTerm?
    @State private var showPresetConfirm = false
    @State private var pendingPreset: TermPreset?
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            List {
                if stores.term.terms.isEmpty {
                    Section {
                        Text("学期が登録されていません")
                            .foregroundStyle(Color.appTextSecondary)
                            .font(.subheadline)
                    }
                    .listRowBackground(Color.appCard)
                } else {
                    Section("登録中の学期") {
                        ForEach(stores.term.terms, id: \.id) { term in
                            TermRowView(term: term)
                                .contentShape(Rectangle())
                                .onTapGesture { editingTerm = term }
                        }
                        .onDelete { indexSet in
                            for i in indexSet { stores.term.deleteTerm(stores.term.terms[i]) }
                        }
                    }
                    .listRowBackground(Color.appCard)
                }

                Section {
                    Button {
                        tapPreset(.semesterJP)
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundStyle(Color.appGreen).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("前期・後期")
                                    .foregroundStyle(Color.appTextPrimary)
                                Text("前期: 4月〜9月 / 後期: 10月〜3月")
                                    .font(.caption).foregroundStyle(Color.appTextSecondary)
                            }
                            if !EntitlementManager.shared.isPro {
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .font(.caption).foregroundStyle(Color.appGreen)
                            }
                        }
                    }
                    Button {
                        tapPreset(.quarterJP)
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundStyle(Color.appGreen).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("4学期制（1T〜4T）")
                                    .foregroundStyle(Color.appTextPrimary)
                                Text("1T:4〜6月 / 2T:7〜9月 / 3T:10〜12月 / 4T:1〜3月")
                                    .font(.caption).foregroundStyle(Color.appTextSecondary)
                            }
                            if !EntitlementManager.shared.isPro {
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .font(.caption).foregroundStyle(Color.appGreen)
                            }
                        }
                    }
                } header: {
                    Text("プリセット")
                } footer: {
                    Text("プリセットを選ぶと既存の学期は削除されます。複数学期の一括登録には 板書っと Pro が必要です。")
                        .font(.caption)
                }
                .listRowBackground(Color.appCard)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("学期の設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if EntitlementManager.shared.isPro || stores.term.terms.isEmpty {
                        showAddTerm = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        if !EntitlementManager.shared.isPro && !stores.term.terms.isEmpty {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.appGreen)
                        }
                        Image(systemName: "plus").foregroundStyle(Color.appTextPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTerm) {
            AddEditTermView(stores: stores, term: nil)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(item: $editingTerm) { term in
            AddEditTermView(stores: stores, term: term)
        }
        .confirmationDialog(
            "既存の学期を削除してプリセットを設定しますか？",
            isPresented: $showPresetConfirm,
            titleVisibility: .visible
        ) {
            Button("設定する", role: .destructive) {
                if let preset = pendingPreset { applyPreset(preset) }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    /// プリセットは複数学期を一括作成するため Pro 限定。無料ユーザーには Paywall を提示する。
    private func tapPreset(_ preset: TermPreset) {
        if EntitlementManager.shared.isPro {
            pendingPreset = preset
            showPresetConfirm = true
        } else {
            showPaywall = true
        }
    }

    private func applyPreset(_ preset: TermPreset) {
        // データ生成は TermStore に集約（View は呼ぶだけ）
        stores.term.applyTermPreset(preset)
    }
}

private struct TermRowView: View {
    let term: AcademicTerm

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(term.name)
                        .font(.headline).fontWeight(.bold)
                        .foregroundStyle(Color.appTextPrimary)
                    if term.isActive {
                        Text("進行中")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.appGreen)
                            .clipShape(Capsule())
                    }
                }
                Text(term.displayRange)
                    .font(.caption).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(Color.appTextSecondary)
        }
        .padding(.vertical, 4)
    }
}

struct AddEditTermView: View {
    let stores: AppStores
    let term: AcademicTerm?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date

    init(stores: AppStores, term: AcademicTerm?) {
        self.stores = stores
        self.term = term
        _name = State(initialValue: term?.name ?? "")
        _startDate = State(initialValue: term?.startDate ?? Date())
        _endDate = State(initialValue: term?.endDate ?? Calendar.current.date(byAdding: .month, value: 6, to: Date())!)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && startDate < endDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("学期情報") {
                    TextField("学期名（例: 前期、1T）", text: $name)
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                    DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                    if startDate >= endDate {
                        Label("終了日は開始日より後に設定してください",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(term == nil ? "学期を追加" : "学期を編集")
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
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let term {
            stores.term.updateTerm(term, name: trimmed, startDate: startDate, endDate: endDate)
        } else {
            stores.term.addTerm(name: trimmed, startDate: startDate, endDate: endDate)
        }
    }
}
