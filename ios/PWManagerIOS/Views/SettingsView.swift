import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication
import PWManagerCore

struct SettingsView: View {
    @Bindable var viewModel: IOSVaultViewModel
    @Environment(\.dismiss) private var dismiss
    enum ExportTarget { case iCloud, share }

    @State private var showExport = false
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false
    @State private var exportTarget: ExportTarget = .iCloud
    @State private var showICloudBrowser = false
    @State private var icloudSavedMessage: String?

    private var biometryName: String {
        switch viewModel.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometrics"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(biometryName) {
                    let ctx = LAContext()
                    if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                        Toggle("Unlock with \(biometryName)", isOn: Binding(
                            get: { viewModel.biometricIsEnabled },
                            set: {
                                viewModel.biometricIsEnabled = $0
                                if !$0 { viewModel.clearStoredBiometricPIN() }
                            }
                        ))
                        Text("Stores your PIN in the iOS Keychain so you can unlock with \(biometryName). The PIN is biometric-gated by iOS. Only the next time you unlock with PIN will the stored copy be refreshed.")
                            .font(.caption)
                            .foregroundStyle(Theme.text3)
                    } else {
                        Text("\(biometryName) not available on this device.")
                            .foregroundStyle(Theme.text3)
                    }
                }

                Section("Backup") {
                    Button {
                        exportTarget = .iCloud
                        showExport = true
                    } label: {
                        Label("Export to iCloud Drive", systemImage: "icloud.and.arrow.up")
                    }
                    .disabled(viewModel.state != .unlocked)

                    Button {
                        exportTarget = .share
                        showExport = true
                    } label: {
                        Label("Export via Share Sheet…", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.state != .unlocked)

                    Button {
                        showICloudBrowser = true
                    } label: {
                        Label("Browse iCloud Backups", systemImage: "icloud")
                    }

                    Text("iCloud backups sync to all devices signed into your Apple ID. Decryptable on any device using your recovery key alone.")
                        .font(.caption)
                        .foregroundStyle(Theme.text3)
                }

                Section("Vault") {
                    Button(role: .destructive) {
                        viewModel.lock()
                        dismiss()
                    } label: {
                        Label("Lock Vault", systemImage: "lock")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Crypto", value: "Argon2id • ML-KEM-768 • AES-256-GCM")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showExport) {
                ExportBackupSheet(viewModel: viewModel, target: exportTarget) { url in
                    exportedFileURL = url
                    showExport = false
                    switch exportTarget {
                    case .iCloud:
                        icloudSavedMessage = "Saved to iCloud Drive → PWManager."
                    case .share:
                        showShareSheet = true
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(url: url)
                }
            }
            .sheet(isPresented: $showICloudBrowser) {
                ICloudBackupsView(viewModel: viewModel, mode: .manage)
            }
            .alert("Backup Saved", isPresented: Binding(
                get: { icloudSavedMessage != nil },
                set: { if !$0 { icloudSavedMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(icloudSavedMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }
}

struct ExportBackupSheet: View {
    @Bindable var viewModel: IOSVaultViewModel
    let target: SettingsView.ExportTarget
    let onExported: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var recovery = ""
    @State private var isExporting = false
    @State private var error: String?
    @State private var icloudStore = ICloudBackupStore()

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 24)
                Text("Enter your recovery key to encrypt\na portable backup of this vault.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
                TextField("XXXX-XXXX-XXXX-XXXX-XXXX", text: $recovery)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 24)
                Text("The backup can be restored on any device using only this recovery key. Keep both safe.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                if let err = error {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                Button {
                    Task { await performExport() }
                } label: {
                    if isExporting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Export Backup")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(recovery.isEmpty || isExporting)
                Spacer()
            }
            .padding()
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Export Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func performExport() async {
        isExporting = true
        error = nil
        do {
            let data = try await viewModel.exportBackup(recoveryKey: recovery)
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd-HHmmss"
            let name = "pwmanager-backup-\(df.string(from: Date())).pwmbackup"
            let url: URL
            switch target {
            case .iCloud:
                icloudStore.refresh()
                guard icloudStore.isAvailable else {
                    isExporting = false
                    error = "iCloud Drive is not available. Enable it in Settings → Apple ID → iCloud."
                    return
                }
                url = try icloudStore.writeBackup(data: data, suggestedName: name)
            case .share:
                url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                try data.write(to: url, options: .atomic)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            }
            isExporting = false
            onExported(url)
        } catch {
            isExporting = false
            if case PasswordManagerError.incorrectPassword = error {
                self.error = "Recovery key is incorrect."
            } else {
                self.error = "Export failed: \(error.localizedDescription)"
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    var onComplete: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // Delete the temp backup file once the share sheet finishes (whether
        // the user actually exported it or cancelled). The encrypted backup
        // should not linger in /tmp where it'd be readable until iOS housekeeping.
        vc.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: url)
            onComplete?()
        }
        return vc
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
