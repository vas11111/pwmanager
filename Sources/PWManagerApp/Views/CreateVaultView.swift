import SwiftUI

struct CreateVaultView: View {
    let viewModel: VaultViewModel
    @State private var password = ""
    @State private var confirm = ""

    private var isValid: Bool {
        password.count >= 8 && password == confirm
    }

    private var validationMessage: (String, Color)? {
        if !password.isEmpty && password.count < 8 {
            return ("At least 8 characters required", .orange)
        }
        if !confirm.isEmpty && password != confirm {
            return ("Passwords do not match", .red)
        }
        if let error = viewModel.errorMessage {
            return (error, .red)
        }
        return nil
    }

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 28) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                VStack(spacing: 6) {
                    Text("Create Your Vault")
                        .font(.title2.weight(.semibold))

                    Text("Choose a strong master password.\nThis is the only password you'll need to remember.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    SecureField("Master Password", text: $password)
                    SecureField("Confirm Password", text: $confirm)
                }
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

                // Fixed-height validation area — prevents layout shift
                Group {
                    if let (message, color) = validationMessage {
                        Text(message)
                            .foregroundStyle(color)
                    } else {
                        Text(" ")
                    }
                }
                .font(.caption)
                .frame(height: 16)

                Button {
                    viewModel.createVault(password: password, confirm: confirm)
                } label: {
                    Group {
                        if viewModel.isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Create Vault")
                        }
                    }
                    .frame(width: 200, height: 20)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isValid || viewModel.isProcessing)
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
    }
}
