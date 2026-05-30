import SwiftUI
import Photos
import UIKit

private struct PhotoBadgeView: View {
    let asset: PHAsset
    let firstClassDate: Date?
    let daysOfWeek: [Int]
    var makeupDates: [Date] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let fcd = firstClassDate {
                Text("第\(asset.sessionNumber(firstClassDate: fcd, daysOfWeek: daysOfWeek, makeupDates: makeupDates))回")
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(asset.creationDateDisplay)
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

    @State private var selectedAsset: PHAsset?
    @State private var shareItems: [Any]?
    @State private var isExporting = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var showExcludeConfirm = false

    private let exclusionStore = PhotoExclusionStore.shared
    private let maxShareCount = 20

    private var makeupDates: [Date] {
        MakeupClassStore.shared.makeupClasses(for: session.schedule.id).map { $0.date }
    }

    // 除外済みをリアルタイムに除いた表示用リスト
    private var displayAssets: [PHAsset] {
        session.assets.filter {
            !exclusionStore.isExcluded(assetID: $0.localIdentifier, scheduleID: session.schedule.id)
        }
    }

    private var assetsToShare: [PHAsset] {
        Array(displayAssets.prefix(maxShareCount))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(displayAssets) { asset in
                        let isSelected = selectedIDs.contains(asset.localIdentifier)
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                ThumbnailView(asset: asset, size: CGSize(width: 200, height: 200))
                            }
                            .overlay(alignment: .bottomLeading) {
                                if !isSelecting {
                                    PhotoBadgeView(asset: asset,
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
                                        selectedIDs.remove(asset.localIdentifier)
                                    } else {
                                        selectedIDs.insert(asset.localIdentifier)
                                    }
                                } else {
                                    selectedAsset = asset
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
        .navigationTitle(SessionTitleStore.shared.title(for: session.id) ?? session.displayTitle)
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
                                Task { await startExport() }
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
                                Task { await exportPDF() }
                            } label: {
                                Label("PDF で出力", systemImage: "doc.richtext")
                            }
                            .disabled(displayAssets.isEmpty)
                        } label: {
                            Image(systemName: "ellipsis.circle")
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
                selectedIDs.removeAll()
                isSelecting = false
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("写真はiPhoneの写真アプリからは削除されません。このアルバムに表示されなくなるだけです。")
        }
        .fullScreenCover(item: $selectedAsset) { asset in
            PhotoDetailView(assets: displayAssets, initialAsset: asset,
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
    }

    private func startExport() async {
        isExporting = true
        defer { isExporting = false }
        let items = await exportImages(assets: assetsToShare)
        shareItems = items
    }

    private func exportPDF() async {
        isExporting = true
        defer { isExporting = false }
        let title = "\(session.schedule.subjectName) \(session.displayTitle)"
        guard let data = await PDFExporter.export(assets: assetsToShare, title: title) else { return }
        shareItems = [data]
    }

    private func exportImages(assets: [PHAsset]) async -> [Any] {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        var images: [UIImage] = []
        for asset in assets {
            let img: UIImage? = await withCheckedContinuation { cont in
                manager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: 1920, height: 1920),
                    contentMode: .aspectFit,
                    options: options
                ) { image, _ in
                    cont.resume(returning: image)
                }
            }
            if let img { images.append(img) }
        }

        let text = "「\(session.schedule.subjectName) \(session.displayTitle)」の板書 \(images.count)枚をClassSnapで共有 📸"
        return [text] + images
    }
}
