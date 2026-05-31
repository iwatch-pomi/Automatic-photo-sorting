import Photos
import UIKit

/// 写真の共有・出力に関する共通ロジック。
/// PhotoGridView（写真単位）と SessionListView（授業回単位）の両方から利用する。
enum PhotoShareService {
    /// 画像共有時の最大枚数（AirDrop / メッセージ等の負荷を考慮）
    static let maxShareCount = 20

    /// AlbumPhoto 配列を共有用の UIImage 配列に変換する（保存写真があればそれを使用）
    static func loadImages(photos: [AlbumPhoto]) async -> [UIImage] {
        var images: [UIImage] = []
        for photo in photos {
            if let img = await photo.loadFullImage() { images.append(img) }
        }
        return images
    }
}
