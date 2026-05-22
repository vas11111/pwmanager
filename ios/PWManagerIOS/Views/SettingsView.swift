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
                    if exportTarget == .share {
                        showExport = false
                        showShareSheet = true
                    }
                    // For .iCloud the sheet shows its own success screen and
                    // dismisses on Done.
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
    @State private var savedFileName: String?

    private var icon: String {
        switch target {
        case .iCloud: return "icloud.and.arrow.up"
        case .share:  return "square.and.arrow.up"
        }
    }
    private var title: String {
        switch target {
        case .iCloud: return "Export to iCloud Drive"
        case .share:  return "Export Backup"
        }
    }
    private var subtitle: String {
        switch target {
        case .iCloud: return "Your backup will sync to the PWManager folder in iCloud Drive on all your devices."
        case .share:  return "Choose where to save the encrypted backup file."
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if let name = savedFileName {
                    successView(name: name)
                } else {
                    formView
                }
            }
            .navigationTitle(savedFileName == nil ? title : "Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if savedFileName == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .interactiveDismissDisabled(isExporting)
    }

    private var formView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 84, height: 84)
                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.text1)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 6) {
                Text("Recovery key")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.text3)
                    .textCase(.uppercase)
                TextField("XXXX-XXXX-XXXX-XXXX-XXXX", text: $recovery)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 24)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Anyone with this backup file and your recovery key can read your vault. Store both somewhere safe.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)

            if let err = error {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                Task { await performExport() }
            } label: {
                HStack {
                    if isExporting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: icon)
                    }
                    Text(isExporting ? "Encrypting..." : title)
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(recovery.isEmpty || isExporting)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func successView(name: String) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }
            .padding(.top, 60)

            Text(target == .iCloud ? "Saved to iCloud Drive" : "Backup Saved")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.text1)

            VStack(spacing: 4) {
                if target == .iCloud {
                    Text("iCloud Drive › PWManager")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.text2)
                }
                Text(name)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.text1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.bgField)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 24)

            if target == .iCloud {
                Text("This backup will sync to all your other devices signed into the same Apple ID. To restore, open PWManager and tap **Restore from iCloud Drive**.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
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
                isExporting = false
                savedFileName = name      // Show in-sheet success screen
                onExported(url)
            case .share:
                url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                try data.write(to: url, options: .atomic)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                isExporting = false
                onExported(url)        // Hands off to system share sheet immediately
            }
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
