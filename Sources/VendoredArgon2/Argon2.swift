//
//  Argon2.swift
//  swift-argon2
//
//  Thin Swift wrapper over the phc-winner-argon2 C reference implementation.
//  See Sources/CArgon2/VENDORED.md for upstream commit and licence details.
//

import Foundation
import CArgon2

/// Argon2 password hashing and key derivation.
///
/// Use ``hash(password:salt:iterations:memory:parallelism:outputLength:variant:)``
/// to derive a fixed-length key from a password. The function is **synchronous
/// and CPU-intensive** — always call it from a background thread:
///
/// ```swift
/// let key = try await Task.detached(priority: .userInitiated) {
///     try Argon2.hash(
///         password: Data("secret".utf8),
///         salt: saltData,
///         iterations: 3,
///         memory: 524_288,   // 512 MiB
///         parallelism: 4,
///         outputLength: 32,
///         variant: .id
///     )
/// }.value
/// ```
public enum Argon2 {

    // MARK: - Variant

    /// Argon2 algorithm variant.
    public enum Variant {
        /// Argon2d — data-dependent memory access; maximises GPU resistance.
        /// Not recommended for password hashing (vulnerable to side-channel attacks).
        case d
        /// Argon2i — data-independent memory access; side-channel resistant.
        /// Recommended when side-channel attacks are a concern.
        case i
        /// Argon2id — hybrid of Argon2d and Argon2i (recommended for most uses).
        /// Specified by RFC 9106 and OWASP as the default variant.
        case id
    }

    // MARK: - Error

    /// An error thrown when Argon2 hashing fails.
    public enum Error: Swift.Error, CustomStringConvertible {
        /// The C implementation returned a non-zero error code.
        case hashingFailed(code: Int32, message: String)

        public var description: String {
            switch self {
            case .hashingFailed(_, let message):
                return "Argon2 hashing failed: \(message)"
            }
        }
    }

    // MARK: - Hash

    /// Derives a fixed-length key from a password using Argon2.
    ///
    /// Output is byte-identical to Python `argon2.low_level.hash_secret_raw` at
    /// the same parameters, as both call the same C reference implementation.
    ///
    /// - Parameters:
    ///   - password:     Raw password bytes.
    ///   - salt:         Random salt. Minimum 8 bytes; 16–32 bytes recommended.
    ///   - iterations:   Time cost (t). Higher values increase computation time.
    ///                   Production recommendation: 3.
    ///   - memory:       Memory cost in KiB (m). Higher values increase memory usage.
    ///                   Production recommendation: 524_288 (512 MiB).
    ///   - parallelism:  Degree of parallelism (p). Should match available CPU threads.
    ///                   Production recommendation: 4.
    ///   - outputLength: Length of derived key in bytes. Default: 32.
    ///   - variant:      Argon2 variant. Default: `.id` (recommended).
    ///
    /// - Returns: Derived key as `Data` of length `outputLength`.
    /// - Throws:  ``Error/hashingFailed(code:message:)`` if the C implementation
    ///   returns a non-zero error code.
    ///
    /// - Important: This function is **synchronous and CPU-intensive**.
    ///   Call it from a background thread, not the main actor.
    public static func hash(
        password: Data,
        salt: Data,
        iterations: Int,
        memory: Int,
        parallelism: Int,
        outputLength: Int = 32,
        variant: Variant = .id
    ) throws -> Data {
        var output = [UInt8](repeating: 0, count: outputLength)

        let rc: Int32 = password.withUnsafeBytes { pwdBuf in
            salt.withUnsafeBytes { saltBuf in
                argon2_hash(
                    UInt32(iterations),
                    UInt32(memory),
                    UInt32(parallelism),
                    pwdBuf.baseAddress,  password.count,
                    saltBuf.baseAddress, salt.count,
                    &output,             outputLength,
                    nil,                 0,              // no encoded string output
                    variant.cType,
                    ARGON2_VERSION_13.rawValue
                )
            }
        }

        guard rc == ARGON2_OK.rawValue else {
            let message = String(cString: argon2_error_message(rc))
            throw Error.hashingFailed(code: rc, message: message)
        }

        return Data(output)
    }
}

// MARK: - Internal

extension Argon2.Variant {
    var cType: argon2_type {
        switch self {
        case .d:  return Argon2_d
        case .i:  return Argon2_i
        case .id: return Argon2_id
        }
    }
}
