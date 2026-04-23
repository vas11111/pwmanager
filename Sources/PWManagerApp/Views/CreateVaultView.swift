import SwiftUI

struct CreateVaultView: View {
    let viewModel: VaultViewModel
    @State private var password = ""
    @State private var confirm = ""

    private var isValid: Bool {
        password.count >= 8 && password == confirm
    }

    private var feedback: (String, Color)? {
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
        ZStack {
            Color(.windowBackgroundColor).ignoresSafeArea()

            ThemeCard {
                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }

                    VStack(spacing: 6) {
                        Text("Create Your Vault")
                            .font(.system(size: 20, weight: .bold))
                            .tracking(-0.3)

                        Text("Choose a strong master password.\nThis is the only password you'll need.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }

                    VStack(spacing: 8) {
                        ThemeTextField(placeholder: "Master Password", text: $password, isSecure: true)
                        ThemeTextField(placeholder: "Confirm Password", text: $confirm, isSecure: true)
                    }
                    .frame(width: 280)

                    Text(feedback?.0 ?? " ")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(feedback?.1 ?? .clear)
                        .frame(height: 14)

                    ThemePrimaryButton(
                        label: "Create Vault",
                        isLoading: viewModel.isProcessing
                    ) {
                        viewModel.createVault(password: password, confirm: confirm)
                    }
                    .disabled(!isValid || viewModel.isProcessing)
                }
            }
            .frame(width: 380)
        }
    }
}
