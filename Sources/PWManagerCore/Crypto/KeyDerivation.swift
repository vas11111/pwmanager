import Foundation
import CryptoKit
import Argon2

enum KeyDerivationError: Error, Sendable {
    case passwordTooShort(minimum: Int)
}

public struct KDFParams: Sendable {
    public let memory: Int
    public let iterations: Int
    public let parallelism: Int

    public static let `default` = KDFParams(
        memory: 65_536,     // 64 MiB
        iterations: 3,
        parallelism: 4
    )

    public static let testing = KDFParams(
        memory: 256,        // 256 KiB — fast for tests
        iterations: 1,
        parallelism: 1
    )

    public static let minimumMemory = 256            // 256 KiB floor
    public static let minimumIterations = 1
    public static let minimumParallelism = 1
    public static let maximumMemory = 4_194_304     // 4 GiB ceiling
    public static let maximumIterations = 100
    public static let maximumParallelism = 16
}

struct KeyDerivation: Sendable {
    static let saltLength = 32
    static let keyLength = 32
    static let minimumPasswordLength = 8

    static func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: saltLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, saltLength, &bytes)
        precondition(status == errSecSuccess, "System RNG failure")
        return Data(bytes)
    }

    static func deriveKey(
        from password: String,
        salt: Data,
        params: KDFParams = .default
    ) throws -> SymmetricKey {
        let derived = try Argon2.hash(
            password: Data(password.utf8),
            salt: salt,
            iterations: params.iterations,
            memory: params.memory,
            parallelism: params.parallelism,
            outputLength: keyLength,
            variant: .id
        )
        return SymmetricKey(data: derived)
    }
}
