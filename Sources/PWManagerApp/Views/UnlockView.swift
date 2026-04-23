import SwiftUI

struct UnlockView: View {
    let viewModel: VaultViewModel
    @State private var password = ""
    @AppStorage("touchIDEnabled") private var touchIDEnabled = false

    private var canUseTouchID: Bool {
        touchIDEnabled
            && viewModel.biometricService.isAvailable
            && viewModel.biometricService.hasStoredPassword
    }

    var body: some View {
        ZStack {
            Color(.windowBackgroundColor).ignoresSafeArea()

            ThemeCard {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: 64, height: 64)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    VStack(spacing: 6) {
                        Text("Welcome Back")
                            .font(.system(size: 20, weight: .bold))
                            .tracking(-0.3)

                        Text("Enter your master password to unlock.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    ThemeTextField(placeholder: "Master Password", text: $password, isSecure: true)
                        .frame(width: 280)
                        .onSubmit { unlock() }

                    Text(viewModel.errorMessage ?? " ")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(height: 14)
                        .opacity(viewModel.errorMessage != nil ? 1 : 0)

                    HStack(spacing: 10) {
                        ThemePrimaryButton(
                            label: "Unlock",
                            isLoading: viewModel.isProcessing
                        ) {
                            unlock()
                        }
                        .disabled(password.isEmpty || viewModel.isProcessing)

                        if canUseTouchID {
                            Button {
                                viewModel.unlockWithBiometrics()
                            } label: {
                                Image(systemName: "touchid")
                                    .font(.system(size: 22, weight: .medium))
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isProcessing)
                            .help("Unlock with Touch ID")
                        }
                    }
                }
            }
            .frame(width: 380)
        }
        .task {
            if canUseTouchID && !viewModel.isProcessing {
                viewModel.unlockWithBiometrics()
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty, !viewModel.isProcessing else { return }
        viewModel.unlock(password: password)
    }
}
