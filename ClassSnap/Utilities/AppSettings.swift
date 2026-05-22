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

    private init() {
        let savedBuffer = UserDefaults.standard.integer(forKey: "bufferMinutes")
        bufferMinutes = savedBuffer > 0 ? savedBuffer : 10

        let savedStart = UserDefaults.standard.integer(forKey: "lunchBreakStartSeconds")
        lunchBreakStartSeconds = savedStart > 0 ? savedStart : 12 * 3600  // 12:00

        let savedEnd = UserDefaults.standard.integer(forKey: "lunchBreakEndSeconds")
        lunchBreakEndSeconds = savedEnd > 0 ? savedEnd : 13 * 3600        // 13:00
    }
}
