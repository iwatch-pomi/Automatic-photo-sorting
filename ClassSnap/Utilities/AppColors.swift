import SwiftUI
import Observation

/// アプリのテーマ（メインの色・背景）を管理する。
///
/// ※ このファイルはアプリ本体とウィジェット拡張の両ターゲットでコンパイルされるため、
///    アプリ専用の型（AppSettings 等）に依存せず、Foundation / Observation / SwiftUI だけで
///    自己完結させている。`@Observable` なので、色を変更するとそれを参照する画面が即座に更新される。
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    /// 選択中のテーマ色ID（AppThemePreset.id）。既定は "green"（従来色）。
    var themeColorID: String {
        didSet { UserDefaults.standard.set(themeColorID, forKey: "themeColorID") }
    }

    /// 背景を白にするか（false のときは従来の淡いベージュ）。
    var useWhiteBackground: Bool {
        didSet { UserDefaults.standard.set(useWhiteBackground, forKey: "useWhiteBackground") }
    }

    var currentPreset: AppThemePreset { AppThemePreset.preset(for: themeColorID) }

    private init() {
        themeColorID = UserDefaults.standard.string(forKey: "themeColorID") ?? "green"
        useWhiteBackground = UserDefaults.standard.bool(forKey: "useWhiteBackground")
    }
}

/// テーマ色のプリセット。`accent` がメインの色、`onAccent` はその色の上に乗せる文字・アイコンの色。
/// 薄い色は文字が読めなくなるため、プリセットごとに読みやすい onAccent を定義している。
struct AppThemePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let accent: Color
    let onAccent: Color

    static let presets: [AppThemePreset] = [
        // 濃いめ（白文字が読める）
        AppThemePreset(id: "green",  name: "グリーン",   accent: Color(red: 0.180, green: 0.349, blue: 0.247), onAccent: .white),
        AppThemePreset(id: "blue",   name: "ブルー",     accent: Color(red: 0.13,  green: 0.40,  blue: 0.68),  onAccent: .white),
        AppThemePreset(id: "purple", name: "パープル",   accent: Color(red: 0.40,  green: 0.28,  blue: 0.62),  onAccent: .white),
        AppThemePreset(id: "pink",   name: "ピンク",     accent: Color(red: 0.82,  green: 0.33,  blue: 0.52),  onAccent: .white),
        AppThemePreset(id: "orange", name: "オレンジ",   accent: Color(red: 0.85,  green: 0.47,  blue: 0.16),  onAccent: .white),
        AppThemePreset(id: "red",    name: "レッド",     accent: Color(red: 0.78,  green: 0.24,  blue: 0.24),  onAccent: .white),
        // 薄い色（濃い文字で読みやすく）
        AppThemePreset(id: "skyblue",  name: "水色",      accent: Color(red: 0.62, green: 0.84, blue: 0.94), onAccent: Color(red: 0.10, green: 0.28, blue: 0.40)),
        AppThemePreset(id: "mint",     name: "ミント",    accent: Color(red: 0.66, green: 0.88, blue: 0.76), onAccent: Color(red: 0.10, green: 0.32, blue: 0.24)),
        AppThemePreset(id: "lavender", name: "ラベンダー", accent: Color(red: 0.80, green: 0.74, blue: 0.93), onAccent: Color(red: 0.28, green: 0.20, blue: 0.42)),
        AppThemePreset(id: "lemon",    name: "イエロー",  accent: Color(red: 0.98, green: 0.86, blue: 0.50), onAccent: Color(red: 0.42, green: 0.30, blue: 0.06)),
    ]

    static func preset(for id: String) -> AppThemePreset {
        presets.first { $0.id == id } ?? presets[0]
    }
}

extension Color {
    /// 背景色。設定で「白」を選ぶと白、既定は淡いベージュ。
    static var appBackground: Color {
        ThemeManager.shared.useWhiteBackground
            ? .white
            : Color(red: 0.961, green: 0.937, blue: 0.898)
    }

    /// カード背景。背景が白のときはカードが埋もれないよう、ごく淡いグレーにして区別する。
    static var appCard: Color {
        ThemeManager.shared.useWhiteBackground
            ? Color(red: 0.950, green: 0.950, blue: 0.965)
            : .white
    }

    static let appAccent = Color(red: 0.843, green: 0.549, blue: 0.122)

    /// アプリのメインの色（テーマで変更可能）。名前は従来の `appGreen` のまま 100 箇所以上で参照されている。
    static var appGreen: Color { ThemeManager.shared.currentPreset.accent }

    /// メインの色をやや明るくした色（グラデーション等で使用）。
    static var appGreenLight: Color { ThemeManager.shared.currentPreset.accent.opacity(0.82) }

    /// メインの色の「上」に置く文字・アイコンの色（薄色テーマでも読めるよう各プリセットで定義）。
    static var appOnAccent: Color { ThemeManager.shared.currentPreset.onAccent }

    static let appTextPrimary   = Color(red: 0.15, green: 0.15, blue: 0.15)
    static let appTextSecondary = Color(red: 0.45, green: 0.45, blue: 0.45)
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
