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
        VStack {
            Spacer()

            VStack(spacing: 28) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text("PWManager")
                        .font(.title2.weight(.semibold))

                    Text("Enter your master password to unlock.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SecureField("Master Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { unlock() }
                    .frame(width: 300)

                // Fixed-height error area
                Group {
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                    } else {
                        Text(" ")
                    }
                }
                .font(.caption)
                .frame(height: 16)

                HStack(spacing: 12) {
                    Button {
                        unlock()
                    } label: {
                        Group {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Unlock")
                            }
                        }
                        .frame(width: canUseTouchID ? 160 : 200, height: 20)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(password.isEmpty || viewModel.isProcessing)

                    if canUseTouchID {
                        Button {
                            viewModel.unlockWithBiometrics()
                        } label: {
                            Image(systemName: "touchid")
                                .font(.title2)
                                .frame(height: 20)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(viewModel.isProcessing)
                        .help("Unlock with Touch ID")
                    }
                }
            }
            .padding(36)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
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
