import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var timetableVM: TimetableViewModel?
    @State private var selectedTab: Tab = .home

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
                            Label("検索", systemImage: selectedTab == .search
                                  ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
                        }
                        .tag(Tab.search)

                    ProfileView()
                        .tabItem {
                            Label("設定", systemImage: selectedTab == .profile
                                  ? "gearshape.fill" : "gearshape")
                        }
                        .tag(Tab.profile)
                }
                .tint(Color.appGreen)
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
            // タブバーの背景をクリーム色に統一
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.appBackground)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
