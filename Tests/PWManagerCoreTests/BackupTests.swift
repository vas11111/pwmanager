import Testing
import Foundation
@testable import PWManagerCore

@Suite("Backup Export & Import", .serialized)
struct BackupTests {
    func makeTestEnv() -> (url: URL, keychain: KeychainManager) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-test-\(UUID().uuidString).pwm")
        let kc = KeychainManager(
            service: "com.pwmanager.backuptest.\(UUID().uuidString)",
            account: "test-key"
        )
        return (url, kc)
    }

    func cleanup(url: URL, keychain: KeychainManager) {
        try? FileManager.default.removeItem(at: url)
        try? keychain.deleteDeviceKey()
    }

    @Test func exportImportRoundTrip() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
        try m.addEntry(PasswordEntry(siteName: "GitHub", username: "user", password: "secret123"))
        try m.addEntry(PasswordEntry(siteName: "Email", username: "me@x.co", password: "p@ss"))

        let backupData = try m.exportBackup(recoveryKey: rk)
        #expect(backupData.count > 0)

        // Import on a fresh manager / file / keychain
        let env2 = makeTestEnv()
        defer { cleanup(url: env2.url, keychain: env2.keychain) }
        let m2 = PasswordManager(fileURL: env2.url, keychain: env2.keychain)
        try m2.restoreFromBackup(
            backupData: backupData,
            backupRecoveryKey: rk.raw,
            newPassword: "999888",
            newRecoveryKey: RecoveryKey(),
            kdfParams: .testing
        )
        let entries = try m2.allEntries()
        #expect(entries.count == 2)
        #expect(entries.contains { $0.siteName == "GitHub" && $0.password == "secret123" })
        #expect(entries.contains { $0.siteName == "Email" && $0.password == "p@ss" })
    }

    @Test func wrongRecoveryKeyOnImportFails() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
        try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
        let backupData = try m.exportBackup(recoveryKey: rk)

        let env2 = makeTestEnv()
        defer { cleanup(url: env2.url, keychain: env2.keychain) }
        let m2 = PasswordManager(fileURL: env2.url, keychain: env2.keychain)

        let wrong = RecoveryKey()
        #expect(throws: PasswordManagerError.self) {
            try m2.restoreFromBackup(
                backupData: backupData,
                backupRecoveryKey: wrong.raw,
                newPassword: "999888",
                newRecoveryKey: RecoveryKey(),
                kdfParams: .testing
            )
        }
    }

    @Test func wrongRecoveryKeyOnExportFails() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)

        let wrong = RecoveryKey()
        #expect(throws: PasswordManagerError.self) {
            _ = try m.exportBackup(recoveryKey: wrong)
        }
    }

    @Test func tamperedBackupFails() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
        try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
        var backupData = try m.exportBackup(recoveryKey: rk)

        // Flip a byte in the middle of the file (encrypted entries area)
        backupData[backupData.count / 2] ^= 0xFF

        let env2 = makeTestEnv()
        defer { cleanup(url: env2.url, keychain: env2.keychain) }
        let m2 = PasswordManager(fileURL: env2.url, keychain: env2.keychain)

        #expect(throws: PasswordManagerError.self) {
            try m2.restoreFromBackup(
                backupData: backupData,
                backupRecoveryKey: rk.raw,
                newPassword: "999888",
                newRecoveryKey: RecoveryKey(),
                kdfParams: .testing
            )
        }
    }

    @Test func backupContainsNoPlaintextSecrets() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
        try m.addEntry(PasswordEntry(
            siteName: "VerySecretSite",
            username: "VerySecretUser",
            password: "VerySecretPassword12345"
        ))
        let backupData = try m.exportBackup(recoveryKey: rk)
        let raw = String(data: backupData, encoding: .utf8) ?? ""

        #expect(!raw.contains("VerySecretPassword12345"), "Password leaked in backup")
        #expect(!raw.contains("VerySecretSite"), "Site name leaked in backup")
        #expect(!raw.contains("VerySecretUser"), "Username leaked in backup")
        #expect(!raw.contains(rk.raw), "Recovery key leaked in backup")
    }

    @Test func backupRestoresSSHKeys() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
        let seed = Data(repeating: 0x42, count: 32)
        try m.addSSHKey(SSHKeyEntry(
            name: "ServerKey", privateKeyData: seed, comment: "deploy"
        ))
        let backupData = try m.exportBackup(recoveryKey: rk)

        let env2 = makeTestEnv()
        defer { cleanup(url: env2.url, keychain: env2.keychain) }
        let m2 = PasswordManager(fileURL: env2.url, keychain: env2.keychain)
        try m2.restoreFromBackup(
            backupData: backupData,
            backupRecoveryKey: rk.raw,
            newPassword: "999888",
            newRecoveryKey: RecoveryKey(),
            kdfParams: .testing
        )
        let keys = try m2.allSSHKeys()
        #expect(keys.count == 1)
        #expect(keys.first?.privateKeyData == seed)
        #expect(keys.first?.name == "ServerKey")
    }

    @Test func vaultWithoutRecoveryKeyCannotExport() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", kdfParams: .testing)

        #expect(throws: PasswordManagerError.self) {
            _ = try m.exportBackup(recoveryKey: RecoveryKey())
        }
    }
}
