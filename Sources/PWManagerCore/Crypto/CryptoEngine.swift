import Foundation
import CryptoKit
@preconcurrency import SwiftKyber

enum CryptoError: Error, Sendable {
    case encryptionFailed
    case decryptionFailed
    case invalidKeyData
    case metadataIntegrityFailure
}

struct CryptoEngine: Sendable {

    // SwiftKyber is not thread-safe — serialize all KEM operations
    private static let kyberLock = NSLock()

    // MARK: - AES-256-GCM

    static func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        return combined
    }

    static func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - ML-KEM-768 (Post-Quantum Key Encapsulation)

    struct MLKEMKeyPair: Sendable {
        let encapsulationKey: EncapsulationKey
        let decapsulationKey: DecapsulationKey
    }

    struct EncapsulationResult: Sendable {
        let sharedSecret: [UInt8]
        let ciphertext: [UInt8]
    }

    static func generateMLKEMKeyPair() -> MLKEMKeyPair {
        kyberLock.lock()
        defer { kyberLock.unlock() }
        let (encapKey, decapKey) = Kyber.GenerateKeyPair(kind: .K768)
        return MLKEMKeyPair(encapsulationKey: encapKey, decapsulationKey: decapKey)
    }

    static func encapsulate(publicKey: EncapsulationKey) -> EncapsulationResult {
        kyberLock.lock()
        defer { kyberLock.unlock() }
        let (sharedSecret, ciphertext) = publicKey.Encapsulate()
        return EncapsulationResult(sharedSecret: sharedSecret, ciphertext: ciphertext)
    }

    static func decapsulate(
        privateKey: DecapsulationKey,
        ciphertext: [UInt8]
    ) throws -> [UInt8] {
        kyberLock.lock()
        defer { kyberLock.unlock() }
        return try privateKey.Decapsulate(ct: ciphertext)
    }

    // MARK: - Key Combination

    static func combineMasterWithDeviceKey(
        masterKey: SymmetricKey,
        deviceKey: Data
    ) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            salt: deviceKey,
            info: Data("pwmanager-combined-key-v2".utf8),
            outputByteCount: 32
        )
    }

    // MARK: - Hybrid Key Derivation

    static func deriveVaultKey(
        masterKey: SymmetricKey,
        quantumSecret: [UInt8]
    ) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterKey,
            salt: Data(quantumSecret),
            info: Data("pwmanager-vault-key-v2".utf8),
            outputByteCount: 32
        )
    }

    // MARK: - Metadata HMAC

    static func computeMetadataHMAC(
        vaultKey: SymmetricKey,
        metadata: Data
    ) -> Data {
        let hmacKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: vaultKey,
            info: Data("pwmanager-metadata-hmac-v2".utf8),
            outputByteCount: 32
        )
        var hmac = HMAC<SHA256>(key: hmacKey)
        hmac.update(data: metadata)
        return Data(hmac.finalize())
    }

    static func verifyMetadataHMAC(
        vaultKey: SymmetricKey,
        metadata: Data,
        expectedHMAC: Data
    ) -> Bool {
        let hmacKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: vaultKey,
            info: Data("pwmanager-metadata-hmac-v2".utf8),
            outputByteCount: 32
        )
        // Constant-time comparison via CryptoKit
        return HMAC<SHA256>.isValidAuthenticationCode(
            expectedHMAC,
            authenticating: metadata,
            using: hmacKey
        )
    }
}
