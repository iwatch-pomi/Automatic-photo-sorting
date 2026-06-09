import SwiftUI
import SwiftData
import RevenueCat

@main
struct ClassSnapApp: App {
    let container: ModelContainer
    @State private var stores: AppStores

    init() {
        EntitlementManager.shared.configure()
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        let builtContainer: ModelContainer
        do {
            builtContainer = try ModelContainer(for: ClassSchedule.self, AcademicTerm.self, MakeupClass.self, SavedPhoto.self, configurations: config)
        } catch {
            // スキーマ変更で移行できない場合は既存ストアを削除して再作成
            let storeURL = config.url
            let fm = FileManager.default
            for suffix in ["", "-shm", "-wal"] {
                try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
            do {
                builtContainer = try ModelContainer(for: ClassSchedule.self, AcademicTerm.self, MakeupClass.self, SavedPhoto.self, configurations: config)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
        container = builtContainer
        // ドメインストアと保存ストアを起動時に確定させ、ルート画面が常に描画される状態にする
        // （onAppear 任せだとモーダル復元時にプレースホルダのまま白画面になることがある）
        _stores = State(initialValue: AppStores(modelContext: builtContainer.mainContext))
        SavedPhotoStore.shared.configure(context: builtContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(stores: stores)
                // アプリは固定のライト配色（クリーム背景・白カード）で設計されているため、
                // 端末がダークモードでも標準コントロールの文字が白くならないようライトに固定する
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}
