import SwiftUI

struct SettingsView: View {
    let viewModel: VaultViewModel

    @AppStorage("autoLockMinutes") private var autoLockMinutes = 5
    @AppStorage("clipboardClearSeconds") private var clipboardClearSeconds = 30
    @AppStorage("touchIDEnabled") private var touchIDEnabled = false
    @AppStorage("screenCaptureProtection") private var screenCaptureProtection = true

    @State private var biometricService = BiometricService()
    @State private var showChangePassword = false
    @State private var showExportBackup = false

    var body: some View {
        TabView {
            securityTab
                .tabItem { Label("Security", systemImage: "lock.shield") }
            privacyTab
                .tabItem { Label("Privacy", systemImage: "eye.slash") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 440, height: 360)
        .task { biometricService.checkAvailability() }
    }

    private var securityTab: some View {
        Form {
            Section("PIN") {
                Button("Change PIN...") {
                    showChangePassword = true
                }
                .sheet(isPresented: $showChangePassword) {
                    ChangePasswordView(viewModel: viewModel)
                        .preferredColorScheme(.dark)
                }
            }

            Section("Backup") {
                Button("Export Encrypted Backup...") {
                    showExportBackup = true
                }
                .sheet(isPresented: $showExportBackup) {
                    ExportBackupView(viewModel: viewModel)
                        .preferredColorScheme(.dark)
                }
                .annotation("Save an encrypted copy of your vault that can be restored on another Mac using your recovery key.")
            }

            Section("Auto-Lock") {
                Picker("Lock vault after", selection: $autoLockMinutes) {
                    Text("1 minute").tag(1)
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                }
                .annotation("Vault locks automatically after this period of inactivity.")
            }

            Section("Clipboard") {
                Picker("Clear clipboard after", selection: $clipboardClearSeconds) {
                    Text("10 seconds").tag(10)
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                }
                .annotation("Copied passwords are cleared from the clipboard after this delay.")
            }

            Section("Touch ID") {
                if biometricService.isAvailable {
                    Toggle("Unlock with Touch ID", isOn: $touchIDEnabled)
                        .annotation("Use biometric authentication instead of typing your master password.")
                        .onChange(of: touchIDEnabled) { _, newValue in
                            if !newValue {
                                try? biometricService.deleteStoredPassword()
                            }
                        }

                    if touchIDEnabled && biometricService.hasStoredPassword {
                        Button("Clear Stored Password") {
                            try? biometricService.deleteStoredPassword()
                            touchIDEnabled = false
                        }
                        .foregroundStyle(.red)
                    }
                } else {
                    Text("Touch ID is not available on this device.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var privacyTab: some View {
        Form {
            Section("SSH Agent") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("The SSH agent serves Ed25519 keys from your vault when unlocked.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("~/.pwmanager/agent.sock")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                        Spacer()
                        Button("Copy Setup Command") {
                            let cmd = "export SSH_AUTH_SOCK=\"$HOME/.pwmanager/agent.sock\""
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(cmd, forType: .string)
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section("Screen Capture") {
                Toggle("Block screen recording & screenshots", isOn: $screenCaptureProtection)
                    .onChange(of: screenCaptureProtection) { _, _ in
                        if let delegate = NSApp.delegate as? AppDelegate {
                            delegate.applyScreenCaptureProtection()
                        }
                    }
                Text("When enabled, the window appears as a black rectangle in screen recordings, screenshots, and screen sharing sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var aboutTab: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint)

            Text("PWManager")
                .font(.system(size: 17, weight: .bold))

            Text("Version 1.0.0")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 3) {
                Text("Quantum-safe password manager")
                Text("Argon2id \u{2022} ML-KEM-768 \u{2022} AES-256-GCM")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)

            Divider().opacity(0.4).padding(.horizontal, 60).padding(.top, 6)

            VStack(spacing: 3) {
                Text("Built with")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text("phc-winner-argon2 \u{2022} Argon2 reference C implementation")
                Text("leif-ibsen/SwiftKyber \u{2022} ML-KEM-768 (FIPS 203)")
                Text("leif-ibsen/Digest \u{2022} SHA-3 / SHAKE")
                Text("leif-ibsen/BigInt \u{2022} arbitrary precision math")
                Text("leif-ibsen/ASN1 \u{2022} key serialization")
                Text("Apple CryptoKit \u{2022} AES-GCM, HKDF, HMAC, Curve25519")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }
}
