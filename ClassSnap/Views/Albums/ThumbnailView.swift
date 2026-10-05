import SwiftUI
import Photos

struct ThumbnailView: View {
    let photo: AlbumPhoto?
    let size: CGSize
    var useBlurBackground: Bool = false

    @State private var image: UIImage?
    // 読み込み中かどうか。これが false で image が nil なら「写真なし（削除済み等）」を意味する。
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                if useBlurBackground {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 12)
                            .opacity(0.7)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            } else {
                Rectangle()
                    .foregroundStyle(Color(.systemGray5))
                    .overlay {
                        if isLoading {
                            ProgressView()
                        } else {
                            // 写真なし（0枚／iPhoneの写真アプリから削除済み）はスピナーではなく
                            // プレースホルダを表示して、ロード中のまま残り続けないようにする。
                            Image(systemName: "photo")
                                .font(.system(size: min(size.width, size.height) * 0.28))
                                .foregroundStyle(Color(.systemGray3))
                        }
                    }
            }
        }
        .task(id: photo?.id) {
            // 写真が無い（nil）なら読み込みを行わず、即「写真なし」表示にする
            guard let photo else {
                image = nil
                isLoading = false
                return
            }
            isLoading = true
            let loaded = await photo.loadImage(targetSize: size)
            image = loaded
            isLoading = false
        }
    }
}
