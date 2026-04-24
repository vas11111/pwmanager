import SwiftUI
import PWManagerCore

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    enum Step { case currentPin, newPin, confirmPin }

    @State private var step: Step = .currentPin
    @State private var pin = ""
    @State private var currentPin = ""
    @State private var newPin = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var success = false
    @State private var shakeError = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Change PIN")
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
        .frame(width: 400, height: 480)
        .background(Theme.bg)
    }

    private var formContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(stepTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text1)

            Text(stepSubtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text2)

            PINPadView(pin: $pin, maxDigits: 6) { completed in
                handlePin(completed)
            }
            .shake(shakeError)

            Group {
                if isProcessing {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Changing PIN...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.text2)
                    }
                } else if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
                } else {
                    Text(" ")
                }
            }
            .frame(height: 16)

            Button("Cancel") { dismiss() }
                .foregroundStyle(Theme.text3)
                .padding(.bottom, 16)

            Spacer()
        }
    }

    private var successContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("PIN Changed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text1)
            Text("Your vault has been re-encrypted with the new PIN.")
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

    private var stepTitle: String {
        switch step {
        case .currentPin: return "Current PIN"
        case .newPin: return "New PIN"
        case .confirmPin: return "Confirm New PIN"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case .currentPin: return "Enter your current PIN to verify."
        case .newPin: return "Choose your new 6-digit PIN."
        case .confirmPin: return "Enter the new PIN again."
        }
    }

    private func handlePin(_ completed: String) {
        switch step {
        case .currentPin:
            currentPin = completed
            pin = ""
            withAnimation(.spring(duration: 0.25)) { step = .newPin }

        case .newPin:
            newPin = completed
            pin = ""
            withAnimation(.spring(duration: 0.25)) { step = .confirmPin }

        case .confirmPin:
            if completed != newPin {
                triggerShake("New PINs don't match. Try again.")
                withAnimation(.spring(duration: 0.25)) {
                    step = .newPin
                    newPin = ""
                }
                return
            }
            changePin()
        }
    }

    private func changePin() {
        isProcessing = true
        errorMessage = nil

        let manager = PasswordManager(fileURL: PasswordManager.defaultFileURL())
        let current = currentPin
        let new = newPin

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
                        triggerShake("Current PIN is incorrect.")
                        step = .currentPin
                        currentPin = ""
                        newPin = ""
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

    private func triggerShake(_ message: String) {
        errorMessage = message
        shakeError = true
        pin = ""
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            shakeError = false
        }
    }
}
