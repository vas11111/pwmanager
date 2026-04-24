import Testing
import Foundation
import CryptoKit
@testable import PWManagerCore

@Suite("PIN & Recovery Key Tests", .serialized)
struct PINAndRecoveryTests {
    func makeTestEnv() -> (url: URL, keychain: KeychainManager) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pin-test-\(UUID().uuidString).pwm")
        let kc = KeychainManager(
            service: "com.pwmanager.pintest.\(UUID().uuidString)",
            account: "test-key"
        )
        return (url, kc)
    }

    func cleanup(url: URL, keychain: KeychainManager) {
        try? FileManager.default.removeItem(at: url)
        try? keychain.deleteDeviceKey()
    }

    // ============================================
    // PIN BASICS
    // ============================================

    @Test func createVaultWith6DigitPIN() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", kdfParams: .testing)
        #expect(m.isUnlocked)

        try m.addEntry(PasswordEntry(siteName: "Test", username: "u", password: "p"))
        m.lock()

        try m.unlock(masterPassword: "123456")
        let entries = try m.allEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.siteName == "Test")
    }

    @Test func wrongPINRejected() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", kdfParams: .testing)
        m.lock()

        #expect(throws: PasswordManagerError.self) {
            try m.unlock(masterPassword: "654321")
        }
    }

    @Test func pinTooShortRejected() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        #expect(throws: PasswordManagerError.self) {
            try m.createVault(masterPassword: "12345", kdfParams: .testing)
        }
    }

    // ============================================
    // RECOVERY KEY
    // ============================================

    @Test func recoveryKeyGeneration() {
        let rk = RecoveryKey()
        #expect(rk.raw.count == 20)
        #expect(RecoveryKey.isValid(rk.raw))
        #expect(RecoveryKey.isValid(rk.formatted))
    }

    @Test func recoveryKeyFormatting() {
        let rk = RecoveryKey()
        let formatted = rk.formatted
        // Should be XXXX-XXXX-XXXX-XXXX-XXXX
        #expect(formatted.contains("-"))
        let parts = formatted.split(separator: "-")
        #expect(parts.count == 5)
        for part in parts {
            #expect(part.count == 4)
        }
    }

    @Test func recoveryKeyParsesWithDashesAndSpaces() {
        let rk = RecoveryKey()
        let withDashes = rk.formatted
        let withSpaces = rk.raw.enumerated().map { i, c in
            i > 0 && i % 4 == 0 ? " \(c)" : "\(c)"
        }.joined()
        let lowercase = rk.raw.lowercased()

        #expect(RecoveryKey(raw: withDashes).raw == rk.raw)
        #expect(RecoveryKey(raw: withSpaces).raw == rk.raw)
        #expect(RecoveryKey(raw: lowercase).raw == rk.raw)
    }

    @Test func recoveryKeyUnlocksVault() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
        try m.addEntry(PasswordEntry(siteName: "Secret", username: "u", password: "p"))
        m.lock()

        // Recovery key should unlock
        try m.unlockWithRecoveryKey(rk.raw)
        #expect(m.isUnlocked)
        let entries = try m.allEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.siteName == "Secret")
    }

    @Test func wrongRecoveryKeyRejected() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
        m.lock()

        let fakeKey = RecoveryKey()
        #expect(throws: PasswordManagerError.self) {
            try m.unlockWithRecoveryKey(fakeKey.raw)
        }
    }

    @Test func pinAndRecoveryKeyBothWork() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "999888", recoveryKey: rk, kdfParams: .testing)
        try m.addEntry(PasswordEntry(siteName: "Both", username: "u", password: "p"))

        // Unlock with PIN
        m.lock()
        try m.unlock(masterPassword: "999888")
        #expect(try m.allEntries().count == 1)

        // Unlock with recovery key
        m.lock()
        try m.unlockWithRecoveryKey(rk.raw)
        #expect(try m.allEntries().count == 1)
    }

    @Test func recoveryKeyUnlockWhenPINForgotten() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
        try m.addEntry(PasswordEntry(siteName: "Important", username: "u", password: "secret"))
        m.lock()

        // Wrong PIN fails
        #expect(throws: PasswordManagerError.self) {
            try m.unlock(masterPassword: "000000")
        }

        // Recovery key still works
        try m.unlockWithRecoveryKey(rk.raw)
        let entries = try m.allEntries()
        #expect(entries.first?.password == "secret")
    }

    // ============================================
    // VAULT FORMAT
    // ============================================

    @Test func vaultFileVersion3() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)

        let data = try Data(contentsOf: env.url)
        let file = try JSONDecoder().decode(VaultFile.self, from: data)
        #expect(file.version == 3)
        #expect(file.hasRecoveryKey)
        #expect(file.recoverySalt != nil)
        #expect(file.encryptedMLKEMPrivateKeyRecovery != nil)
    }

    @Test func recoveryKeySlotFullyEncrypted() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)

        let raw = try String(data: Data(contentsOf: env.url), encoding: .utf8) ?? ""
        #expect(!raw.contains(rk.raw), "Recovery key should not appear in vault file")
        #expect(!raw.contains(rk.formatted), "Recovery key formatted should not appear in vault file")
    }

    @Test func hardenedKDFParamsStored() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456")

        let data = try Data(contentsOf: env.url)
        let file = try JSONDecoder().decode(VaultFile.self, from: data)
        #expect(file.kdfMemory == 262_144, "Default should be 256 MiB")
        #expect(file.kdfIterations == 8, "Default should be 8 iterations")
    }

    // ============================================
    // SSH KEYS + RECOVERY
    // ============================================

    @Test func sshKeysSurviveRecoveryUnlock() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let rk = RecoveryKey()
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)

        let privKey = Curve25519.Signing.PrivateKey()
        try m.addSSHKey(SSHKeyEntry(
            name: "RecoveryTest",
            privateKeyData: privKey.rawRepresentation,
            comment: "test"
        ))
        m.lock()

        try m.unlockWithRecoveryKey(rk.raw)
        let keys = try m.allSSHKeys()
        #expect(keys.count == 1)
        #expect(keys.first?.privateKeyData == privKey.rawRepresentation)
    }

    // ============================================
    // RECOVERY KEY VALIDATION
    // ============================================

    @Test func recoveryKeyValidation() {
        // Valid: only ABCDEFGHJKLMNPQRSTUVWXYZ23456789 (no I, O, 0, 1)
        #expect(RecoveryKey.isValid("ABCD2345EFGH6789JKLM"))
        #expect(RecoveryKey.isValid("ABCD-2345-EFGH-6789-JKLM"))
        #expect(RecoveryKey.isValid("abcd-2345-efgh-6789-jklm"))
        #expect(!RecoveryKey.isValid("short"))
        #expect(!RecoveryKey.isValid(""))
        #expect(!RecoveryKey.isValid("ABCD2345EFGH6789JKLMX")) // 21 chars
        #expect(!RecoveryKey.isValid("ABCD2345EFGO6789JKLM")) // O not in alphabet
        #expect(!RecoveryKey.isValid("ABCD1234EFGH5678JKLM")) // 1 not in alphabet
    }

    // ============================================
    // EDGE CASES
    // ============================================

    @Test func vaultWithoutRecoveryKeyRejectsRecoveryUnlock() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        // Create without recovery key
        let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m.createVault(masterPassword: "123456", kdfParams: .testing)
        m.lock()

        #expect(throws: PasswordManagerError.self) {
            try m.unlockWithRecoveryKey("ABCD2345EFGH6789JKLM")
        }
    }

    @Test func recoveryKeyUniquePerVault() {
        let rk1 = RecoveryKey()
        let rk2 = RecoveryKey()
        #expect(rk1.raw != rk2.raw)
    }
}
