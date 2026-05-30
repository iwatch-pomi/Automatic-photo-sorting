import Photos
import UIKit

/// 写真の共有・出力に関する共通ロジック。
/// PhotoGridView（写真単位）と SessionListView（授業回単位）の両方から利用する。
enum PhotoShareService {
    /// 画像共有時の最大枚数（AirDrop / メッセージ等の負荷を考慮）
    static let maxShareCount = 20

    /// PHAsset 配列を共有用の UIImage 配列に変換する
    static func loadImages(assets: [PHAsset]) async -> [UIImage] {
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
        return images
    }
}
