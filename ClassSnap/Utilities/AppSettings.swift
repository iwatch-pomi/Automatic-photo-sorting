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
    }
}
