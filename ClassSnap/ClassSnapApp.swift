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
            // スキーマ変更等で開けない場合、既存ストアは削除せずバックアップへ退避してから再作成する。
            // （ディスク満杯や一時的なロックでも catch に入るため、無条件削除はデータ消失につながる）
            let storeURL = config.url
            let fm = FileManager.default
            let backupSuffix = ".backup-\(Int(Date().timeIntervalSince1970))"
            for suffix in ["", "-shm", "-wal"] {
                let src = URL(fileURLWithPath: storeURL.path + suffix)
                guard fm.fileExists(atPath: src.path) else { continue }
                let dst = URL(fileURLWithPath: storeURL.path + suffix + backupSuffix)
                do {
                    try fm.moveItem(at: src, to: dst)
                } catch {
                    // 退避すらできない場合のみ削除を試みる（起動不能ループの回避を優先）
                    try? fm.removeItem(at: src)
                }
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
                // DatePicker・数値フォーマット等のシステムUIを日本語・日本ロケールに固定する
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .environment(\.calendar, Calendar(identifier: .gregorian))
        }
        .modelContainer(container)
    }
}
