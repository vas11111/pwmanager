import Foundation
import CryptoKit

// MARK: - SSH Agent Protocol Constants

private enum AgentMessage: UInt8 {
    case failure = 5
    case requestIdentities = 11
    case identitiesAnswer = 12
    case signRequest = 13
    case signResponse = 14
}

// MARK: - SSH Key Helper

public struct SSHKey: Sendable {
    public let privateKey: Curve25519.Signing.PrivateKey
    public let comment: String
    public let entryID: UUID

    public var publicKeyBlob: Data {
        var blob = Data()
        blob.appendSSHString("ssh-ed25519")
        blob.appendSSHString(privateKey.publicKey.rawRepresentation)
        return blob
    }

    public var authorizedKeysLine: String {
        let blob = publicKeyBlob
        return "ssh-ed25519 \(blob.base64EncodedString()) \(comment)"
    }

    public init(privateKey: Curve25519.Signing.PrivateKey, comment: String, entryID: UUID) {
        self.privateKey = privateKey
        self.comment = comment
        self.entryID = entryID
    }

    public init?(seed: Data, comment: String, entryID: UUID) {
        guard seed.count == 32 else { return nil }
        do {
            let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
            self.init(privateKey: key, comment: comment, entryID: entryID)
        } catch {
            return nil
        }
    }
}

// MARK: - SSH Agent Server

public final class SSHAgentServer: @unchecked Sendable {
    private let socketPath: String
    private var serverFD: Int32 = -1
    private var dispatchSource: DispatchSourceRead?
    private var clientSources: [Int32: DispatchSourceRead] = [:]
    private let queue = DispatchQueue(label: "com.pwmanager.ssh-agent", qos: .userInitiated)
    private let lock = NSLock()

    // Thread-safe key snapshot — updated on main actor, read on agent queue
    private var keySnapshot: [SSHKey] = []
    private let snapshotLock = NSLock()

    public var onSignRequest: (@Sendable (SSHKey, Data) -> Void)?

    public init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".pwmanager", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        self.socketPath = dir.appendingPathComponent("agent.sock").path
    }

    public var socketURL: String { socketPath }

    public func updateKeys(_ keys: [SSHKey]) {
        snapshotLock.withLock { keySnapshot = keys }
    }

    private func currentKeys() -> [SSHKey] {
        snapshotLock.withLock { keySnapshot }
    }

    public func start() throws {
        stop()

        unlink(socketPath)

        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SSHAgentError.socketCreationFailed }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            Darwin.close(fd)
            throw SSHAgentError.pathTooLong
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for i in 0..<pathBytes.count { dest[i] = pathBytes[i] }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(fd)
            throw SSHAgentError.bindFailed
        }

        // Verify we own the socket (not a symlink)
        var stat = Darwin.stat()
        guard lstat(socketPath, &stat) == 0,
              (stat.st_mode & S_IFMT) == S_IFSOCK else {
            unlink(socketPath)
            Darwin.close(fd)
            throw SSHAgentError.bindFailed
        }

        chmod(socketPath, 0o600)

        guard Darwin.listen(fd, 5) == 0 else {
            Darwin.close(fd)
            throw SSHAgentError.listenFailed
        }

        serverFD = fd

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptClient()
        }
        source.setCancelHandler {
            Darwin.close(fd)
        }
        source.resume()
        dispatchSource = source
    }

    public func stop() {
        lock.withLock {
            for (_, source) in clientSources {
                source.cancel()
            }
            clientSources.removeAll()
        }
        dispatchSource?.cancel()
        dispatchSource = nil
        if serverFD >= 0 {
            serverFD = -1
        }
        // Drain the queue to ensure no in-flight handlers use stale keys
        queue.sync {}
        snapshotLock.withLock { keySnapshot = [] }
        unlink(socketPath)
    }

    deinit {
        stop()
    }

    // MARK: - Connection Handling

    private func acceptClient() {
        let clientFD = Darwin.accept(serverFD, nil, nil)
        guard clientFD >= 0 else { return }

        let source = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: queue)
        source.setEventHandler { [weak self] in
            self?.handleClientData(fd: clientFD)
        }
        source.setCancelHandler {
            Darwin.close(clientFD)
        }
        source.resume()

        lock.withLock {
            clientSources[clientFD] = source
        }
    }

    private func handleClientData(fd: Int32) {
        var lengthBuf = [UInt8](repeating: 0, count: 4)
        let bytesRead = Darwin.read(fd, &lengthBuf, 4)
        guard bytesRead == 4 else {
            removeClient(fd: fd)
            return
        }

        let length = Int(UInt32(lengthBuf[0]) << 24 | UInt32(lengthBuf[1]) << 16
                         | UInt32(lengthBuf[2]) << 8 | UInt32(lengthBuf[3]))
        guard length > 0, length < 256 * 1024 else {
            removeClient(fd: fd)
            return
        }

        var payload = [UInt8](repeating: 0, count: length)
        var totalRead = 0
        while totalRead < length {
            let remaining = length - totalRead
            let n = payload.withUnsafeMutableBufferPointer { buf in
                Darwin.read(fd, buf.baseAddress! + totalRead, remaining)
            }
            guard n > 0 else { removeClient(fd: fd); return }
            totalRead += n
        }

        guard let msgType = AgentMessage(rawValue: payload[0]) else {
            sendFailure(fd: fd)
            return
        }

        let messageData = Data(payload.dropFirst())

        switch msgType {
        case .requestIdentities:
            handleRequestIdentities(fd: fd)
        case .signRequest:
            handleSignRequest(fd: fd, data: messageData)
        default:
            sendFailure(fd: fd)
        }
    }

    // MARK: - Protocol Handlers

    private func handleRequestIdentities(fd: Int32) {
        let keys = currentKeys()
        var response = Data()
        response.append(AgentMessage.identitiesAnswer.rawValue)
        response.appendUInt32(UInt32(keys.count))
        for key in keys {
            response.appendSSHString(key.publicKeyBlob)
            response.appendSSHString(key.comment)
        }
        sendMessage(fd: fd, data: response)
    }

    private func handleSignRequest(fd: Int32, data: Data) {
        var reader = DataReader(data)
        guard let keyBlob = reader.readSSHString(),
              let signData = reader.readSSHString() else {
            sendFailure(fd: fd)
            return
        }

        let keys = currentKeys()
        guard let key = keys.first(where: { $0.publicKeyBlob == keyBlob }) else {
            sendFailure(fd: fd)
            return
        }

        do {
            let signature = try key.privateKey.signature(for: signData)
            var sigBlob = Data()
            sigBlob.appendSSHString("ssh-ed25519")
            sigBlob.appendSSHString(signature)

            var response = Data()
            response.append(AgentMessage.signResponse.rawValue)
            response.appendSSHString(sigBlob)
            sendMessage(fd: fd, data: response)

            onSignRequest?(key, signData)
        } catch {
            sendFailure(fd: fd)
        }
    }

    // MARK: - I/O

    private func sendMessage(fd: Int32, data: Data) {
        var frame = Data()
        frame.appendUInt32(UInt32(data.count))
        frame.append(data)
        frame.withUnsafeBytes { ptr in
            _ = Darwin.write(fd, ptr.baseAddress!, frame.count)
        }
    }

    private func sendFailure(fd: Int32) {
        sendMessage(fd: fd, data: Data([AgentMessage.failure.rawValue]))
    }

    private func removeClient(fd: Int32) {
        lock.withLock {
            if let source = clientSources.removeValue(forKey: fd) {
                source.cancel()
            }
        }
    }
}

// MARK: - Errors

public enum SSHAgentError: Error, Sendable {
    case socketCreationFailed
    case pathTooLong
    case bindFailed
    case listenFailed
}

// MARK: - Data Helpers

private extension Data {
    mutating func appendSSHString(_ value: String) {
        let bytes = Data(value.utf8)
        appendUInt32(UInt32(bytes.count))
        append(bytes)
    }

    mutating func appendSSHString(_ value: Data) {
        appendUInt32(UInt32(value.count))
        append(value)
    }

    mutating func appendUInt32(_ value: UInt32) {
        var v = value.bigEndian
        append(Data(bytes: &v, count: 4))
    }
}

private struct DataReader {
    private let data: Data
    private var offset: Int = 0

    init(_ data: Data) { self.data = data }

    mutating func readUInt32() -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        let value = UInt32(data[offset]) << 24 | UInt32(data[offset+1]) << 16
                  | UInt32(data[offset+2]) << 8 | UInt32(data[offset+3])
        offset += 4
        return value
    }

    mutating func readSSHString() -> Data? {
        guard let length = readUInt32() else { return nil }
        let len = Int(length)
        guard offset + len <= data.count else { return nil }
        let result = data[offset..<offset+len]
        offset += len
        return Data(result)
    }
}
