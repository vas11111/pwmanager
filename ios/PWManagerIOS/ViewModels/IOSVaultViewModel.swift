import SwiftUI
import UIKit
import LocalAuthentication
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

    @ObservationIgnored
    @AppStorage("clipboardClearSecondsIOS") private var clipboardClearSeconds = 30
    @ObservationIgnored
    @AppStorage("biometricEnabledIOS") private var biometricEnabled = false

    private static let attemptsPerHour = 3
    private static let maxTotalAttempts = 25
    private static let lockoutDuration: TimeInterval = 3600
    private static let bioService = "com.pwmanager.ios.biometric"
    private static let bioAccount = "stored-pin"

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

    var hasStoredBiometricPIN: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.bioService,
            kSecAttrAccount as String: Self.bioAccount,
            kSecReturnData as String: false,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    var biometricIsEnabled: Bool {
        get { biometricEnabled }
        set { biometricEnabled = newValue }
    }

    var canUseBiometric: Bool {
        let ctx = LAContext()
        var err: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
            && biometricEnabled
            && hasStoredBiometricPIN
    }

    var biometryType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
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
        clearStoredBiometricPIN()
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
                    if self.biometricEnabled {
                        self.storeBiometricPIN(password)
                    }
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
        guard state == .locked, canUseBiometric, !isProcessing else { return }
        errorMessage = nil; isProcessing = true
        Task {
            do {
                let ctx = LAContext()
                let ok = try await ctx.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Unlock your vault"
                )
                guard ok else { isProcessing = false; return }
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: Self.bioService,
                    kSecAttrAccount as String: Self.bioAccount,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                ]
                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                guard status == errSecSuccess, let data = result as? Data,
                      let pin = String(data: data, encoding: .utf8) else {
                    isProcessing = false
                    errorMessage = "Couldn't read stored PIN."
                    return
                }
                isProcessing = false
                guard state == .locked else { return }
                unlock(password: pin)
            } catch {
                isProcessing = false
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
        pendingRecoveryKey = nil
        selectedItemID = nil
        searchText = ""
        errorMessage = nil
        state = .locked
    }

    // MARK: - Biometric PIN store

    func storeBiometricPIN(_ pin: String) {
        clearStoredBiometricPIN()
        guard let data = pin.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.bioService,
            kSecAttrAccount as String: Self.bioAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func clearStoredBiometricPIN() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.bioService,
            kSecAttrAccount as String: Self.bioAccount,
        ]
        SecItemDelete(query as CFDictionary)
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

    func addEntry(siteName: String, username: String, password: String, url: String?, notes: String?) {
        guard state == .unlocked else { return }
        let entry = PasswordEntry(
            siteName: siteName, username: username, password: password,
            url: url?.isEmpty == true ? nil : url,
            notes: notes?.isEmpty == true ? nil : notes
        )
        do { try manager.addEntry(entry); refreshEntries(); selectedItemID = entry.id }
        catch { errorMessage = Self.friendlyError(error) }
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
        do { try manager.updateEntry(updated); refreshEntries() }
        catch { errorMessage = Self.friendlyError(error) }
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
        UIPasteboard.general.string = value
        let changeCount = UIPasteboard.general.changeCount
        toastMessage = "Copied"
        Task {
            try? await Task.sleep(for: .seconds(max(clipboardClearSeconds, 10)))
            if UIPasteboard.general.changeCount == changeCount {
                UIPasteboard.general.items = []
            }
        }
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
        guard let pwErr = error as? PasswordManagerError else { return "An unexpected error occurred." }
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
}
