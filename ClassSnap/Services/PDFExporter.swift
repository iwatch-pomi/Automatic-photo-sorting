import UIKit
import Photos

struct PDFExporter {

    /// PDF描画用の最大長辺(px)。A4@2x相当で、板書の文字が読める解像度を保ちつつメモリを抑える。
    private static let maxImageLongEdge: CGFloat = 2048

    static func export(photos: [AlbumPhoto], title: String) async -> Data? {
        // 全フル解像度画像を同時にメモリ展開すると枚数次第で数GBに達しクラッシュするため、
        // 1枚ずつ縮小して圧縮データ(JPEG)で保持し、描画時に1枚ずつ展開する。
        var imageDatas: [Data] = []
        for photo in photos {
            guard let img = await photo.loadFullImage() else { continue }
            let data = autoreleasepool { () -> Data? in
                downsampled(img, maxLongEdge: maxImageLongEdge)
                    .jpegData(compressionQuality: 0.85)
            }
            if let data { imageDatas.append(data) }
        }

        guard !imageDatas.isEmpty else { return nil }

        // A4 縦 (pt): 595 × 842
        let pageSize = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 24

        let renderer = UIGraphicsPDFRenderer(bounds: pageSize)
        let data = renderer.pdfData { ctx in

            // タイトルページ
            ctx.beginPage()
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let dateStr = DateFormatter.localizedString(
                from: Date(), dateStyle: .medium, timeStyle: .none)
            let titleText = "\(title)\n\(dateStr)"
            titleText.draw(
                with: CGRect(x: margin, y: margin, width: pageSize.width - margin * 2, height: 100),
                options: .usesLineFragmentOrigin,
                attributes: titleAttrs,
                context: nil
            )

            // 写真ページ (1枚/ページ)。デコードはページ描画時に1枚ずつ行い、描画後に解放する。
            for imageData in imageDatas {
                autoreleasepool {
                    guard let image = UIImage(data: imageData) else { return }
                    ctx.beginPage()
                    let availW = pageSize.width - margin * 2
                    let availH = pageSize.height - margin * 2
                    let scale = min(availW / image.size.width, availH / image.size.height)
                    let drawW = image.size.width * scale
                    let drawH = image.size.height * scale
                    let drawX = margin + (availW - drawW) / 2
                    let drawY = margin + (availH - drawH) / 2
                    image.draw(in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
                }
            }
        }
        return data
    }

    /// 長辺が maxLongEdge を超える画像を縮小する（向きの正規化も兼ねる）
    private static func downsampled(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let longEdge = max(image.size.width, image.size.height)
        guard longEdge > 0 else { return image }
        let ratio = min(1, maxLongEdge / longEdge)
        let newSize = CGSize(width: image.size.width * ratio,
                             height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
