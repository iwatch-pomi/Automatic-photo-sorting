import SwiftUI
import SwiftData

struct ContentView: View {
    let stores: AppStores
    @State private var selectedTab: Tab = .home
    @State private var showOnboarding = false

    enum Tab { case home, timetable, search, profile }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(stores: stores)
                .tabItem {
                    Label("ホーム", systemImage: selectedTab == .home
                          ? "house.fill" : "house")
                }
                .tag(Tab.home)

            TimetableView(stores: stores)
                .tabItem {
                    Label("時間割", systemImage: "calendar")
                }
                .tag(Tab.timetable)

            AlbumListView(stores: stores)
                .tabItem {
                    Label("アルバム", systemImage: selectedTab == .search
                          ? "photo.stack.fill" : "photo.stack")
                }
                .tag(Tab.search)

            ProfileView(stores: stores)
                .tabItem {
                    Label("設定", systemImage: selectedTab == .profile
                          ? "gearshape.fill" : "gearshape")
                }
                .tag(Tab.profile)
        }
        .tint(Color.appGreen)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(stores: stores) {
                AppSettings.shared.hasCompletedOnboarding = true
                showOnboarding = false
            }
        }
        .onAppear {
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
