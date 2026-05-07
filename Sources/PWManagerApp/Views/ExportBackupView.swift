import SwiftUI
import AppKit
import PWManagerCore

struct ExportBackupView: View {
    let viewModel: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var recoveryInput = ""
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var shakeError = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Export Backup")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.text1)
                Spacer()
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
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().overlay(Theme.border)

            VStack(spacing: 14) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 18)

                Text("Enter your recovery key to encrypt\na portable backup of this vault.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)

                ThemeTextField(
                    placeholder: "XXXX-XXXX-XXXX-XXXX-XXXX",
                    text: $recoveryInput
                )
                .padding(.horizontal, 20)
                .shake(shakeError)

                Text("The backup can be restored on any Mac using only this recovery key. Keep both safe.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Group {
                    if isExporting {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Encrypting...")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.text2)
                        }
                    } else if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                    } else {
                        Text(" ")
                    }
                }
                .frame(height: 14)

                Button {
                    performExport()
                } label: {
                    Text("Export Backup...")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 200)
                }
                .buttonStyle(AccentButtonStyle(disabled: recoveryInput.isEmpty || isExporting))
                .disabled(recoveryInput.isEmpty || isExporting)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 380, height: 360)
        .background(Theme.bg)
    }

    private func performExport() {
        isExporting = true
        errorMessage = nil
        let rk = recoveryInput
        Task {
            do {
                let data = try await viewModel.exportBackup(recoveryKey: rk)
                isExporting = false
                let panel = NSSavePanel()
                panel.allowedContentTypes = []
                panel.nameFieldStringValue = "pwmanager-backup-\(dateString()).pwmbackup"
                panel.canCreateDirectories = true
                panel.title = "Save Encrypted Backup"
                panel.message = "Save the encrypted backup file. You'll need this file AND your recovery key to restore on another Mac."
                if panel.runModal() == .OK, let url = panel.url {
                    try data.write(to: url, options: .atomic)
                    try? FileManager.default.setAttributes(
                        [.posixPermissions: 0o600], ofItemAtPath: url.path
                    )
                    dismiss()
                }
            } catch {
                isExporting = false
                if case PasswordManagerError.incorrectPassword = error {
                    triggerShake("Recovery key is incorrect.")
                } else {
                    errorMessage = "Export failed."
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

    private func dateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
