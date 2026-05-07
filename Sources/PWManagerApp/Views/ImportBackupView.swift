import SwiftUI
import PWManagerCore

struct ImportBackupView: View {
    let viewModel: VaultViewModel
    let backupData: Data
    @Environment(\.dismiss) private var dismiss

    enum Step { case recoveryKey, setPin, confirmPin, success }

    @State private var step: Step = .recoveryKey
    @State private var recoveryInput = ""
    @State private var pin = ""
    @State private var firstPin = ""
    @State private var newRecoveryKey: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var shakeError = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Restore from Backup")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.text1)
                Spacer()
                if step != .success {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.text3)
                            .frame(width: 22, height: 22)
                            .background(Theme.bgField)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().overlay(Theme.border)

            if step == .success {
                successContent
            } else {
                formContent
            }
        }
        .frame(width: 400, height: 460)
        .background(Theme.bg)
    }

    private var formContent: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: stepIcon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(stepIconColor)

            Text(stepTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text1)

            Text(stepSubtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Group {
                if step == .recoveryKey {
                    ThemeTextField(
                        placeholder: "XXXX-XXXX-XXXX-XXXX-XXXX",
                        text: $recoveryInput
                    )
                    .padding(.horizontal, 20)
                    .shake(shakeError)
                } else {
                    PINPadView(pin: $pin, maxDigits: 6) { completed in
                        handlePinStep(completed)
                    }
                    .shake(shakeError)
                }
            }

            Group {
                if isProcessing {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Restoring...")
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
            .frame(height: 14)

            if step == .recoveryKey {
                Button {
                    advanceFromRecoveryKey()
                } label: {
                    Text("Continue")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 200)
                }
                .buttonStyle(AccentButtonStyle(disabled: recoveryInput.isEmpty || isProcessing))
                .disabled(recoveryInput.isEmpty || isProcessing)
            }

            Spacer()
        }
    }

    private var successContent: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("Vault Restored")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text1)
            Text("Your vault has been restored on this Mac.\nA new recovery key has been generated.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)

            if let key = newRecoveryKey {
                VStack(spacing: 6) {
                    Text("New Recovery Key")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)
                    Text(key)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.text1)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(Theme.bgField)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
                    Text("Save this key. The old recovery key no longer works.\nDelete the old backup file — it's no longer secure.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }

            Spacer()
            Button("I've Saved It") { dismiss() }
                .buttonStyle(AccentButtonStyle())
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
    }

    private var stepIcon: String {
        switch step {
        case .recoveryKey: return "key.horizontal.fill"
        case .setPin, .confirmPin: return "shield.checkered"
        case .success: return "checkmark.circle.fill"
        }
    }

    private var stepIconColor: Color {
        switch step {
        case .recoveryKey: return .orange
        case .setPin, .confirmPin: return Theme.accent
        case .success: return .green
        }
    }

    private var stepTitle: String {
        switch step {
        case .recoveryKey: return "Recovery Key"
        case .setPin: return "Set New PIN"
        case .confirmPin: return "Confirm New PIN"
        case .success: return ""
        }
    }

    private var stepSubtitle: String {
        switch step {
        case .recoveryKey: return "Enter the recovery key for this backup."
        case .setPin: return "Choose a new 6-digit PIN for this Mac."
        case .confirmPin: return "Enter the new PIN again."
        case .success: return ""
        }
    }

    private func advanceFromRecoveryKey() {
        guard RecoveryKey.isValid(recoveryInput) else {
            triggerShake("Invalid recovery key format.")
            return
        }
        errorMessage = nil
        withAnimation(.spring(duration: 0.25)) { step = .setPin }
    }

    private func handlePinStep(_ completed: String) {
        switch step {
        case .setPin:
            firstPin = completed
            pin = ""
            withAnimation(.spring(duration: 0.25)) { step = .confirmPin }
        case .confirmPin:
            if completed != firstPin {
                triggerShake("PINs don't match. Try again.")
                pin = ""
                withAnimation(.spring(duration: 0.25)) {
                    step = .setPin
                    firstPin = ""
                }
                return
            }
            performRestore(pin: completed)
        default:
            break
        }
    }

    private func performRestore(pin: String) {
        isProcessing = true
        errorMessage = nil
        let rk = recoveryInput
        Task {
            do {
                let newKey = try await viewModel.restoreFromBackup(
                    backupData: backupData,
                    backupRecoveryKey: rk,
                    newPin: pin
                )
                isProcessing = false
                newRecoveryKey = newKey
                withAnimation(.spring(duration: 0.3)) { step = .success }
            } catch {
                isProcessing = false
                if case PasswordManagerError.incorrectPassword = error {
                    triggerShake("Recovery key is incorrect.")
                    self.pin = ""
                    withAnimation(.spring(duration: 0.25)) {
                        step = .recoveryKey
                        firstPin = ""
                    }
                } else if case PasswordManagerError.metadataTampered = error {
                    triggerShake("Backup file is corrupted or tampered.")
                } else if case PasswordManagerError.unsupportedBackupVersion = error {
                    errorMessage = "Backup file version is not supported."
                } else {
                    errorMessage = "Restore failed."
                }
            }
        }
    }

    private func triggerShake(_ message: String) {
        errorMessage = message
        shakeError = true
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            shakeError = false
        }
    }
}
