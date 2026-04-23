import SwiftUI

struct PasswordStrengthBar: View {
    let password: String

    private var strength: (Double, Color, String) {
        let len = password.count
        if len == 0 { return (0, .clear, "") }

        var score = 0.0
        if len >= 8 { score += 0.2 }
        if len >= 12 { score += 0.15 }
        if len >= 16 { score += 0.15 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 0.1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 0.1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 0.1 }
        if password.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil { score += 0.1 }
        if len >= 20 { score += 0.1 }

        let clamped = min(score, 1.0)
        let color: Color
        let label: String
        switch clamped {
        case 0..<0.3: color = .red; label = "Weak"
        case 0.3..<0.6: color = .orange; label = "Fair"
        case 0.6..<0.8: color = .yellow; label = "Good"
        default: color = .green; label = "Strong"
        }
        return (clamped, color, label)
    }

    var body: some View {
        let (value, color, label) = strength
        if !password.isEmpty {
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 4)
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * value, height: 4)
                            .animation(.spring(duration: 0.4), value: value)
                    }
                }
                .frame(height: 4)

                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}
