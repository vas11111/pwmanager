import Foundation

public struct RecoveryKey: Sendable {
    public let raw: String

    public var formatted: String {
        stride(from: 0, to: raw.count, by: 4).map { i in
            let start = raw.index(raw.startIndex, offsetBy: i)
            let end = raw.index(start, offsetBy: min(4, raw.count - i))
            return String(raw[start..<end])
        }.joined(separator: "-")
    }

    public init() {
        var bytes = [UInt8](repeating: 0, count: 20)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "System RNG failure")

        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        raw = bytes.map { byte in
            let idx = Int(byte) % alphabet.count
            return alphabet[alphabet.index(alphabet.startIndex, offsetBy: idx)]
        }.map(String.init).joined()
    }

    public init(raw: String) {
        self.raw = raw.uppercased().filter { $0 != "-" && $0 != " " }
    }

    public static func isValid(_ input: String) -> Bool {
        let cleaned = input.uppercased().filter { $0 != "-" && $0 != " " }
        return cleaned.count == 20 && cleaned.allSatisfy { "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains($0) }
    }
}
