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

    private init() {}

    func configure() {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
              !apiKey.isEmpty else {
            return
        }
        Purchases.configure(withAPIKey: apiKey)
        Purchases.logLevel = .warn

        Task {
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
}
