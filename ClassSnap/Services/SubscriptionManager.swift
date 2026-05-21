import Foundation
import Observation
// RevenueCat は Xcode の "File → Add Package Dependencies" で追加してください:
// https://github.com/RevenueCat/purchases-ios  (version: 5.x)
import RevenueCat

@Observable
final class SubscriptionManager: NSObject {
    static let shared = SubscriptionManager()

    var isPremium: Bool = false
    var isLoading: Bool = false
    var offerings: Offerings?
    var errorMessage: String?

    private override init() { super.init() }

    // MARK: - Setup

    /// ClassSnapApp.init() から呼ぶ
    func configure(apiKey: String) {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
    }

    // MARK: - Status

    func refreshStatus() async {
        guard let info = try? await Purchases.shared.customerInfo() else { return }
        isPremium = info.entitlements["premium"]?.isActive == true
    }

    // MARK: - Offerings

    func fetchOfferings() async {
        guard offerings == nil else { return }
        offerings = try? await Purchases.shared.offerings()
    }

    // MARK: - Purchase

    func purchase(_ package: Package) async throws {
        isLoading = true
        defer { isLoading = false }
        let result = try await Purchases.shared.purchase(package: package)
        isPremium = result.customerInfo.entitlements["premium"]?.isActive == true
    }

    // MARK: - Restore

    func restore() async throws {
        isLoading = true
        defer { isLoading = false }
        let info = try await Purchases.shared.restorePurchases()
        isPremium = info.entitlements["premium"]?.isActive == true
    }
}

// MARK: - PurchasesDelegate

extension SubscriptionManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        isPremium = customerInfo.entitlements["premium"]?.isActive == true
    }
}
