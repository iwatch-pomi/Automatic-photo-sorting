import SwiftUI
import Photos

struct ThumbnailView: View {
    let photo: AlbumPhoto?
    let size: CGSize
    var useBlurBackground: Bool = false

    @State private var image: UIImage?

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
                    .overlay { ProgressView() }
            }
        }
        .task(id: photo?.id) {
            guard let photo else { return }
            image = await photo.loadImage(targetSize: size)
        }
    }
}
