import SwiftUI
import AppKit

struct CreateVaultView: View {
    let viewModel: VaultViewModel

    enum Step { case setPin, confirmPin }

    @State private var step: Step = .setPin
    @State private var pin = ""
    @State private var firstPin = ""
    @State private var shakeError = false
    @State private var errorText: String?
    @State private var importBackupData: Data?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            Circle()
                .fill(Theme.accent.opacity(0.06))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(y: -40)

            VStack(spacing: 0) {
                Spacer().frame(height: 10)
                cardContent
                Spacer().frame(height: 10)
            }
            .frame(maxHeight: .infinity)
        }
        .sheet(item: Binding(
            get: { importBackupData.map { BackupDataWrapper(data: $0) } },
            set: { if $0 == nil { importBackupData = nil } }
        )) { wrapper in
            ImportBackupView(viewModel: viewModel, backupData: wrapper.data)
                .preferredColorScheme(.dark)
        }
    }

    private var cardContent: some View {
        ThemeCard(padding: 20) {
                VStack(spacing: 14) {
                    Spacer(minLength: 0)

                    VStack(spacing: 4) {
                        Text(step == .setPin ? "Set Your PIN" : "Confirm Your PIN")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.text1)
                            .tracking(-0.4)
                        Text(step == .setPin
                             ? "Choose a 6-digit PIN to protect your vault."
                             : "Enter the same PIN again to confirm.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                            .multilineTextAlignment(.center)
                    }

                    PINPadView(pin: $pin, maxDigits: 6) { completed in
                        handlePinEntry(completed)
                    }
                    .shake(shakeError)

                    // Error / status area
                    Group {
                        if viewModel.isProcessing {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Creating vault...")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.text2)
                            }
                        } else if let err = errorText ?? viewModel.errorMessage {
                            Text(err)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.red)
                        } else {
                            Text(" ")
                        }
                    }
                    .frame(height: 16)

                    Button("Restore from backup") {
                        pickBackupFile()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.text3)
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
            }
            .frame(width: 400)
            .frame(maxHeight: .infinity)
    }

    private func pickBackupFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Select Backup File"
        panel.message = "Choose a .pwmbackup file to restore."
        if panel.runModal() == .OK, let url = panel.url,
           let data = try? Data(contentsOf: url) {
            importBackupData = data
        }
    }

    private func handlePinEntry(_ completed: String) {
        switch step {
        case .setPin:
            firstPin = completed
            pin = ""
            withAnimation(.spring(duration: 0.25)) {
                step = .confirmPin
            }

        case .confirmPin:
            if completed == firstPin {
                viewModel.createVault(password: completed, confirm: completed)
            } else {
                shakeError = true
                errorText = "PINs don't match. Try again."
                pin = ""
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    shakeError = false
                }
                withAnimation(.spring(duration: 0.25)) {
                    step = .setPin
                    firstPin = ""
                }
            }
        }
    }
}

private struct BackupDataWrapper: Identifiable {
    let id = UUID()
    let data: Data
}
