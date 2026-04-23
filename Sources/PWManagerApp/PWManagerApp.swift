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
        .commands { AppCommands(viewModel: viewModel) }
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
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        }
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
        }
    }
}
