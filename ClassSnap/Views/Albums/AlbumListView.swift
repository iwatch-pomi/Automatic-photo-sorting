import SwiftUI
import Photos

struct AlbumListView: View {
    let schedules: [ClassSchedule]

    @State private var selectedTermID: UUID? = TermStore.shared.currentTerm?.id
    @State private var albumVM = AlbumViewModel()

    private var filteredSchedules: [ClassSchedule] {
        guard let termID = selectedTermID else { return schedules }
        return schedules.filter { $0.termID == termID || $0.termID == nil }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.appBackground.ignoresSafeArea()

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
                            description: Text("授業時間帯に撮影された写真が見つかりませんでした。")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                if !TermStore.shared.terms.isEmpty {
                                    termPickerView
                                        .padding(.bottom, 4)
                                }
                                ForEach(albumVM.albums, id: \.schedule.id) { album in
                                    NavigationLink(destination: SessionListView(album: album)) {
                                        AlbumRowView(album: album)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 70)
                        }
                    }
                }

                statusFooter
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.appTextPrimary)
                }
                ToolbarItem(placement: .principal) {
                    Text("黒板フォト同期")
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await albumVM.loadAlbums(schedules: filteredSchedules) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.appTextPrimary)
                    }
                    .disabled(albumVM.isLoading)
                }
            }
            .task { await albumVM.loadAlbums(schedules: filteredSchedules) }
            .onChange(of: selectedTermID) {
                Task { await albumVM.loadAlbums(schedules: filteredSchedules) }
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
                ForEach(TermStore.shared.terms, id: \.id) { term in
                    TermChipButton(label: term.name,
                                   isSelected: selectedTermID == term.id,
                                   isActive: term.isActive) {
                        selectedTermID = term.id
                    }
                }
            }
        }
    }

    private var statusFooter: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ステータス：")
                    .font(.caption2).fontWeight(.bold).foregroundStyle(Color.appTextSecondary)
                Text(schedules.isEmpty
                     ? "時間割を登録すると自動写真整理が開始されます。"
                     : "本日のスケジュールで自動写真整理が「有効」です。")
                    .font(.caption2).foregroundStyle(Color.appTextSecondary)
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

private struct AlbumRowView: View {
    let album: ClassAlbum

    private var sessionCount: Int {
        album.sessionAlbums().count
    }

    var body: some View {
        HStack(spacing: 14) {
            ThumbnailView(asset: album.thumbnailAsset, size: CGSize(width: 160, height: 120))
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
