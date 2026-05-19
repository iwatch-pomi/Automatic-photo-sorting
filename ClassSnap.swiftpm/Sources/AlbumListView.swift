import SwiftUI
import Photos

struct AlbumListView: View {
    let schedules: [ClassSchedule]

    @State private var albumVM = AlbumViewModel()

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if albumVM.isLoading {
                        ProgressView("写真を読み込み中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if schedules.isEmpty {
                        ContentUnavailableView(
                            "時間割が登録されていません",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("「時間割」タブで授業を登録してください。")
                        )
                    } else if albumVM.albums.isEmpty {
                        ContentUnavailableView(
                            "写真が見つかりません",
                            systemImage: "photo.badge.exclamationmark",
                            description: Text("過去1週間の写真と授業時間割が一致しませんでした。")
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(albumVM.albums, id: \.schedule.id) { album in
                                    NavigationLink(destination: PhotoGridView(album: album)) {
                                        AlbumCardView(album: album)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                            .padding(.bottom, 60)
                        }
                    }
                }

                // ステータスフッター
                statusFooter
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "plus")
                        .foregroundStyle(.appTextPrimary)
                }
                ToolbarItem(placement: .principal) {
                    Text("黒板フォト同期")
                        .font(.headline)
                        .foregroundStyle(.appTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await albumVM.loadAlbums(schedules: schedules) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.appTextPrimary)
                    }
                    .disabled(albumVM.isLoading)
                }
            }
            .task { await albumVM.loadAlbums(schedules: schedules) }
            .alert("アクセス権が必要です", isPresented: Binding(
                get: { albumVM.errorMessage != nil },
                set: { if !$0 { albumVM.errorMessage = nil } }
            )) {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("閉じる", role: .cancel) { albumVM.errorMessage = nil }
            } message: {
                Text(albumVM.errorMessage ?? "")
            }
        }
    }

    private var statusFooter: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ステータス：")
                    .font(.caption2).fontWeight(.bold).foregroundStyle(.appTextSecondary)
                Text(schedules.isEmpty
                     ? "時間割を登録すると自動写真整理が開始されます。"
                     : "本日のスケジュールで自動写真整理が「有効」です。")
                    .font(.caption2).foregroundStyle(.appTextSecondary)
            }
            Spacer()
            Text("時間割を管理")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(Color.appGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}
