import Foundation
import SwiftUI
import CoreGraphics

@MainActor
@Observable
final class AutoLockService {
    var onLock: (@MainActor () -> Void)?

    private var idleTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    @ObservationIgnored
    @AppStorage("autoLockMinutes") var autoLockMinutes: Int = 5

    func start() {
        stop()

        let nc = NSWorkspace.shared.notificationCenter

        let sleepObs = nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.triggerLock() }
        }

        let screenObs = nc.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.triggerLock() }
        }

        workspaceObservers = [sleepObs, screenObs]
        startIdleTimer()
    }

    func stop() {
        idleTimer?.invalidate()
        idleTimer = nil
        let nc = NSWorkspace.shared.notificationCenter
        for obs in workspaceObservers {
            nc.removeObserver(obs)
        }
        workspaceObservers = []
    }

    func resetIdleTimer() {
        startIdleTimer()
    }

    private func startIdleTimer() {
        idleTimer?.invalidate()
        let minutes = max(autoLockMinutes, 1)
        let interval = TimeInterval(minutes * 60)
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIdle(timeout: interval)
            }
        }
    }

    private func checkIdle(timeout: TimeInterval) {
        let idle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: ~0)!
        )
        if idle >= timeout {
            triggerLock()
        }
    }

    private func triggerLock() {
        onLock?()
    }
}
