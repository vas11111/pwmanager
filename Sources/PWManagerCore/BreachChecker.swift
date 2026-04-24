import Foundation
import CryptoKit

public enum BreachStatus: Sendable {
    case breached(Int)
    case safe
    case unknown
}

public struct BreachResult: Sendable {
    public let status: BreachStatus

    public var isBreached: Bool {
        if case .breached = status { return true }
        return false
    }

    public var occurrences: Int {
        if case .breached(let count) = status { return count }
        return 0
    }

    public var isUnknown: Bool {
        if case .unknown = status { return true }
        return false
    }
}

public actor BreachChecker {
    private var cache: [String: BreachResult] = [:]
    private let cacheHMACKey = SymmetricKey(size: .bits256)

    public init() {}

    private func cacheKey(for hex: String) -> String {
        let mac = HMAC<SHA256>.authenticationCode(for: Data(hex.utf8), using: cacheHMACKey)
        return Data(mac).prefix(16).base64EncodedString()
    }

    /// Checks if a password has appeared in known data breaches using the
    /// Have I Been Pwned k-anonymity API. Only the first 5 characters of
    /// the SHA-1 hash are sent to the server — the full hash and password
    /// never leave the device.
    public func check(password: String) async -> BreachResult {
        let sha1 = Insecure.SHA1.hash(data: Data(password.utf8))
        let hex = sha1.map { String(format: "%02X", $0) }.joined()
        let prefix = String(hex.prefix(5))
        let suffix = String(hex.dropFirst(5))

        let cid = cacheKey(for: hex)
        if let cached = cache[cid] { return cached }

        guard let url = URL(string: "https://api.pwnedpasswords.com/range/\(prefix)") else {
            return BreachResult(status: .unknown)
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("PWManager", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let body = String(data: data, encoding: .utf8) else {
                return BreachResult(status: .unknown)
            }

            for line in body.components(separatedBy: "\r\n") {
                let parts = line.split(separator: ":")
                guard parts.count == 2 else { continue }
                if parts[0].uppercased() == suffix {
                    let count = Int(parts[1]) ?? 0
                    let result = BreachResult(status: .breached(count))
                    cache[cid] = result
                    return result
                }
            }

            let result = BreachResult(status: .safe)
            cache[cid] = result
            return result
        } catch {
            return BreachResult(status: .unknown)
        }
    }

    public func clearCache() {
        cache = [:]
    }
}
