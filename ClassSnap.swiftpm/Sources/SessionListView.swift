import SwiftUI
import Photos
import PhotosUI

struct SessionListView: View {
    let album: ClassAlbum

    private let titleStore = SessionTitleStore.shared
    private let testRangeStore = TestRangeStore.shared

    @State private var editingSessionID: String?
    @State private var editingTitle: String = ""

    // 授業回の選択共有
    @State private var isSelecting = false
    @State private var selectedSessionIDs: Set<String> = []
    @State private var shareItems: [Any]?
    @State private var isExporting = false

    // 手動追加（画面内で追加された写真を即時反映するためローカルに保持）
    @State private var manualAssets: [PHAsset]
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var pendingAssetIDs: Set<String> = []
    @State private var showSessionAssignment = false
    private let inclusionStore = PhotoInclusionStore.shared

    // テスト範囲
    @State private var showTestRangeEditor = false

    private let maxShareCount = PhotoShareService.maxShareCount

    init(album: ClassAlbum) {
        self.album = album
        _manualAssets = State(initialValue: album.manualAssets)
    }

    /// 最新の手動追加写真を反映したアルバム
    private var workingAlbum: ClassAlbum {
        var a = album
        a.manualAssets = manualAssets
        return a
    }

    private var sessions: [SessionAlbum] { workingAlbum.sessionAlbums() }

    private var testRanges: [TestRange] {
        testRangeStore.ranges(for: album.schedule.id)
    }

    private var selectedSessions: [SessionAlbum] {
        sessions.filter { selectedSessionIDs.contains($0.id) }
    }

    private var selectedAssets: [PHAsset] {
        selectedSessions
            .flatMap { $0.assets }
            .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                // テスト範囲カード
                if !testRanges.isEmpty && !isSelecting {
                    Section {
                        testRangeBanner
                    }
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                ForEach(sessions) { session in
                    let customTitle = titleStore.title(for: session.id)
                    let matchingRanges = testRangeStore.rangesContaining(
                        session: session.sessionNumber ?? 0,
                        scheduleID: album.schedule.id
                    )
                    if isSelecting {
                        Button {
                            toggleSelection(session.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedSessionIDs.contains(session.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selectedSessionIDs.contains(session.id)
                                                     ? Color.appGreen : Color.appTextSecondary)
                                SessionRowCard(
                                    session: session,
                                    customTitle: customTitle,
                                    testRanges: matchingRanges,
                                    onRename: {},
                                    onReset: nil,
                                    showMenu: false
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(destination: PhotoGridView(session: session)) {
                            SessionRowCard(
                                session: session,
                                customTitle: customTitle,
                                testRanges: matchingRanges,
                                onRename: {
                                    editingSessionID = session.id
                                    editingTitle = customTitle ?? session.displayTitle
                                },
                                onReset: customTitle != nil ? {
                                    titleStore.removeTitle(for: session.id)
                                } : nil,
                                showMenu: true
                            )
                        }
                    }
                }
                .listRowBackground(Color.appCard)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                if isSelecting {
                    Color.clear
                        .frame(height: 60)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)

            if isSelecting {
                selectionBar
            }
        }
        .navigationTitle(album.schedule.subjectName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isSelecting {
                    Button("完了") {
                        isSelecting = false
                        selectedSessionIDs.removeAll()
                    }
                    .foregroundStyle(Color.appGreen)
                } else {
                    HStack(spacing: 12) {
                        Button {
                            showTestRangeEditor = true
                        } label: {
                            Image(systemName: testRanges.isEmpty ? "flag" : "flag.fill")
                                .foregroundStyle(testRanges.isEmpty ? Color.appTextSecondary : Color.orange)
                        }
                        PhotosPicker(
                            selection: $pickerItems,
                            maxSelectionCount: 50,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.appGreen)
                        }
                        if !sessions.isEmpty {
                            Button("選択") { isSelecting = true }
                                .foregroundStyle(Color.appGreen)
                        }
                    }
                }
            }
        }
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            var ids: Set<String> = []
            for item in newItems {
                if let id = item.itemIdentifier { ids.insert(id) }
            }
            pickerItems = []
            guard !ids.isEmpty else { return }
            pendingAssetIDs = ids
            showSessionAssignment = true
        }
        .sheet(isPresented: $showSessionAssignment) {
            SessionAssignmentSheet(
                sessions: sessions,
                photoCount: pendingAssetIDs.count,
                onConfirm: { sessionOverride in
                    inclusionStore.include(assetIDs: pendingAssetIDs,
                                           scheduleID: album.schedule.id,
                                           sessionOverride: sessionOverride)
                    pendingAssetIDs = []
                    showSessionAssignment = false
                    reloadManualAssets()
                },
                onCancel: {
                    pendingAssetIDs = []
                    showSessionAssignment = false
                }
            )
        }
        .sheet(isPresented: $showTestRangeEditor) {
            TestRangeEditorSheet(scheduleID: album.schedule.id, sessions: sessions)
        }
        .alert("セッション名を変更", isPresented: Binding(
            get: { editingSessionID != nil },
            set: { if !$0 { editingSessionID = nil } }
        )) {
            TextField("セッション名", text: $editingTitle)
            Button("保存") {
                if let id = editingSessionID { titleStore.setTitle(editingTitle, for: id) }
                editingSessionID = nil
            }
            Button("キャンセル", role: .cancel) { editingSessionID = nil }
        }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems { ShareSheet(items: items) }
        }
        .task { reloadManualAssets() }
    }

    /// 手動追加写真をバックグラウンドで再解決（PHKitの同期APIをメインスレッド外で実行）
    private func reloadManualAssets() {
        let id = album.schedule.id
        Task {
            let assets = await Task.detached(priority: .userInitiated) {
                PhotoInclusionStore.shared.fetchAssets(for: id)
            }.value
            manualAssets = assets
        }
    }

    // MARK: - Test range banner

    private var testRangeBanner: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(testRanges) { range in
                    let sessionCount = sessions.filter {
                        range.contains($0.sessionNumber ?? 0)
                    }.count
                    let photoCount = sessions
                        .filter { range.contains($0.sessionNumber ?? 0) }
                        .flatMap { $0.assets }
                        .count

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "flag.fill")
                                .font(.caption)
                            Text(range.label)
                                .font(.subheadline).fontWeight(.bold)
                        }
                        .foregroundStyle(range.color)

                        Text(range.displayRange)
                            .font(.headline).fontWeight(.bold)
                            .foregroundStyle(Color.appTextPrimary)

                        HStack(spacing: 4) {
                            Image(systemName: "book.closed")
                                .font(.caption2)
                            Text("\(sessionCount)回分")
                            Text("·")
                            Image(systemName: "photo")
                                .font(.caption2)
                            Text("\(photoCount)枚")
                        }
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(range.color.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(range.color.opacity(0.35), lineWidth: 1.5)
                            )
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Selection bar

    private var selectionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedSessionIDs.isEmpty
                         ? "共有する授業回を選択"
                         : "\(selectedSessionIDs.count)回分・\(selectedAssets.count)枚を選択中")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                    if selectedAssets.count > maxShareCount {
                        Text("写真共有は最新\(maxShareCount)枚まで（PDFは全枚）")
                            .font(.caption2)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
                Spacer()
                if isExporting {
                    ProgressView()
                } else {
                    Menu {
                        Button { Task { await shareImages() } } label: {
                            Label(
                                selectedAssets.count > maxShareCount
                                    ? "最新\(maxShareCount)枚を共有" : "写真を共有",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        Button { Task { await sharePDF() } } label: {
                            Label("PDF で出力", systemImage: "doc.richtext")
                        }
                    } label: {
                        Label("共有", systemImage: "square.and.arrow.up")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(selectedSessionIDs.isEmpty ? Color.appTextSecondary : Color.appGreen)
                    }
                    .disabled(selectedSessionIDs.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackground)
        }
    }

    // MARK: - Actions

    private func toggleSelection(_ id: String) {
        if selectedSessionIDs.contains(id) { selectedSessionIDs.remove(id) }
        else { selectedSessionIDs.insert(id) }
    }

    private func sessionTitlesText() -> String {
        selectedSessions.map { titleStore.title(for: $0.id) ?? $0.displayTitle }.joined(separator: "・")
    }

    private func shareImages() async {
        isExporting = true
        defer { isExporting = false }
        let assets = Array(selectedAssets.prefix(maxShareCount))
        let images = await PhotoShareService.loadImages(assets: assets)
        guard !images.isEmpty else { return }
        let text = "「\(album.schedule.subjectName)」\(sessionTitlesText()) の板書 \(images.count)枚をClassSnapで共有 📸"
        shareItems = [text] + images
    }

    private func sharePDF() async {
        isExporting = true
        defer { isExporting = false }
        let title = "\(album.schedule.subjectName) \(sessionTitlesText())"
        guard let data = await PDFExporter.export(assets: selectedAssets, title: title) else { return }
        shareItems = [data]
    }
}

// MARK: - Test Range Editor Sheet

private struct TestRangeEditorSheet: View {
    let scheduleID: UUID
    let sessions: [SessionAlbum]

    private let store = TestRangeStore.shared
    @State private var showAddSheet = false
    @State private var editingRange: TestRange?

    private var ranges: [TestRange] { store.ranges(for: scheduleID) }

    var body: some View {
        NavigationStack {
            Group {
                if ranges.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(ranges) { range in
                            Button {
                                editingRange = range
                            } label: {
                                rangeRow(range)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            for idx in offsets {
                                store.remove(id: ranges[idx].id, for: scheduleID)
                            }
                        }
                        .listRowBackground(Color.appCard)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground)
                }
            }
            .navigationTitle("テスト範囲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundStyle(Color.appGreen)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEditTestRangeSheet(
                    scheduleID: scheduleID,
                    sessions: sessions,
                    existingRange: nil
                )
            }
            .sheet(item: $editingRange) { range in
                AddEditTestRangeSheet(
                    scheduleID: scheduleID,
                    sessions: sessions,
                    existingRange: range
                )
            }
        }
        .background(Color.appBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag")
                .font(.system(size: 48))
                .foregroundStyle(Color.appTextSecondary.opacity(0.5))
            Text("テスト範囲が未設定です")
                .font(.headline)
                .foregroundStyle(Color.appTextSecondary)
            Text("「+」ボタンからテスト範囲を追加できます。\n先生から指定された授業回の範囲を\n登録しておきましょう。")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
            Button {
                showAddSheet = true
            } label: {
                Label("テスト範囲を追加", systemImage: "plus.circle")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.appGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private func rangeRow(_ range: TestRange) -> some View {
        let sessionCount = sessions.filter { range.contains($0.sessionNumber ?? 0) }.count
        let photoCount = sessions
            .filter { range.contains($0.sessionNumber ?? 0) }
            .flatMap { $0.assets }
            .count

        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(range.color)
                .frame(width: 5, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(range.label)
                    .font(.headline).fontWeight(.bold)
                    .foregroundStyle(Color.appTextPrimary)
                Text(range.displayRange)
                    .font(.subheadline)
                    .foregroundStyle(range.color)
                HStack(spacing: 8) {
                    Label("\(sessionCount)回分", systemImage: "book.closed")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                    Label("\(photoCount)枚", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Add / Edit Test Range Sheet

private struct AddEditTestRangeSheet: View {
    let scheduleID: UUID
    let sessions: [SessionAlbum]
    let existingRange: TestRange?

    private let store = TestRangeStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var startSession: Int = 1
    @State private var endSession: Int = 5
    @State private var colorName: String = "orange"

    private var isEditing: Bool { existingRange != nil }
    private var isValid: Bool { !label.trimmingCharacters(in: .whitespaces).isEmpty && startSession <= endSession }

    // セッション番号の選択候補（既存＋余裕）
    private var sessionOptions: [Int] {
        let maxExisting = sessions.compactMap { $0.sessionNumber }.max() ?? 0
        let upper = max(maxExisting + 5, endSession + 5, 15)
        return Array(1...upper)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("テスト名") {
                    TextField("例：中間テスト、期末テスト", text: $label)
                }

                Section("授業回の範囲") {
                    Picker("開始回", selection: $startSession) {
                        ForEach(sessionOptions, id: \.self) { n in
                            Text("第\(n)回").tag(n)
                        }
                    }
                    Picker("終了回", selection: $endSession) {
                        ForEach(sessionOptions.filter { $0 >= startSession }, id: \.self) { n in
                            Text("第\(n)回").tag(n)
                        }
                    }

                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.appGreen)
                            .font(.caption)
                        Text("\(label.isEmpty ? "この範囲" : label)は \(endSession - startSession + 1) 授業回分です")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                Section("カラー") {
                    HStack(spacing: 16) {
                        ForEach(TestRange.colorOptions, id: \.name) { option in
                            Button {
                                colorName = option.name
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 32, height: 32)
                                    if colorName == option.name {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // プレビュー
                Section("プレビュー") {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(TestRange(label: "", startSession: 1, endSession: 1, colorName: colorName).color)
                            .frame(width: 5, height: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(label.isEmpty ? "テスト名" : label)
                                .font(.headline).fontWeight(.bold)
                                .foregroundStyle(label.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)
                            Text("第\(startSession)回〜第\(endSession)回")
                                .font(.subheadline)
                                .foregroundStyle(TestRange(label: "", startSession: 1, endSession: 1, colorName: colorName).color)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(isEditing ? "テスト範囲を編集" : "テスト範囲を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "追加") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(isValid ? Color.appGreen : Color.appTextSecondary)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let range = existingRange {
                    label        = range.label
                    startSession = range.startSession
                    endSession   = range.endSession
                    colorName    = range.colorName
                }
            }
            .onChange(of: startSession) { _, newVal in
                if endSession < newVal { endSession = newVal }
            }
        }
        .background(Color.appBackground)
    }

    private func save() {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        if var range = existingRange {
            range.label        = trimmed
            range.startSession = startSession
            range.endSession   = endSession
            range.colorName    = colorName
            store.update(range, for: scheduleID)
        } else {
            store.add(TestRange(label: trimmed, startSession: startSession, endSession: endSession, colorName: colorName),
                      for: scheduleID)
        }
    }
}

// MARK: - Session Assignment Sheet

private struct SessionAssignmentSheet: View {
    let sessions: [SessionAlbum]
    let photoCount: Int
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void

    private enum Selection: Equatable {
        case auto
        case session(Int)
    }

    @State private var selection: Selection = .auto
    @State private var customSession: Int = 1

    private var confirmLabel: String {
        switch selection {
        case .auto: return "自動で追加"
        case .session(let n): return "第\(n)回に追加"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    selectionRow(systemImage: "wand.and.stars",
                                 title: "自動（撮影日で判定）",
                                 subtitle: "写真の撮影日をもとに授業回を自動で振り分けます",
                                 isSelected: selection == .auto) {
                        selection = .auto
                    }
                }

                // 第N回が確定しているセッションのみ選択肢に出す
                // （sessionNumber が nil の「全写真」グループは番号指定の対象外）
                let numberedSessions = sessions.filter { $0.sessionNumber != nil }
                if !numberedSessions.isEmpty {
                    Section("既存の授業回") {
                        ForEach(numberedSessions) { session in
                            let n = session.sessionNumber ?? 1
                            selectionRow(systemImage: "book.closed",
                                         title: session.displayTitle,
                                         subtitle: session.dateRangeDisplay.isEmpty ? nil : session.dateRangeDisplay,
                                         isSelected: selection == .session(n)) {
                                selection = .session(n)
                            }
                        }
                    }
                }

                Section("番号で指定") {
                    HStack(spacing: 12) {
                        Image(systemName: selection == .session(customSession)
                              ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selection == .session(customSession)
                                             ? Color.appGreen : Color.secondary)
                        Text("第\(customSession)回")
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Stepper("", value: $customSession, in: 1...99)
                            .labelsHidden()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selection = .session(customSession) }
                    .onChange(of: customSession) { _, _ in selection = .session(customSession) }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("\(photoCount)枚の追加先")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmLabel) {
                        switch selection {
                        case .auto: onConfirm(0)
                        case .session(let n): onConfirm(max(1, n))
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appGreen)
                }
            }
        }
    }

    private func selectionRow(systemImage: String, title: String, subtitle: String?,
                               isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.appGreen : Color.secondary)
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(Color.appGreen)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Color.appTextPrimary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundStyle(Color.appTextSecondary)
                    }
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Row Card

private struct SessionRowCard: View {
    let session: SessionAlbum
    let customTitle: String?
    let testRanges: [TestRange]
    let onRename: () -> Void
    let onReset: (() -> Void)?
    var showMenu: Bool = true

    private var displayTitle: String { customTitle ?? session.displayTitle }

    var body: some View {
        HStack(spacing: 0) {
            // テスト範囲の色ストライプ（複数範囲の場合は先頭の色）
            if let firstRange = testRanges.first {
                RoundedRectangle(cornerRadius: 3)
                    .fill(firstRange.color)
                    .frame(width: 4)
                    .padding(.trailing, 10)
            } else {
                Color.clear.frame(width: 4).padding(.trailing, 10)
            }

            HStack(spacing: 12) {
                ThumbnailView(asset: session.assets.first, size: CGSize(width: 120, height: 90))
                    .frame(width: 80, height: 60)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Text(displayTitle)
                            .font(.headline).fontWeight(.bold)
                            .foregroundStyle(Color.appTextPrimary)
                        if customTitle != nil {
                            Image(systemName: "pencil.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.appGreen.opacity(0.8))
                        }
                    }

                    // テスト範囲バッジ（最大2つ）
                    if !testRanges.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(testRanges.prefix(2)) { range in
                                Text(range.label)
                                    .font(.caption2).fontWeight(.semibold)
                                    .foregroundStyle(range.color)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(range.color.opacity(0.12))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().strokeBorder(range.color.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }

                    if !session.dateRangeDisplay.isEmpty {
                        Text(session.dateRangeDisplay)
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.appGreen)
                        Text("\(session.assets.count)枚")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                Spacer()

                if showMenu {
                    Menu {
                        Button { onRename() } label: {
                            Label("名前を変更", systemImage: "pencil")
                        }
                        if let onReset {
                            Button(role: .destructive) { onReset() } label: {
                                Label("名前をリセット", systemImage: "arrow.uturn.backward")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .simultaneousGesture(TapGesture())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
