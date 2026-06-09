import SwiftUI
import Photos

struct AlbumListView: View {
    var viewModel: TimetableViewModel

    @State private var selectedTermID: UUID?
    @State private var albumVM = AlbumViewModel()
    @State private var didInitTerm = false

    private var schedules: [ClassSchedule] { viewModel.schedules }

    private var filteredSchedules: [ClassSchedule] {
        guard let termID = selectedTermID else { return schedules }
        return schedules.filter { $0.termIDs.contains(termID) || $0.termIDs.isEmpty }
    }

    private func reloadAlbums() {
        Task {
            await albumVM.loadAlbums(schedules: filteredSchedules,
                                     terms: viewModel.terms,
                                     makeupsBySchedule: viewModel.makeupsBySchedule)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !viewModel.terms.isEmpty {
                    termPickerView
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                if albumVM.isLoading {
                    ProgressView("写真を読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if schedules.isEmpty {
                    ContentUnavailableView(
                        "時間割が登録されていません",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("「時間割」タブで授業を登録してください。")
                    )
                } else if filteredSchedules.isEmpty {
                    ContentUnavailableView(
                        "この学期には授業がありません",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("授業登録時にこの学期を選択してください。")
                    )
                } else if albumVM.albums.isEmpty {
                    ContentUnavailableView(
                        "写真が見つかりません",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("授業時間帯に撮影された写真が見つかりませんでした。")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(albumVM.albums, id: \.schedule.id) { album in
                                NavigationLink(destination: SessionListView(album: album)) {
                                    AlbumRowView(album: album)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("授業アルバム")
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        reloadAlbums()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.appTextPrimary)
                    }
                    .disabled(albumVM.isLoading)
                }
            }
            .task {
                if !didInitTerm {
                    selectedTermID = viewModel.currentTerm?.id
                    didInitTerm = true
                }
                reloadAlbums()
            }
            .onChange(of: selectedTermID) { reloadAlbums() }
            .onChange(of: PhotoInclusionStore.shared.version) { reloadAlbums() }
            .onChange(of: SavedPhotoStore.shared.version) { reloadAlbums() }
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

    private var termPickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TermChipButton(label: "全期間", isSelected: selectedTermID == nil, isActive: false) {
                    selectedTermID = nil
                }
                ForEach(viewModel.terms, id: \.id) { term in
                    TermChipButton(label: term.name,
                                   isSelected: selectedTermID == term.id,
                                   isActive: term.isActive) {
                        selectedTermID = term.id
                    }
                }
            }
        }
    }


}

private struct AlbumRowView: View {
    let album: ClassAlbum

    private var sessionCount: Int {
        album.sessionAlbums().count
    }

    var body: some View {
        HStack(spacing: 14) {
            ThumbnailView(photo: album.thumbnailPhoto, size: CGSize(width: 160, height: 120))
                .frame(width: 88, height: 66)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                Text(album.schedule.subjectName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(Color.appGreen)
                    Text(album.schedule.daysDisplay)
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(Color.appGreen)
                    Text(album.schedule.hasUniformTime
                         ? "\(album.schedule.startTimeDisplay)〜\(album.schedule.endTimeDisplay)"
                         : "曜日により異なる")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }

                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.appAccent)
                        Text("\(album.activeCount)枚")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    if album.schedule.firstClassDate != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "folder.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.appAccent)
                            Text("\(sessionCount)回分")
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(12)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}
