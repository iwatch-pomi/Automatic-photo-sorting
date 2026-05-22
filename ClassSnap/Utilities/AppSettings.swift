import Foundation
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var bufferMinutes: Int {
        didSet { UserDefaults.standard.set(bufferMinutes, forKey: "bufferMinutes") }
    }

    private init() {
        let saved = UserDefaults.standard.integer(forKey: "bufferMinutes")
        bufferMinutes = saved > 0 ? saved : 10
    }
}
