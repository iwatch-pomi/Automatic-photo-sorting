import SwiftUI

struct ProfileView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List {
                    Section {
                        HStack {
                            Image(systemName: "clock.badge")
                                .foregroundStyle(Color.appGreen)
                                .frame(width: 24)
                            Text("バッファ時間")
                                .foregroundStyle(Color.appTextPrimary)
                            Spacer()
                            Stepper(
                                "±\(settings.bufferMinutes)分",
                                value: $settings.bufferMinutes,
                                in: 0...60,
                                step: 5
                            )
                            .fixedSize()
                            .foregroundStyle(Color.appTextSecondary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Label("バッファ時間とは？", systemImage: "questionmark.circle")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(Color.appGreen)
                            Text("""
                                授業の開始・終了時刻の前後に「ゆとり」を持たせて写真を探す機能です。

                                例）バッファ±10分・授業が9:00〜10:30の場合
                                → **8:50〜10:40** の間に撮影された写真を取得します。

                                授業ギリギリに撮り忘れた写真や、終了後すぐに撮った写真も拾えるように設定してください。0分にするとぴったりの時間帯だけを対象にします。
                                """)
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("アプリ設定")
                    }
                    .listRowBackground(Color.appCard)

                    Section {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(Color.appGreen)
                                .frame(width: 24)
                            Text("取得期間")
                                .foregroundStyle(Color.appTextPrimary)
                            Spacer()
                            Text("全期間")
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    .listRowBackground(Color.appCard)

                    Section("情報") {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(Color.appGreen)
                                .frame(width: 24)
                            Text("バージョン")
                                .foregroundStyle(Color.appTextPrimary)
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
