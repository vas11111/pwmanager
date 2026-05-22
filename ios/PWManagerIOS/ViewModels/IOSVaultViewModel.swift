import SwiftUI
import UIKit
import Security
import PWManagerCore

private struct Unsendable<T>: @unchecked Sendable { let value: T }

private enum RateLimitStore {
    static let service = "com.pwmanager.ios.ratelimit"
    static let account = "attempt-data"

    struct AttemptData: Codable {
        var totalFailed: Int = 0
        var timestamps: [Date] = []
    }

    static func load() -> AttemptData {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let decoded = try? JSONDecoder().decode(AttemptData.self, from: data) else {
            return AttemptData()
        }
        return decoded
    }

    static func save(_ data: AttemptData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attrs: [String: Any] = [kSecValueData as String: encoded]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = encoded
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
@Observable
final class IOSVaultViewModel {
    enum AppState { case loading, needsSetup, locked, unlocked }

    private(set) var state: AppState = .loading
    private(set) var entries: [PasswordEntry] = []
    private(set) var sshKeys: [SSHKeyEntry] = []
    private(set) var isProcessing = false
    var errorMessage: String?
    var searchText: String = ""
    var selectedItemID: UUID?
    var toastMessage: String?
    var pendingRecoveryKey: String?

    nonisolated(unsafe) private let manager: PasswordManager
    private var inflightTask: Task<Void, Never>?
    @ObservationIgnored private var rateLimits = RateLimitStore.load()
    let breachChecker = BreachChecker()
    private(set) var breachResults: [UUID: BreachResult] = [:]

    @ObservationIgnored
    @AppStorage("clipboardClearSecondsIOS") private var clipboardClearSeconds = 30

    private static let attemptsPerHour = 3
    private static let maxTotalAttempts = 25
    private static let lockoutDuration: TimeInterval = 3600

    init() {
        self.manager = PasswordManager(fileURL: Self.vaultURL())
    }

    static func vaultURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PWManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vault.pwm")
    }

    var filteredEntries: [PasswordEntry] {
        let sorted = entries.sorted { $0.siteName.localizedCaseInsensitiveCompare($1.siteName) == .orderedAscending }
        guard !searchText.isEmpty else { return sorted }
        let q = searchText.lowercased()
        return sorted.filter {
            $0.siteName.lowercased().contains(q)
            || $0.username.lowercased().contains(q)
            || ($0.url?.lowercased().contains(q) ?? false)
        }
    }

    var selectedEntry: PasswordEntry? {
        guard let id = selectedItemID else { return nil }
        return entries.first { $0.id == id }
    }

    func checkVaultStatus() {
        state = PasswordManager.vaultExists(at: Self.vaultURL()) ? .locked : .needsSetup
    }

    var isLockedOut: Bool {
        let cutoff = Date().addingTimeInterval(-Self.lockoutDuration)
        return rateLimits.timestamps.filter { $0 > cutoff }.count >= Self.attemptsPerHour
    }

    var remainingAttempts: Int {
        max(0, Self.maxTotalAttempts - rateLimits.totalFailed)
    }

    private func recordFailedAttempt() {
        rateLimits.totalFailed += 1
        rateLimits.timestamps.append(Date())
        let cutoff = Date().addingTimeInterval(-Self.lockoutDuration)
        rateLimits.timestamps = rateLimits.timestamps.filter { $0 > cutoff }
        RateLimitStore.save(rateLimits)
    }

    private func clearAttempts() {
        rateLimits.totalFailed = 0
        rateLimits.timestamps = []
        RateLimitStore.save(rateLimits)
    }

    private func selfDestructVault() {
        manager.lock()
        try? FileManager.default.removeItem(at: Self.vaultURL())
        entries = []
        sshKeys = []
        selectedItemID = nil
        RateLimitStore.clear()
        rateLimits = RateLimitStore.AttemptData()
        errorMessage = nil
        state = .needsSetup
        toastMessage = "Vault destroyed after too many failed attempts"
    }

    // MARK: - Lifecycle

    func createVault(password: String, confirm: String) {
        guard state == .needsSetup else { return }
        guard password == confirm else { errorMessage = "PINs don't match."; return }
        guard password.count >= 6 else { errorMessage = "PIN must be at least 6 digits."; return }

        errorMessage = nil; isProcessing = true
        let box = Unsendable(value: manager)
        let recoveryKey = RecoveryKey()

        inflightTask = Task.detached {
            do {
                try box.value.createVault(masterPassword: password, recoveryKey: recoveryKey)
                await MainActor.run {
                    self.isProcessing = false
                    self.pendingRecoveryKey = recoveryKey.formatted
                    self.refreshEntries()
                    self.state = .unlocked
                    self.checkBreaches()
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
        if rateLimits.totalFailed >= Self.maxTotalAttempts {
            selfDestructVault()
            return
        }
        if isLockedOut {
            errorMessage = "Too many attempts. Try again in 1 hour."
            return
        }
        errorMessage = nil; isProcessing = true
        let box = Unsendable(value: manager)

        inflightTask = Task.detached {
            do {
                try box.value.unlock(masterPassword: password)
                await MainActor.run {
                    self.isProcessing = false
                    self.clearAttempts()
                    self.refreshEntries()
                    self.state = .unlocked
                    self.checkBreaches()
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.isProcessing = false
                    self.recordFailedAttempt()
                    if self.rateLimits.totalFailed >= Self.maxTotalAttempts {
                        self.selfDestructVault()
                    } else {
                        self.errorMessage = "Wrong PIN. \(self.remainingAttempts) attempts left."
                    }
                }
            }
        }
    }

    func unlockWithRecovery(key: String) {
        let cleaned = RecoveryKey(raw: key).raw
        guard RecoveryKey.isValid(cleaned) else {
            errorMessage = "Invalid recovery key format."
            return
        }
        errorMessage = nil; isProcessing = true
        let box = Unsendable(value: manager)
        inflightTask = Task.detached {
            do {
                try box.value.unlockWithRecoveryKey(cleaned)
                await MainActor.run {
                    self.isProcessing = false
                    self.clearAttempts()
                    self.refreshEntries()
                    self.state = .unlocked
                    self.checkBreaches()
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

    func lock() {
        inflightTask?.cancel()
        inflightTask = nil
        isProcessing = false
        manager.lock()
        entries = []
        sshKeys = []
        breachResults = [:]
        Task { await breachChecker.clearCache() }
        pendingRecoveryKey = nil
        selectedItemID = nil
        searchText = ""
        errorMessage = nil
        state = .locked
    }

    // MARK: - Breach checking

    func checkBreaches() {
        guard state == .unlocked else { return }
        let current = entries
        Task {
            for entry in current {
                let result = await breachChecker.check(password: entry.password)
                await MainActor.run { breachResults[entry.id] = result }
            }
        }
    }

    func checkBreach(for entry: PasswordEntry) {
        Task {
            let result = await breachChecker.check(password: entry.password)
            await MainActor.run { breachResults[entry.id] = result }
        }
    }

    // MARK: - Entries

    func refreshEntries() {
        do {
            entries = try manager.allEntries()
            sshKeys = try manager.allSSHKeys()
        } catch {
            entries = []
            sshKeys = []
            errorMessage = "Failed to read vault."
        }
    }

    func addEntry(
        siteName: String, username: String, password: String,
        url: String?, notes: String?,
        totpSecret: String? = nil, recoveryCode: String? = nil
    ) {
        guard state == .unlocked else { return }
        let entry = PasswordEntry(
            siteName: siteName, username: username, password: password,
            url: url?.isEmpty == true ? nil : url,
            notes: notes?.isEmpty == true ? nil : notes,
            totpSecret: totpSecret?.isEmpty == true ? nil : totpSecret,
            recoveryCode: recoveryCode?.isEmpty == true ? nil : recoveryCode
        )
        do {
            try manager.addEntry(entry)
            refreshEntries()
            selectedItemID = entry.id
            checkBreach(for: entry)
        } catch { errorMessage = Self.friendlyError(error) }
    }

    func updateEntry(_ entry: PasswordEntry, oldPassword: String? = nil) {
        guard state == .unlocked else { return }
        var updated = entry
        if let old = oldPassword, old != entry.password {
            updated.password = old
            updated.updatePassword(entry.password)
        } else {
            updated.modifiedAt = Date()
        }
        do {
            try manager.updateEntry(updated)
            refreshEntries()
            checkBreach(for: updated)
        } catch { errorMessage = Self.friendlyError(error) }
    }

    func deleteEntry(id: UUID) {
        guard state == .unlocked else { return }
        do {
            try manager.deleteEntry(id: id)
            if selectedItemID == id { selectedItemID = nil }
            refreshEntries()
        } catch { errorMessage = Self.friendlyError(error) }
    }

    // MARK: - Clipboard

    func copyToClipboard(_ value: String) {
        guard state == .unlocked else { return }
        Self.secureCopy(value, expireAfter: max(clipboardClearSeconds, 10))
        toastMessage = "Copied"
    }

    /// Places a string on UIPasteboard with two privacy guarantees:
    /// 1. `.localOnly: true`  — never synced to Universal Clipboard / iCloud / other Apple devices
    /// 2. `.expirationDate`   — iOS auto-clears the clipboard at this time even if the app is killed
    static func secureCopy(_ value: String, expireAfter seconds: Int) {
        let expiry = Date().addingTimeInterval(TimeInterval(seconds))
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: value]],
            options: [
                .localOnly: true,
                .expirationDate: expiry,
            ]
        )
    }

    // MARK: - Backup

    func exportBackup(recoveryKey: String) async throws -> Data {
        guard state == .unlocked else { throw PasswordManagerError.vaultLocked }
        let cleaned = RecoveryKey(raw: recoveryKey)
        guard RecoveryKey.isValid(cleaned.raw) else { throw PasswordManagerError.incorrectPassword }
        let box = Unsendable(value: manager)
        return try await Task.detached {
            try box.value.exportBackup(recoveryKey: cleaned)
        }.value
    }

    func restoreFromBackup(backupData: Data, backupRecoveryKey: String, newPin: String) async throws -> String {
        guard state == .needsSetup else { throw PasswordManagerError.vaultAlreadyExists }
        let cleaned = RecoveryKey(raw: backupRecoveryKey)
        guard RecoveryKey.isValid(cleaned.raw) else { throw PasswordManagerError.incorrectPassword }
        let newRk = RecoveryKey()
        let box = Unsendable(value: manager)
        try await Task.detached {
            try box.value.restoreFromBackup(
                backupData: backupData, backupRecoveryKey: cleaned.raw,
                newPassword: newPin, newRecoveryKey: newRk
            )
        }.value
        refreshEntries()
        state = .unlocked
        return newRk.formatted
    }

    // MARK: - Errors

    private static func friendlyError(_ error: any Error) -> String {
        if let pwErr = error as? PasswordManagerError {
            switch pwErr {
            case .incorrectPassword: return "Incorrect PIN."
            case .deviceKeyMissing: return "Device key missing. This vault belongs to another device."
            case .passwordTooShort(let n): return "PIN must be at least \(n) digits."
            case .vaultAlreadyExists: return "A vault already exists."
            case .metadataTampered: return "Vault file is tampered."
            case .vaultNotFound: return "No vault file found."
            case .vaultLocked: return "Vault is locked."
            case .entryNotFound: return "Entry not found."
            case .unsupportedVaultVersion: return "Unsupported vault version."
            case .weakKDFParams: return "Unsafe encryption parameters."
            case .recoveryKeyNotConfigured: return "No recovery key configured."
            case .unsupportedBackupVersion: return "Unsupported backup version."
            }
        }
        if let kc = error as? KeychainError {
            switch kc {
            case .unableToStore(let s):    return "Keychain store failed (OSStatus \(s))."
            case .unableToRetrieve(let s): return "Keychain read failed (OSStatus \(s))."
            case .deviceKeyNotFound:       return "Device key not found in Keychain."
            case .unableToDelete(let s):   return "Keychain delete failed (OSStatus \(s))."
            }
        }
        return "Error: \(String(describing: error))"
    }
}
