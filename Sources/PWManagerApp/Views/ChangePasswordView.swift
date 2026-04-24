import SwiftUI
import PWManagerCore

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var success = false

    private var isValid: Bool {
        !currentPassword.isEmpty
            && newPassword.count >= 8
            && newPassword == confirmPassword
    }

    private var feedback: (String, Color)? {
        if !newPassword.isEmpty && newPassword.count < 8 {
            return ("At least 8 characters", .orange)
        }
        if !confirmPassword.isEmpty && newPassword != confirmPassword {
            return ("Passwords don't match", .red)
        }
        if let e = errorMessage { return (e, .red) }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Change Master Password")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().overlay(Theme.border)

            if success {
                successContent
            } else {
                formContent
            }
        }
        .frame(width: 420, height: 380)
        .background(Theme.bg)
    }

    private var formContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Password")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                        ThemeTextField(placeholder: "Enter current password", text: $currentPassword, isSecure: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("New Password")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                        ThemeTextField(placeholder: "Enter new password", text: $newPassword, isSecure: true)
                        PasswordStrengthBar(password: newPassword)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Confirm New Password")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                        ThemeTextField(placeholder: "Confirm new password", text: $confirmPassword, isSecure: true)
                    }

                    Text(feedback?.0 ?? " ")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(feedback?.1 ?? .clear)
                        .frame(height: 14)
                }
                .padding(32)
            }

            Divider().overlay(Theme.border)

            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Theme.text2)
                Spacer()
                Button {
                    changePassword()
                } label: {
                    Group {
                        if isProcessing {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Change Password")
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 140)
                }
                .buttonStyle(AccentButtonStyle(disabled: !isValid || isProcessing))
                .disabled(!isValid || isProcessing)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
    }

    private var successContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("Password Changed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text1)
            Text("Your vault has been re-encrypted with the new password.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(AccentButtonStyle())
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
    }

    private func changePassword() {
        isProcessing = true
        errorMessage = nil

        let manager = PasswordManager(fileURL: PasswordManager.defaultFileURL())
        let current = currentPassword
        let new = newPassword

        // Unlock first, then change
        Task.detached {
            do {
                try manager.unlock(masterPassword: current)
                try manager.changeMasterPassword(
                    currentPassword: current,
                    newPassword: new
                )
                await MainActor.run {
                    isProcessing = false
                    withAnimation(.spring(duration: 0.3)) { success = true }
                }
            } catch let error as PasswordManagerError {
                await MainActor.run {
                    isProcessing = false
                    switch error {
                    case .incorrectPassword:
                        errorMessage = "Current password is incorrect."
                    case .passwordTooShort(let min):
                        errorMessage = "New password must be at least \(min) characters."
                    default:
                        errorMessage = "An error occurred."
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "An unexpected error occurred."
                }
            }
        }
    }
}
