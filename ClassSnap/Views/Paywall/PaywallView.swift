import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    private let manager = EntitlementManager.shared

    @State private var selectedIndex: Int = 2
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    private struct PlanInfo {
        let label: String
        let price: String
        let monthly: String
        let badge: String?
        let packageId: String
    }

    private let plans: [PlanInfo] = [
        PlanInfo(label: "月額",       price: "¥580",   monthly: "¥580/月",   badge: nil,          packageId: "$rc_monthly"),
        PlanInfo(label: "2ヶ月",      price: "¥880",   monthly: "¥440/月",   badge: "24%お得",     packageId: "two_month"),
        PlanInfo(label: "学期（4ヶ月）", price: "¥1,480", monthly: "¥370/月",  badge: "36%お得",     packageId: "four_month"),
        PlanInfo(label: "年間",        price: "¥3,600", monthly: "¥300/月",   badge: "48%お得 🎉",  packageId: "$rc_annual"),
    ]

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
                    featureSection
                    planSelector
                    purchaseButton
                    restoreButton
                    footerNote
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
            Button("OK") {}
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
        .task { await manager.fetchOfferings() }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.appGreen)
                .padding(.top, 8)
            Text("ClassSnap Pro")
                .font(.title).fontWeight(.bold)
                .foregroundStyle(Color.appTextPrimary)
            Text("授業写真をもっとスマートに管理")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
        }
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
                                if let badge = plan.badge {
                                    Text(badge)
                                        .font(.caption2).fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.appGreen)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(plan.monthly)
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                        Text(plan.price)
                            .font(.headline).fontWeight(.bold)
                            .foregroundStyle(isSelected ? Color.appGreen : Color.appTextPrimary)
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
        .disabled(manager.isLoading)
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

    private var footerNote: some View {
        Text("支払いは Apple ID に請求されます。サブスクリプションは自動更新されます。更新日の24時間以上前にキャンセルしない限り、自動的に更新されます。購入後はキャンセルするまで継続します。")
            .font(.caption2)
            .foregroundStyle(Color.appTextSecondary)
            .multilineTextAlignment(.center)
    }

    private func performPurchase() async {
        let plan = plans[selectedIndex]
        guard let offering = manager.offerings?.current else { return }

        let package: Package?
        switch plan.packageId {
        case "$rc_monthly":   package = offering.monthly
        case "$rc_annual":    package = offering.annual
        default:
            package = offering.availablePackages.first { $0.identifier == plan.packageId }
        }
        guard let pkg = package else { return }
        await manager.purchase(package: pkg)
        if manager.isPro { dismiss() }
    }

    private func performRestore() async {
        await manager.restorePurchases()
        if manager.isPro {
            restoreMessage = "購入が復元されました。ClassSnap Pro をお楽しみください！"
            showRestoreAlert = true
            dismiss()
        } else {
            restoreMessage = "復元できる購入が見つかりませんでした。"
            showRestoreAlert = true
        }
    }
}

struct ProGateModifier: ViewModifier {
    @Binding var showPaywall: Bool
    let isLocked: Bool

    func body(content: Content) -> some View {
        content
            .disabled(isLocked)
            .onTapGesture { if isLocked { showPaywall = true } }
            .allowsHitTesting(true)
    }
}
