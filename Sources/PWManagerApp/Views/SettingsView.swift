import SwiftUI

struct SettingsView: View {
    @AppStorage("autoLockMinutes") private var autoLockMinutes = 5
    @AppStorage("clipboardClearSeconds") private var clipboardClearSeconds = 30
    @AppStorage("touchIDEnabled") private var touchIDEnabled = false

    @State private var biometricService = BiometricService()

    var body: some View {
        TabView {
            securityTab
                .tabItem { Label("Security", systemImage: "lock.shield") }
        }
        .frame(width: 420, height: 300)
        .task { biometricService.checkAvailability() }
    }

    private var securityTab: some View {
        Form {
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
}
