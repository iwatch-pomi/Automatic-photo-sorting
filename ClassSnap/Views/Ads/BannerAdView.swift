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

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: Self.adaptiveSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = AdManager.rootViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    /// 画面幅に追従するアンカー型アダプティブバナーのサイズ。
    static var adaptiveSize: AdSize {
        let width = UIScreen.main.bounds.width
        return currentOrientationAnchoredAdaptiveBanner(width: width)
    }
}

/// 広告非表示（課金済み）でなければ、コンテンツの下端にバナーを敷くコンテナ。
///
/// `EntitlementManager` は `@Observable` なので、購入／復元で `isAdFree` が true になった瞬間に
/// バナーが自動で消える。バナーはタブバーのすぐ上（＝各タブのコンテンツ最下部）に固定される。
struct BannerAdContainer<Content: View>: View {
    @ViewBuilder var content: Content

    private let entitlement = EntitlementManager.shared

    var body: some View {
        VStack(spacing: 0) {
            content
            if !entitlement.isAdFree {
                BannerAdView()
                    .frame(height: BannerAdView.adaptiveSize.size.height)
                    .frame(maxWidth: .infinity)
                    .background(Color.appBackground)
            }
        }
    }
}

extension View {
    /// このビューの下端にバナー広告を敷く（課金済みなら何もしない）。
    func bannerAd() -> some View {
        BannerAdContainer { self }
    }
}
