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

// .foregroundStyle(Color.appTextPrimary) のようなドット構文を使えるようにする
// （SwiftUI が .red や .blue を ShapeStyle 上で提供しているのと同じ仕組み）
extension ShapeStyle where Self == Color {
    static var appBackground: Color    { Color(red: 0.961, green: 0.937, blue: 0.898) }
    static var appCard: Color          { .white }
    static var appAccent: Color        { Color(red: 0.843, green: 0.549, blue: 0.122) }
    static var appGreen: Color         { Color(red: 0.180, green: 0.349, blue: 0.247) }
    static var appGreenLight: Color    { Color(red: 0.220, green: 0.420, blue: 0.300) }
    static var appTextPrimary: Color   { Color(red: 0.15,  green: 0.15,  blue: 0.15) }
    static var appTextSecondary: Color { Color(red: 0.45,  green: 0.45,  blue: 0.45) }
}
