import SwiftUI

struct PINPadView: View {
    @Binding var pin: String
    let maxDigits: Int
    var onComplete: ((String) -> Void)?

    private let columns = Array(repeating: GridItem(.fixed(72), spacing: 16), count: 3)

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                ForEach(0..<maxDigits, id: \.self) { i in
                    Circle()
                        .fill(i < pin.count ? Theme.accent : Theme.bgField)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(i < pin.count ? Theme.accent : Theme.border, lineWidth: 1))
                        .scaleEffect(i < pin.count ? 1.1 : 1.0)
                        .animation(.spring(duration: 0.15, bounce: 0.4), value: pin.count)
                }
            }
            .frame(height: 22)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(1...9, id: \.self) { d in pinButton("\(d)") { appendDigit("\(d)") } }

                Color.clear.frame(height: 64)

                pinButton("0") { appendDigit("0") }

                Button {
                    if !pin.isEmpty { pin.removeLast() }
                } label: {
                    Image(systemName: "delete.backward")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.text2)
                        .frame(width: 64, height: 64)
                }
            }
        }
    }

    private func pinButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Theme.text1)
                .frame(width: 64, height: 64)
                .background(Theme.bgField)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.border, lineWidth: 0.5))
        }
        .disabled(pin.count >= maxDigits)
    }

    private func appendDigit(_ digit: String) {
        guard pin.count < maxDigits else { return }
        pin += digit
        if pin.count == maxDigits {
            Task {
                try? await Task.sleep(for: .seconds(0.15))
                onComplete?(pin)
            }
        }
    }
}
