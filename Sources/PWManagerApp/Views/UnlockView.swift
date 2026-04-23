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
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("PWManager")
                .font(.title)
                .fontWeight(.semibold)

            Text("Enter your master password to unlock.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                SecureField("Master Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { unlock() }
                    .frame(width: 280)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: 280)
                }
            }

            HStack(spacing: 12) {
                Button {
                    unlock()
                } label: {
                    if viewModel.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 140)
                    } else {
                        Text("Unlock")
                            .frame(width: 140)
                    }
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
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(viewModel.isProcessing)
                    .help("Unlock with Touch ID")
                }
            }

            Spacer()
        }
        .padding(40)
        .frame(minWidth: 440, minHeight: 380)
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
