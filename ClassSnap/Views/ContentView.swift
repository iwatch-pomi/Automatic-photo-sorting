import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var timetableVM: TimetableViewModel?
    @State private var selectedTab: Tab = .home
    @State private var showOnboarding = false

    enum Tab { case home, timetable, search, profile }

    var body: some View {
        Group {
            if let vm = timetableVM {
                TabView(selection: $selectedTab) {
                    HomeView(timetableVM: vm)
                        .tabItem {
                            Label("ホーム", systemImage: selectedTab == .home
                                  ? "house.fill" : "house")
                        }
                        .tag(Tab.home)

                    TimetableView(viewModel: vm)
                        .tabItem {
                            Label("時間割", systemImage: "calendar")
                        }
                        .tag(Tab.timetable)

                    AlbumListView(schedules: vm.schedules)
                        .tabItem {
                            Label("アルバム", systemImage: selectedTab == .search
                                  ? "photo.stack.fill" : "photo.stack")
                        }
                        .tag(Tab.search)

                    ProfileView(viewModel: vm)
                        .tabItem {
                            Label("設定", systemImage: selectedTab == .profile
                                  ? "gearshape.fill" : "gearshape")
                        }
                        .tag(Tab.profile)
                }
                .tint(Color.appGreen)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(viewModel: vm) {
                        AppSettings.shared.hasCompletedOnboarding = true
                        showOnboarding = false
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
            }
        }
        .onAppear {
            if timetableVM == nil {
                timetableVM = TimetableViewModel(modelContext: modelContext)
            }
            // アプリ内保存写真ストアに ModelContext を注入し、孤児ファイルを整理
            SavedPhotoStore.shared.configure(context: modelContext)
            if !AppSettings.shared.hasCompletedOnboarding {
                showOnboarding = true
            }
            // タブバーの背景をクリーム色に統一
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.appBackground)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
