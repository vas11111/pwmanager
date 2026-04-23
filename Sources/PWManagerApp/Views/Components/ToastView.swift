import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.green)
            Text(message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let msg = message {
                ToastView(message: msg, icon: "checkmark.circle.fill")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 24)
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(1.8))
                            withAnimation(.spring(duration: 0.3)) { message = nil }
                        }
                    }
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.3), value: message != nil)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
