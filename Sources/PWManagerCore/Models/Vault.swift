import Foundation

struct VaultData: Codable, Sendable {
    var entries: [LoginEntry]
    var sshKeys: [SSHKeyEntry]

    var allItems: [VaultItem] {
        entries.map { .login($0) } + sshKeys.map { .sshKey($0) }
    }

    static let empty = VaultData(entries: [], sshKeys: [])

    // Backward compatibility: decode vaults that only have "entries"
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entries = try container.decode([LoginEntry].self, forKey: .entries)
        sshKeys = try container.decodeIfPresent([SSHKeyEntry].self, forKey: .sshKeys) ?? []
    }

    init(entries: [LoginEntry], sshKeys: [SSHKeyEntry] = []) {
        self.entries = entries
        self.sshKeys = sshKeys
    }
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
