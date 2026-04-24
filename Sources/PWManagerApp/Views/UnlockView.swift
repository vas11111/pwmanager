import SwiftUI

struct UnlockView: View {
    let viewModel: VaultViewModel
    @State private var pin = ""
    @State private var shakeError = false
    @AppStorage("touchIDEnabled") private var touchIDEnabled = false

    private var canUseTouchID: Bool {
        touchIDEnabled
            && viewModel.biometricService.isAvailable
            && viewModel.biometricService.hasStoredPassword
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            Circle()
                .fill(Theme.accent.opacity(0.04))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(y: -40)

            ThemeCard {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 68, height: 68)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Theme.text2)
                    }

                    VStack(spacing: 6) {
                        Text("Welcome Back")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.text1)
                            .tracking(-0.4)
                        Text("Enter your PIN to unlock.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                    }

                    PINPadView(pin: $pin, maxDigits: 6) { completed in
                        viewModel.unlock(password: completed)
                    }
                    .shake(shakeError)

                    // Error / status area
                    Group {
                        if viewModel.isProcessing {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Unlocking...")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.text2)
                            }
                        } else if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.red)
                        } else {
                            Text(" ")
                        }
                    }
                    .frame(height: 16)

                    if canUseTouchID {
                        Button {
                            viewModel.unlockWithBiometrics()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "touchid")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Touch ID")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Theme.bgField)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.r, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.r, style: .continuous)
                                    .stroke(Theme.border, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(GhostButtonStyle())
                        .disabled(viewModel.isProcessing)
                    }

                    if viewModel.remainingAttempts > 0 && viewModel.remainingAttempts < 10 {
                        Text("\(viewModel.remainingAttempts) attempts remaining")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.text3)
                    }
                }
            }
            .frame(width: 400)
        }
        .task {
            if canUseTouchID && !viewModel.isProcessing {
                viewModel.unlockWithBiometrics()
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            if newState == .unlocked { pin = "" }
        }
        .onChange(of: viewModel.errorMessage) { _, msg in
            if msg != nil {
                shakeError = true
                pin = ""
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    shakeError = false
                }
            }
        }
    }
}
