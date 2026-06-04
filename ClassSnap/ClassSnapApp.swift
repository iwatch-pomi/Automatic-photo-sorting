import SwiftUI
import SwiftData
import RevenueCat

@main
struct ClassSnapApp: App {
    let container: ModelContainer

    init() {
        EntitlementManager.shared.configure()
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: ClassSchedule.self, AcademicTerm.self, MakeupClass.self, SavedPhoto.self, configurations: config)
        } catch {
            // スキーマ変更で移行できない場合は既存ストアを削除して再作成
            let storeURL = config.url
            let fm = FileManager.default
            for suffix in ["", "-shm", "-wal"] {
                try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
            do {
                container = try ModelContainer(for: ClassSchedule.self, AcademicTerm.self, MakeupClass.self, SavedPhoto.self, configurations: config)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
