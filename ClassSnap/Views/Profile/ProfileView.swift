import SwiftUI

struct ProfileView: View {
    @State private var showPaywall = false
    private let sub = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List {
                    // ── プレミアムセクション ──
                    Section("プレミアム") {
                        if sub.isPremium {
                            HStack {
                                Label("プレミアム会員", systemImage: "crown.fill")
                                    .foregroundStyle(Color.appAccent)
                                Spacer()
                                Text("有効")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundStyle(Color.appGreen)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.appGreen.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    Label("プレミアムにアップグレード", systemImage: "crown")
                                        .foregroundStyle(Color.appTextPrimary)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("¥150/月")
                                            .font(.caption).fontWeight(.bold)
                                            .foregroundStyle(Color.appAccent)
                                        Text("無制限・PDF出力")
                                            .font(.caption2)
                                            .foregroundStyle(Color.appTextSecondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.appCard)

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
                            Text(sub.isPremium ? "過去1年間" : "過去7日間")
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}
