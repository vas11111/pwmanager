import Foundation

public struct HistoryRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let password: String
    public let changedAt: Date

    public init(password: String, changedAt: Date = Date()) {
        self.id = UUID()
        self.password = password
        self.changedAt = changedAt
    }
}

public struct PasswordEntry: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var siteName: String
    public var username: String
    public var password: String
    public var url: String?
    public var notes: String?
    public var totpSecret: String?
    public var sshKeyData: Data?
    public var history: [HistoryRecord]
    public let createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        siteName: String,
        username: String,
        password: String,
        url: String? = nil,
        notes: String? = nil,
        totpSecret: String? = nil,
        sshKeyData: Data? = nil,
        history: [HistoryRecord] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.siteName = siteName
        self.username = username
        self.password = password
        self.url = url
        self.notes = notes
        self.totpSecret = totpSecret
        self.sshKeyData = sshKeyData
        self.history = history
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public mutating func updatePassword(_ newPassword: String) {
        if !password.isEmpty && newPassword != password {
            history.insert(HistoryRecord(password: password), at: 0)
            // Keep last 20 entries
            if history.count > 20 { history = Array(history.prefix(20)) }
        }
        password = newPassword
        modifiedAt = Date()
    }
}
