import SwiftUI

enum Theme {
    static let bg = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let bgCard = Color(red: 0.10, green: 0.10, blue: 0.11)
    static let bgField = Color(red: 0.13, green: 0.13, blue: 0.14)
    static let bgHover = Color.white.opacity(0.04)
    static let border = Color.white.opacity(0.08)
    static let accent = Color(red: 0.45, green: 0.55, blue: 1.0)
    static let accentGlow = Color(red: 0.45, green: 0.55, blue: 1.0).opacity(0.18)
    static let text1 = Color.white
    static let text2 = Color.white.opacity(0.72)
    static let text3 = Color.white.opacity(0.48)
    static let r: CGFloat = 10
    static let rSm: CGFloat = 8
    static let rLg: CGFloat = 16
}
