@preconcurrency import Foundation
import LocalAuthentication
import Security
import os.log

private let bioLog = Logger(subsystem: "com.pwmanager.app", category: "biometric")

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
        if !isAvailable {
            let code = error?.code ?? 0
            let desc = error?.localizedDescription ?? "<no error>"
            let biometryType = context.biometryType.rawValue
            bioLog.error("Touch ID check failed: code=\(code) biometryType=\(biometryType) desc=\(desc)")
        } else {
            bioLog.info("Touch ID check passed: biometryType=\(context.biometryType.rawValue)")
        }
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

        // Ad-hoc signed apps cannot create Keychain items with biometric access
        // control flags (returns errSecMissingEntitlement = -34018). Instead we
        // store the item plainly and gate retrieval with an explicit LAContext
        // evaluatePolicy call — same UX, works without keychain-access-groups.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricError.storeFailed(status)
        }
    }

    func retrievePassword() async throws -> String {
        // 1. Require Touch ID before reading the stored PIN.
        let context = LAContext()
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your vault"
            )
            guard ok else { throw BiometricError.cancelled }
        } catch let err as LAError where err.code == .userCancel || err.code == .systemCancel || err.code == .appCancel {
            throw BiometricError.cancelled
        }

        // 2. Fetch from Keychain.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw BiometricError.retrieveFailed(status)
        }
        return password
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
