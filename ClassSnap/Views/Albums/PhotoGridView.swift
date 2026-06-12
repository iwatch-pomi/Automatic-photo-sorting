import SwiftUI
import Photos
import UIKit

private struct PhotoBadgeView: View {
    let photo: AlbumPhoto
    let firstClassDate: Date?
    let daysOfWeek: [Int]
    var makeupDates: [Date] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let fcd = firstClassDate,
               let number = photo.sessionNumber(firstClassDate: fcd, daysOfWeek: daysOfWeek, makeupDates: makeupDates) {
                Text("第\(number)回")
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(photo.creationDateDisplay)
                .font(.system(size: 8))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(.black.opacity(0.55))
        .padding(2)
    }
}

struct PhotoGridView: View {
    let session: SessionAlbum

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    @State private var selectedPhoto: AlbumPhoto?
    @State private var shareItems: [Any]?
    @State private var isExporting = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var showExcludeConfirm = false
    @State private var showPaywall = false

    private let exclusionStore = PhotoExclusionStore.shared
    private let maxShareCount = PhotoShareService.maxShareCount

    private var makeupDates: [Date] { session.makeupDates }

    // 除外済みをリアルタイムに除いた表示用リスト
    private var displayAssets: [AlbumPhoto] {
        session.assets.filter {
            !exclusionStore.isExcluded(assetID: $0.id, scheduleID: session.schedule.id)
        }
    }

    // displayAssets は撮影日昇順のため、「最新N枚」は suffix で取る
    private var assetsToShare: [AlbumPhoto] {
        Array(displayAssets.suffix(maxShareCount))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(displayAssets) { photo in
                        let isSelected = selectedIDs.contains(photo.id)
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                ThumbnailView(photo: photo, size: CGSize(width: 200, height: 200))
                            }
                            .overlay(alignment: .bottomLeading) {
                                if !isSelecting {
                                    PhotoBadgeView(photo: photo,
                                                  firstClassDate: session.schedule.firstClassDate,
                                                  daysOfWeek: session.schedule.daysOfWeek,
                                                  makeupDates: makeupDates)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if isSelecting {
                                    Image(systemName: isSelected
                                          ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(isSelected ? Color.appGreen : .white)
                                        .shadow(color: .black.opacity(0.4), radius: 2)
                                        .padding(4)
                                }
                            }
                            .overlay {
                                if isSelecting && isSelected {
                                    Color.appGreen.opacity(0.2)
                                }
                            }
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelecting {
                                    if isSelected {
                                        selectedIDs.remove(photo.id)
                                    } else {
                                        selectedIDs.insert(photo.id)
                                    }
                                } else {
                                    selectedPhoto = photo
                                }
                            }
                    }
                }
                .padding(.bottom, isSelecting ? 80 : 0)
            }

            // 選択モード時の下部バー
            if isSelecting {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        Text(selectedIDs.isEmpty ? "写真を選択してください" : "\(selectedIDs.count)枚を選択中")
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Button {
                            showExcludeConfirm = true
                        } label: {
                            Label("アルバムから除外", systemImage: "minus.circle")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }
                        .disabled(selectedIDs.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.appBackground)
                }
            }
        }
        .navigationTitle(SessionTitleStore.shared.title(primaryKey: session.titleKey, legacyKey: session.id) ?? session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isSelecting {
                    Button("完了") {
                        isSelecting = false
                        selectedIDs.removeAll()
                    }
                    .foregroundStyle(Color.appGreen)
                } else if isExporting {
                    ProgressView()
                } else {
                    HStack(spacing: 12) {
                        Button {
                            isSelecting = true
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(Color.appTextPrimary)
                        }
                        Menu {
                            Button {
                                if EntitlementManager.shared.isPro {
                                    Task { await startExport() }
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                Label(
                                    displayAssets.count > maxShareCount
                                        ? "最新\(maxShareCount)枚を共有"
                                        : "写真を共有",
                                    systemImage: "square.and.arrow.up"
                                )
                            }
                            .disabled(displayAssets.isEmpty)

                            Button {
                                if EntitlementManager.shared.isPro {
                                    Task { await exportPDF() }
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                Label("PDF で出力", systemImage: "doc.richtext")
                            }
                            .disabled(displayAssets.isEmpty)
                        } label: {
                            HStack(spacing: 4) {
                                if !EntitlementManager.shared.isPro {
                                    Image(systemName: "crown.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color.appGreen)
                                }
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "\(selectedIDs.count)枚の写真をアルバムから除外しますか？",
            isPresented: $showExcludeConfirm,
            titleVisibility: .visible
        ) {
            Button("除外する", role: .destructive) {
                exclusionStore.exclude(assetIDs: selectedIDs, scheduleID: session.schedule.id)
                for id in selectedIDs {
                    PhotoInclusionStore.shared.remove(assetID: id, scheduleID: session.schedule.id)
                }
                selectedIDs.removeAll()
                isSelecting = false
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("写真はiPhoneの写真アプリからは削除されません。このアルバムに表示されなくなるだけです。")
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoDetailView(photos: displayAssets, initialPhoto: photo,
                            firstClassDate: session.schedule.firstClassDate,
                            daysOfWeek: session.schedule.daysOfWeek,
                            makeupDates: makeupDates)
        }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ShareSheet(items: items)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func startExport() async {
        isExporting = true
        defer { isExporting = false }
        let items = await exportImages(photos: assetsToShare)
        shareItems = items
    }

    private func exportPDF() async {
        isExporting = true
        defer { isExporting = false }
        let title = "\(session.schedule.subjectName) \(session.displayTitle)"
        // PDF は枚数制限なし（SessionListView と同仕様）
        guard let data = await PDFExporter.export(photos: displayAssets, title: title) else { return }
        shareItems = [data]
    }

    private func exportImages(photos: [AlbumPhoto]) async -> [Any] {
        let images = await PhotoShareService.loadImages(photos: photos)
        let text = "「\(session.schedule.subjectName) \(session.displayTitle)」の板書 \(images.count)枚をコマフォトで共有 📸"
        return [text] + images
    }
}
