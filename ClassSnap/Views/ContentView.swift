import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var timetableVM: TimetableViewModel?

    var body: some View {
        Group {
            if let vm = timetableVM {
                TabView {
                    TimetableView(viewModel: vm)
                        .tabItem {
                            Label("時間割", systemImage: "calendar")
                        }

                    AlbumListView(schedules: vm.schedules)
                        .tabItem {
                            Label("アルバム", systemImage: "photo.stack")
                        }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if timetableVM == nil {
                timetableVM = TimetableViewModel(modelContext: modelContext)
            }
        }
    }
}
