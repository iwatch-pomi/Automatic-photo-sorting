import SwiftUI
import Photos
import UIKit

private struct PhotoBadgeView: View {
    let asset: PHAsset
    let firstClassDate: Date?
    let daysOfWeek: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let fcd = firstClassDate {
                Text("第\(asset.sessionNumber(firstClassDate: fcd, daysOfWeek: daysOfWeek))回")
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

    private let maxShareCount = 20

    private var assetsToShare: [PHAsset] {
        Array(session.assets.prefix(maxShareCount))
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(session.assets) { asset in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            ThumbnailView(asset: asset, size: CGSize(width: 200, height: 200))
                        }
                        .overlay(alignment: .bottomLeading) {
                            PhotoBadgeView(asset: asset,
                                          firstClassDate: session.schedule.firstClassDate,
                                          daysOfWeek: session.schedule.daysOfWeek)
                        }
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { selectedAsset = asset }
                }
            }
        }
        .navigationTitle(SessionTitleStore.shared.title(for: session.id) ?? session.displayTitle)
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
                                session.assets.count > maxShareCount
                                    ? "最新\(maxShareCount)枚を共有"
                                    : "写真を共有",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .disabled(session.assets.isEmpty)

                        Button {
                            Task { await exportPDF() }
                        } label: {
                            Label("PDF で出力", systemImage: "doc.richtext")
                        }
                        .disabled(session.assets.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedAsset) { asset in
            PhotoDetailView(assets: session.assets, initialAsset: asset,
                            firstClassDate: session.schedule.firstClassDate,
                            daysOfWeek: session.schedule.daysOfWeek)
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
