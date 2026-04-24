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
                .onChange(of: viewModel.state == .unlocked) { _, unlocked in
                    AppDelegate.resizeWindow(expanded: unlocked)
                }
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
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }

        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Image(systemName: "lock.shield")
                .symbolRenderingMode(.monochrome)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct RecoveryKeyWrapper: Identifiable {
    let id = UUID()
    let key: String
}

struct RootView: View {
    let viewModel: VaultViewModel
    @State private var showOverlay = false

    private var isExpanded: Bool {
        viewModel.state == .unlocked
    }

    var body: some View {
        ZStack {
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

            if showOverlay {
                Theme.bg
                    .transition(.opacity)
            }
        }
        .frame(
            minWidth: isExpanded ? 780 : 420,
            maxWidth: isExpanded ? .infinity : 420,
            minHeight: isExpanded ? 500 : 580,
            maxHeight: isExpanded ? .infinity : 580
        )
        .background(Theme.bg)
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.state) { oldState, newState in
            let resizing = (oldState != .unlocked && newState == .unlocked)
                || (oldState == .unlocked && newState != .unlocked)
            guard resizing else { return }

            withAnimation(.easeOut(duration: 0.08)) { showOverlay = true }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.25)) { showOverlay = false }
            }
        }
        .sheet(item: Binding(
            get: { viewModel.pendingRecoveryKey.map { RecoveryKeyWrapper(key: $0) } },
            set: { if $0 == nil { viewModel.pendingRecoveryKey = nil } }
        )) { wrapper in
            RecoveryKeyView(recoveryKey: wrapper.key) {
                viewModel.pendingRecoveryKey = nil
            }
            .preferredColorScheme(.dark)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @AppStorage("screenCaptureProtection") private var screenCaptureProtection = true

    static let lockedSize = NSSize(width: 420, height: 580)
    static let expandedSize = NSSize(width: 960, height: 620)

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

            let size = Self.lockedSize
            window.setContentSize(size)
            window.center()
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self, self.screenCaptureProtection,
                  let window = note.object as? NSWindow else { return }
            DispatchQueue.main.async {
                window.sharingType = .none
            }
        }
    }

    @MainActor static func resizeWindow(expanded: Bool) {
        guard let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }

        let newSize = expanded ? expandedSize : lockedSize
        let currentFrame = window.frame

        // Calculate new frame centered horizontally from current position
        let dx = (newSize.width - currentFrame.width) / 2
        let dy = (newSize.height - currentFrame.height) / 2
        let newFrame = NSRect(
            x: currentFrame.origin.x - dx,
            y: currentFrame.origin.y - dy,
            width: newSize.width,
            height: newSize.height
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }

    @MainActor func applyScreenCaptureProtection(to window: NSWindow? = nil) {
        let type: NSWindow.SharingType = screenCaptureProtection ? .none : .readOnly
        if let window {
            window.sharingType = type
        } else {
            for w in NSApp.windows { w.sharingType = type }
        }
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
