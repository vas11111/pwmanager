import Testing
import Foundation
import CryptoKit
@testable import PWManagerCore

// MARK: - Key Derivation (Argon2id)

@Suite("Key Derivation")
struct KeyDerivationTests {
    let testParams = KDFParams.testing

    @Test func derivesDeterministicKey() throws {
        let salt = Data(repeating: 0xAB, count: 32)
        let key1 = try KeyDerivation.deriveKey(from: "password", salt: salt, params: testParams)
        let key2 = try KeyDerivation.deriveKey(from: "password", salt: salt, params: testParams)
        let bytes1 = key1.withUnsafeBytes { Data($0) }
        let bytes2 = key2.withUnsafeBytes { Data($0) }
        #expect(bytes1 == bytes2)
    }

    @Test func differentPasswordsDifferentKeys() throws {
        let salt = Data(repeating: 0xAB, count: 32)
        let key1 = try KeyDerivation.deriveKey(from: "password1", salt: salt, params: testParams)
        let key2 = try KeyDerivation.deriveKey(from: "password2", salt: salt, params: testParams)
        let bytes1 = key1.withUnsafeBytes { Data($0) }
        let bytes2 = key2.withUnsafeBytes { Data($0) }
        #expect(bytes1 != bytes2)
    }

    @Test func differentSaltsDifferentKeys() throws {
        let salt1 = Data(repeating: 0xAA, count: 32)
        let salt2 = Data(repeating: 0xBB, count: 32)
        let key1 = try KeyDerivation.deriveKey(from: "password", salt: salt1, params: testParams)
        let key2 = try KeyDerivation.deriveKey(from: "password", salt: salt2, params: testParams)
        let bytes1 = key1.withUnsafeBytes { Data($0) }
        let bytes2 = key2.withUnsafeBytes { Data($0) }
        #expect(bytes1 != bytes2)
    }

    @Test func generatesSaltOfCorrectLength() {
        let salt = KeyDerivation.generateSalt()
        #expect(salt.count == 32)
    }

    @Test func generatedSaltsAreUnique() {
        let salt1 = KeyDerivation.generateSalt()
        let salt2 = KeyDerivation.generateSalt()
        #expect(salt1 != salt2)
    }

    @Test func derivedKeyIs256Bits() throws {
        let salt = Data(repeating: 0xAB, count: 32)
        let key = try KeyDerivation.deriveKey(from: "password", salt: salt, params: testParams)
        let size = key.withUnsafeBytes { $0.count }
        #expect(size == 32)
    }
}

// MARK: - AES-256-GCM

@Suite("AES-256-GCM Encryption")
struct AESEncryptionTests {
    @Test func encryptDecryptRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("Hello, quantum-safe world!".utf8)

        let encrypted = try CryptoEngine.encrypt(plaintext, using: key)
        let decrypted = try CryptoEngine.decrypt(encrypted, using: key)

        #expect(decrypted == plaintext)
        #expect(encrypted != plaintext)
    }

    @Test func wrongKeyFailsDecryption() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let plaintext = Data("secret data".utf8)

        let encrypted = try CryptoEngine.encrypt(plaintext, using: key1)
        #expect(throws: (any Error).self) {
            _ = try CryptoEngine.decrypt(encrypted, using: key2)
        }
    }

    @Test func tamperedCiphertextFailsDecryption() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("sensitive info".utf8)
        var encrypted = try CryptoEngine.encrypt(plaintext, using: key)

        encrypted[encrypted.count / 2] ^= 0xFF

        #expect(throws: (any Error).self) {
            _ = try CryptoEngine.decrypt(encrypted, using: key)
        }
    }

    @Test func encryptionIsNonDeterministic() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data("same plaintext".utf8)

        let encrypted1 = try CryptoEngine.encrypt(plaintext, using: key)
        let encrypted2 = try CryptoEngine.encrypt(plaintext, using: key)

        #expect(encrypted1 != encrypted2)
    }

    @Test func emptyDataEncryptDecrypt() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = Data()

        let encrypted = try CryptoEngine.encrypt(plaintext, using: key)
        let decrypted = try CryptoEngine.decrypt(encrypted, using: key)

        #expect(decrypted == plaintext)
    }

    @Test func largeDataEncryptDecrypt() throws {
        let key = SymmetricKey(size: .bits256)
        var bytes = [UInt8](repeating: 0, count: 1_000_000)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess)
        let plaintext = Data(bytes)

        let encrypted = try CryptoEngine.encrypt(plaintext, using: key)
        let decrypted = try CryptoEngine.decrypt(encrypted, using: key)

        #expect(decrypted == plaintext)
    }
}

// MARK: - ML-KEM-768

@Suite("ML-KEM-768 Post-Quantum")
struct MLKEMTests {
    @Test func encapsulateDecapsulateRoundTrip() throws {
        let keyPair = CryptoEngine.generateMLKEMKeyPair()

        let result = CryptoEngine.encapsulate(publicKey: keyPair.encapsulationKey)
        let decapsulated = try CryptoEngine.decapsulate(
            privateKey: keyPair.decapsulationKey,
            ciphertext: result.ciphertext
        )

        #expect(result.sharedSecret == decapsulated)
    }

    @Test func differentKeyPairsProduceDifferentSecrets() throws {
        let keyPair1 = CryptoEngine.generateMLKEMKeyPair()
        let keyPair2 = CryptoEngine.generateMLKEMKeyPair()

        let result1 = CryptoEngine.encapsulate(publicKey: keyPair1.encapsulationKey)
        let result2 = CryptoEngine.encapsulate(publicKey: keyPair2.encapsulationKey)

        #expect(result1.sharedSecret != result2.sharedSecret)
    }

    @Test func wrongPrivateKeyFailsDecapsulation() throws {
        let keyPair1 = CryptoEngine.generateMLKEMKeyPair()
        let keyPair2 = CryptoEngine.generateMLKEMKeyPair()

        let result = CryptoEngine.encapsulate(publicKey: keyPair1.encapsulationKey)

        let wrongSecret = try CryptoEngine.decapsulate(
            privateKey: keyPair2.decapsulationKey,
            ciphertext: result.ciphertext
        )
        #expect(result.sharedSecret != wrongSecret)
    }

    @Test func sharedSecretIs32Bytes() {
        let keyPair = CryptoEngine.generateMLKEMKeyPair()
        let result = CryptoEngine.encapsulate(publicKey: keyPair.encapsulationKey)
        #expect(result.sharedSecret.count == 32)
    }

    @Test func hybridKeyDerivationIsDeterministic() {
        let masterKey = SymmetricKey(size: .bits256)
        let quantumSecret: [UInt8] = Array(repeating: 0xFF, count: 32)

        let key1 = CryptoEngine.deriveVaultKey(
            masterKey: masterKey, quantumSecret: quantumSecret
        )
        let key2 = CryptoEngine.deriveVaultKey(
            masterKey: masterKey, quantumSecret: quantumSecret
        )

        let bytes1 = key1.withUnsafeBytes { Data($0) }
        let bytes2 = key2.withUnsafeBytes { Data($0) }
        #expect(bytes1 == bytes2)
    }

    @Test func hybridKeyChangesWithDifferentMasterKey() {
        let masterKey1 = SymmetricKey(size: .bits256)
        let masterKey2 = SymmetricKey(size: .bits256)
        let quantumSecret: [UInt8] = Array(repeating: 0xFF, count: 32)

        let key1 = CryptoEngine.deriveVaultKey(
            masterKey: masterKey1, quantumSecret: quantumSecret
        )
        let key2 = CryptoEngine.deriveVaultKey(
            masterKey: masterKey2, quantumSecret: quantumSecret
        )

        let bytes1 = key1.withUnsafeBytes { Data($0) }
        let bytes2 = key2.withUnsafeBytes { Data($0) }
        #expect(bytes1 != bytes2)
    }

    @Test func hybridKeyChangesWithDifferentQuantumSecret() {
        let masterKey = SymmetricKey(size: .bits256)
        let secret1: [UInt8] = Array(repeating: 0xAA, count: 32)
        let secret2: [UInt8] = Array(repeating: 0xBB, count: 32)

        let key1 = CryptoEngine.deriveVaultKey(masterKey: masterKey, quantumSecret: secret1)
        let key2 = CryptoEngine.deriveVaultKey(masterKey: masterKey, quantumSecret: secret2)

        let bytes1 = key1.withUnsafeBytes { Data($0) }
        let bytes2 = key2.withUnsafeBytes { Data($0) }
        #expect(bytes1 != bytes2)
    }
}

// MARK: - Key Combination & Metadata HMAC

@Suite("Two-Secret Model & HMAC")
struct CryptoIntegrationTests {
    @Test func deviceKeyCombinationChangesOutput() {
        let masterKey = SymmetricKey(size: .bits256)
        let deviceKey1 = Data(repeating: 0xAA, count: 16)
        let deviceKey2 = Data(repeating: 0xBB, count: 16)

        let combined1 = CryptoEngine.combineMasterWithDeviceKey(
            masterKey: masterKey, deviceKey: deviceKey1
        )
        let combined2 = CryptoEngine.combineMasterWithDeviceKey(
            masterKey: masterKey, deviceKey: deviceKey2
        )

        let b1 = combined1.withUnsafeBytes { Data($0) }
        let b2 = combined2.withUnsafeBytes { Data($0) }
        #expect(b1 != b2)
    }

    @Test func metadataHMACVerifiesCorrectly() throws {
        let key = SymmetricKey(size: .bits256)
        let metadata = Data("test-metadata-payload".utf8)

        let hmac = CryptoEngine.computeMetadataHMAC(vaultKey: key, metadata: metadata)
        #expect(CryptoEngine.verifyMetadataHMAC(
            vaultKey: key, metadata: metadata, expectedHMAC: hmac
        ))
    }

    @Test func metadataHMACRejectsTampering() throws {
        let key = SymmetricKey(size: .bits256)
        let metadata = Data("original-metadata".utf8)
        let tampered = Data("tampered-metadata".utf8)

        let hmac = CryptoEngine.computeMetadataHMAC(vaultKey: key, metadata: metadata)
        #expect(!CryptoEngine.verifyMetadataHMAC(
            vaultKey: key, metadata: tampered, expectedHMAC: hmac
        ))
    }

    @Test func metadataHMACRejectsWrongKey() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let metadata = Data("test-metadata".utf8)

        let hmac = CryptoEngine.computeMetadataHMAC(vaultKey: key1, metadata: metadata)
        #expect(!CryptoEngine.verifyMetadataHMAC(
            vaultKey: key2, metadata: metadata, expectedHMAC: hmac
        ))
    }
}

// MARK: - Keychain Manager

@Suite("Keychain Manager", .serialized)
struct KeychainTests {
    func makeKeychain() -> KeychainManager {
        KeychainManager(
            service: "com.pwmanager.test.\(UUID().uuidString)",
            account: "test-device-key"
        )
    }

    @Test func generateAndRetrieveDeviceKey() throws {
        let kc = makeKeychain()
        defer { try? kc.deleteDeviceKey() }

        let generated = try kc.generateAndStoreDeviceKey()
        #expect(generated.count == KeychainManager.deviceKeyLength)

        let retrieved = try kc.retrieveDeviceKey()
        #expect(generated == retrieved)
    }

    @Test func deviceKeyExistsCheck() throws {
        let kc = makeKeychain()
        defer { try? kc.deleteDeviceKey() }

        #expect(!kc.deviceKeyExists())
        _ = try kc.generateAndStoreDeviceKey()
        #expect(kc.deviceKeyExists())
    }

    @Test func deleteDeviceKey() throws {
        let kc = makeKeychain()
        _ = try kc.generateAndStoreDeviceKey()
        #expect(kc.deviceKeyExists())

        try kc.deleteDeviceKey()
        #expect(!kc.deviceKeyExists())
    }

    @Test func retrieveMissingKeyThrows() {
        let kc = makeKeychain()
        #expect(throws: KeychainError.self) {
            _ = try kc.retrieveDeviceKey()
        }
    }
}

// MARK: - Password Manager

@Suite("Password Manager", .serialized)
struct PasswordManagerTests {
    func makeTestEnv() -> (url: URL, keychain: KeychainManager) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-vault-\(UUID().uuidString).pwm")
        let kc = KeychainManager(
            service: "com.pwmanager.test.\(UUID().uuidString)",
            account: "test-key"
        )
        return (url, kc)
    }

    func cleanup(url: URL, keychain: KeychainManager) {
        try? FileManager.default.removeItem(at: url)
        try? keychain.deleteDeviceKey()
    }

    @Test func createAndUnlockVault() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: "test-master-pw", kdfParams: .testing)
        #expect(manager.isUnlocked)
        #expect(manager.entryCount == 0)

        manager.lock()
        #expect(!manager.isUnlocked)

        try manager.unlock(masterPassword: "test-master-pw")
        #expect(manager.isUnlocked)
    }

    @Test func wrongPasswordFails() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: "correct-password", kdfParams: .testing)
        manager.lock()

        #expect(throws: PasswordManagerError.self) {
            try manager.unlock(masterPassword: "wrong-password")
        }
    }

    @Test func missingDeviceKeyFails() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: "test-password", kdfParams: .testing)
        manager.lock()

        // Delete the device key from Keychain
        try env.keychain.deleteDeviceKey()

        #expect(throws: PasswordManagerError.self) {
            try manager.unlock(masterPassword: "test-password")
        }
    }

    @Test func shortPasswordRejected() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        #expect(throws: PasswordManagerError.self) {
            try manager.createVault(masterPassword: "short", kdfParams: .testing)
        }
        #expect(!manager.isUnlocked)
    }

    @Test func minimumLengthPasswordAccepted() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let minPw = String(repeating: "a", count: KeyDerivation.minimumPasswordLength)
        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: minPw, kdfParams: .testing)
        #expect(manager.isUnlocked)
    }

    @Test func duplicateCreateFails() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: "first-password", kdfParams: .testing)

        #expect(throws: PasswordManagerError.self) {
            try manager.createVault(masterPassword: "second-password", kdfParams: .testing)
        }
    }

    @Test func vaultFileHasRestrictedPermissions() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: "test-password", kdfParams: .testing)

        let attrs = try FileManager.default.attributesOfItem(atPath: env.url.path)
        let permissions = attrs[.posixPermissions] as! Int
        #expect(permissions == 0o600)
    }

    @Test func addAndRetrieveEntries() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: "test-password", kdfParams: .testing)

        let entry = PasswordEntry(
            siteName: "GitHub",
            username: "vasil",
            password: "gh-secret-123",
            url: "https://github.com"
        )
        try manager.addEntry(entry)
        #expect(manager.entryCount == 1)

        let results = try manager.searchEntries(query: "github")
        #expect(results.count == 1)
        #expect(results.first?.username == "vasil")
    }

    @Test func entriesPersistAcrossLockUnlock() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: "test-password", kdfParams: .testing)

        try manager.addEntry(PasswordEntry(
            siteName: "Site1", username: "user1", password: "pass1"
        ))
        try manager.addEntry(PasswordEntry(
            siteName: "Site2", username: "user2", password: "pass2"
        ))
        #expect(manager.entryCount == 2)

        manager.lock()
        try manager.unlock(masterPassword: "test-password")

        let entries = try manager.allEntries()
        #expect(entries.count == 2)
        #expect(entries.contains { $0.siteName == "Site1" })
        #expect(entries.contains { $0.siteName == "Site2" })
    }

    @Test func entriesPersistAcrossInstances() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let m1 = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m1.createVault(masterPassword: "test-password", kdfParams: .testing)
        try m1.addEntry(PasswordEntry(
            siteName: "Persistent", username: "user", password: "pass"
        ))

        let m2 = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try m2.unlock(masterPassword: "test-password")
        let entries = try m2.allEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.siteName == "Persistent")
    }

    @Test func deleteEntry() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: "test-password", kdfParams: .testing)

        let entry = PasswordEntry(siteName: "ToDelete", username: "u", password: "p")
        try manager.addEntry(entry)
        #expect(manager.entryCount == 1)

        try manager.deleteEntry(id: entry.id)
        #expect(manager.entryCount == 0)
    }

    @Test func updateEntry() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: "test-password", kdfParams: .testing)

        var entry = PasswordEntry(
            siteName: "Original", username: "user", password: "old-pass"
        )
        try manager.addEntry(entry)

        entry.password = "new-pass"
        entry.modifiedAt = Date()
        try manager.updateEntry(entry)

        let retrieved = try manager.getEntry(id: entry.id)
        #expect(retrieved.password == "new-pass")
    }

    @Test func operationsOnLockedVaultFail() throws {
        let env = makeTestEnv()
        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)

        let entry = PasswordEntry(siteName: "Test", username: "u", password: "p")

        #expect(throws: PasswordManagerError.self) { try manager.addEntry(entry) }
        #expect(throws: PasswordManagerError.self) { try manager.deleteEntry(id: entry.id) }
        #expect(throws: PasswordManagerError.self) { try manager.updateEntry(entry) }
        #expect(throws: PasswordManagerError.self) { _ = try manager.allEntries() }
        #expect(throws: PasswordManagerError.self) {
            _ = try manager.searchEntries(query: "test")
        }
    }

    @Test func deleteNonexistentEntryFails() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: "test-password", kdfParams: .testing)

        #expect(throws: PasswordManagerError.self) {
            try manager.deleteEntry(id: UUID())
        }
    }

    @Test func searchIsCaseInsensitive() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: "test-password", kdfParams: .testing)

        try manager.addEntry(PasswordEntry(
            siteName: "GitHub", username: "Vasil", password: "p"
        ))

        #expect(try manager.searchEntries(query: "github").count == 1)
        #expect(try manager.searchEntries(query: "GITHUB").count == 1)
        #expect(try manager.searchEntries(query: "vasil").count == 1)
        #expect(try manager.searchEntries(query: "nonexistent").count == 0)
    }

    @Test func vaultFileStoresArgon2Params() throws {
        let env = makeTestEnv()
        defer { cleanup(url: env.url, keychain: env.keychain) }

        let manager = PasswordManager(fileURL: env.url, keychain: env.keychain)
        try manager.createVault(masterPassword: "test-password", kdfParams: .testing)

        let data = try Data(contentsOf: env.url)
        let file = try JSONDecoder().decode(VaultFile.self, from: data)
        #expect(file.version == 2)
        #expect(file.kdfMemory == KDFParams.testing.memory)
        #expect(file.kdfIterations == KDFParams.testing.iterations)
        #expect(file.kdfParallelism == KDFParams.testing.parallelism)
        #expect(!file.metadataHMAC.isEmpty)
    }
}

// MARK: - Password Generator

@Suite("Password Generator")
struct PasswordGeneratorTests {
    @Test func generatesCorrectLength() {
        let pw = PasswordGenerator.generate(length: 32)
        #expect(pw.count == 32)
    }

    @Test func containsAllCharacterSets() {
        let pw = PasswordGenerator.generate(length: 100)
        #expect(pw.rangeOfCharacter(from: .lowercaseLetters) != nil)
        #expect(pw.rangeOfCharacter(from: .uppercaseLetters) != nil)
        #expect(pw.rangeOfCharacter(from: .decimalDigits) != nil)
    }

    @Test func shortPasswordRespectsLength() {
        let pw = PasswordGenerator.generate(length: 2)
        #expect(pw.count == 2)
    }

    @Test func lengthOneWorks() {
        let pw = PasswordGenerator.generate(length: 1)
        #expect(pw.count == 1)
    }

    @Test func lengthZeroReturnsEmpty() {
        let pw = PasswordGenerator.generate(length: 0)
        #expect(pw.isEmpty)
    }

    @Test func generatedPasswordsAreUnique() {
        let passwords = (0..<10).map { _ in PasswordGenerator.generate(length: 32) }
        let unique = Set(passwords)
        #expect(unique.count == 10)
    }

    @Test func singleCharacterSetWorks() {
        let pw = PasswordGenerator.generate(length: 16, using: [.digits])
        #expect(pw.count == 16)
        #expect(pw.allSatisfy { $0.isNumber })
    }
}
