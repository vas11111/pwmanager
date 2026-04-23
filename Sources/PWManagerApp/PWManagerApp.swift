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
                .preferredColorScheme(.dark)
        }
        .commands { AppCommands(viewModel: viewModel) }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 920, height: 600)

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
                Color.clear
            case .needsSetup:
                CreateVaultView(viewModel: viewModel)
            case .locked:
                UnlockView(viewModel: viewModel)
            case .unlocked:
                VaultContentView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 740, minHeight: 480)
        .animation(.easeOut(duration: 0.3), value: viewModel.state == .unlocked)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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
