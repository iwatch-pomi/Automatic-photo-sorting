import SwiftUI

struct SearchView: View {
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ContentUnavailableView(
                    "検索",
                    systemImage: "magnifyingglass",
                    description: Text("授業名や日付で写真を検索できます（近日公開）")
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("黒板フォト同期")
                        .font(.headline).foregroundStyle(Color.appTextPrimary)
                }
            }
            .searchable(text: $query, prompt: "授業名・日付で検索")
        }
    }
}
