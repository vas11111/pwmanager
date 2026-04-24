import Foundation

// MARK: - History

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

// MARK: - Login Entry

public struct LoginEntry: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var siteName: String
    public var username: String
    public var password: String
    public var url: String?
    public var notes: String?
    public var totpSecret: String?
    public var recoveryCode: String?
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
        recoveryCode: String? = nil,
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
        self.recoveryCode = recoveryCode
        self.history = history
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public mutating func updatePassword(_ newPassword: String) {
        if !password.isEmpty && newPassword != password {
            history.insert(HistoryRecord(password: password), at: 0)
            if history.count > 20 { history = Array(history.prefix(20)) }
        }
        password = newPassword
        modifiedAt = Date()
    }
}

// MARK: - SSH Key Entry

public struct SSHKeyEntry: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var privateKeyData: Data
    public var comment: String
    public var notes: String?
    public let createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        privateKeyData: Data,
        comment: String = "",
        notes: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.privateKeyData = privateKeyData
        self.comment = comment.isEmpty ? name : comment
        self.notes = notes
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

// MARK: - Vault Item (tagged union)

public enum VaultItem: Codable, Identifiable, Sendable, Equatable {
    case login(LoginEntry)
    case sshKey(SSHKeyEntry)

    public var id: UUID {
        switch self {
        case .login(let e): return e.id
        case .sshKey(let e): return e.id
        }
    }

    public var displayName: String {
        switch self {
        case .login(let e): return e.siteName
        case .sshKey(let e): return e.name
        }
    }

    public var subtitle: String {
        switch self {
        case .login(let e): return e.username
        case .sshKey(let e): return e.comment
        }
    }

    public var createdAt: Date {
        switch self {
        case .login(let e): return e.createdAt
        case .sshKey(let e): return e.createdAt
        }
    }

    public var modifiedAt: Date {
        switch self {
        case .login(let e): return e.modifiedAt
        case .sshKey(let e): return e.modifiedAt
        }
    }

    public var isLogin: Bool {
        if case .login = self { return true }
        return false
    }

    public var isSSHKey: Bool {
        if case .sshKey = self { return true }
        return false
    }

    public var asLogin: LoginEntry? {
        if case .login(let e) = self { return e }
        return nil
    }

    public var asSSHKey: SSHKeyEntry? {
        if case .sshKey(let e) = self { return e }
        return nil
    }
}

// MARK: - Backward Compatibility

public typealias PasswordEntry = LoginEntry
