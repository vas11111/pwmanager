import SwiftUI

@main
struct PWManagerApp: App {
    @State private var viewModel = VaultViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                        .frame(width: 400, height: 300)
                case .needsSetup:
                    CreateVaultView(viewModel: viewModel)
                case .locked:
                    UnlockView(viewModel: viewModel)
                case .unlocked:
                    VaultContentView(viewModel: viewModel)
                }
            }
            .task { viewModel.checkVaultStatus() }
        }
        .commands {
            AppCommands(viewModel: viewModel)
        }
        .defaultSize(width: 800, height: 500)

        Settings {
            SettingsView()
        }

        MenuBarExtra("PWManager", systemImage: "lock.shield") {
            MenuBarView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
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
