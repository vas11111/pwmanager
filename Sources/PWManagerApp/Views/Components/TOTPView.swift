import SwiftUI
import PWManagerCore

struct TOTPView: View {
    let secret: String
    let viewModel: VaultViewModel
    @State private var code: String = ""
    @State private var progress: Double = 0

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            // Countdown ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 2.5)
                    .frame(width: 28, height: 28)
                Circle()
                    .trim(from: 0, to: 1 - progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: progress)

                Text("\(Int(TOTPGenerator.timeRemaining()))")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(ringColor)
                    .monospacedDigit()
            }

            // Code display
            Text(formattedCode)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.text1)
                .tracking(2)
                .textSelection(.enabled)

            Spacer()

            Button { viewModel.copyToClipboard(code) } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.text3)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(GhostButtonStyle())
            .help("Copy code")
        }
        .onReceive(timer) { _ in refresh() }
        .onAppear { refresh() }
    }

    private var formattedCode: String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }

    private var ringColor: Color {
        let remaining = TOTPGenerator.timeRemaining()
        if remaining < 5 { return .red }
        if remaining < 10 { return .orange }
        return Theme.accent
    }

    private func refresh() {
        code = TOTPGenerator.generateCode(secret: secret) ?? "------"
        progress = TOTPGenerator.progress()
    }
}
