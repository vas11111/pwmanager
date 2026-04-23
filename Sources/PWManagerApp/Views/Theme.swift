import SwiftUI

enum Theme {
    // Backgrounds
    static let bg          = Color(nsColor: .init(red: 0.07, green: 0.07, blue: 0.08, alpha: 1))
    static let bgSidebar   = Color(nsColor: .init(red: 0.09, green: 0.09, blue: 0.10, alpha: 1))
    static let bgCard      = Color(nsColor: .init(red: 0.11, green: 0.11, blue: 0.13, alpha: 1))
    static let bgField     = Color(nsColor: .init(red: 0.13, green: 0.13, blue: 0.15, alpha: 1))
    static let bgHover     = Color.white.opacity(0.05)
    static let bgSelected  = Color.white.opacity(0.08)

    // Text
    static let text1 = Color(white: 0.92)
    static let text2 = Color(white: 0.52)
    static let text3 = Color(white: 0.32)

    // Accent
    static let accent     = Color(red: 0.40, green: 0.52, blue: 1.0)
    static let accentGlow = Color(red: 0.40, green: 0.52, blue: 1.0).opacity(0.15)

    // Borders
    static let border     = Color.white.opacity(0.07)
    static let borderSoft = Color.white.opacity(0.04)

    // Radii
    static let r: CGFloat = 8
    static let rLg: CGFloat = 12
    static let rSm: CGFloat = 6
}

// MARK: - Text Field

struct ThemeTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .textFieldStyle(.plain)
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.bgField)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                .stroke(Theme.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Card

struct ThemeCard<Content: View>: View {
    var padding: CGFloat = 28
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(Theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
                    .stroke(Theme.border, lineWidth: 0.5)
            )
    }
}

// MARK: - Section Label

struct ThemeLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.text3)
            .tracking(0.8)
    }
}

// MARK: - Icon Badge

struct ThemeIconBadge: View {
    var icon: String = "key.fill"
    var size: CGFloat = 32
    var iconSize: CGFloat = 13

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(Theme.accentGlow)
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
    }
}
