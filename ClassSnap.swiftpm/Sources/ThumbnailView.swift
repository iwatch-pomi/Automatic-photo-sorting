import SwiftUI
import Photos

struct ThumbnailView: View {
    let asset: PHAsset?
    let size: CGSize

    @State private var image: UIImage?

    // 高コストなので static で1インスタンスを共有
    private static let imageManager = PHCachingImageManager()

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .foregroundStyle(Color(.systemGray5))
                    .overlay { ProgressView() }
            }
        }
        .task(id: asset?.localIdentifier) {
            guard let asset else { return }
            image = await loadThumbnail(asset: asset)
        }
    }

    private func loadThumbnail(asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast

            ThumbnailView.imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // .opportunistic は低解像度→高解像度の順に2回コールバックされる
                // degraded（低解像度）の場合は無視し、最終コールバックのみ resume する
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }
}
