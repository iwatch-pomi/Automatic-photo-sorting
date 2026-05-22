import SwiftUI
import Photos

struct SessionListView: View {
    let album: ClassAlbum

    private var sessions: [SessionAlbum] { album.sessionAlbums() }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
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
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                ThumbnailView(asset: session.assets.first, size: CGSize(width: 200, height: 140))
                    .aspectRatio(4/3, contentMode: .fill)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.appGreen.opacity(session.assets.isEmpty ? 1.0 : 0.0))
                    )

                HStack {
                    if !session.dateRangeDisplay.isEmpty {
                        Text(session.dateRangeDisplay)
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "photo.fill").font(.caption2)
                        Text("\(session.assets.count)").font(.caption2).fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                }
                .padding(6)
            }

            Text(session.displayTitle)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color.appTextPrimary)
                .lineLimit(1)
        }
        .padding(8)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}
