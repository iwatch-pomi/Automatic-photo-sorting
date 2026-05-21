import SwiftUI
import Photos

struct HomeView: View {
    var timetableVM: TimetableViewModel
    @State private var albumVM = AlbumViewModel()
    @State private var now = Date()
    @State private var selectedScheduleID: UUID?
    @State private var showAddClass = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var todaySchedules: [ClassSchedule] { timetableVM.todaySchedules(now: now) }
    private var nextClass: ClassSchedule? { timetableVM.nextClass(now: now) }

    private var countdownText: String? {
        guard let secs = timetableVM.secondsUntilNextClass(now: now), secs > 0 else { return nil }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 今日の授業
                        todaySection
                        // 最近同期された授業アルバム
                        albumSection
                        // マイ時間割
                        timetableListSection
                        // ステータス下部スペース
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // ステータスバー（固定フッター）
                statusFooter
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showAddClass = true } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.appTextPrimary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("黒板フォト同期")
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Color.appTextPrimary)
                }
            }
            .sheet(isPresented: $showAddClass) {
                AddClassView(viewModel: timetableVM)
            }
        }
        .onReceive(timer) { now = $0 }
        .task { await albumVM.loadAlbums(schedules: timetableVM.schedules) }
    }

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日の授業")
                    .font(.title2).fontWeight(.bold).foregroundStyle(Color.appTextPrimary)
                Spacer()
                Text(todayDateString)
                    .font(.caption).foregroundStyle(Color.appTextSecondary)
            }

            if todaySchedules.isEmpty {
                Text("今日は授業がありません")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(todaySchedules, id: \.id) { s in
                            TodayClassCard(
                                schedule: s,
                                isSelected: selectedScheduleID == s.id
                            ) {
                                selectedScheduleID = (selectedScheduleID == s.id) ? nil : s.id
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }

            // 次の授業カウントダウン
            if let next = nextClass, let countdown = countdownText {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(Color.appAccent)
                        .font(.caption)
                    Text("次: \(next.className) (\(countdown))")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Album Section

    private var albumSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近同期された授業アルバム")
                .font(.title3).fontWeight(.bold).foregroundStyle(Color.appTextPrimary)

            if albumVM.isLoading {
                ProgressView().frame(maxWidth: .infinity).padding()
            } else if albumVM.albums.isEmpty {
                Text("写真が見つかりませんでした")
                    .font(.subheadline).foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(albumVM.albums.prefix(4), id: \.schedule.id) { album in
                        NavigationLink(destination: PhotoGridView(album: album)) {
                            AlbumCardView(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Timetable List Section

    private var timetableListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("マイ時間割")
                .font(.title3).fontWeight(.bold).foregroundStyle(Color.appTextPrimary)

            if timetableVM.schedules.isEmpty {
                Text("まだ授業が登録されていません")
                    .font(.subheadline).foregroundStyle(Color.appTextSecondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(todaySchedules.isEmpty ? timetableVM.schedules : todaySchedules, id: \.id) { s in
                    TimetableRowCard(schedule: s, albums: albumVM.albums)
                }
            }
        }
    }

    // MARK: - Status Footer

    private var statusFooter: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ステータス：")
                    .font(.caption2).fontWeight(.bold).foregroundStyle(Color.appTextSecondary)
                Text(timetableVM.schedules.isEmpty
                     ? "時間割を登録すると自動写真整理が開始されます。"
                     : "本日のスケジュールで自動写真整理が「有効」です。")
                    .font(.caption2).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Button("時間割を管理") { showAddClass = true }
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
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Helpers

    private var todayDateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d"
        fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: now)
    }
}

// MARK: - Timetable Row Card

struct TimetableRowCard: View {
    let schedule: ClassSchedule
    let albums: [ClassAlbum]

    private var matchedAlbum: ClassAlbum? {
        albums.first { $0.schedule.id == schedule.id }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 時間列
            VStack(alignment: .trailing, spacing: 2) {
                Text(schedule.startTimeDisplay)
                    .font(.caption).fontWeight(.semibold).foregroundStyle(Color.appTextSecondary)
                Text(schedule.endTimeDisplay)
                    .font(.caption).foregroundStyle(Color.appTextSecondary)
            }
            .frame(width: 44)

            // 区切り線
            Rectangle()
                .fill(Color.appAccent.opacity(0.5))
                .frame(width: 2)
                .padding(.top, 3)

            // 授業情報列
            VStack(alignment: .leading, spacing: 3) {
                Text(schedule.className)
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.appTextPrimary)
                if !schedule.professor.isEmpty {
                    Text(schedule.professor)
                        .font(.caption).foregroundStyle(Color.appTextSecondary)
                }
                if !schedule.room.isEmpty {
                    Text(schedule.room)
                        .font(.caption).foregroundStyle(Color.appTextSecondary)
                }
                if let album = matchedAlbum {
                    Text("自動振り分け写真：\(schedule.startTimeDisplay)-\(schedule.endTimeDisplay)の時間枠（+10分バッファ）で\(album.assets.count)枚の写真が見つかりました")
                        .font(.caption2)
                        .foregroundStyle(Color.appGreen)
                        .padding(.top, 2)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
