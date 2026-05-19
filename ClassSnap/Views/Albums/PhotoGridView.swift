import SwiftUI
import Photos

struct PhotoGridView: View {
    let album: ClassAlbum

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 2)]
    @State private var selectedAsset: PHAsset?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(album.assets) { asset in
                    ThumbnailView(asset: asset, size: CGSize(width: 150, height: 150))
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                        .onTapGesture {
                            selectedAsset = asset
                        }
                }
            }
        }
        .navigationTitle(album.schedule.className)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedAsset) { asset in
            PhotoDetailView(assets: album.assets, initialAsset: asset)
        }
    }
}
