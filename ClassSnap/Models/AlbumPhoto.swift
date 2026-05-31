import Foundation
import Photos
import UIKit
import ImageIO

/// アルバム内の1枚の写真を表す抽象。ライブ（写真ライブラリの PHAsset）と
/// アプリ保存（端末内 JPEG）の両方を統一的に扱う。
/// 写真ライブラリから削除された保存写真も `asset == nil` で表現できる。
struct AlbumPhoto: Identifiable, Hashable {
    /// 識別子。常に元の localIdentifier と一致させ、除外/手動追加（localIdentifier キー）と整合させる。
    let id: String
    let creationDate: Date?
    let localIdentifier: String?
    /// ライブラリに存在する場合の PHAsset。削除済みなら nil。
    let asset: PHAsset?
    /// アプリ内に保存したコピーがある場合のファイル URL。
    let savedFileURL: URL?

    /// 保存コピーのみ（ライブラリには存在しない）かどうか
    var isSavedOnly: Bool { asset == nil && savedFileURL != nil }

    var creationDateDisplay: String { photoCreationDateDisplay(creationDate) }

    func sessionNumber(firstClassDate: Date, daysOfWeek: [Int], makeupDates: [Date] = []) -> Int {
        computeSessionNumber(creationDate: creationDate, firstClassDate: firstClassDate,
                             daysOfWeek: daysOfWeek, makeupDates: makeupDates)
    }

    // MARK: - Identity

    static func == (lhs: AlbumPhoto, rhs: AlbumPhoto) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: - Convenience initializers

    init(id: String, creationDate: Date?, localIdentifier: String?,
         asset: PHAsset?, savedFileURL: URL?) {
        self.id = id
        self.creationDate = creationDate
        self.localIdentifier = localIdentifier
        self.asset = asset
        self.savedFileURL = savedFileURL
    }

    /// ライブ PHAsset から生成（任意で保存ファイルを付与）
    init(asset: PHAsset, savedFileURL: URL? = nil) {
        self.id = asset.localIdentifier
        self.creationDate = asset.creationDate
        self.localIdentifier = asset.localIdentifier
        self.asset = asset
        self.savedFileURL = savedFileURL
    }

    // MARK: - Image loading

    private static let imageManager = PHCachingImageManager()

    /// サムネイル/中サイズ画像を取得。保存ファイルがあれば優先（高速・オフライン）。
    func loadImage(targetSize: CGSize) async -> UIImage? {
        if let url = savedFileURL {
            let scale = await MainActor.run { UIScreen.main.scale }
            let maxPixel = max(targetSize.width, targetSize.height) * scale
            if let image = await Self.downsampledImage(at: url, maxPixelSize: maxPixel) {
                return image
            }
        }
        guard let asset else { return nil }
        return await Self.requestImage(asset: asset, targetSize: targetSize,
                                       deliveryMode: .opportunistic, resizeMode: .fast)
    }

    /// フル解像度画像を取得（詳細表示・共有・PDF用）。保存ファイルがあれば優先。
    func loadFullImage() async -> UIImage? {
        if let url = savedFileURL, let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        guard let asset else { return nil }
        return await Self.requestImage(asset: asset, targetSize: PHImageManagerMaximumSize,
                                       deliveryMode: .highQualityFormat, resizeMode: .none)
    }

    // MARK: - Helpers

    private static func requestImage(asset: PHAsset, targetSize: CGSize,
                                     deliveryMode: PHImageRequestOptionsDeliveryMode,
                                     resizeMode: PHImageRequestOptionsResizeMode) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = deliveryMode
            options.resizeMode = resizeMode
            let resumed = ResumeGuard()
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                // opportunistic は低解像度→高解像度の順に呼ばれる。最終のみ resume。
                // 二重 resume（クラッシュ）を防ぐためフラグでガードする。
                if !isDegraded, resumed.markResumed() {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    /// 保存ファイルから maxPixelSize に合わせてダウンサンプリングして読み込む（メモリ効率重視）。
    private static func downsampledImage(at url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { () -> UIImage? in
            let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
                return UIImage(contentsOfFile: url.path)
            }
            let downsampleOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            ] as CFDictionary
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
                return UIImage(contentsOfFile: url.path)
            }
            return UIImage(cgImage: cgImage)
        }.value
    }
}

/// withCheckedContinuation の二重 resume を防ぐためのスレッドセーフなフラグ
final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    /// まだ resume していなければ true を返してフラグを立てる
    func markResumed() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
