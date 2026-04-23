import Foundation
import CryptoKit

public struct TOTPGenerator: Sendable {
    public static let period: TimeInterval = 30
    public static let digits = 6

    public static func generateCode(secret: String, time: Date = Date()) -> String? {
        guard let keyData = base32Decode(secret) else { return nil }
        let counter = UInt64(time.timeIntervalSince1970 / period)
        return hotp(key: keyData, counter: counter)
    }

    public static func timeRemaining(time: Date = Date()) -> TimeInterval {
        let elapsed = time.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
        return period - elapsed
    }

    public static func progress(time: Date = Date()) -> Double {
        let elapsed = time.timeIntervalSince1970.truncatingRemainder(dividingBy: period)
        return elapsed / period
    }

    public static func isValidSecret(_ secret: String) -> Bool {
        base32Decode(secret) != nil
    }

    // MARK: - HOTP (RFC 4226)

    private static func hotp(key: Data, counter: UInt64) -> String {
        var bigEndianCounter = counter.bigEndian
        let counterData = Data(bytes: &bigEndianCounter, count: 8)

        let hmac = HMAC<Insecure.SHA1>.authenticationCode(
            for: counterData,
            using: SymmetricKey(data: key)
        )
        let hmacBytes = Array(hmac)

        let offset = Int(hmacBytes[hmacBytes.count - 1] & 0x0F)
        let truncated =
            (UInt32(hmacBytes[offset]) & 0x7F) << 24
            | UInt32(hmacBytes[offset + 1]) << 16
            | UInt32(hmacBytes[offset + 2]) << 8
            | UInt32(hmacBytes[offset + 3])

        let code = truncated % UInt32(pow(10, Double(digits)))
        return String(format: "%0\(digits)d", code)
    }

    // MARK: - Base32

    private static let base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    private static func base32Decode(_ input: String) -> Data? {
        let clean = input.uppercased().filter { $0 != "=" && $0 != " " && $0 != "-" }
        guard !clean.isEmpty else { return nil }

        let lookup: [Character: UInt8] = Dictionary(
            uniqueKeysWithValues: base32Alphabet.enumerated().map {
                (base32Alphabet[base32Alphabet.index(base32Alphabet.startIndex, offsetBy: $0.offset)], UInt8($0.offset))
            }
        )

        var bits = 0
        var accumulator: UInt64 = 0
        var output = Data()

        for char in clean {
            guard let value = lookup[char] else { return nil }
            accumulator = (accumulator << 5) | UInt64(value)
            bits += 5
            if bits >= 8 {
                bits -= 8
                output.append(UInt8((accumulator >> bits) & 0xFF))
            }
        }

        return output.isEmpty ? nil : output
    }
}
