import SwiftUI

extension Color {
    static let appBackground    = Color(red: 0.961, green: 0.937, blue: 0.898)
    static let appCard          = Color.white
    static let appAccent        = Color(red: 0.843, green: 0.549, blue: 0.122)
    static let appGreen         = Color(red: 0.180, green: 0.349, blue: 0.247)
    static let appGreenLight    = Color(red: 0.220, green: 0.420, blue: 0.300)
    static let appTextPrimary   = Color(red: 0.15,  green: 0.15,  blue: 0.15)
    static let appTextSecondary = Color(red: 0.45,  green: 0.45,  blue: 0.45)
}

/// 時間割の授業セルで使うパステルカラーの共有パレット。
/// 授業ごとに `ClassSchedule.colorIndex` として色番号を保存し、
/// 未設定時は並び順ベースの自動割当にフォールバックする。
enum ClassColorPalette {
    static let colors: [Color] = [
        Color(red: 0.73, green: 0.88, blue: 0.98),   // blue
        Color(red: 0.99, green: 0.76, blue: 0.76),   // red/pink
        Color(red: 0.79, green: 0.95, blue: 0.82),   // green
        Color(red: 1.00, green: 0.93, blue: 0.76),   // yellow
        Color(red: 0.90, green: 0.80, blue: 0.97),   // purple
        Color(red: 0.77, green: 0.94, blue: 0.95),   // cyan
        Color(red: 1.00, green: 0.87, blue: 0.76),   // orange
        Color(red: 0.83, green: 0.86, blue: 0.99),   // indigo
    ]
}
