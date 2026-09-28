import SwiftUI
import UIKit
import GoogleMobileAds

/// アダプティブバナー広告を SwiftUI に載せる UIViewRepresentable ラッパ。
///
/// ※ Google Mobile Ads SDK v12 系の Swift API 名（BannerView / Request /
///    currentOrientationAnchoredAdaptiveBanner）に合わせている。
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    init(adUnitID: String = AdConfig.bannerUnitID) {
        self.adUnitID = adUnitID
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: Self.adaptiveSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = AdManager.appRootViewController()
        banner.delegate = context.coordinator
        context.coordinator.banner = banner
        context.coordinator.loadAd()
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // 生成時に rootViewController が未確定だった場合に補完し、必要なら読み込み直す
        if uiView.rootViewController == nil {
            uiView.rootViewController = AdManager.appRootViewController()
            context.coordinator.loadAd()
        }
    }

    /// 画面幅に追従するアンカー型アダプティブバナーのサイズ。
    static var adaptiveSize: AdSize {
        let width = UIScreen.main.bounds.width
        return currentOrientationAnchoredAdaptiveBanner(width: width)
    }

    /// バナーの読み込み結果を受け取り、失敗時（no-fill/エラー）に自動リトライするデリゲート。
    /// これが無いと、タブ表示時にたまたま読み込み失敗したバナーが空白のまま残ってしまう。
    final class Coordinator: NSObject, BannerViewDelegate {
        weak var banner: BannerView?
        private var retryCount = 0
        private let maxRetries = 5

        func loadAd() {
            guard let banner else { return }
            if banner.rootViewController == nil {
                banner.rootViewController = AdManager.appRootViewController()
            }
            banner.load(Request())
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            retryCount = 0
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            guard retryCount < maxRetries else { return }
            retryCount += 1
            // 8, 16, 24, 32, 40 秒とバックオフしながら再試行
            let delay = Double(retryCount) * 8.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.loadAd()
            }
        }
    }
}

/// 広告非表示（課金済み）でなければ、コンテンツの下端にバナーを敷くコンテナ。
///
/// `EntitlementManager` は `@Observable` なので、購入／復元で `isAdFree` が true になった瞬間に
/// バナーが自動で消える。バナーはタブバーのすぐ上（＝各タブのコンテンツ最下部）に固定される。
struct BannerAdContainer<Content: View>: View {
    @ViewBuilder var content: Content

    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            content
            if AdManager.adsVisible {
                // バナーの上に、控えめな「広告を非表示にする」導線を置く（節度ある課金導線）
                Button { showPaywall = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.system(size: 10))
                        Text("広告を非表示にする").font(.caption2).fontWeight(.semibold)
                        Image(systemName: "chevron.right").font(.system(size: 8))
                    }
                    .foregroundStyle(Color.appGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.appBackground)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                BannerAdView()
                    .frame(height: BannerAdView.adaptiveSize.size.height)
                    .frame(maxWidth: .infinity)
                    .background(Color.appBackground)
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}

extension View {
    /// このビューの下端にバナー広告を敷く（課金済みなら何もしない）。
    func bannerAd() -> some View {
        BannerAdContainer { self }
    }
}
