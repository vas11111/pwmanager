import SwiftUI

struct CreateVaultView: View {
    let viewModel: VaultViewModel
    @State private var password = ""
    @State private var confirm = ""
    @FocusState private var focusedField: Field?
    private enum Field { case password, confirm }

    private var isValid: Bool { password.count >= 8 && password == confirm }

    private var feedback: (String, Color)? {
        if !password.isEmpty && password.count < 8 { return ("At least 8 characters", .orange) }
        if !confirm.isEmpty && password != confirm { return ("Passwords don't match", .red) }
        if let e = viewModel.errorMessage { return (e, .red) }
        return nil
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            // Subtle gradient glow behind the card
            Circle()
                .fill(Theme.accent.opacity(0.06))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(y: -40)

            ThemeCard {
                VStack(spacing: 26) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Theme.accentGlow)
                            .frame(width: 68, height: 68)
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }

                    VStack(spacing: 6) {
                        Text("Create Your Vault")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.text1)
                            .tracking(-0.4)
                        Text("Choose a master password to protect\nyour credentials with quantum-safe encryption.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }

                    VStack(spacing: 8) {
                        ThemeTextField(placeholder: "Master password", text: $password, isSecure: true)
                            .focused($focusedField, equals: .password)
                            .onSubmit { focusedField = .confirm }
                        PasswordStrengthBar(password: password)
                        ThemeTextField(placeholder: "Confirm password", text: $confirm, isSecure: true)
                            .focused($focusedField, equals: .confirm)
                            .onSubmit {
                                if isValid { viewModel.createVault(password: password, confirm: confirm) }
                            }
                    }
                    .frame(width: 280)
                    .onAppear { focusedField = .password }

                    Text(feedback?.0 ?? " ")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(feedback?.1 ?? .clear)
                        .frame(height: 14)

                    Button {
                        viewModel.createVault(password: password, confirm: confirm)
                    } label: {
                        Group {
                            if viewModel.isProcessing {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Create Vault")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .frame(width: 260, height: 20)
                    }
                    .buttonStyle(AccentButtonStyle(disabled: !isValid || viewModel.isProcessing))
                    .disabled(!isValid || viewModel.isProcessing)
                }
            }
            .frame(width: 400)
        }
    }
}
