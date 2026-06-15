import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    private let manager = EntitlementManager.shared

    @State private var selectedIndex: Int = 2
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var offeringsLoadFailed = false

    /// リリース記念キャンペーンの表示フラグ。
    /// 人気が出たらこの値を false にする（または launchPromoBanner ごと削除する）だけで
    /// アップデートで非表示にできる。
    private let showLaunchPromo = true

    private struct PlanInfo {
        let label: String
        let packageId: String   // "$rc_monthly" / "$rc_two_month" / "$rc_six_month" / "$rc_annual"
        let months: Int         // 月換算・割引計算用
    }

    private let plans: [PlanInfo] = [
        PlanInfo(label: "月額",         packageId: "$rc_monthly",   months: 1),
        PlanInfo(label: "2ヶ月",        packageId: "$rc_two_month", months: 2),
        PlanInfo(label: "学期（6ヶ月）", packageId: "$rc_six_month", months: 6),
        PlanInfo(label: "年間",         packageId: "$rc_annual",    months: 12),
    ]

    /// 利用規約（Apple標準EULA）とプライバシーポリシーのURL。
    /// App Store の審査要件（Guideline 3.1.2）により、課金画面から到達できるようにする。
    private static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyPolicyURL = URL(string: "https://iwatch-pomi.github.io/Automatic-photo-sorting/")!

    private let features: [(String, String)] = [
        ("photo.fill.on.rectangle.fill", "写真の自動マッチング・閲覧"),
        ("square.and.arrow.up",          "写真・PDF の書き出し"),
        ("internaldrive",                "写真をアプリ内に保存"),
        ("textformat",                   "授業回のカスタム名称"),
        ("bookmark.fill",                "テスト範囲マーカー"),
        ("calendar.badge.plus",          "複数学期の管理"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    if showLaunchPromo { launchPromoBanner }
                    featureSection
                    planSelector
                    if offeringsLoadFailed {
                        Text("価格情報を取得できませんでした。通信環境をご確認のうえ、時間をおいて再度お試しください。")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    purchaseButton
                    restoreButton
                    redeemCodeButton
                    footerNote
                    legalLinks
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.appTextSecondary)
                            .font(.title3)
                    }
                }
            }
        }
        .alert("購入の復元", isPresented: $showRestoreAlert) {
            // 復元成功時はメッセージを見せてから閉じる（即 dismiss するとアラートが表示されない）
            Button("OK") { if manager.isPro { dismiss() } }
        } message: {
            Text(restoreMessage)
        }
        .alert("エラー", isPresented: Binding(
            get: { manager.purchaseError != nil },
            set: { if !$0 { manager.purchaseError = nil } }
        )) {
            Button("OK") { manager.purchaseError = nil }
        } message: {
            Text(manager.purchaseError ?? "")
        }
        .task {
            await manager.fetchOfferings()
            // 取得できない場合（APIキー未設定・通信不可など）はスピナーを出し続けず明示する
            offeringsLoadFailed = manager.offerings?.current == nil
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.appGreen)
                .padding(.top, 8)
            Text("コマフォト Pro")
                .font(.title).fontWeight(.bold)
                .foregroundStyle(Color.appTextPrimary)
            Text("授業写真をもっとスマートに管理")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    // MARK: - リリース記念キャンペーン（人気が出たら削除予定）
    // 削除方法: showLaunchPromo を false にする、または本 computed property と
    // body 内の `if showLaunchPromo { launchPromoBanner }` 行を削除する。
    private var launchPromoBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("🎉")
                Text("アプリリリース記念キャンペーン")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(Color.appGreen)
                Spacer()
                Text("今だけ")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.appGreen)
                    .clipShape(Capsule())
            }
            Text("X（旧Twitter）でコマフォトを紹介していただき、その投稿に「いいね」が10件ついたら、コマフォト Pro 2ヶ月分を無料でプレゼント！")
                .font(.footnote)
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(Color.appTextSecondary)
                Text("「#コマフォト」を付けて投稿し、いいねが10件ついたら投稿リンクをXのDMで@iwaseAppLABまでお送りください。")
                    .font(.caption2)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.appGreen.opacity(0.35), lineWidth: 1.5)
        )
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(features.indices, id: \.self) { i in
                let (icon, label) = features[i]
                let isFree = i <= 0
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundStyle(Color.appGreen)
                        .frame(width: 22)
                    Text(label)
                        .foregroundStyle(Color.appTextPrimary)
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: isFree ? "checkmark.circle" : "checkmark.circle.fill")
                        .foregroundStyle(isFree ? Color.appTextSecondary : Color.appGreen)
                }
            }
        }
        .padding(16)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var planSelector: some View {
        VStack(spacing: 10) {
            ForEach(plans.indices, id: \.self) { i in
                let plan = plans[i]
                let isSelected = selectedIndex == i
                Button { selectedIndex = i } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(plan.label)
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundStyle(Color.appTextPrimary)
                                if let badge = discountBadge(for: plan) {
                                    Text(badge)
                                        .font(.caption2).fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.appGreen)
                                        .clipShape(Capsule())
                                }
                            }
                            if let monthly = monthlyString(for: plan) {
                                Text(monthly)
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        Spacer()
                        if let price = localizedPrice(for: plan) {
                            Text(price)
                                .font(.headline).fontWeight(.bold)
                                .foregroundStyle(isSelected ? Color.appGreen : Color.appTextPrimary)
                        } else {
                            ProgressView()
                        }
                    }
                    .padding(14)
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? Color.appGreen : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            Task { await performPurchase() }
        } label: {
            Group {
                if manager.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("今すぐ始める")
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.appGreen)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(manager.isLoading || manager.offerings?.current == nil)
    }

    private var restoreButton: some View {
        Button {
            Task { await performRestore() }
        } label: {
            Text("購入を復元する")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .underline()
        }
        .disabled(manager.isLoading)
    }

    /// プロモーションコード（オファーコード）入力シートを表示
    private var redeemCodeButton: some View {
        Button {
            manager.presentOfferCodeRedemption()
        } label: {
            Text("プロモーションコードを入力")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .underline()
        }
        .disabled(manager.isLoading)
    }

    private var footerNote: some View {
        Text("コマフォト Pro（月額／2ヶ月／6ヶ月／年間の自動更新サブスクリプション）。支払いは購入確定時に Apple ID に請求されます。期間終了の24時間以上前に自動更新をオフにしない限り、同じ期間・同じ料金で自動更新されます。購入後はキャンセルするまで継続し、解約は購入後に Apple ID の設定からいつでも行えます。")
            .font(.caption2)
            .foregroundStyle(Color.appTextSecondary)
            .multilineTextAlignment(.center)
    }

    /// 利用規約・プライバシーポリシーへの機能するリンク（App Store 審査要件）
    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("利用規約（EULA）", destination: Self.termsOfUseURL)
            Text("・")
                .foregroundStyle(Color.appTextSecondary)
            Link("プライバシーポリシー", destination: Self.privacyPolicyURL)
        }
        .font(.caption2)
        .tint(Color.appGreen)
        .multilineTextAlignment(.center)
    }

    // MARK: - Package / Price Helpers

    /// プランに対応する RevenueCat パッケージを解決
    private func package(for plan: PlanInfo) -> Package? {
        guard let offering = manager.offerings?.current else { return nil }
        switch plan.packageId {
        case "$rc_monthly": return offering.monthly
        case "$rc_annual":  return offering.annual
        default:            return offering.availablePackages.first { $0.identifier == plan.packageId }
        }
    }

    /// ローカライズされた価格文字列（例: ¥580）。未取得時は nil
    private func localizedPrice(for plan: PlanInfo) -> String? {
        package(for: plan)?.storeProduct.localizedPriceString
    }

    /// 実価格から計算した月換算表示（例: ¥440/月）
    private func monthlyString(for plan: PlanInfo) -> String? {
        guard let product = package(for: plan)?.storeProduct else { return nil }
        let perMonth = product.price / Decimal(plan.months)
        guard let formatted = formatCurrency(perMonth, like: product) else { return nil }
        return "\(formatted)/月"
    }

    /// 月額プランの月単価を基準に割引率を計算（正のときだけバッジ表示）
    private func discountBadge(for plan: PlanInfo) -> String? {
        guard plan.months > 1,
              let base = perMonthPrice(forPackageId: "$rc_monthly"),
              base > 0,
              let product = package(for: plan)?.storeProduct else { return nil }
        let perMonth = product.price / Decimal(plan.months)
        let ratio = (perMonth as NSDecimalNumber).doubleValue / (base as NSDecimalNumber).doubleValue
        let percent = Int((1.0 - ratio) * 100.0 + 0.5)
        guard percent > 0 else { return nil }
        // 最大割引（年間）には祝祭感を添える
        return plan.packageId == "$rc_annual" ? "\(percent)%お得 🎉" : "\(percent)%お得"
    }

    private func perMonthPrice(forPackageId id: String) -> Decimal? {
        guard let plan = plans.first(where: { $0.packageId == id }),
              let product = package(for: plan)?.storeProduct else { return nil }
        return product.price / Decimal(plan.months)
    }

    /// 商品の通貨設定に合わせて金額を整形（priceFormatter 優先、無ければ currencyCode から組む）
    private func formatCurrency(_ value: Decimal, like product: StoreProduct) -> String? {
        let formatter = product.priceFormatter ?? {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencyCode = product.currencyCode
            f.locale = Locale(identifier: "ja_JP")
            return f
        }()
        return formatter.string(from: value as NSDecimalNumber)
    }

    private func performPurchase() async {
        let plan = plans[selectedIndex]
        guard let pkg = package(for: plan) else { return }
        await manager.purchase(package: pkg)
        if manager.isPro { dismiss() }
    }

    private func performRestore() async {
        await manager.restorePurchases()
        if manager.isPro {
            restoreMessage = "購入が復元されました。コマフォト Pro をお楽しみください！"
            showRestoreAlert = true
            dismiss()
        } else {
            restoreMessage = "復元できる購入が見つかりませんでした。"
            showRestoreAlert = true
        }
    }
}

