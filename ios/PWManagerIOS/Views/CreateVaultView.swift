import SwiftUI
import UniformTypeIdentifiers
import PWManagerCore

struct CreateVaultView: View {
    let viewModel: IOSVaultViewModel
    enum Step { case setPin, confirmPin }
    @State private var step: Step = .setPin
    @State private var pin = ""
    @State private var firstPin = ""
    @State private var errorText: String?
    @State private var showImporter = false
    @State private var showICloudPicker = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(step == .setPin ? "Set Your PIN" : "Confirm Your PIN")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.text1)
                .tracking(-0.4)

            Text(step == .setPin
                 ? "Choose a 6-digit PIN to protect your vault."
                 : "Enter the same PIN again to confirm.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.bottom, 32)
                .padding(.horizontal, 24)

            PINPadView(pin: $pin, maxDigits: 6) { handlePinEntry($0) }

            Group {
                if viewModel.isProcessing {
                    HStack(spacing: 6) {
                        ProgressView().tint(.white)
                        Text("Creating vault...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                    }
                } else if let err = errorText ?? viewModel.errorMessage {
                    Text(err)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                } else {
                    Text(" ")
                }
            }
            .frame(height: 18)
            .padding(.top, 20)

            VStack(spacing: 12) {
                Button { showICloudPicker = true } label: {
                    Label("Restore from iCloud Drive", systemImage: "icloud.and.arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.bgField)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.accent.opacity(0.4), lineWidth: 0.5))
                }

                Button("Pick file from another location…") { showImporter = true }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.text3)
            }
            .padding(.top, 16)

            Spacer()
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $showICloudPicker) {
            ICloudBackupsView(viewModel: viewModel, mode: .restore)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "pwmbackup") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Only call stopAccessingSecurityScopedResource if start
                    // actually returned true; the system can return false (we
                    // don't own the scope) and stopping in that case is
                    // undefined behaviour that can break later access.
                    let needsScope = url.startAccessingSecurityScopedResource()
                    defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url) {
                        importedBackup = data
                    }
                }
            case .failure: break
            }
        }
        .sheet(item: Binding(
            get: { importedBackup.map { BackupBlob(data: $0) } },
            set: { if $0 == nil { importedBackup = nil } }
        )) { blob in
            ImportBackupFlow(viewModel: viewModel, backupData: blob.data)
        }
    }

    @State private var importedBackup: Data?

    private func handlePinEntry(_ completed: String) {
        switch step {
        case .setPin:
            firstPin = completed
            pin = ""
            withAnimation(.spring(duration: 0.25)) { step = .confirmPin }
        case .confirmPin:
            if completed == firstPin {
                viewModel.createVault(password: completed, confirm: completed)
            } else {
                errorText = "PINs don't match. Try again."
                pin = ""
                withAnimation(.spring(duration: 0.25)) {
                    step = .setPin
                    firstPin = ""
                }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    errorText = nil
                }
            }
        }
    }
}

private struct BackupBlob: Identifiable {
    let id = UUID()
    let data: Data
}

struct ImportBackupFlow: View {
    @Bindable var viewModel: IOSVaultViewModel
    let backupData: Data
    @Environment(\.dismiss) private var dismiss

    enum Step { case recovery, setPin, confirmPin, success }
    @State private var step: Step = .recovery
    @State private var recovery = ""
    @State private var pin = ""
    @State private var firstPin = ""
    @State private var newRecoveryKey: String?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                switch step {
                case .recovery:
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                        .padding(.top, 24)
                    Text("Enter the recovery key for this backup.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text2)
                    TextField("XXXX-XXXX-XXXX-XXXX-XXXX", text: $recovery)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 24)
                    if let err = error { Text(err).font(.caption).foregroundStyle(.red) }
                    Button("Continue") {
                        if RecoveryKey.isValid(recovery) {
                            error = nil
                            withAnimation { step = .setPin }
                        } else { error = "Invalid recovery key format." }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(recovery.isEmpty)

                case .setPin, .confirmPin:
                    Text(step == .setPin ? "Set New PIN" : "Confirm New PIN")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.text1)
                        .padding(.top, 24)
                    Text(step == .setPin ? "Choose a new 6-digit PIN for this device." : "Enter the new PIN again.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text2)
                    PINPadView(pin: $pin, maxDigits: 6) { handlePin($0) }
                    if let err = error { Text(err).font(.caption).foregroundStyle(.red) }

                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                        .padding(.top, 24)
                    Text("Vault Restored")
                        .font(.system(size: 22, weight: .bold))
                    Text("A new recovery key has been generated.\nSave it. The old backup recovery key no longer works.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.text2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    if let key = newRecoveryKey {
                        Text(key)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.text1)
                            .textSelection(.enabled)
                            .padding(12)
                            .background(Theme.bgField)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button("I've Saved It") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .padding()
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Restore from Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .success {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func handlePin(_ completed: String) {
        switch step {
        case .setPin:
            firstPin = completed
            pin = ""
            withAnimation { step = .confirmPin }
        case .confirmPin:
            if completed != firstPin {
                error = "PINs don't match."
                pin = ""
                withAnimation { step = .setPin; firstPin = "" }
                return
            }
            Task {
                do {
                    let key = try await viewModel.restoreFromBackup(
                        backupData: backupData,
                        backupRecoveryKey: recovery,
                        newPin: completed
                    )
                    newRecoveryKey = key
                    withAnimation { step = .success }
                } catch let e as PasswordManagerError {
                    if case .incorrectPassword = e {
                        error = "Recovery key is incorrect."
                        withAnimation { step = .recovery }
                    } else if case .metadataTampered = e {
                        error = "Backup file is corrupted or tampered."
                    } else {
                        error = "Restore failed."
                    }
                } catch {
                    self.error = "Restore failed."
                }
            }
        default: break
        }
    }
}
