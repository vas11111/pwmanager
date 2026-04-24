import SwiftUI
import PWManagerCore

struct SettingsView: View {
    @AppStorage("autoLockMinutes") private var autoLockMinutes = 5
    @AppStorage("clipboardClearSeconds") private var clipboardClearSeconds = 30
    @AppStorage("touchIDEnabled") private var touchIDEnabled = false
    @AppStorage("screenCaptureProtection") private var screenCaptureProtection = true

    @State private var biometricService = BiometricService()
    @State private var showChangePassword = false

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
            Section("Master Password") {
                Button("Change Master Password...") {
                    showChangePassword = true
                }
                .sheet(isPresented: $showChangePassword) {
                    ChangePasswordView()
                        .preferredColorScheme(.dark)
                }
            }

            Section("Auto-Lock") {
                Picker("Lock vault after", selection: $autoLockMinutes) {
                    Text("1 minute").tag(1)
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                }
            }

            Section("Clipboard") {
                Picker("Clear clipboard after", selection: $clipboardClearSeconds) {
                    Text("10 seconds").tag(10)
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                }
            }

            Section("Touch ID") {
                if biometricService.isAvailable {
                    Toggle("Unlock with Touch ID", isOn: $touchIDEnabled)
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
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("PWManager")
                .font(.system(size: 18, weight: .bold))

            Text("Version 1.0.0")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("Quantum-safe password manager")
                Text("Argon2id \u{2022} ML-KEM-768 \u{2022} AES-256-GCM")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
