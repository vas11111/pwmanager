import SwiftUI

struct CreateVaultView: View {
    let viewModel: VaultViewModel
    @State private var password = ""
    @State private var confirm = ""

    private var isValid: Bool {
        password.count >= 8 && password == confirm
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Create Your Vault")
                .font(.title)
                .fontWeight(.semibold)

            Text("Choose a strong master password. This is the only password you need to remember.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            VStack(spacing: 12) {
                SecureField("Master Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                SecureField("Confirm Password", text: $confirm)
                    .textFieldStyle(.roundedBorder)

                if !password.isEmpty && password.count < 8 {
                    Label("At least 8 characters required", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !confirm.isEmpty && password != confirm {
                    Label("Passwords do not match", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(width: 280)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                viewModel.createVault(password: password, confirm: confirm)
            } label: {
                if viewModel.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 200)
                } else {
                    Text("Create Vault")
                        .frame(width: 200)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isValid || viewModel.isProcessing)

            Spacer()
        }
        .padding(40)
        .frame(minWidth: 440, minHeight: 420)
    }
}
