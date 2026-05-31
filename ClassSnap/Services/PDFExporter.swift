import UIKit
import Photos

struct PDFExporter {

    static func export(photos: [AlbumPhoto], title: String) async -> Data? {
        var images: [UIImage] = []
        for photo in photos {
            if let img = await photo.loadFullImage() { images.append(img) }
        }

        guard !images.isEmpty else { return nil }

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

            // 写真ページ (1枚/ページ)
            for image in images {
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
        return data
    }
}
