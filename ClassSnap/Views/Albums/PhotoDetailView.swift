import SwiftUI
import Photos
import UIKit

struct PhotoDetailView: View {
    let assets: [PHAsset]
    let initialAsset: PHAsset
    var firstClassDate: Date?
    var daysOfWeek: [Int] = []
    var makeupDates: [Date] = []

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var shareItems: [Any]?
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(assets.enumerated()), id: \.offset) { index, asset in
                    FullResolutionImageView(asset: asset)
                        .tag(index)
                        .ignoresSafeArea()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color.black)
            .ignoresSafeArea()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                        .tint(.white)
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        if currentIndex < assets.count {
                            let asset = assets[currentIndex]
                            if let fcd = firstClassDate {
                                Text("第\(asset.sessionNumber(firstClassDate: fcd, daysOfWeek: daysOfWeek, makeupDates: makeupDates))回")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            Text(asset.creationDateDisplay)
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isExporting {
                        ProgressView().tint(.white)
                    } else {
                        Button {
                            Task { await shareCurrentPhoto() }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .tint(.white)
                        }
                    }
                }
            }
            .toolbarBackground(Color.black.opacity(0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: Binding(
                get: { shareItems != nil },
                set: { if !$0 { shareItems = nil } }
            )) {
                if let items = shareItems {
                    ShareSheet(items: items)
                }
            }
        }
        .onAppear {
            if let idx = assets.firstIndex(where: { $0.localIdentifier == initialAsset.localIdentifier }) {
                currentIndex = idx
            }
        }
    }

    private func shareCurrentPhoto() async {
        guard currentIndex < assets.count else { return }
        isExporting = true
        defer { isExporting = false }

        let asset = assets[currentIndex]
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        let image: UIImage? = await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1920, height: 1920),
                contentMode: .aspectFit,
                options: options
            ) { img, _ in
                cont.resume(returning: img)
            }
        }

        if let image {
            shareItems = [image]
        }
    }
}
