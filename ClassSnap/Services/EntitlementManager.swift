import Foundation
import RevenueCat

@MainActor
@Observable
final class EntitlementManager {
    static let shared = EntitlementManager()

    var isPro: Bool = false
    var offerings: Offerings?
    var isLoading: Bool = false
    var purchaseError: String?

    /// customerInfo 監視タスク。ライフサイクルを明示するためプロパティで保持する。
    @ObservationIgnored private var customerInfoTask: Task<Void, Never>?

    private init() {}

    func configure() {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
              !apiKey.isEmpty else {
            // APIキー未設定のままリリースすると課金導線が全滅するため、開発時に即気付けるようにする
            assertionFailure("RevenueCatAPIKey が未設定です。Secrets.xcconfig を確認してください。")
            return
        }
        Purchases.configure(withAPIKey: apiKey)
        Purchases.logLevel = .warn

        customerInfoTask = Task {
            for await customerInfo in Purchases.shared.customerInfoStream {
                isPro = customerInfo.entitlements["pro"]?.isActive == true
            }
        }
    }

    func fetchOfferings() async {
        guard Purchases.isConfigured else { return }
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// 最新の購読状態を RevenueCat から取り直して isPro を更新する。
    /// フォアグラウンド復帰時に呼び、期限切れ（自動更新の停止・解約）を即座に反映する。
    /// customerInfoStream による自動更新に加えた明示的な再検証。
    func refreshCustomerInfo() async {
        guard Purchases.isConfigured else { return }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPro = customerInfo.entitlements["pro"]?.isActive == true
        } catch {
            // 取得失敗時は既存の isPro を維持（オフライン等での誤ロックを避ける）
        }
    }

    func purchase(package: Package) async {
        guard Purchases.isConfigured else { return }
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            isPro = result.customerInfo.entitlements["pro"]?.isActive == true
        } catch {
            if (error as? ErrorCode) != .purchaseCancelledError {
                purchaseError = error.localizedDescription
            }
        }
    }

    func restorePurchases() async {
        guard Purchases.isConfigured else { return }
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isPro = customerInfo.entitlements["pro"]?.isActive == true
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// App Store のオファーコード（プロモーションコード）入力シートを表示する。
    /// シート上で引き換えが完了すると、customerInfoStream 経由で isPro が更新される。
    func presentOfferCodeRedemption() {
        guard Purchases.isConfigured else { return }
        Purchases.shared.presentCodeRedemptionSheet()
    }
}
