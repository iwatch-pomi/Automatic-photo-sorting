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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
