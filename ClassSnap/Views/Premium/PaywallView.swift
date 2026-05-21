import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    private let sub = SubscriptionManager.shared

    @State private var packages: [Package] = []
    @State private var selectedPackage: Package?
    @State private var errorText: String?

    private let features: [(icon: String, free: String, premium: String)] = [
        ("book.closed",     "3教科まで",    "無制限"),
        ("calendar",        "過去7日間",    "過去1年間"),
        ("doc.richtext",    "なし",         "PDF一括出力"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // ── ヘッダー ──
                        VStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.appAccent)
                            Text("ClassSnap プレミアム")
                                .font(.title2).fontWeight(.bold)
                                .foregroundStyle(Color.appTextPrimary)
                            Text("授業の記録をもっと便利に")
                                .font(.subheadline)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .padding(.top, 16)

                        // ── 比較テーブル ──
                        VStack(spacing: 0) {
                            // ヘッダー行
                            HStack {
                                Text("機能").frame(maxWidth: .infinity, alignment: .leading)
                                Text("無料").frame(width: 80, alignment: .center)
                                    .foregroundStyle(Color.appTextSecondary)
                                Text("プレミアム").frame(width: 88, alignment: .center)
                                    .foregroundStyle(Color.appAccent)
                            }
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.appCard)

                            Divider()

                            ForEach(features.indices, id: \.self) { i in
                                let f = features[i]
                                HStack {
                                    Label(f.icon == "book.closed" ? "登録教科数"
                                          : f.icon == "calendar" ? "写真取得期間"
                                          : "PDF一括出力",
                                          systemImage: f.icon)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appTextPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(f.free)
                                        .font(.caption)
                                        .foregroundStyle(Color.appTextSecondary)
                                        .frame(width: 80, alignment: .center)
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.appGreen)
                                            .font(.caption)
                                        Text(f.premium)
                                            .font(.caption).fontWeight(.semibold)
                                            .foregroundStyle(Color.appGreen)
                                    }
                                    .frame(width: 88, alignment: .center)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.appCard)

                                if i < features.count - 1 { Divider() }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 16)

                        // ── プラン選択 ──
                        if packages.isEmpty {
                            ProgressView("プランを読み込み中...")
                                .padding()
                        } else {
                            VStack(spacing: 10) {
                                ForEach(packages, id: \.identifier) { pkg in
                                    PackageRow(package: pkg,
                                               isSelected: selectedPackage?.identifier == pkg.identifier)
                                        .onTapGesture { selectedPackage = pkg }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // ── 購入ボタン ──
                        if let pkg = selectedPackage {
                            Button {
                                Task { await buySelected(pkg) }
                            } label: {
                                Group {
                                    if sub.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("このプランで始める")
                                            .fontWeight(.bold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.appGreen)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(sub.isLoading)
                            .padding(.horizontal, 16)
                        }

                        // ── 復元 ──
                        Button("購入を復元") {
                            Task { await restorePurchases() }
                        }
                        .font(.footnote)
                        .foregroundStyle(Color.appTextSecondary)

                        if let err = errorText {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // 利用規約
                        Text("購入はApple IDに請求されます。サブスクリプションは期間終了の24時間前に自動更新されます。")
                            .font(.caption2)
                            .foregroundStyle(Color.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.appTextPrimary)
                }
            }
        }
        .task {
            await sub.fetchOfferings()
            packages = sub.offerings?.current?.availablePackages ?? []
            selectedPackage = packages.first
        }
    }

    private func buySelected(_ pkg: Package) async {
        errorText = nil
        do {
            try await sub.purchase(pkg)
            dismiss()
        } catch {
            errorText = "購入に失敗しました: \(error.localizedDescription)"
        }
    }

    private func restorePurchases() async {
        errorText = nil
        do {
            try await sub.restore()
            if sub.isPremium { dismiss() }
            else { errorText = "復元できる購入履歴が見つかりませんでした。" }
        } catch {
            errorText = "復元に失敗しました: \(error.localizedDescription)"
        }
    }
}

// MARK: - Package Row

private struct PackageRow: View {
    let package: Package
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(package.storeProduct.localizedTitle)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.appTextPrimary)
                Text(package.storeProduct.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Text(package.localizedPriceString)
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(isSelected ? Color.appAccent : Color.appTextPrimary)
        }
        .padding(14)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.appAccent : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}
