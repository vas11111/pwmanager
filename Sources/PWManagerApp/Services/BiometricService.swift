@preconcurrency import Foundation
import LocalAuthentication
import Security

@MainActor
@Observable
final class BiometricService {
    private(set) var isAvailable = false

    private static let service = "com.pwmanager.biometric"
    private static let account = "master-password"

    func checkAvailability() {
        let context = LAContext()
        var error: NSError?
        isAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
    }

    var hasStoredPassword: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: false,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func storePassword(_ password: String) throws {
        try deleteStoredPassword()

        guard let data = password.data(using: .utf8) else { return }

        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        )

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecValueData as String: data,
        ]
        if let access { query[kSecAttrAccessControl as String] = access }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricError.storeFailed(status)
        }
    }

    func retrievePassword() async throws -> String {
        let context = LAContext()
        context.localizedReason = "Unlock your vault"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context,
        ]

        let cfQuery = query as CFDictionary
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var result: AnyObject?
                let status = SecItemCopyMatching(cfQuery, &result)

                if status == errSecSuccess, let data = result as? Data,
                   let password = String(data: data, encoding: .utf8)
                {
                    continuation.resume(returning: password)
                } else if status == errSecUserCanceled || status == errSecAuthFailed {
                    continuation.resume(throwing: BiometricError.cancelled)
                } else {
                    continuation.resume(throwing: BiometricError.retrieveFailed(status))
                }
            }
        }
    }

    func deleteStoredPassword() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw BiometricError.deleteFailed(status)
        }
    }
}

enum BiometricError: Error {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case cancelled
}
