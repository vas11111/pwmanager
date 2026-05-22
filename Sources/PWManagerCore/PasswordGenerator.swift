import Foundation

public struct PasswordGenerator: Sendable {
    public enum CharacterSet: Sendable {
        case lowercase
        case uppercase
        case digits
        case symbols
        case customSymbols(String)

        public static let defaultSymbols = "!@#$%^&*()-_=+[]{}|;:',.<>?/"

        var characters: String {
            switch self {
            case .lowercase: return "abcdefghijklmnopqrstuvwxyz"
            case .uppercase: return "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            case .digits: return "0123456789"
            case .symbols: return Self.defaultSymbols
            case .customSymbols(let s):
                // De-duplicate while preserving order.
                var seen = Set<Character>()
                return s.filter { seen.insert($0).inserted }
            }
        }
    }

    public static func generate(
        length: Int = 24,
        using sets: [CharacterSet] = [.lowercase, .uppercase, .digits, .symbols]
    ) -> String {
        // Drop any empty sets (e.g. customSymbols("")) so the guarantee loop
        // doesn't try to pick from an empty alphabet.
        let activeSets = sets.filter { !$0.characters.isEmpty }
        let allChars = Array(activeSets.map(\.characters).joined())
        guard !allChars.isEmpty, length > 0 else { return "" }

        var result: [Character] = []

        // Guarantee at least one character from each set, up to the requested length
        for set in activeSets.prefix(length) {
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
