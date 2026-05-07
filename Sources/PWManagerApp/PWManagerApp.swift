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
    @State private var contentVisible = true

    private var isExpanded: Bool {
        viewModel.state == .unlocked
    }

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
        .opacity(contentVisible ? 1 : 0)
        .frame(
            minWidth: isExpanded ? 780 : 420,
            maxWidth: isExpanded ? .infinity : 420,
            minHeight: isExpanded ? 500 : 600,
            maxHeight: isExpanded ? .infinity : 600
        )
        .background(Theme.bg)
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.state) { oldState, newState in
            let resizing = (oldState != .unlocked && newState == .unlocked)
                || (oldState == .unlocked && newState != .unlocked)
            guard resizing else { return }

            contentVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeIn(duration: 0.15)) { contentVisible = true }
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

    static let lockedSize = NSSize(width: 420, height: 600)
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
            window.collectionBehavior.insert([.fullScreenAuxiliary, .stationary])
            window.standardWindowButton(.zoomButton)?.isEnabled = false
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
        if expanded {
            applyExpandedGeometry(window: window, animated: true)
        } else {
            applyLockedGeometry(window: window, animated: true)
        }
    }

    @MainActor static func applyLockedGeometry(window: NSWindow, animated: Bool) {
        // Make the window fixed-size at the locked dimensions. Removing
        // .resizable from the styleMask prevents user drag-resize AND tiling
        // managers from overriding. minSize == maxSize is also belt-and-suspenders.
        let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: lockedSize)).size
        window.styleMask.remove(.resizable)
        window.minSize = frameSize
        window.maxSize = frameSize
        animateToFrame(window: window, size: frameSize, animated: animated)
    }

    @MainActor static func applyExpandedGeometry(window: NSWindow, animated: Bool) {
        let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: expandedSize)).size
        // Allow user to resize the unlocked window (within reasonable bounds).
        window.minSize = NSSize(width: frameSize.width, height: frameSize.height)
        window.maxSize = NSSize(width: 5000, height: frameSize.height)
        window.styleMask.insert(.resizable)
        animateToFrame(window: window, size: frameSize, animated: animated)
    }

    @MainActor private static func animateToFrame(window: NSWindow, size: NSSize, animated: Bool) {
        let currentFrame = window.frame
        let dx = (size.width - currentFrame.width) / 2
        let dy = (size.height - currentFrame.height) / 2
        let newFrame = NSRect(
            x: currentFrame.origin.x - dx,
            y: currentFrame.origin.y - dy,
            width: size.width,
            height: size.height
        )
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        } else {
            window.setFrame(newFrame, display: true)
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
