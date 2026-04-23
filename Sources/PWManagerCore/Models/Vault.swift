import Foundation

struct VaultData: Codable, Sendable {
    var entries: [PasswordEntry]

    static let empty = VaultData(entries: [])
}

struct VaultMetadata: Codable, Sendable {
    let version: Int
    let salt: Data
    let kdfMemory: Int
    let kdfIterations: Int
    let kdfParallelism: Int
    let mlkemPublicKey: Data
    let encapsulatedKey: Data

    func canonicalBytes() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }
}

public struct VaultFile: Codable, Sendable {
    static let currentVersion = 2

    let version: Int
    let salt: Data
    let kdfMemory: Int
    let kdfIterations: Int
    let kdfParallelism: Int
    let mlkemPublicKey: Data
    let encryptedMLKEMPrivateKey: Data
    let encapsulatedKey: Data
    let encryptedEntries: Data
    let metadataHMAC: Data

    var metadata: VaultMetadata {
        VaultMetadata(
            version: version,
            salt: salt,
            kdfMemory: kdfMemory,
            kdfIterations: kdfIterations,
            kdfParallelism: kdfParallelism,
            mlkemPublicKey: mlkemPublicKey,
            encapsulatedKey: encapsulatedKey
        )
    }
}
