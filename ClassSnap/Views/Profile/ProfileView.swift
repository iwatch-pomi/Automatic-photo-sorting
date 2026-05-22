import SwiftUI

private struct SettingsRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.appGreen)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(Color.appTextPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List {
                    Section("アプリ設定") {
                        SettingsRow(icon: "clock.badge", label: "バッファ時間", value: "±10分")
                        SettingsRow(icon: "calendar",    label: "取得期間",     value: "全期間")
                    }
                    .listRowBackground(Color.appCard)

                    Section("情報") {
                        SettingsRow(icon: "info.circle", label: "バージョン", value: "1.0.0 MVP")
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
