import SwiftUI
import Photos

struct AlbumListView: View {
    let schedules: [ClassSchedule]

    @State private var albumVM = AlbumViewModel()
    @State private var showSettingsAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if albumVM.isLoading {
                    ProgressView("写真を読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if schedules.isEmpty {
                    ContentUnavailableView(
                        "時間割が登録されていません",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("まず「時間割」タブで授業を登録してください。")
                    )
                } else if albumVM.albums.isEmpty {
                    ContentUnavailableView(
                        "写真が見つかりません",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("過去1週間の写真と授業時間割が一致しませんでした。")
                    )
                } else {
                    List(albumVM.albums, id: \.schedule.id) { album in
                        NavigationLink(destination: PhotoGridView(album: album)) {
                            AlbumRowView(album: album)
                        }
                    }
                }
            }
            .navigationTitle("授業アルバム")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await albumVM.loadAlbums(schedules: schedules) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(albumVM.isLoading)
                }
            }
            .task {
                await albumVM.loadAlbums(schedules: schedules)
            }
            .alert("アクセス権が必要です", isPresented: Binding(
                get: { albumVM.errorMessage != nil },
                set: { if !$0 { albumVM.errorMessage = nil } }
            )) {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("閉じる", role: .cancel) {
                    albumVM.errorMessage = nil
                }
            } message: {
                Text(albumVM.errorMessage ?? "")
            }
        }
    }
}

struct AlbumRowView: View {
    let album: ClassAlbum

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(asset: album.assets.first, size: CGSize(width: 60, height: 60))
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(album.schedule.className)
                    .font(.headline)
                Text(WeekdayHelper.name(for: album.schedule.dayOfWeek)
                     + "  \(album.schedule.startTimeDisplay)–\(album.schedule.endTimeDisplay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(album.assets.count)枚")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
