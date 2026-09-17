import SwiftUI
import UIKit
import GoogleMobileAds
import AppTrackingTransparency

/// 広告ユニットID・App ID の設定。
///
/// App ID / 広告ユニットID は秘密情報ではない（配布バイナリに埋め込まれ公開される）。
/// DEBUG ビルドでは Google 公式のテストID を使い、実収益・実広告に影響を与えない。
/// Release ビルドでは Info.plist（xcconfig 経由）の実IDを読み、未設定時はテストIDに
/// フォールバックして「無効なIDで本番広告が出ない」事故を防ぐ。
///   - Info.plist キー: GADBannerUnitID / GADInterstitialUnitID
///   - AdMob App ID は Info.plist の GADApplicationIdentifier に設定（SDK が起動時に読む）
enum AdConfig {
    // Google 公式テスト広告ユニットID（https://developers.google.com/admob/ios/test-ads）
    static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"
    static let testInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    static var bannerUnitID: String {
        #if DEBUG
        return testBannerUnitID
        #else
        return infoPlistValue("GADBannerUnitID") ?? testBannerUnitID
        #endif
    }

    static var interstitialUnitID: String {
        #if DEBUG
        return testInterstitialUnitID
        #else
        return infoPlistValue("GADInterstitialUnitID") ?? testInterstitialUnitID
        #endif
    }

    private static func infoPlistValue(_ key: String) -> String? {
        guard let v = Bundle.main.object(forInfoDictionaryKey: key) as? String, !v.isEmpty else { return nil }
        return v
    }
}

/// AdMob（Google Mobile Ads）の初期化とインタースティシャル（全画面）広告の管理。
///
/// 収益モデル：全機能は無料。課金（買い切り／サブスク）の対価は「広告の非表示」。
/// そのため広告表示は常に `EntitlementManager.shared.isAdFree` で早期 return し、
/// 課金済みユーザーには一切広告を出さない。
///
/// ※ Google Mobile Ads SDK v12 系の Swift API 名（MobileAds / BannerView / Request /
///    InterstitialAd / currentOrientationAnchoredAdaptiveBanner）に合わせている。
@MainActor
@Observable
final class AdManager {
    static let shared = AdManager()

    @ObservationIgnored private var interstitial: InterstitialAd?
    @ObservationIgnored private var interstitialTriggerCount = 0
    @ObservationIgnored private var lastInterstitialShownAt: Date?
    @ObservationIgnored private var didStart = false

    /// 頻度制御。過剰表示は審査・UX の両面でリスクなので保守的に設定する（必要に応じて調整）。
    /// 「N 回に 1 回」かつ「前回表示から minInterval 秒以上」の両方を満たしたときだけ表示。
    @ObservationIgnored private let interstitialEveryNTriggers = 3
    @ObservationIgnored private let interstitialMinInterval: TimeInterval = 180

    private init() {}

    /// アプリ起動時に一度だけ呼ぶ。課金済みでも SDK 自体は初期化しておく
    /// （フォアグラウンド中に失効・解約された場合にすぐ広告を出せるようにするため）。
    func configure() {
        guard !didStart else { return }
        didStart = true
        MobileAds.shared.start(completionHandler: nil)
        preloadInterstitial()
    }

    /// ATT（App Tracking Transparency）の許可を要求する。初回フォアグラウンド後に呼ぶ想定。
    /// 拒否されても広告は非パーソナライズで表示するため、結果は問わない。
    func requestTrackingAuthorizationIfNeeded() {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        ATTrackingManager.requestTrackingAuthorization { _ in }
    }

    // MARK: - Interstitial

    /// 次回表示に備えてインタースティシャルを事前ロードしておく。
    func preloadInterstitial() {
        guard !EntitlementManager.shared.isAdFree else { return }
        guard interstitial == nil else { return }
        Task { [weak self] in
            let ad = try? await InterstitialAd.load(with: AdConfig.interstitialUnitID, request: Request())
            self?.interstitial = ad
        }
    }

    /// 自然な区切り（例：授業の追加完了）で呼ぶ。頻度制御を満たしたときだけ全画面広告を表示する。
    func maybeShowInterstitial() {
        guard !EntitlementManager.shared.isAdFree else { return }
        interstitialTriggerCount += 1

        let hitFrequency = interstitialTriggerCount % interstitialEveryNTriggers == 0
        let intervalOK: Bool = {
            guard let last = lastInterstitialShownAt else { return true }
            return Date().timeIntervalSince(last) >= interstitialMinInterval
        }()

        guard hitFrequency, intervalOK,
              let interstitial,
              let root = Self.rootViewController() else {
            preloadInterstitial()
            return
        }

        interstitial.present(from: root)
        lastInterstitialShownAt = Date()
        self.interstitial = nil
        preloadInterstitial()  // 次回に備えて再ロード
    }

    /// 現在最前面に表示されている UIViewController を取得（広告の presentation 用）。
    static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let keyWindow = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
