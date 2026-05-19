import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List {
                    Section("アプリ設定") {
                        HStack {
                            Label("バッファ時間", systemImage: "clock.badge")
                            Spacer()
                            Text("±10分")
                                .foregroundStyle(.appTextSecondary)
                        }
                        HStack {
                            Label("取得期間", systemImage: "calendar")
                            Spacer()
                            Text("過去7日間")
                                .foregroundStyle(.appTextSecondary)
                        }
                    }
                    .listRowBackground(Color.appCard)

                    Section("情報") {
                        HStack {
                            Label("バージョン", systemImage: "info.circle")
                            Spacer()
                            Text("1.0.0 MVP")
                                .foregroundStyle(.appTextSecondary)
                        }
                    }
                    .listRowBackground(Color.appCard)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("黒板フォト同期")
                        .font(.headline).foregroundStyle(.appTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "gearshape").foregroundStyle(.appTextPrimary)
                }
            }
        }
    }
}
