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
    static let testRewardedUnitID = "ca-app-pub-3940256099942544/1712485313"

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

    static var rewardedUnitID: String {
        #if DEBUG
        return testRewardedUnitID
        #else
        return infoPlistValue("GADRewardedUnitID") ?? testRewardedUnitID
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
    @ObservationIgnored private var rewarded: RewardedAd?
    @ObservationIgnored private var isLoadingRewarded = false
    @ObservationIgnored private var interstitialTriggerCount = 0
    @ObservationIgnored private var lastInterstitialShownAt: Date?
    @ObservationIgnored private var didStart = false
    /// 今回の起動（プロセス）中に、ホーム→アルバム移動時の全画面広告を出したか。
    /// メモリ上のみ保持するため、アプリを閉じて（プロセス終了して）開き直すとリセットされ、
    /// バックグラウンド復帰だけでは再表示しない。
    @ObservationIgnored private var albumsInterstitialShownThisLaunch = false

    /// 頻度制御。過剰表示は審査・UX の両面でリスクなので保守的に設定する（必要に応じて調整）。
    /// 「N 回に 1 回」かつ「前回表示から minInterval 秒以上」の両方を満たしたときだけ表示。
    @ObservationIgnored private let interstitialEveryNTriggers = 1
    @ObservationIgnored private let interstitialMinInterval: TimeInterval = 120

    private init() {}

    /// 広告を表示すべきか。課金（広告非表示）中でも、デベロッパーモード（広告テスト）が
    /// ONのときは広告を表示する。バナー・インタースティシャルはこの判定を用いる。
    @MainActor
    static var adsVisible: Bool {
        if AppSettings.shared.adTestModeEnabled { return true }
        if EntitlementManager.shared.isAdFree { return false }
        // リワード広告の視聴報酬による一時的な広告非表示期間中は広告を出さない
        if AppSettings.shared.isRewardAdFreeActive { return false }
        return true
    }

    /// アプリ起動時に一度だけ呼ぶ。課金済みでも SDK 自体は初期化しておく
    /// （フォアグラウンド中に失効・解約された場合にすぐ広告を出せるようにするため）。
    func configure() {
        guard !didStart else { return }
        didStart = true
        MobileAds.shared.start(completionHandler: nil)
        preloadInterstitial()
        preloadRewarded()
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
        guard Self.adsVisible else { return }
        guard interstitial == nil else { return }
        Task { [weak self] in
            let ad = try? await InterstitialAd.load(with: AdConfig.interstitialUnitID, request: Request())
            self?.interstitial = ad
        }
    }

    /// 自然な区切り（例：授業の追加完了）で呼ぶ。頻度制御を満たしたときだけ全画面広告を表示する。
    func maybeShowInterstitial() {
        guard Self.adsVisible else { return }
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

    /// ホーム→アルバム移動時に、今回の起動につき1回だけ全画面広告を表示する。
    /// 通常の頻度制御（120秒間隔）とは独立した「起動ごと1回」の枠。
    /// 広告が未ロードのときは表示せず、フラグも立てない（次回の移動で再挑戦）。
    func showAlbumsInterstitialOncePerLaunch() {
        guard Self.adsVisible else { return }
        guard !albumsInterstitialShownThisLaunch else { return }
        guard let interstitial, let root = Self.rootViewController() else {
            preloadInterstitial()
            return
        }
        interstitial.present(from: root)
        albumsInterstitialShownThisLaunch = true
        lastInterstitialShownAt = Date()
        self.interstitial = nil
        preloadInterstitial()  // 次回に備えて再ロード
    }

    // MARK: - Rewarded（動画リワード広告：視聴で6時間 広告非表示）

    /// 視聴報酬で広告を非表示にする時間（時間単位）。収益機会を増やすため長めの報酬に設定。
    static let rewardAdFreeHours: Double = 6

    /// 次回表示に備えてリワード広告を事前ロードしておく。
    /// すでに広告非表示（課金 or 報酬期間中）なら不要なのでロードしない。
    func preloadRewarded() {
        guard Self.adsVisible else { return }
        guard rewarded == nil, !isLoadingRewarded else { return }
        isLoadingRewarded = true
        Task { [weak self] in
            let ad = try? await RewardedAd.load(with: AdConfig.rewardedUnitID, request: Request())
            self?.rewarded = ad
            self?.isLoadingRewarded = false
        }
    }

    /// リワード（動画）広告を表示し、最後まで視聴（報酬獲得）したら
    /// `AppSettings.grantRewardAdFree` で一定時間 広告を非表示にする。
    /// 未ロードのときはその場でロードしてから表示する。
    /// - Parameters:
    ///   - onReward: 報酬獲得（＝広告非表示が有効化）時に呼ばれる
    ///   - onUnavailable: 広告を読み込めず表示できなかったときに呼ばれる
    func showRewardedForAdFree(onReward: @escaping () -> Void = {},
                               onUnavailable: @escaping () -> Void = {}) {
        func present(_ ad: RewardedAd) {
            guard let root = Self.rootViewController() else { onUnavailable(); return }
            ad.present(from: root) { [weak self] in
                AppSettings.shared.grantRewardAdFree(hours: Self.rewardAdFreeHours)
                self?.rewarded = nil
                self?.preloadRewarded()  // 次回に備えて再ロード
                onReward()
            }
        }

        if let ad = rewarded {
            present(ad)
        } else {
            // 未ロード：その場でロードして表示（少し待たせる可能性があるが確実に表示を試みる）
            isLoadingRewarded = true
            Task { [weak self] in
                let ad = try? await RewardedAd.load(with: AdConfig.rewardedUnitID, request: Request())
                self?.isLoadingRewarded = false
                guard let ad else { onUnavailable(); return }
                self?.rewarded = ad
                present(ad)
            }
        }
    }

    /// デベロッパーモード用：リワード広告を即時にテスト表示する（確実に出る Google テストIDを使用）。
    /// 視聴すると本番同様に報酬（広告非表示）が付与される。
    func showTestRewarded() {
        Task { [weak self] in
            guard let ad = try? await RewardedAd.load(
                with: AdConfig.testRewardedUnitID, request: Request()
            ), let root = Self.rootViewController() else { return }
            ad.present(from: root) {
                AppSettings.shared.grantRewardAdFree(hours: Self.rewardAdFreeHours)
                self?.preloadRewarded()
            }
        }
    }

    /// デベロッパーモード用：全画面広告を即時にテスト表示する（頻度制御・課金状態を無視）。
    /// 実広告は在庫割当まで表示されないことがあるため、確実に出る Google テスト広告IDを使う。
    func showTestInterstitial() {
        Task {
            guard let ad = try? await InterstitialAd.load(
                with: AdConfig.testInterstitialUnitID, request: Request()
            ) else { return }
            if let root = Self.rootViewController() {
                ad.present(from: root)
            }
        }
    }

    /// バナー用：ウィンドウのルート VC（タブ間で安定）。最前面の presented VC を辿らないため、
    /// タブ切替や生成タイミングに左右されず、バナーの rootViewController として安定して使える。
    static func appRootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let keyWindow = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        return keyWindow?.rootViewController
    }

    /// 現在最前面に表示されている UIViewController を取得（全画面広告の presentation 用）。
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
