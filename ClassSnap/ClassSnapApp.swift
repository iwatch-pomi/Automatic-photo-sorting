import SwiftUI
import SwiftData

@main
struct ClassSnapApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: ClassSchedule.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // RevenueCat 初期化
        // TODO: RevenueCat ダッシュボードで取得した iOS API キーに置き換えてください
        SubscriptionManager.shared.configure(apiKey: "YOUR_REVENUECAT_API_KEY")
        Task { await SubscriptionManager.shared.refreshStatus() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
