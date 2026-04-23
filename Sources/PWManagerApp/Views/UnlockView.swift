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
            Theme.bg.ignoresSafeArea()

            Circle()
                .fill(Theme.accent.opacity(0.04))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(y: -40)

            ThemeCard {
                VStack(spacing: 26) {
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
                        Text("Enter your master password to unlock.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                    }

                    ThemeTextField(placeholder: "Master password", text: $password, isSecure: true)
                        .frame(width: 280)
                        .onSubmit { unlock() }

                    Text(viewModel.errorMessage ?? " ")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(height: 14)
                        .opacity(viewModel.errorMessage != nil ? 1 : 0)

                    HStack(spacing: 10) {
                        Button {
                            unlock()
                        } label: {
                            Group {
                                if viewModel.isProcessing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("Unlock")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            }
                            .frame(width: canUseTouchID ? 210 : 260, height: 20)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 10)
                        .background(!password.isEmpty && !viewModel.isProcessing ? Theme.accent : Theme.accent.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.r, style: .continuous))
                        .disabled(password.isEmpty || viewModel.isProcessing)

                        if canUseTouchID {
                            Button {
                                viewModel.unlockWithBiometrics()
                            } label: {
                                Image(systemName: "touchid")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 40, height: 40)
                            }
                            .buttonStyle(.plain)
                            .background(Theme.bgField)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.r, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.r, style: .continuous)
                                    .stroke(Theme.border, lineWidth: 0.5)
                            )
                            .disabled(viewModel.isProcessing)
                        }
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
            if newState == .unlocked { password = "" }
        }
    }

    private func unlock() {
        guard !password.isEmpty, !viewModel.isProcessing else { return }
        viewModel.unlock(password: password)
    }
}
