import SwiftUI

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var hoverColor: Color = Theme.bgHover

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(duration: 0.15, bounce: 0.4), value: configuration.isPressed)
    }
}

struct AccentButtonStyle: ButtonStyle {
    var disabled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .background(disabled ? Theme.accent.opacity(0.3) : Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.r, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}
