import SwiftUI
import Photos

struct HomeView: View {
    var timetableVM: TimetableViewModel
    @State private var albumVM = AlbumViewModel()
    @State private var now = Date()
    @State private var selectedScheduleID: UUID?
    @State private var showAddClass = false
    @State private var showSettings = false
    @State private var showAddMakeup = false
    @State private var makeupToDelete: MakeupClass?

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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 今日の授業
                    todaySection
                    // 補講日
                    if !timetableVM.schedules.isEmpty || !timetableVM.upcomingMakeupClasses.isEmpty {
                        makeupSection
                    }
                    // 最近同期された授業アルバム
                    albumSection
                    // マイ時間割
                    timetableListSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
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
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.appTextPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddClass, onDismiss: reloadAlbums) {
                AddClassView(viewModel: timetableVM)
            }
            .sheet(isPresented: $showSettings, onDismiss: reloadAlbums) {
                ProfileView(viewModel: timetableVM)
            }
            .sheet(isPresented: $showAddMakeup, onDismiss: reloadAlbums) {
                AddMakeupClassView(viewModel: timetableVM)
            }
            .confirmationDialog(
                "この補講を削除しますか？",
                isPresented: Binding(
                    get: { makeupToDelete != nil },
                    set: { if !$0 { makeupToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: makeupToDelete
            ) { makeup in
                Button("削除する", role: .destructive) {
                    timetableVM.deleteMakeupClass(makeup)
                    reloadAlbums()
                }
                Button("キャンセル", role: .cancel) { makeupToDelete = nil }
            } message: { makeup in
                Text("\(makeup.dateDisplay) の補講をリストから削除します。")
            }
        }
        .onReceive(timer) { now = $0 }
        .task { await albumVM.loadAlbums(schedules: timetableVM.schedulesForSelectedTerm) }
        .onChange(of: timetableVM.selectedTermID) { reloadAlbums() }
        .onChange(of: timetableVM.schedules.count) { reloadAlbums() }
        .onChange(of: timetableVM.makeupClasses.count) { reloadAlbums() }
        // 手動で写真を追加/除外したらアルバムの枚数を再計算
        .onChange(of: PhotoInclusionStore.shared.version) { reloadAlbums() }
    }

    private func reloadAlbums() {
        Task { await albumVM.loadAlbums(schedules: timetableVM.schedulesForSelectedTerm) }
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
                                day: timetableVM.todayAppDay(now: now),
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
                    Text("次: \(next.subjectName) (\(countdown))")
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

    // MARK: - Makeup Section

    private var makeupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("補講日")
                    .font(.title3).fontWeight(.bold).foregroundStyle(Color.appTextPrimary)
                Spacer()
                Button { showAddMakeup = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.appGreen)
                        .font(.title3)
                }
            }

            if timetableVM.upcomingMakeupClasses.isEmpty {
                Text("登録された補講はありません")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(timetableVM.upcomingMakeupClasses, id: \.id) { makeup in
                    let name = timetableVM.schedules
                        .first { $0.id == makeup.scheduleID }?.subjectName ?? "不明な授業"
                    MakeupClassRowView(makeup: makeup, scheduleName: name) {
                        makeupToDelete = makeup
                    }
                }
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(albumVM.albums, id: \.schedule.id) { album in
                            NavigationLink(destination: SessionListView(album: album)) {
                                AlbumCardView(album: album)
                                    .frame(width: 160)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.bottom, 4)
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
                ForEach(timetableVM.schedulesForSelectedTerm, id: \.id) { s in
                    TimetableRowCard(schedule: s, albums: albumVM.albums)
                }
            }
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
                if schedule.hasUniformTime {
                    Text(schedule.startTimeDisplay)
                        .font(.caption).fontWeight(.semibold).foregroundStyle(Color.appTextSecondary)
                    Text(schedule.endTimeDisplay)
                        .font(.caption).foregroundStyle(Color.appTextSecondary)
                } else {
                    Text("曜日")
                        .font(.caption2).fontWeight(.semibold).foregroundStyle(Color.appTextSecondary)
                    Text("により")
                        .font(.caption2).foregroundStyle(Color.appTextSecondary)
                    Text("異なる")
                        .font(.caption2).foregroundStyle(Color.appTextSecondary)
                }
            }
            .frame(width: 44)

            // 区切り線
            Rectangle()
                .fill(Color.appAccent.opacity(0.5))
                .frame(width: 2)
                .padding(.top, 3)

            // 授業情報列
            VStack(alignment: .leading, spacing: 3) {
                Text(schedule.subjectName)
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.appTextPrimary)
                Text(schedule.daysDisplay)
                    .font(.caption).foregroundStyle(Color.appAccent)
                if !schedule.professor.isEmpty {
                    Text(schedule.professor)
                        .font(.caption).foregroundStyle(Color.appTextSecondary)
                }
                if !schedule.room.isEmpty {
                    Text(schedule.room)
                        .font(.caption).foregroundStyle(Color.appTextSecondary)
                }
                if let album = matchedAlbum {
                    Text("自動振り分け写真：各授業時間枠（+バッファ）で\(album.activeCount)枚の写真が見つかりました")
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

// MARK: - Makeup Class Row

private struct MakeupClassRowView: View {
    let makeup: MakeupClass
    let scheduleName: String
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(makeup.startDisplay)
                    .font(.caption).fontWeight(.semibold).foregroundStyle(Color.appTextSecondary)
                Text(makeup.endDisplay)
                    .font(.caption).foregroundStyle(Color.appTextSecondary)
            }
            .frame(width: 44)

            Rectangle()
                .fill(Color.appGreen.opacity(0.6))
                .frame(width: 2)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(scheduleName)
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.appTextPrimary)
                Text(makeup.dateDisplay)
                    .font(.caption).foregroundStyle(Color.appGreen)
                if !makeup.room.isEmpty {
                    Text(makeup.room)
                        .font(.caption).foregroundStyle(Color.appTextSecondary)
                }
                if !makeup.note.isEmpty {
                    Text(makeup.note)
                        .font(.caption2).foregroundStyle(Color.appTextSecondary)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
