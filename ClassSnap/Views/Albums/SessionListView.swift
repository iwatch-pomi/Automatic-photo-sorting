import SwiftUI
import Photos

struct SessionListView: View {
    let album: ClassAlbum

    private var sessions: [SessionAlbum] { album.sessionAlbums() }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sessions) { session in
                    NavigationLink(destination: PhotoGridView(session: session)) {
                        SessionCardView(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color.appBackground)
        .navigationTitle(album.schedule.subjectName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SessionCardView: View {
    let session: SessionAlbum

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(asset: session.assets.first, size: CGSize(width: 120, height: 90))
                .frame(width: 100, height: 75)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(session.displayTitle)
                    .font(.headline).fontWeight(.bold)
                    .foregroundStyle(Color.appTextPrimary)
                if !session.dateRangeDisplay.isEmpty {
                    Text(session.dateRangeDisplay)
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "photo.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.appGreen)
                    Text("\(session.assets.count)枚")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(12)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}
