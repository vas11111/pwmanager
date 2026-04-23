import SwiftUI
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

    private(set) var state: AppState = .loading
    private(set) var entries: [PasswordEntry] = []
    private(set) var isProcessing = false
    var errorMessage: String?
    var searchText: String = ""
    var selectedEntryID: UUID?
    var showingAddEntry = false

    nonisolated(unsafe) private let manager: PasswordManager

    init() {
        self.manager = PasswordManager(fileURL: PasswordManager.defaultFileURL())
    }

    var filteredEntries: [PasswordEntry] {
        guard !searchText.isEmpty else { return entries }
        let query = searchText.lowercased()
        return entries.filter {
            $0.siteName.lowercased().contains(query)
                || $0.username.lowercased().contains(query)
                || ($0.url?.lowercased().contains(query) ?? false)
        }
    }

    var selectedEntry: PasswordEntry? {
        guard let id = selectedEntryID else { return nil }
        return entries.first { $0.id == id }
    }

    func checkVaultStatus() {
        if PasswordManager.vaultExists(at: PasswordManager.defaultFileURL()) {
            state = .locked
        } else {
            state = .needsSetup
        }
    }

    func createVault(password: String, confirm: String) {
        guard password == confirm else {
            errorMessage = "Passwords do not match."
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        errorMessage = nil
        isProcessing = true
        let box = Unsendable(value: manager)

        Task.detached {
            do {
                try box.value.createVault(masterPassword: password)
                await MainActor.run {
                    self.isProcessing = false
                    self.refreshEntries()
                    self.state = .unlocked
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = Self.friendlyError(error)
                }
            }
        }
    }

    func unlock(password: String) {
        guard !password.isEmpty else {
            errorMessage = "Enter your master password."
            return
        }

        errorMessage = nil
        isProcessing = true
        let box = Unsendable(value: manager)

        Task.detached {
            do {
                try box.value.unlock(masterPassword: password)
                await MainActor.run {
                    self.isProcessing = false
                    self.refreshEntries()
                    self.state = .unlocked
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = Self.friendlyError(error)
                }
            }
        }
    }

    func lock() {
        manager.lock()
        entries = []
        selectedEntryID = nil
        searchText = ""
        errorMessage = nil
        state = .locked
    }

    func addEntry(
        siteName: String,
        username: String,
        password: String,
        url: String?,
        notes: String?
    ) {
        let entry = PasswordEntry(
            siteName: siteName,
            username: username,
            password: password,
            url: url?.isEmpty == true ? nil : url,
            notes: notes?.isEmpty == true ? nil : notes
        )
        do {
            try manager.addEntry(entry)
            refreshEntries()
            selectedEntryID = entry.id
        } catch {
            errorMessage = Self.friendlyError(error)
        }
    }

    func updateEntry(_ entry: PasswordEntry) {
        var updated = entry
        updated.modifiedAt = Date()
        do {
            try manager.updateEntry(updated)
            refreshEntries()
        } catch {
            errorMessage = Self.friendlyError(error)
        }
    }

    func deleteEntry(id: UUID) {
        do {
            try manager.deleteEntry(id: id)
            if selectedEntryID == id { selectedEntryID = nil }
            refreshEntries()
        } catch {
            errorMessage = Self.friendlyError(error)
        }
    }

    func refreshEntries() {
        do {
            entries = try manager.allEntries()
        } catch {
            entries = []
        }
    }

    private static func friendlyError(_ error: any Error) -> String {
        guard let pwError = error as? PasswordManagerError else {
            return error.localizedDescription
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
