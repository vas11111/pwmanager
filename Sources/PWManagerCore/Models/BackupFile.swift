import Foundation

struct BackupMetadata: Codable, Sendable {
    let version: Int
    let createdAt: Date
    let salt: Data
    let kdfMemory: Int
    let kdfIterations: Int
    let kdfParallelism: Int
    let mlkemPublicKey: Data
    let mlkemCiphertext: Data

    func canonicalBytes() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

public struct BackupFile: Codable, Sendable {
    public static let currentVersion = 1

    let version: Int
    let createdAt: Date
    let salt: Data
    let kdfMemory: Int
    let kdfIterations: Int
    let kdfParallelism: Int
    let mlkemPublicKey: Data
    let mlkemCiphertext: Data
    let encryptedMLKEMPrivateKey: Data
    let encryptedEntries: Data
    let metadataHMAC: Data

    var metadata: BackupMetadata {
        BackupMetadata(
            version: version,
            createdAt: createdAt,
            salt: salt,
            kdfMemory: kdfMemory,
            kdfIterations: kdfIterations,
            kdfParallelism: kdfParallelism,
            mlkemPublicKey: mlkemPublicKey,
            mlkemCiphertext: mlkemCiphertext
        )
    }
}
