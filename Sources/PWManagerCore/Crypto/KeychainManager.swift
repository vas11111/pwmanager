import Foundation
import Security

public enum KeychainError: Error, Sendable {
    case unableToStore(OSStatus)
    case unableToRetrieve(OSStatus)
    case deviceKeyNotFound
    case unableToDelete(OSStatus)
}

public struct KeychainManager: Sendable {
    let service: String
    let account: String

    static let deviceKeyLength = 32

    public init(
        service: String = "com.pwmanager",
        account: String = "device-key"
    ) {
        self.service = service
        self.account = account
    }

    func storeDeviceKey(_ key: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore(status)
        }
    }

    func retrieveDeviceKey() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                throw KeychainError.deviceKeyNotFound
            }
            throw KeychainError.unableToRetrieve(status)
        }

        return data
    }

    func generateAndStoreDeviceKey() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: Self.deviceKeyLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, Self.deviceKeyLength, &bytes)
        precondition(status == errSecSuccess, "System RNG failure")
        let key = Data(bytes)
        try storeDeviceKey(key)
        return key
    }

    func deviceKeyExists() -> Bool {
        (try? retrieveDeviceKey()) != nil
    }

    func deleteDeviceKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete(status)
        }
    }
}
