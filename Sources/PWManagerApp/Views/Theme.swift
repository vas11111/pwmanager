import SwiftUI

// MARK: - Color Palette

enum Theme {
    static let bg         = Color(.windowBackgroundColor)
    static let bgCard     = Color(nsColor: .init(white: 0.5, alpha: 0.06))
    static let bgField    = Color(nsColor: .init(white: 0.5, alpha: 0.08))
    static let bgHover    = Color(nsColor: .init(white: 0.5, alpha: 0.10))
    static let bgSelected = Color.accentColor.opacity(0.15)
    static let border     = Color(nsColor: .separatorColor)
    static let borderSoft = Color.primary.opacity(0.06)

    static let textPrimary   = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary  = Color(nsColor: .tertiaryLabelColor)

    static let accent = Color.accentColor

    static let radius: CGFloat = 8
    static let radiusLg: CGFloat = 12
}

// MARK: - Modern Text Field

struct ThemeTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    @State private var revealed = false

    var body: some View {
        Group {
            if isSecure && !revealed {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .textFieldStyle(.plain)
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.bgField)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Theme.borderSoft, lineWidth: 0.5)
        )
    }
}

// MARK: - Modern Card

struct ThemeCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                    .stroke(Theme.borderSoft, lineWidth: 0.5)
            }
    }
}

// MARK: - Field Row (for detail view)

struct ThemeFieldRow: View {
    let label: String
    let value: String
    var isMono = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(0.6)
            Text(value)
                .font(isMono ? .system(size: 13, weight: .medium, design: .monospaced) : .system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .textSelection(.enabled)
                .lineLimit(1)
        }
    }
}

// MARK: - Primary Button

struct ThemePrimaryButton: View {
    let label: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .frame(width: 180, height: 18)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

// MARK: - Section Label

struct ThemeSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.textTertiary)
            .tracking(0.8)
    }
}
