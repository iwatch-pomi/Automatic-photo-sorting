import Foundation
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var bufferMinutes: Int {
        didSet { UserDefaults.standard.set(bufferMinutes, forKey: "bufferMinutes") }
    }

    // 昼休みのデフォルト時間帯（深夜0時からの秒数）
    var lunchBreakStartSeconds: Int {
        didSet { UserDefaults.standard.set(lunchBreakStartSeconds, forKey: "lunchBreakStartSeconds") }
    }
    var lunchBreakEndSeconds: Int {
        didSet { UserDefaults.standard.set(lunchBreakEndSeconds, forKey: "lunchBreakEndSeconds") }
    }

    // 初回起動時のオンボーディングを完了したか
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    // 最後に閲覧した「お知らせ（What's New）」の識別子。
    // WhatsNewView.currentID と一致しないときだけ、起動時に1度ポップアップを表示する。
    var whatsNewSeenID: String {
        didSet { UserDefaults.standard.set(whatsNewSeenID, forKey: "whatsNewSeenID") }
    }

    // 起動回数（コールドローンチのたびに +1）。控えめな課金導線の表示判定に使う。
    var launchCount: Int {
        didSet { UserDefaults.standard.set(launchCount, forKey: "launchCount") }
    }

    // 「広告なしで使いませんか？」の案内を一度表示したか（未課金ユーザーに1回だけ）。
    var adFreePromptSeen: Bool {
        didSet { UserDefaults.standard.set(adFreePromptSeen, forKey: "adFreePromptSeen") }
    }

    // 隠しデベロッパーモード：ON のとき、課金（広告非表示）中でも広告を強制表示する。
    // 設定画面のバージョン番号を5回タップで切り替える（動作確認用）。
    var adTestModeEnabled: Bool {
        didSet { UserDefaults.standard.set(adTestModeEnabled, forKey: "adTestModeEnabled") }
    }

    // リワード（動画）広告の視聴報酬として、広告を一時的に非表示にする期限（UNIX秒）。
    // 0 以下＝無効。視聴するたびに「視聴時刻 + 6時間」に更新する。
    var rewardAdFreeUntil: Double {
        didSet { UserDefaults.standard.set(rewardAdFreeUntil, forKey: "rewardAdFreeUntil") }
    }

    /// リワード報酬による広告非表示期間が現在有効か。
    var isRewardAdFreeActive: Bool {
        rewardAdFreeUntil > Date().timeIntervalSince1970
    }

    /// リワード報酬による広告非表示の残り時間（秒）。無効なら 0。
    var rewardAdFreeRemaining: TimeInterval {
        max(0, rewardAdFreeUntil - Date().timeIntervalSince1970)
    }

    /// リワード広告の視聴報酬を付与する（指定時間だけ広告を非表示にする）。
    /// 「視聴したら◯時間消える」という分かりやすい挙動にするため、残り時間へ加算せず
    /// 「現在時刻 + hours」で上書きする（残りが短ければ延長、長ければ据え置き相当）。
    func grantRewardAdFree(hours: Double) {
        let candidate = Date().timeIntervalSince1970 + hours * 3600
        rewardAdFreeUntil = max(rewardAdFreeUntil, candidate)
    }

    private init() {
        // 登録デフォルトを使うことで、ユーザーが 0（バッファなし）を選んでも
        // 「未設定」と区別して正しく永続化・復元できる。
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "bufferMinutes": 10,
            "lunchBreakStartSeconds": 12 * 3600,  // 12:00
            "lunchBreakEndSeconds": 13 * 3600,    // 13:00
        ])

        bufferMinutes = defaults.integer(forKey: "bufferMinutes")
        lunchBreakStartSeconds = defaults.integer(forKey: "lunchBreakStartSeconds")
        lunchBreakEndSeconds = defaults.integer(forKey: "lunchBreakEndSeconds")
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        whatsNewSeenID = defaults.string(forKey: "whatsNewSeenID") ?? ""
        launchCount = defaults.integer(forKey: "launchCount")
        adFreePromptSeen = defaults.bool(forKey: "adFreePromptSeen")
        adTestModeEnabled = defaults.bool(forKey: "adTestModeEnabled")
        rewardAdFreeUntil = defaults.double(forKey: "rewardAdFreeUntil")
    }
}
