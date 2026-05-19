import Foundation
import Photos

enum WeekdayHelper {
    // appDayOfWeek: 1=月〜5=金
    static func name(for appDayOfWeek: Int) -> String {
        switch appDayOfWeek {
        case 1: return "月曜日"
        case 2: return "火曜日"
        case 3: return "水曜日"
        case 4: return "木曜日"
        case 5: return "金曜日"
        default: return "不明"
        }
    }

    static func shortName(for appDayOfWeek: Int) -> String {
        switch appDayOfWeek {
        case 1: return "月"
        case 2: return "火"
        case 3: return "水"
        case 4: return "木"
        case 5: return "金"
        default: return "?"
        }
    }
}

// PHAsset を SwiftUI の ForEach / fullScreenCover(item:) で使えるようにする
extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}
