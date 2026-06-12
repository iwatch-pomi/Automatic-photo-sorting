import SwiftUI
import SwiftData

struct ContentView: View {
    let stores: AppStores
    @State private var selectedTab: Tab = .home
    @State private var showOnboarding = false

    enum Tab { case home, timetable, albums, profile }

    /// 各ドメインストアの読み込みエラーをまとめて表示する（無言の空表示を防ぐ）
    private var storeError: String? {
        stores.schedule.errorMessage ?? stores.term.errorMessage ?? stores.makeup.errorMessage
    }

    private func clearStoreErrors() {
        stores.schedule.errorMessage = nil
        stores.term.errorMessage = nil
        stores.makeup.errorMessage = nil
    }

    var body: some View {
        // body 内で読むことで @Observable の変更追跡を効かせる
        let currentError = storeError
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
                    Label("アルバム", systemImage: selectedTab == .albums
                          ? "photo.stack.fill" : "photo.stack")
                }
                .tag(Tab.albums)

            ProfileView(stores: stores)
                .tabItem {
                    Label("設定", systemImage: selectedTab == .profile
                          ? "gearshape.fill" : "gearshape")
                }
                .tag(Tab.profile)
        }
        .tint(Color.appGreen)
        .alert("エラー", isPresented: Binding(
            get: { currentError != nil },
            set: { if !$0 { clearStoreErrors() } }
        )) {
            Button("OK") { clearStoreErrors() }
        } message: {
            Text(currentError ?? "")
        }
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
