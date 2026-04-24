import SwiftUI
import AppKit

@main
struct PWManagerApp: App {
    @State private var viewModel = VaultViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .task { viewModel.checkVaultStatus() }
        }
        .commands {
            AppCommands(viewModel: viewModel)

            CommandGroup(replacing: .appInfo) {
                Button("About PWManager") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "PWManager",
                        .applicationVersion: "1.0.0",
                        .version: "1",
                        .credits: NSAttributedString(
                            string: "Quantum-safe password manager\nArgon2id \u{2022} ML-KEM-768 \u{2022} AES-256-GCM",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 11),
                                .foregroundColor: NSColor.secondaryLabelColor,
                            ]
                        ),
                    ])
                }
            }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 620)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
                .preferredColorScheme(.dark)
        }

        MenuBarExtra("PWManager", systemImage: "lock.shield") {
            MenuBarView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

struct RootView: View {
    let viewModel: VaultViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                Theme.bg.ignoresSafeArea()
            case .needsSetup:
                CreateVaultView(viewModel: viewModel)
            case .locked:
                UnlockView(viewModel: viewModel)
            case .unlocked:
                VaultContentView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 780, minHeight: 500)
        .background(Theme.bg)
        .preferredColorScheme(.dark)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: viewModel.state == .unlocked)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @AppStorage("screenCaptureProtection") private var screenCaptureProtection = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = "PWManager"
            window.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
            window.setFrameAutosaveName("PWManagerMain")
            applyScreenCaptureProtection(to: window)
        }
    }

    @MainActor func applyScreenCaptureProtection(to window: NSWindow? = nil) {
        let target = window ?? NSApp.windows.first
        target?.sharingType = screenCaptureProtection ? .none : .readOnly
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                if window.canBecomeMain {
                    window.makeKeyAndOrderFront(self)
                    return false
                }
            }
        }
        return true
    }
}

struct AppCommands: Commands {
    let viewModel: VaultViewModel

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Entry") { viewModel.showingAddEntry = true }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(viewModel.state != .unlocked)
        }
        CommandGroup(after: .toolbar) {
            Button("Lock Vault") { viewModel.lock() }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(viewModel.state != .unlocked)
            Divider()
            Button("Copy Password") { viewModel.copySelectedPassword() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(viewModel.state != .unlocked || viewModel.selectedEntry == nil)
            Button("Copy Username") {
                if let entry = viewModel.selectedEntry {
                    viewModel.copyToClipboard(entry.username)
                }
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
            .disabled(viewModel.state != .unlocked || viewModel.selectedEntry == nil)
        }
    }
}
