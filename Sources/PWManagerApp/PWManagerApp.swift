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
        .defaultSize(width: 900, height: 580)

        Settings {
            SettingsView()
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
        ZStack {
            switch viewModel.state {
            case .loading:
                Color.clear
            case .needsSetup:
                CreateVaultView(viewModel: viewModel)
                    .transition(.opacity)
            case .locked:
                UnlockView(viewModel: viewModel)
                    .transition(.opacity)
            case .unlocked:
                VaultContentView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(minWidth: 700, minHeight: 460)
        .animation(.easeInOut(duration: 0.25), value: viewModel.state == .unlocked)
        .animation(.easeInOut(duration: 0.25), value: viewModel.state == .locked)
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
            Button("New Entry") {
                viewModel.showingAddEntry = true
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(viewModel.state != .unlocked)
        }

        CommandGroup(after: .toolbar) {
            Button("Lock Vault") {
                viewModel.lock()
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(viewModel.state != .unlocked)

            Divider()

            Button("Copy Password") {
                viewModel.copySelectedPassword()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(viewModel.state != .unlocked || viewModel.selectedEntry == nil)
        }
    }
}
