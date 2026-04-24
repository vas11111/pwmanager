import SwiftUI

struct CreateVaultView: View {
    let viewModel: VaultViewModel

    enum Step { case setPin, confirmPin }

    @State private var step: Step = .setPin
    @State private var pin = ""
    @State private var firstPin = ""
    @State private var shakeError = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            Circle()
                .fill(Theme.accent.opacity(0.06))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(y: -40)

            ThemeCard {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentGlow)
                            .frame(width: 68, height: 68)
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }

                    VStack(spacing: 6) {
                        Text(step == .setPin ? "Set Your PIN" : "Confirm Your PIN")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.text1)
                            .tracking(-0.4)
                        Text(step == .setPin
                             ? "Choose a 6-digit PIN to protect your vault."
                             : "Enter the same PIN again to confirm.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                            .multilineTextAlignment(.center)
                    }

                    PINPadView(pin: $pin, maxDigits: 6) { completed in
                        handlePinEntry(completed)
                    }
                    .shake(shakeError)

                    // Error / status area
                    Group {
                        if viewModel.isProcessing {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Creating vault...")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.text2)
                            }
                        } else if let err = errorText ?? viewModel.errorMessage {
                            Text(err)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.red)
                        } else {
                            Text(" ")
                        }
                    }
                    .frame(height: 16)
                }
            }
            .frame(width: 400)
        }
    }

    private func handlePinEntry(_ completed: String) {
        switch step {
        case .setPin:
            firstPin = completed
            pin = ""
            withAnimation(.spring(duration: 0.25)) {
                step = .confirmPin
            }

        case .confirmPin:
            if completed == firstPin {
                viewModel.createVault(password: completed, confirm: completed)
            } else {
                shakeError = true
                errorText = "PINs don't match. Try again."
                pin = ""
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    shakeError = false
                }
                withAnimation(.spring(duration: 0.25)) {
                    step = .setPin
                    firstPin = ""
                }
            }
        }
    }
}
