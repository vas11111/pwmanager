import Foundation
import CryptoKit
@preconcurrency import VendoredKyber

public enum PasswordManagerError: Error, Sendable {
    case vaultAlreadyExists
    case vaultNotFound
    case vaultLocked
    case incorrectPassword
    case entryNotFound(UUID)
    case unsupportedVaultVersion(Int)
    case passwordTooShort(minimum: Int)
    case metadataTampered
    case deviceKeyMissing
    case weakKDFParams
    case recoveryKeyNotConfigured
    case unsupportedBackupVersion(Int)
}

public final class PasswordManager {
    private let fileURL: URL
    private let keychain: KeychainManager
    private let stateLock = NSLock()
    private var vaultData: VaultData?
    private var vaultKey: SymmetricKey?
    private var vaultFileMetadata: VaultFile?

    public var isUnlocked: Bool { stateLock.withLock { vaultData != nil } }

    public var entryCount: Int { stateLock.withLock { vaultData?.entries.count ?? 0 } }

    public init(fileURL: URL, keychain: KeychainManager = KeychainManager()) {
        self.fileURL = fileURL
        self.keychain = keychain
    }

    public static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("PWManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vault.pwm")
    }

    public static func vaultExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - Vault Lifecycle

    public func createVault(
        masterPassword: String,
        recoveryKey: RecoveryKey? = nil,
        kdfParams: KDFParams = .default
    ) throws {
        try createVaultInternal(
            masterPassword: masterPassword,
            recoveryKey: recoveryKey,
            initialData: VaultData.empty,
            kdfParams: kdfParams
        )
    }

    private func createVaultInternal(
        masterPassword: String,
        recoveryKey: RecoveryKey?,
        initialData: VaultData,
        kdfParams: KDFParams
    ) throws {
        try stateLock.withLock {
            guard masterPassword.count >= KeyDerivation.minimumPasswordLength else {
                throw PasswordManagerError.passwordTooShort(
                    minimum: KeyDerivation.minimumPasswordLength
                )
            }

            guard exclusiveCreate(at: fileURL) else {
                throw PasswordManagerError.vaultAlreadyExists
            }

            do {
                let deviceKey = try keychain.generateAndStoreDeviceKey()

                let salt = KeyDerivation.generateSalt()
                let masterKey = try KeyDerivation.deriveKey(
                    from: masterPassword, salt: salt, params: kdfParams
                )
                let combinedKey = CryptoEngine.combineMasterWithDeviceKey(
                    masterKey: masterKey, deviceKey: deviceKey
                )

                let keyPair = CryptoEngine.generateMLKEMKeyPair()
                let encapResult = CryptoEngine.encapsulate(
                    publicKey: keyPair.encapsulationKey
                )
                let derivedVaultKey = CryptoEngine.deriveVaultKey(
                    quantumSecret: encapResult.sharedSecret
                )

                let encoded = try JSONEncoder().encode(initialData)
                let encryptedEntries = try CryptoEngine.encrypt(encoded, using: derivedVaultKey)
                let encryptedPrivateKey = try CryptoEngine.encrypt(
                    Data(keyPair.decapsulationKey.keyBytes), using: combinedKey
                )

                // Recovery key slot
                var recoverySalt: Data? = nil
                var recoveryKdfMemory: Int? = nil
                var recoveryKdfIterations: Int? = nil
                var recoveryKdfParallelism: Int? = nil
                var encryptedMLKEMPrivateKeyRecovery: Data? = nil

                if let rk = recoveryKey {
                    let rSalt = KeyDerivation.generateSalt()
                    let rParams = KDFParams.recovery
                    let rMasterKey = try KeyDerivation.deriveKey(
                        from: rk.raw, salt: rSalt, params: rParams
                    )
                    let rCombined = CryptoEngine.combineMasterWithDeviceKey(
                        masterKey: rMasterKey, deviceKey: deviceKey
                    )
                    encryptedMLKEMPrivateKeyRecovery = try CryptoEngine.encrypt(
                        Data(keyPair.decapsulationKey.keyBytes), using: rCombined
                    )
                    recoverySalt = rSalt
                    recoveryKdfMemory = rParams.memory
                    recoveryKdfIterations = rParams.iterations
                    recoveryKdfParallelism = rParams.parallelism
                }

                let metadata = VaultMetadata(
                    version: VaultFile.currentVersion,
                    salt: salt,
                    kdfMemory: kdfParams.memory,
                    kdfIterations: kdfParams.iterations,
                    kdfParallelism: kdfParams.parallelism,
                    mlkemPublicKey: Data(keyPair.encapsulationKey.keyBytes),
                    encapsulatedKey: Data(encapResult.ciphertext),
                    recoverySalt: recoverySalt,
                    recoveryKdfMemory: recoveryKdfMemory,
                    recoveryKdfIterations: recoveryKdfIterations,
                    recoveryKdfParallelism: recoveryKdfParallelism
                )
                let hmac = CryptoEngine.computeMetadataHMAC(
                    vaultKey: derivedVaultKey,
                    metadata: try metadata.canonicalBytes()
                )

                let file = VaultFile(
                    version: VaultFile.currentVersion,
                    salt: salt,
                    kdfMemory: kdfParams.memory,
                    kdfIterations: kdfParams.iterations,
                    kdfParallelism: kdfParams.parallelism,
                    mlkemPublicKey: Data(keyPair.encapsulationKey.keyBytes),
                    encryptedMLKEMPrivateKey: encryptedPrivateKey,
                    encapsulatedKey: Data(encapResult.ciphertext),
                    encryptedEntries: encryptedEntries,
                    metadataHMAC: hmac,
                    recoverySalt: recoverySalt,
                    recoveryKdfMemory: recoveryKdfMemory,
                    recoveryKdfIterations: recoveryKdfIterations,
                    recoveryKdfParallelism: recoveryKdfParallelism,
                    encryptedMLKEMPrivateKeyRecovery: encryptedMLKEMPrivateKeyRecovery
                )

                try writeVaultFile(file)

                self.vaultData = initialData
                self.vaultKey = derivedVaultKey
                self.vaultFileMetadata = file
            } catch {
                try? FileManager.default.removeItem(at: fileURL)
                throw error
            }
        }
    }

    public func unlock(masterPassword: String) throws {
        try stateLock.withLock {
            let file = try readVaultFile()

            guard file.version == VaultFile.currentVersion else {
                throw PasswordManagerError.unsupportedVaultVersion(file.version)
            }

            // Reject vault files with unsafe KDF parameters (too weak or absurdly high)
            guard file.kdfMemory >= KDFParams.minimumMemory,
                  file.kdfMemory <= KDFParams.maximumMemory,
                  file.kdfIterations >= KDFParams.minimumIterations,
                  file.kdfIterations <= KDFParams.maximumIterations,
                  file.kdfParallelism >= KDFParams.minimumParallelism,
                  file.kdfParallelism <= KDFParams.maximumParallelism else {
                throw PasswordManagerError.weakKDFParams
            }

            // 1. Retrieve device key from Keychain
            let deviceKey: Data
            do {
                deviceKey = try keychain.retrieveDeviceKey()
            } catch {
                throw PasswordManagerError.deviceKeyMissing
            }

            // 2. Argon2id key derivation with stored parameters
            let kdfParams = KDFParams(
                memory: file.kdfMemory,
                iterations: file.kdfIterations,
                parallelism: file.kdfParallelism
            )
            let masterKey = try KeyDerivation.deriveKey(
                from: masterPassword, salt: file.salt, params: kdfParams
            )

            // 3. Combine with device key
            let combinedKey = CryptoEngine.combineMasterWithDeviceKey(
                masterKey: masterKey, deviceKey: deviceKey
            )

            // 4. Decrypt ML-KEM private key
            let privateKeyData: Data
            do {
                privateKeyData = try CryptoEngine.decrypt(
                    file.encryptedMLKEMPrivateKey, using: combinedKey
                )
            } catch {
                throw PasswordManagerError.incorrectPassword
            }

            let mlkemPrivateKey: DecapsulationKey
            do {
                mlkemPrivateKey = try DecapsulationKey(
                    keyBytes: [UInt8](privateKeyData)
                )
            } catch {
                throw PasswordManagerError.incorrectPassword
            }

            // 5. Decapsulate quantum shared secret
            let sharedSecret: [UInt8]
            do {
                sharedSecret = try CryptoEngine.decapsulate(
                    privateKey: mlkemPrivateKey,
                    ciphertext: [UInt8](file.encapsulatedKey)
                )
            } catch {
                throw PasswordManagerError.incorrectPassword
            }

            // 6. Derive vault key
            let derivedVaultKey = CryptoEngine.deriveVaultKey(
                quantumSecret: sharedSecret
            )

            // 7. Verify metadata HMAC before trusting any header fields
            let metadataBytes = try file.metadata.canonicalBytes()
            guard CryptoEngine.verifyMetadataHMAC(
                vaultKey: derivedVaultKey,
                metadata: metadataBytes,
                expectedHMAC: file.metadataHMAC
            ) else {
                throw PasswordManagerError.metadataTampered
            }

            // 8. Decrypt vault entries
            let decryptedData: Data
            do {
                decryptedData = try CryptoEngine.decrypt(
                    file.encryptedEntries, using: derivedVaultKey
                )
            } catch {
                throw PasswordManagerError.incorrectPassword
            }

            let vault = try JSONDecoder().decode(VaultData.self, from: decryptedData)

            self.vaultData = vault
            self.vaultKey = derivedVaultKey
            self.vaultFileMetadata = file
        }
    }

    public func unlockWithRecoveryKey(_ recoveryKey: String) throws {
        try stateLock.withLock {
            let file = try readVaultFile()

            guard file.hasRecoveryKey,
                  let rSalt = file.recoverySalt,
                  let rMem = file.recoveryKdfMemory,
                  let rIter = file.recoveryKdfIterations,
                  let rPar = file.recoveryKdfParallelism,
                  let encryptedPrivateKeyRecovery = file.encryptedMLKEMPrivateKeyRecovery else {
                throw PasswordManagerError.incorrectPassword
            }

            // Validate recovery KDF params
            guard rMem >= KDFParams.minimumMemory,
                  rMem <= KDFParams.maximumMemory,
                  rIter >= KDFParams.minimumIterations,
                  rIter <= KDFParams.maximumIterations,
                  rPar >= KDFParams.minimumParallelism,
                  rPar <= KDFParams.maximumParallelism else {
                throw PasswordManagerError.weakKDFParams
            }

            let deviceKey: Data
            do { deviceKey = try keychain.retrieveDeviceKey() }
            catch { throw PasswordManagerError.deviceKeyMissing }

            let rParams = KDFParams(memory: rMem, iterations: rIter, parallelism: rPar)
            let rMasterKey = try KeyDerivation.deriveKey(
                from: recoveryKey, salt: rSalt, params: rParams
            )
            let rCombined = CryptoEngine.combineMasterWithDeviceKey(
                masterKey: rMasterKey, deviceKey: deviceKey
            )

            let privateKeyData: Data
            do {
                privateKeyData = try CryptoEngine.decrypt(
                    encryptedPrivateKeyRecovery, using: rCombined
                )
            } catch {
                throw PasswordManagerError.incorrectPassword
            }

            let mlkemPrivateKey: DecapsulationKey
            do {
                mlkemPrivateKey = try DecapsulationKey(keyBytes: [UInt8](privateKeyData))
            } catch {
                throw PasswordManagerError.incorrectPassword
            }

            let sharedSecret: [UInt8]
            do {
                sharedSecret = try CryptoEngine.decapsulate(
                    privateKey: mlkemPrivateKey,
                    ciphertext: [UInt8](file.encapsulatedKey)
                )
            } catch {
                throw PasswordManagerError.incorrectPassword
            }

            let derivedVaultKey = CryptoEngine.deriveVaultKey(
                quantumSecret: sharedSecret
            )

            let metadataBytes = try file.metadata.canonicalBytes()
            guard CryptoEngine.verifyMetadataHMAC(
                vaultKey: derivedVaultKey,
                metadata: metadataBytes,
                expectedHMAC: file.metadataHMAC
            ) else {
                throw PasswordManagerError.metadataTampered
            }

            let decryptedData: Data
            do {
                decryptedData = try CryptoEngine.decrypt(
                    file.encryptedEntries, using: derivedVaultKey
                )
            } catch {
                throw PasswordManagerError.incorrectPassword
            }

            let vault = try JSONDecoder().decode(VaultData.self, from: decryptedData)

            self.vaultData = vault
            self.vaultKey = derivedVaultKey
            self.vaultFileMetadata = file
        }
    }

    public func changeMasterPassword(
        currentPassword: String,
        newPassword: String,
        newRecoveryKey: RecoveryKey? = nil,
        kdfParams: KDFParams = .default
    ) throws {
        try stateLock.withLock {
            guard let data = vaultData else { throw PasswordManagerError.vaultLocked }

            guard newPassword.count >= KeyDerivation.minimumPasswordLength else {
                throw PasswordManagerError.passwordTooShort(
                    minimum: KeyDerivation.minimumPasswordLength
                )
            }

            // Verify current password by attempting full unlock chain
            let file = try readVaultFile()
            let currentMasterKey = try KeyDerivation.deriveKey(
                from: currentPassword, salt: file.salt,
                params: KDFParams(
                    memory: file.kdfMemory,
                    iterations: file.kdfIterations,
                    parallelism: file.kdfParallelism
                )
            )
            let deviceKey = try keychain.retrieveDeviceKey()
            let currentCombined = CryptoEngine.combineMasterWithDeviceKey(
                masterKey: currentMasterKey, deviceKey: deviceKey
            )
            do {
                _ = try CryptoEngine.decrypt(
                    file.encryptedMLKEMPrivateKey, using: currentCombined
                )
            } catch {
                throw PasswordManagerError.incorrectPassword
            }

            // Re-derive with new password
            let newSalt = KeyDerivation.generateSalt()
            let newMasterKey = try KeyDerivation.deriveKey(
                from: newPassword, salt: newSalt, params: kdfParams
            )
            let newCombined = CryptoEngine.combineMasterWithDeviceKey(
                masterKey: newMasterKey, deviceKey: deviceKey
            )

            // New ML-KEM keypair
            let keyPair = CryptoEngine.generateMLKEMKeyPair()
            let encapResult = CryptoEngine.encapsulate(publicKey: keyPair.encapsulationKey)

            let newVaultKey = CryptoEngine.deriveVaultKey(
                quantumSecret: encapResult.sharedSecret
            )

            // Re-encrypt everything
            let encoded = try JSONEncoder().encode(data)
            let encryptedEntries = try CryptoEngine.encrypt(encoded, using: newVaultKey)
            let encryptedPrivateKey = try CryptoEngine.encrypt(
                Data(keyPair.decapsulationKey.keyBytes), using: newCombined
            )

            // Recovery key slot
            var recoverySalt: Data? = nil
            var recoveryKdfMemory: Int? = nil
            var recoveryKdfIterations: Int? = nil
            var recoveryKdfParallelism: Int? = nil
            var encryptedMLKEMPrivateKeyRecovery: Data? = nil

            if let rk = newRecoveryKey {
                let rSalt = KeyDerivation.generateSalt()
                let rParams = KDFParams.recovery
                let rMasterKey = try KeyDerivation.deriveKey(
                    from: rk.raw, salt: rSalt, params: rParams
                )
                let rCombined = CryptoEngine.combineMasterWithDeviceKey(
                    masterKey: rMasterKey, deviceKey: deviceKey
                )
                encryptedMLKEMPrivateKeyRecovery = try CryptoEngine.encrypt(
                    Data(keyPair.decapsulationKey.keyBytes), using: rCombined
                )
                recoverySalt = rSalt
                recoveryKdfMemory = rParams.memory
                recoveryKdfIterations = rParams.iterations
                recoveryKdfParallelism = rParams.parallelism
            }

            let metadata = VaultMetadata(
                version: VaultFile.currentVersion,
                salt: newSalt,
                kdfMemory: kdfParams.memory,
                kdfIterations: kdfParams.iterations,
                kdfParallelism: kdfParams.parallelism,
                mlkemPublicKey: Data(keyPair.encapsulationKey.keyBytes),
                encapsulatedKey: Data(encapResult.ciphertext),
                recoverySalt: recoverySalt,
                recoveryKdfMemory: recoveryKdfMemory,
                recoveryKdfIterations: recoveryKdfIterations,
                recoveryKdfParallelism: recoveryKdfParallelism
            )
            let hmac = CryptoEngine.computeMetadataHMAC(
                vaultKey: newVaultKey,
                metadata: try metadata.canonicalBytes()
            )

            let newFile = VaultFile(
                version: VaultFile.currentVersion,
                salt: newSalt,
                kdfMemory: kdfParams.memory,
                kdfIterations: kdfParams.iterations,
                kdfParallelism: kdfParams.parallelism,
                mlkemPublicKey: Data(keyPair.encapsulationKey.keyBytes),
                encryptedMLKEMPrivateKey: encryptedPrivateKey,
                encapsulatedKey: Data(encapResult.ciphertext),
                encryptedEntries: encryptedEntries,
                metadataHMAC: hmac,
                recoverySalt: recoverySalt,
                recoveryKdfMemory: recoveryKdfMemory,
                recoveryKdfIterations: recoveryKdfIterations,
                recoveryKdfParallelism: recoveryKdfParallelism,
                encryptedMLKEMPrivateKeyRecovery: encryptedMLKEMPrivateKeyRecovery
            )

            try writeVaultFile(newFile)
            self.vaultKey = newVaultKey
            self.vaultFileMetadata = newFile
        }
    }

    // MARK: - Backup Export / Import

    public func exportBackup(recoveryKey: RecoveryKey) throws -> Data {
        try stateLock.withLock {
            guard let data = vaultData else { throw PasswordManagerError.vaultLocked }

            // Verify the recovery key against the existing vault's recovery slot
            let file = try readVaultFile()
            guard let rSalt = file.recoverySalt,
                  let rMem = file.recoveryKdfMemory,
                  let rIter = file.recoveryKdfIterations,
                  let rPar = file.recoveryKdfParallelism,
                  let encryptedRecoveryPriv = file.encryptedMLKEMPrivateKeyRecovery else {
                throw PasswordManagerError.recoveryKeyNotConfigured
            }
            guard rMem >= KDFParams.minimumMemory, rMem <= KDFParams.maximumMemory,
                  rIter >= KDFParams.minimumIterations, rIter <= KDFParams.maximumIterations,
                  rPar >= KDFParams.minimumParallelism, rPar <= KDFParams.maximumParallelism else {
                throw PasswordManagerError.weakKDFParams
            }
            let verifyParams = KDFParams(memory: rMem, iterations: rIter, parallelism: rPar)
            let verifyMaster = try KeyDerivation.deriveKey(from: recoveryKey.raw, salt: rSalt, params: verifyParams)
            let deviceKey = try keychain.retrieveDeviceKey()
            let verifyCombined = CryptoEngine.combineMasterWithDeviceKey(masterKey: verifyMaster, deviceKey: deviceKey)
            do {
                _ = try CryptoEngine.decrypt(encryptedRecoveryPriv, using: verifyCombined)
            } catch {
                throw PasswordManagerError.incorrectPassword
            }

            // Build portable backup (no device key dependency)
            let backupSalt = KeyDerivation.generateSalt()
            let backupKdfParams = KDFParams.default
            let backupRecoveryMaster = try KeyDerivation.deriveKey(
                from: recoveryKey.raw, salt: backupSalt, params: backupKdfParams
            )

            let keyPair = CryptoEngine.generateMLKEMKeyPair()
            let encapResult = CryptoEngine.encapsulate(publicKey: keyPair.encapsulationKey)
            let backupKey = CryptoEngine.deriveBackupKey(quantumSecret: encapResult.sharedSecret)

            let encodedEntries = try JSONEncoder().encode(data)
            let encryptedEntries = try CryptoEngine.encrypt(encodedEntries, using: backupKey)
            let encryptedMLKEMPriv = try CryptoEngine.encrypt(
                Data(keyPair.decapsulationKey.keyBytes), using: backupRecoveryMaster
            )

            let createdAt = Date()
            let metadata = BackupMetadata(
                version: BackupFile.currentVersion,
                createdAt: createdAt,
                salt: backupSalt,
                kdfMemory: backupKdfParams.memory,
                kdfIterations: backupKdfParams.iterations,
                kdfParallelism: backupKdfParams.parallelism,
                mlkemPublicKey: Data(keyPair.encapsulationKey.keyBytes),
                mlkemCiphertext: Data(encapResult.ciphertext)
            )
            let hmac = CryptoEngine.computeBackupHMAC(
                backupKey: backupKey, metadata: try metadata.canonicalBytes()
            )

            let backup = BackupFile(
                version: BackupFile.currentVersion,
                createdAt: createdAt,
                salt: backupSalt,
                kdfMemory: backupKdfParams.memory,
                kdfIterations: backupKdfParams.iterations,
                kdfParallelism: backupKdfParams.parallelism,
                mlkemPublicKey: Data(keyPair.encapsulationKey.keyBytes),
                mlkemCiphertext: Data(encapResult.ciphertext),
                encryptedMLKEMPrivateKey: encryptedMLKEMPriv,
                encryptedEntries: encryptedEntries,
                metadataHMAC: hmac
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(backup)
        }
    }

    public func restoreFromBackup(
        backupData: Data,
        backupRecoveryKey: String,
        newPassword: String,
        newRecoveryKey: RecoveryKey,
        kdfParams: KDFParams = .default
    ) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupFile.self, from: backupData)

        guard backup.version == BackupFile.currentVersion else {
            throw PasswordManagerError.unsupportedBackupVersion(backup.version)
        }

        guard backup.kdfMemory >= KDFParams.minimumMemory,
              backup.kdfMemory <= KDFParams.maximumMemory,
              backup.kdfIterations >= KDFParams.minimumIterations,
              backup.kdfIterations <= KDFParams.maximumIterations,
              backup.kdfParallelism >= KDFParams.minimumParallelism,
              backup.kdfParallelism <= KDFParams.maximumParallelism else {
            throw PasswordManagerError.weakKDFParams
        }
        let backupKdfParams = KDFParams(
            memory: backup.kdfMemory,
            iterations: backup.kdfIterations,
            parallelism: backup.kdfParallelism
        )

        let recoveryMaster = try KeyDerivation.deriveKey(
            from: backupRecoveryKey, salt: backup.salt, params: backupKdfParams
        )

        // Decrypt ML-KEM private key — fails if recovery key is wrong
        let mlkemPrivData: Data
        do {
            mlkemPrivData = try CryptoEngine.decrypt(
                backup.encryptedMLKEMPrivateKey, using: recoveryMaster
            )
        } catch {
            throw PasswordManagerError.incorrectPassword
        }

        let mlkemPriv = try DecapsulationKey(keyBytes: [UInt8](mlkemPrivData))

        let sharedSecret: [UInt8]
        do {
            sharedSecret = try mlkemPriv.Decapsulate(ct: [UInt8](backup.mlkemCiphertext))
        } catch {
            throw PasswordManagerError.incorrectPassword
        }

        let backupKey = CryptoEngine.deriveBackupKey(quantumSecret: sharedSecret)

        guard CryptoEngine.verifyBackupHMAC(
            backupKey: backupKey,
            metadata: try backup.metadata.canonicalBytes(),
            expectedHMAC: backup.metadataHMAC
        ) else {
            throw PasswordManagerError.metadataTampered
        }

        let entriesData: Data
        do {
            entriesData = try CryptoEngine.decrypt(backup.encryptedEntries, using: backupKey)
        } catch {
            throw PasswordManagerError.incorrectPassword
        }

        let restored = try JSONDecoder().decode(VaultData.self, from: entriesData)

        try createVaultInternal(
            masterPassword: newPassword,
            recoveryKey: newRecoveryKey,
            initialData: restored,
            kdfParams: kdfParams
        )
    }

    public func lock() {
        stateLock.withLock {
            vaultData = nil
            vaultKey = nil
            vaultFileMetadata = nil
        }
    }

    // MARK: - Entry Management

    public func addEntry(_ entry: PasswordEntry) throws {
        try stateLock.withLock {
            guard vaultData != nil else { throw PasswordManagerError.vaultLocked }
            vaultData!.entries.append(entry)
            try save()
        }
    }

    public func deleteEntry(id: UUID) throws {
        try stateLock.withLock {
            guard vaultData != nil else { throw PasswordManagerError.vaultLocked }
            guard let index = vaultData!.entries.firstIndex(where: { $0.id == id }) else {
                throw PasswordManagerError.entryNotFound(id)
            }
            vaultData!.entries.remove(at: index)
            try save()
        }
    }

    public func updateEntry(_ entry: PasswordEntry) throws {
        try stateLock.withLock {
            guard vaultData != nil else { throw PasswordManagerError.vaultLocked }
            guard let idx = vaultData!.entries.firstIndex(where: { $0.id == entry.id }) else {
                throw PasswordManagerError.entryNotFound(entry.id)
            }
            vaultData!.entries[idx] = entry
            try save()
        }
    }

    public func allEntries() throws -> [PasswordEntry] {
        try stateLock.withLock {
            guard let data = vaultData else { throw PasswordManagerError.vaultLocked }
            return data.entries
        }
    }

    public func searchEntries(query: String) throws -> [PasswordEntry] {
        try stateLock.withLock {
            guard let data = vaultData else { throw PasswordManagerError.vaultLocked }
            let lowered = query.lowercased()
            return data.entries.filter {
                $0.siteName.lowercased().contains(lowered)
                    || $0.username.lowercased().contains(lowered)
                    || ($0.url?.lowercased().contains(lowered) ?? false)
                    || ($0.notes?.lowercased().contains(lowered) ?? false)
            }
        }
    }

    public func getEntry(id: UUID) throws -> PasswordEntry {
        try stateLock.withLock {
            guard let data = vaultData else { throw PasswordManagerError.vaultLocked }
            guard let entry = data.entries.first(where: { $0.id == id }) else {
                throw PasswordManagerError.entryNotFound(id)
            }
            return entry
        }
    }

    // MARK: - SSH Key Management

    public func addSSHKey(_ key: SSHKeyEntry) throws {
        try stateLock.withLock {
            guard vaultData != nil else { throw PasswordManagerError.vaultLocked }
            vaultData!.sshKeys.append(key)
            try save()
        }
    }

    public func deleteSSHKey(id: UUID) throws {
        try stateLock.withLock {
            guard vaultData != nil else { throw PasswordManagerError.vaultLocked }
            guard let index = vaultData!.sshKeys.firstIndex(where: { $0.id == id }) else {
                throw PasswordManagerError.entryNotFound(id)
            }
            vaultData!.sshKeys.remove(at: index)
            try save()
        }
    }

    public func updateSSHKey(_ key: SSHKeyEntry) throws {
        try stateLock.withLock {
            guard vaultData != nil else { throw PasswordManagerError.vaultLocked }
            guard let idx = vaultData!.sshKeys.firstIndex(where: { $0.id == key.id }) else {
                throw PasswordManagerError.entryNotFound(key.id)
            }
            vaultData!.sshKeys[idx] = key
            try save()
        }
    }

    public func allSSHKeys() throws -> [SSHKeyEntry] {
        try stateLock.withLock {
            guard let data = vaultData else { throw PasswordManagerError.vaultLocked }
            return data.sshKeys
        }
    }

    public func allItems() throws -> [VaultItem] {
        try stateLock.withLock {
            guard let data = vaultData else { throw PasswordManagerError.vaultLocked }
            return data.allItems
        }
    }

    // MARK: - Persistence

    private func save() throws {
        guard let data = vaultData, let key = vaultKey, let meta = vaultFileMetadata else {
            throw PasswordManagerError.vaultLocked
        }

        let encoded = try JSONEncoder().encode(data)
        let encrypted = try CryptoEngine.encrypt(encoded, using: key)

        let hmac = CryptoEngine.computeMetadataHMAC(
            vaultKey: key,
            metadata: try meta.metadata.canonicalBytes()
        )

        let updatedFile = VaultFile(
            version: meta.version,
            salt: meta.salt,
            kdfMemory: meta.kdfMemory,
            kdfIterations: meta.kdfIterations,
            kdfParallelism: meta.kdfParallelism,
            mlkemPublicKey: meta.mlkemPublicKey,
            encryptedMLKEMPrivateKey: meta.encryptedMLKEMPrivateKey,
            encapsulatedKey: meta.encapsulatedKey,
            encryptedEntries: encrypted,
            metadataHMAC: hmac,
            recoverySalt: meta.recoverySalt,
            recoveryKdfMemory: meta.recoveryKdfMemory,
            recoveryKdfIterations: meta.recoveryKdfIterations,
            recoveryKdfParallelism: meta.recoveryKdfParallelism,
            encryptedMLKEMPrivateKeyRecovery: meta.encryptedMLKEMPrivateKeyRecovery
        )

        try writeVaultFile(updatedFile)
        self.vaultFileMetadata = updatedFile
    }

    // MARK: - File I/O

    // Atomically creates the file with 0600 permissions. Returns false if it exists.
    private func exclusiveCreate(at url: URL) -> Bool {
        let fd = open(url.path, O_CREAT | O_EXCL | O_WRONLY, 0o600)
        guard fd >= 0 else { return false }
        close(fd)
        return true
    }

    private func writeVaultFile(_ file: VaultFile) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let encoded = try encoder.encode(file)

        // Write to temp file with restricted permissions, then atomic rename
        let tempURL = fileURL.appendingPathExtension("tmp")
        FileManager.default.createFile(
            atPath: tempURL.path,
            contents: encoded,
            attributes: [.posixPermissions: 0o600]
        )
        try FileManager.default.replaceItem(
            at: fileURL,
            withItemAt: tempURL,
            backupItemName: nil,
            resultingItemURL: nil
        )
    }

    private func readVaultFile() throws -> VaultFile {
        guard Self.vaultExists(at: fileURL) else {
            throw PasswordManagerError.vaultNotFound
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(VaultFile.self, from: data)
    }
}
