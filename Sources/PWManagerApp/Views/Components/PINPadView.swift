import SwiftUI

struct PINPadView: View {
    @Binding var pin: String
    let maxDigits: Int
    var onComplete: ((String) -> Void)?
    var showTouchID: Bool = false
    var onTouchID: (() -> Void)? = nil

    private let columns = Array(repeating: GridItem(.fixed(72), spacing: 14), count: 3)

    var body: some View {
        VStack(spacing: 26) {
            // Dot display
            HStack(spacing: 16) {
                ForEach(0..<maxDigits, id: \.self) { i in
                    Circle()
                        .fill(i < pin.count ? Theme.accent : Theme.bgField)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(i < pin.count ? Theme.accent : Theme.border, lineWidth: 1)
                        )
                        .scaleEffect(i < pin.count ? 1.1 : 1.0)
                        .animation(.spring(duration: 0.15, bounce: 0.4), value: pin.count)
                }
            }
            .frame(height: 20)

            // Number grid
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(1...9, id: \.self) { digit in
                    pinButton("\(digit)") { appendDigit("\(digit)") }
                }

                // Bottom row: Touch ID (or empty), 0, delete
                if showTouchID, let onTouchID {
                    Button(action: onTouchID) {
                        Image(systemName: "touchid")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 56, height: 56)
                    }
                    .buttonStyle(GhostButtonStyle())
                } else {
                    Color.clear.frame(height: 56)
                }

                pinButton("0") { appendDigit("0") }

                Button {
                    if !pin.isEmpty {
                        withAnimation(.spring(duration: 0.1)) {
                            pin.removeLast()
                        }
                    }
                } label: {
                    Image(systemName: "delete.backward")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Theme.text2)
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private func pinButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.text1)
                .frame(width: 56, height: 56)
                .background(Theme.bgField)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.border, lineWidth: 0.5))
        }
        .buttonStyle(PressButtonStyle())
        .disabled(pin.count >= maxDigits)
    }

    private func appendDigit(_ digit: String) {
        guard pin.count < maxDigits else { return }
        withAnimation(.spring(duration: 0.15)) {
            pin += digit
        }
        if pin.count == maxDigits {
            Task {
                try? await Task.sleep(for: .seconds(0.15))
                onComplete?(pin)
            }
        }
    }
}
