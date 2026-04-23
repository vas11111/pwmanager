import Foundation

public struct PasswordGenerator: Sendable {
    public enum CharacterSet: Sendable {
        case lowercase
        case uppercase
        case digits
        case symbols

        var characters: String {
            switch self {
            case .lowercase: "abcdefghijklmnopqrstuvwxyz"
            case .uppercase: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            case .digits: "0123456789"
            case .symbols: "!@#$%^&*()-_=+[]{}|;:',.<>?/"
            }
        }
    }

    public static func generate(
        length: Int = 24,
        using sets: [CharacterSet] = [.lowercase, .uppercase, .digits, .symbols]
    ) -> String {
        let allChars = Array(sets.map(\.characters).joined())
        guard !allChars.isEmpty, length > 0 else { return "" }

        var result: [Character] = []

        // Guarantee at least one character from each set, up to the requested length
        for set in sets.prefix(length) {
            let setChars = Array(set.characters)
            result.append(setChars[uniformRandomIndex(below: setChars.count)])
        }

        while result.count < length {
            result.append(allChars[uniformRandomIndex(below: allChars.count)])
        }

        // Fisher-Yates shuffle
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            let j = uniformRandomIndex(below: i + 1)
            result.swapAt(i, j)
        }

        return String(result)
    }

    // Rejection sampling to eliminate modulo bias
    private static func uniformRandomIndex(below bound: Int) -> Int {
        precondition(bound > 0)
        let bound32 = UInt32(bound)
        let limit = UInt32.max - (UInt32.max % bound32)
        while true {
            var randomBytes = [UInt8](repeating: 0, count: 4)
            let status = SecRandomCopyBytes(kSecRandomDefault, 4, &randomBytes)
            precondition(status == errSecSuccess, "System RNG failure")
            let value = randomBytes.withUnsafeBytes { $0.load(as: UInt32.self) }
            if value < limit {
                return Int(value % bound32)
            }
        }
    }
}
