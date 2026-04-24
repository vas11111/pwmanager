import Foundation
import CryptoKit

public struct BreachResult: Sendable {
    public let isBreached: Bool
    public let occurrences: Int
}

public actor BreachChecker {
    private var cache: [String: BreachResult] = [:]

    public init() {}

    /// Checks if a password has appeared in known data breaches using the
    /// Have I Been Pwned k-anonymity API. Only the first 5 characters of
    /// the SHA-1 hash are sent to the server — the full hash and password
    /// never leave the device.
    public func check(password: String) async -> BreachResult {
        let sha1 = Insecure.SHA1.hash(data: Data(password.utf8))
        let hex = sha1.map { String(format: "%02X", $0) }.joined()
        let prefix = String(hex.prefix(5))
        let suffix = String(hex.dropFirst(5))

        if let cached = cache[hex] { return cached }

        guard let url = URL(string: "https://api.pwnedpasswords.com/range/\(prefix)") else {
            return BreachResult(isBreached: false, occurrences: 0)
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("PWManager", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let body = String(data: data, encoding: .utf8) else {
                return BreachResult(isBreached: false, occurrences: 0)
            }

            // Response format: SUFFIX:COUNT\r\n per line
            for line in body.components(separatedBy: "\r\n") {
                let parts = line.split(separator: ":")
                guard parts.count == 2 else { continue }
                if parts[0].uppercased() == suffix {
                    let count = Int(parts[1]) ?? 0
                    let result = BreachResult(isBreached: true, occurrences: count)
                    cache[hex] = result
                    return result
                }
            }

            let result = BreachResult(isBreached: false, occurrences: 0)
            cache[hex] = result
            return result
        } catch {
            return BreachResult(isBreached: false, occurrences: 0)
        }
    }

    public func clearCache() {
        cache = [:]
    }
}
