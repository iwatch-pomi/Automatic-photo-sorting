import SwiftUI
import Photos

struct AlbumCardView: View {
    let album: ClassAlbum

    private var latestDate: String {
        guard let date = album.thumbnailAsset?.creationDate else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        return fmt.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                // サムネイル（黒板風プレースホルダー付き）
                ThumbnailView(asset: album.thumbnailAsset, size: CGSize(width: 200, height: 140), useBlurBackground: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.appGreen.opacity(album.thumbnailAsset == nil ? 1.0 : 0.0))
                    )

                // バッジ群
                HStack {
                    if !latestDate.isEmpty {
                        Text(latestDate)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                        Text("\(album.activeCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                }
                .padding(6)
            }

            Text(album.schedule.subjectName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appTextPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}
