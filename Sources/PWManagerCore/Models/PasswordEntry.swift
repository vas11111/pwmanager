import Foundation

public struct PasswordEntry: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var siteName: String
    public var username: String
    public var password: String
    public var url: String?
    public var notes: String?
    public var totpSecret: String?
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
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
