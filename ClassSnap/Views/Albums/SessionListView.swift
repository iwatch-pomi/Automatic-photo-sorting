import SwiftUI
import Photos

struct SessionListView: View {
    let album: ClassAlbum

    private var sessions: [SessionAlbum] { album.sessionAlbums() }
    private let titleStore = SessionTitleStore.shared

    @State private var editingSessionID: String?
    @State private var editingTitle: String = ""

    // 授業回の選択共有
    @State private var isSelecting = false
    @State private var selectedSessionIDs: Set<String> = []
    @State private var shareItems: [Any]?
    @State private var isExporting = false

    private let maxShareCount = PhotoShareService.maxShareCount

    private var selectedSessions: [SessionAlbum] {
        sessions.filter { selectedSessionIDs.contains($0.id) }
    }

    /// 選択中の授業回の写真（撮影日昇順）
    private var selectedAssets: [PHAsset] {
        selectedSessions
            .flatMap { $0.assets }
            .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                ForEach(sessions) { session in
                    let customTitle = titleStore.title(for: session.id)
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
                    // 下部バーに隠れないようスペースを確保
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
                } else if !sessions.isEmpty {
                    Button("選択") { isSelecting = true }
                        .foregroundStyle(Color.appGreen)
                }
            }
        }
        .alert("セッション名を変更", isPresented: Binding(
            get: { editingSessionID != nil },
            set: { if !$0 { editingSessionID = nil } }
        )) {
            TextField("セッション名", text: $editingTitle)
            Button("保存") {
                if let id = editingSessionID {
                    titleStore.setTitle(editingTitle, for: id)
                }
                editingSessionID = nil
            }
            Button("キャンセル", role: .cancel) {
                editingSessionID = nil
            }
        }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ShareSheet(items: items)
            }
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
                        Button {
                            Task { await shareImages() }
                        } label: {
                            Label(
                                selectedAssets.count > maxShareCount
                                    ? "最新\(maxShareCount)枚を共有"
                                    : "写真を共有",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        Button {
                            Task { await sharePDF() }
                        } label: {
                            Label("PDF で出力", systemImage: "doc.richtext")
                        }
                    } label: {
                        Label("共有", systemImage: "square.and.arrow.up")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(selectedSessionIDs.isEmpty
                                             ? Color.appTextSecondary : Color.appGreen)
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
        if selectedSessionIDs.contains(id) {
            selectedSessionIDs.remove(id)
        } else {
            selectedSessionIDs.insert(id)
        }
    }

    private func sessionTitlesText() -> String {
        selectedSessions
            .map { titleStore.title(for: $0.id) ?? $0.displayTitle }
            .joined(separator: "・")
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

private struct SessionRowCard: View {
    let session: SessionAlbum
    let customTitle: String?
    let onRename: () -> Void
    let onReset: (() -> Void)?
    var showMenu: Bool = true

    private var displayTitle: String { customTitle ?? session.displayTitle }

    var body: some View {
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
                    Button {
                        onRename()
                    } label: {
                        Label("名前を変更", systemImage: "pencil")
                    }

                    if let onReset {
                        Button(role: .destructive) {
                            onReset()
                        } label: {
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
        .padding(.vertical, 4)
    }
}
