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
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        HStack {
                            Label("取得期間", systemImage: "calendar")
                            Spacer()
                            Text("全期間")
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    .listRowBackground(Color.appCard)

                    Section("情報") {
                        HStack {
                            Label("バージョン", systemImage: "info.circle")
                            Spacer()
                            Text("1.0.0 MVP")
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    .listRowBackground(Color.appCard)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("設定")
                        .font(.headline).foregroundStyle(Color.appTextPrimary)
                }
            }
        }
    }
}
