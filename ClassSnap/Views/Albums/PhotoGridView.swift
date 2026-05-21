import SwiftUI
import Photos
import UIKit

struct PhotoGridView: View {
    let album: ClassAlbum

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 2)]
    @State private var selectedAsset: PHAsset?
    @State private var shareItems: [Any]?
    @State private var isExporting = false
    @State private var showPDFPaywall = false
    private let sub = SubscriptionManager.shared

    private let maxShareCount = 20

    private var assetsToShare: [PHAsset] {
        Array(album.assets.prefix(maxShareCount))
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(album.assets) { asset in
                    ThumbnailView(asset: asset, size: CGSize(width: 150, height: 150))
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                        .onTapGesture {
                            selectedAsset = asset
                        }
                }
            }
        }
        .navigationTitle(album.schedule.subjectName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isExporting {
                    ProgressView()
                } else {
                    Menu {
                        Button {
                            Task { await startExport() }
                        } label: {
                            Label(
                                album.assets.count > maxShareCount
                                    ? "最新\(maxShareCount)枚を共有"
                                    : "写真を共有",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .disabled(album.assets.isEmpty)

                        Button {
                            if sub.isPremium {
                                Task { await exportPDF() }
                            } else {
                                showPDFPaywall = true
                            }
                        } label: {
                            Label(
                                sub.isPremium ? "PDF で出力" : "PDF で出力（プレミアム）",
                                systemImage: sub.isPremium ? "doc.richtext" : "crown"
                            )
                        }
                        .disabled(album.assets.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedAsset) { asset in
            PhotoDetailView(assets: album.assets, initialAsset: asset)
        }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ShareSheet(items: items)
            }
        }
        .sheet(isPresented: $showPDFPaywall) {
            PaywallView()
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
        guard let data = await PDFExporter.export(
            assets: assetsToShare,
            title: album.schedule.subjectName
        ) else { return }
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

        let text = "「\(album.schedule.subjectName)」の板書 \(images.count)枚をClassSnapで共有 📸"
        return [text] + images
    }
}
