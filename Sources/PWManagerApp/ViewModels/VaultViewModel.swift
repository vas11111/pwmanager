import SwiftUI
import AppKit
import CryptoKit
import PWManagerCore

private struct Unsendable<T>: @unchecked Sendable { let value: T }

@MainActor
@Observable
final class VaultViewModel {
    enum AppState {
        case loading
        case needsSetup
        case locked
        case unlocked
    }

    enum SidebarSection: String, CaseIterable {
        case logins = "Logins"
        case sshKeys = "SSH Keys"
    }

    private(set) var state: AppState = .loading
    private(set) var entries: [PasswordEntry] = []
    private(set) var sshKeys: [SSHKeyEntry] = []
    private(set) var isProcessing = false
    var errorMessage: String?
    var searchText: String = ""
    var selectedItemID: UUID?
    var selectedSection: SidebarSection = .logins
    var showingAddEntry = false
    var showingAddSSHKey = false
    var toastMessage: String?
    var pendingRecoveryKey: String?

    let biometricService = BiometricService()
    let autoLockService = AutoLockService()
    let breachChecker = BreachChecker()
    let sshAgent = SSHAgentServer()
    private(set) var breachResults: [UUID: BreachResult] = [:]
    private(set) var sshAgentRunning = false

    nonisolated(unsafe) private let manager: PasswordManager
    private var inflightTask: Task<Void, Never>?

    @ObservationIgnored
    @AppStorage("failedUnlockAttempts") private var failedAttempts = 0
    @ObservationIgnored
    @AppStorage("lockoutUntilTimestamp") private var lockoutUntilTimestamp: Double = 0

    @ObservationIgnored
    @AppStorage("clipboardClearSeconds") private var clipboardClearSeconds = 30

    private var lockoutUntil: Date? {
        get { lockoutUntilTimestamp > 0 ? Date(timeIntervalSince1970: lockoutUntilTimestamp) : nil }
        set { lockoutUntilTimestamp = newValue?.timeIntervalSince1970 ?? 0 }
    }

    private static let attemptsPerHour = 3
    private static let maxTotalAttempts = 25
    private static let lockoutDuration: TimeInterval = 3600
    private static let minimumClipboardClear = 10

    @ObservationIgnored
    @AppStorage("totalFailedAttempts") private var totalFailedAttempts = 0
    @ObservationIgnored
    @AppStorage("hourlyAttemptTimestamps") private var hourlyTimestampsData = Data()

    init() {
        self.manager = PasswordManager(fileURL: PasswordManager.defaultFileURL())
    }

    var filteredEntries: [PasswordEntry] {
        let sorted = entries.sorted { $0.siteName.localizedCaseInsensitiveCompare($1.siteName) == .orderedAscending }
        guard !searchText.isEmpty else { return sorted }
        let query = searchText.lowercased()
        return sorted.filter {
            $0.siteName.lowercased().contains(query)
                || $0.username.lowercased().contains(query)
                || ($0.url?.lowercased().contains(query) ?? false)
        }
    }

    var selectedEntry: PasswordEntry? {
        guard let id = selectedItemID else { return nil }
        return entries.first { $0.id == id }
    }

    var selectedSSHKey: SSHKeyEntry? {
        guard let id = selectedItemID else { return nil }
        return sshKeys.first { $0.id == id }
    }

    var filteredSSHKeys: [SSHKeyEntry] {
        let sorted = sshKeys.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !searchText.isEmpty else { return sorted }
        let query = searchText.lowercased()
        return sorted.filter {
            $0.name.lowercased().contains(query)
                || $0.comment.lowercased().contains(query)
        }
    }

    var isLockedOut: Bool {
        recentAttemptCount >= Self.attemptsPerHour
    }

    var lockoutRemaining: Int {
        guard isLockedOut else { return 0 }
        let timestamps = decodeTimestamps()
        guard let oldest = timestamps.first else { return 0 }
        let unlockTime = oldest.addingTimeInterval(Self.lockoutDuration)
        return max(0, Int(unlockTime.timeIntervalSinceNow.rounded(.up)))
    }

    var remainingAttempts: Int {
        max(0, Self.maxTotalAttempts - totalFailedAttempts)
    }

    private var recentAttemptCount: Int {
        let cutoff = Date().addingTimeInterval(-Self.lockoutDuration)
        return decodeTimestamps().filter { $0 > cutoff }.count
    }

    private func recordFailedAttempt() {
        totalFailedAttempts += 1
        var timestamps = decodeTimestamps()
        timestamps.append(Date())
        let cutoff = Date().addingTimeInterval(-Self.lockoutDuration)
        timestamps = timestamps.filter { $0 > cutoff }
        encodeTimestamps(timestamps)
    }

    private func clearAttempts() {
        failedAttempts = 0
        lockoutUntil = nil
        var timestamps: [Date] = []
        encodeTimestamps(timestamps)
    }

    private func decodeTimestamps() -> [Date] {
        guard !hourlyTimestampsData.isEmpty else { return [] }
        return (try? JSONDecoder().decode([Date].self, from: hourlyTimestampsData)) ?? []
    }

    private func encodeTimestamps(_ timestamps: [Date]) {
        hourlyTimestampsData = (try? JSONEncoder().encode(timestamps)) ?? Data()
    }

    private func selfDestructVault() {
        manager.lock()
        try? FileManager.default.removeItem(at: PasswordManager.defaultFileURL())
        entries = []
        sshKeys = []
        breachResults = [:]
        selectedItemID = nil
        totalFailedAttempts = 0
        encodeTimestamps([])
        errorMessage = nil
        state = .needsSetup
        toastMessage = "Vault destroyed after too many failed attempts"
    }

    // MARK: - Lifecycle

    func checkVaultStatus() {
        biometricService.checkAvailability()
        autoLockService.onLock = { [weak self] in self?.lock() }

        if PasswordManager.vaultExists(at: PasswordManager.defaultFileURL()) {
            state = .locked
        } else {
            state = .needsSetup
        }
    }

    func createVault(password: String, confirm: String) {
        guard state == .needsSetup else { return }
        guard password == confirm else {
            errorMessage = "PINs don't match."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "PIN must be 6 digits."
            return
        }

        errorMessage = nil
        isProcessing = true
        let box = Unsendable(value: manager)

        let recoveryKey = RecoveryKey()

        inflightTask = Task.detached {
            do {
                try box.value.createVault(
                    masterPassword: password,
                    recoveryKey: recoveryKey
                )
                await MainActor.run {
                    guard self.isProcessing, self.state == .needsSetup else { return }
                    self.isProcessing = false
                    self.pendingRecoveryKey = recoveryKey.formatted
                    self.refreshEntries()
                    self.state = .unlocked
                    self.autoLockService.start()
                    self.offerTouchID(password: password)
                    self.checkBreaches()
                    self.startSSHAgent()
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = Self.friendlyError(error)
                }
            }
        }
    }

    func unlock(password: String) {
        guard state == .locked else { return }
        guard !password.isEmpty else {
            errorMessage = "Enter your PIN."
            return
        }

        // Self-destruct check
        if totalFailedAttempts >= Self.maxTotalAttempts {
            selfDestructVault()
            return
        }

        // Hourly rate limit
        if isLockedOut {
            let mins = lockoutRemaining / 60
            errorMessage = "Too many attempts. Try again in \(mins > 0 ? "\(mins)m" : "\(lockoutRemaining)s")."
            return
        }

        errorMessage = nil
        isProcessing = true
        let box = Unsendable(value: manager)

        inflightTask = Task.detached {
            do {
                try box.value.unlock(masterPassword: password)
                await MainActor.run {
                    guard self.isProcessing, self.state == .locked else { return }
                    self.isProcessing = false
                    self.clearAttempts()
                    self.totalFailedAttempts = 0
                    self.refreshEntries()
                    self.state = .unlocked
                    self.autoLockService.start()
                    self.offerTouchID(password: password)
                    self.checkBreaches()
                    self.startSSHAgent()
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.isProcessing = false
                    self.recordFailedAttempt()

                    if self.totalFailedAttempts >= Self.maxTotalAttempts {
                        self.selfDestructVault()
                    } else if self.isLockedOut {
                        self.errorMessage = "3 wrong attempts. Locked for 1 hour."
                    } else {
                        self.errorMessage = "Wrong PIN. \(self.remainingAttempts) attempts left."
                    }
                }
            }
        }
    }

    func unlockWithRecovery(key: String) {
        guard state == .locked else { return }
        let cleaned = RecoveryKey(raw: key).raw
        guard RecoveryKey.isValid(cleaned) else {
            errorMessage = "Invalid recovery key format."
            return
        }

        errorMessage = nil
        isProcessing = true
        let box = Unsendable(value: manager)

        inflightTask = Task.detached {
            do {
                try box.value.unlockWithRecoveryKey(cleaned)
                await MainActor.run {
                    guard self.isProcessing, self.state == .locked else { return }
                    self.isProcessing = false
                    self.clearAttempts()
                    self.totalFailedAttempts = 0
                    self.refreshEntries()
                    self.state = .unlocked
                    self.autoLockService.start()
                    self.checkBreaches()
                    self.startSSHAgent()
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = "Invalid recovery key."
                }
            }
        }
    }

    func unlockWithBiometrics() {
        guard state == .locked else { return }
        guard biometricService.isAvailable, biometricService.hasStoredPassword else { return }
        guard !isProcessing else { return }
        errorMessage = nil
        isProcessing = true

        Task {
            do {
                let password = try await biometricService.retrievePassword()
                await MainActor.run {
                    self.isProcessing = false
                    guard self.state == .locked else { return }
                    self.unlock(password: password)
                }
            } catch is BiometricError {
                isProcessing = false
            } catch {
                isProcessing = false
                errorMessage = "Touch ID failed."
            }
        }
    }

    func lock() {
        inflightTask?.cancel()
        inflightTask = nil
        isProcessing = false
        autoLockService.stop()
        sshAgent.stop()
        sshAgentRunning = false
        manager.lock()
        entries = []
        sshKeys = []
        breachResults = [:]
        pendingRecoveryKey = nil
        Task { await breachChecker.clearCache() }
        selectedItemID = nil
        searchText = ""
        errorMessage = nil
        state = .locked
    }

    func copySelectedPassword() {
        guard state == .unlocked, let entry = selectedEntry else { return }
        copyToClipboard(entry.password)
    }

    func selectNext() {
        let ids = currentSectionIDs
        guard !ids.isEmpty else { return }
        guard let current = selectedItemID,
              let idx = ids.firstIndex(of: current),
              idx + 1 < ids.count else {
            selectedItemID = ids.first
            return
        }
        selectedItemID = ids[idx + 1]
    }

    func selectPrevious() {
        let ids = currentSectionIDs
        guard !ids.isEmpty else { return }
        guard let current = selectedItemID,
              let idx = ids.firstIndex(of: current),
              idx > 0 else {
            selectedItemID = ids.last
            return
        }
        selectedItemID = ids[idx - 1]
    }

    private var currentSectionIDs: [UUID] {
        switch selectedSection {
        case .logins: return filteredEntries.map(\.id)
        case .sshKeys: return filteredSSHKeys.map(\.id)
        }
    }

    // MARK: - Entry Management

    func addEntry(
        siteName: String,
        username: String,
        password: String,
        url: String?,
        notes: String?,
        totpSecret: String? = nil,
        recoveryCode: String? = nil
    ) {
        guard state == .unlocked else { return }
        let cleanURL = sanitizeURL(url)
        let entry = PasswordEntry(
            siteName: siteName,
            username: username,
            password: password,
            url: cleanURL,
            notes: notes?.isEmpty == true ? nil : notes,
            totpSecret: totpSecret,
            recoveryCode: recoveryCode
        )
        do {
            try manager.addEntry(entry)
            refreshEntries()
            selectedItemID = entry.id
        } catch {
            errorMessage = Self.friendlyError(error)
        }
    }

    func updateEntry(_ entry: PasswordEntry, oldPassword: String? = nil) {
        guard state == .unlocked else { return }
        var updated = entry
        updated.url = sanitizeURL(updated.url)
        if let old = oldPassword, old != entry.password {
            // Restore the old password first, then call updatePassword with the new one
            // so history correctly archives the old value
            updated.password = old
            updated.updatePassword(entry.password)
        } else {
            updated.modifiedAt = Date()
        }
        do {
            try manager.updateEntry(updated)
            refreshEntries()
        } catch {
            errorMessage = Self.friendlyError(error)
        }
    }

    func deleteEntry(id: UUID) {
        guard state == .unlocked else { return }
        let list = filteredEntries
        let nextID: UUID? = {
            guard let idx = list.firstIndex(where: { $0.id == id }) else { return nil }
            if idx + 1 < list.count { return list[idx + 1].id }
            if idx > 0 { return list[idx - 1].id }
            return nil
        }()
        do {
            try manager.deleteEntry(id: id)
            if selectedItemID == id { selectedItemID = nextID }
            refreshEntries()
        } catch {
            errorMessage = Self.friendlyError(error)
        }
    }

    func refreshEntries() {
        do {
            entries = try manager.allEntries()
            sshKeys = try manager.allSSHKeys()
            if sshAgentRunning { updateSSHKeySnapshot() }
        } catch {
            entries = []
            sshKeys = []
            if !PasswordManager.vaultExists(at: PasswordManager.defaultFileURL()) {
                toastMessage = "Vault file was removed"
                lock()
            } else {
                errorMessage = "Failed to read vault data."
            }
        }
    }

    // MARK: - Breach Checking

    func checkBreaches() {
        guard state == .unlocked else { return }
        let currentEntries = entries
        Task {
            for entry in currentEntries {
                let result = await breachChecker.check(password: entry.password)
                await MainActor.run {
                    breachResults[entry.id] = result
                }
            }
        }
    }

    func checkBreach(for entry: PasswordEntry) {
        Task {
            let result = await breachChecker.check(password: entry.password)
            await MainActor.run {
                breachResults[entry.id] = result
            }
        }
    }

    // MARK: - SSH Agent

    private func startSSHAgent() {
        sshAgent.onSignRequest = { [weak self] key, _ in
            Task { @MainActor in
                self?.toastMessage = "SSH signed: \(key.comment)"
            }
        }
        updateSSHKeySnapshot()
        do {
            try sshAgent.start()
            sshAgentRunning = true
        } catch {
            sshAgentRunning = false
        }
    }

    private func updateSSHKeySnapshot() {
        let keys = sshKeys.compactMap { entry -> SSHKey? in
            SSHKey(seed: entry.privateKeyData, comment: entry.comment, entryID: entry.id)
        }
        sshAgent.updateKeys(keys)
    }

    func addSSHKey(name: String, comment: String, notes: String?, importedKeyData: Data? = nil) {
        guard state == .unlocked else { return }
        let keyData: Data
        let verb: String
        if let imported = importedKeyData {
            guard imported.count == 32,
                  (try? Curve25519.Signing.PrivateKey(rawRepresentation: imported)) != nil else {
                errorMessage = "Invalid Ed25519 key data."
                return
            }
            keyData = imported
            verb = "imported"
        } else {
            keyData = Curve25519.Signing.PrivateKey().rawRepresentation
            verb = "generated"
        }
        let entry = SSHKeyEntry(
            name: name,
            privateKeyData: keyData,
            comment: comment.isEmpty ? name : comment,
            notes: notes?.isEmpty == true ? nil : notes
        )
        do {
            try manager.addSSHKey(entry)
            refreshEntries()
            selectedItemID = entry.id
            selectedSection = .sshKeys
            toastMessage = "SSH key \(verb)"
        } catch {
            errorMessage = Self.friendlyError(error)
        }
    }

    func updateSSHKeyEntry(_ key: SSHKeyEntry) {
        guard state == .unlocked else { return }
        var updated = key
        updated.modifiedAt = Date()
        do {
            try manager.updateSSHKey(updated)
            refreshEntries()
        } catch {
            errorMessage = Self.friendlyError(error)
        }
    }

    func deleteSSHKey(id: UUID) {
        guard state == .unlocked else { return }
        do {
            try manager.deleteSSHKey(id: id)
            if selectedItemID == id { selectedItemID = nil }
            refreshEntries()
        } catch {
            errorMessage = Self.friendlyError(error)
        }
    }

    // MARK: - Clipboard

    func copyToClipboard(_ value: String) {
        guard state == .unlocked else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)

        // Also set concealed type so clipboard managers are less likely to capture
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        toastMessage = "Copied to clipboard"

        let changeCount = pasteboard.changeCount
        let clearDelay = max(clipboardClearSeconds, Self.minimumClipboardClear)

        Task {
            try? await Task.sleep(for: .seconds(clearDelay))
            if pasteboard.changeCount == changeCount {
                pasteboard.clearContents()
            }
        }
    }

    // MARK: - Touch ID

    @ObservationIgnored
    @AppStorage("touchIDEnabled") private var touchIDEnabled = false

    private func offerTouchID(password: String) {
        guard touchIDEnabled, biometricService.isAvailable else { return }
        try? biometricService.storePassword(password)
    }

    // MARK: - URL Validation

    private func sanitizeURL(_ url: String?) -> String? {
        guard let url, !url.isEmpty else { return nil }
        if let parsed = URL(string: url),
           let scheme = parsed.scheme?.lowercased(),
           scheme == "https" || scheme == "http" {
            return url
        }
        if !url.contains("://") {
            return "https://\(url)"
        }
        return nil
    }

    // MARK: - Errors

    private static func friendlyError(_ error: any Error) -> String {
        guard let pwError = error as? PasswordManagerError else {
            return "An unexpected error occurred."
        }
        switch pwError {
        case .incorrectPassword: return "Incorrect master password."
        case .deviceKeyMissing: return "Device key not found. This vault may belong to another device."
        case .passwordTooShort(let min): return "Password must be at least \(min) characters."
        case .vaultAlreadyExists: return "A vault already exists."
        case .metadataTampered: return "Vault file appears to be tampered with."
        case .vaultNotFound: return "No vault file found."
        case .vaultLocked: return "Vault is locked."
        case .entryNotFound: return "Entry not found."
        case .unsupportedVaultVersion: return "Unsupported vault format version."
        case .weakKDFParams: return "Vault has unsafe encryption parameters."
        }
    }
}
