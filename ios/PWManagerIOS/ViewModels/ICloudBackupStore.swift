import Foundation

/// Lists, reads, and writes `.pwmbackup` files in the app's iCloud Drive
/// container. The container is visible to the user as a "PWManager" folder
/// in the Files app under iCloud Drive, so backups saved here automatically
/// sync to all of the user's signed-in Apple devices.
@MainActor
@Observable
final class ICloudBackupStore {
    private(set) var backups: [BackupFile] = []
    private(set) var isAvailable: Bool = false
    private(set) var lastError: String?

    struct BackupFile: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        let name: String
        let modifiedAt: Date
        let size: Int64
    }

    /// Returns the app's iCloud Drive Documents directory, creating it if
    /// needed. Returns nil if iCloud Drive is not available (user not signed
    /// in or feature disabled in Settings).
    func containerURL() -> URL? {
        let ubiquity = FileManager.default.url(forUbiquityContainerIdentifier: nil)
        guard let root = ubiquity else { return nil }
        let docs = root.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        return docs
    }

    func refresh() {
        guard let docs = containerURL() else {
            isAvailable = false
            backups = []
            return
        }
        isAvailable = true
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: docs,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            backups = urls
                .filter { $0.pathExtension.lowercased() == "pwmbackup" }
                .compactMap { url -> BackupFile? in
                    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                    return BackupFile(
                        url: url,
                        name: url.lastPathComponent,
                        modifiedAt: values?.contentModificationDate ?? Date(),
                        size: Int64(values?.fileSize ?? 0)
                    )
                }
                .sorted { $0.modifiedAt > $1.modifiedAt }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            backups = []
        }
    }

    /// Triggers a download for a backup that's in iCloud but not yet on
    /// the local device.
    func ensureDownloaded(_ backup: BackupFile) async throws -> Data {
        // Start a download if needed.
        try? FileManager.default.startDownloadingUbiquitousItem(at: backup.url)

        // Wait up to 30s for the file to be downloaded.
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            let values = try backup.url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if values.ubiquitousItemDownloadingStatus == .current {
                return try Data(contentsOf: backup.url)
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        // Final attempt — may succeed if the file was already local.
        return try Data(contentsOf: backup.url)
    }

    func writeBackup(data: Data, suggestedName: String) throws -> URL {
        guard let docs = containerURL() else {
            throw NSError(domain: "ICloudBackupStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "iCloud Drive is not available. Enable iCloud Drive in Settings → Apple ID → iCloud."
            ])
        }
        let url = docs.appendingPathComponent(suggestedName)
        try data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        refresh()
        return url
    }

    func delete(_ backup: BackupFile) {
        try? FileManager.default.removeItem(at: backup.url)
        refresh()
    }
}
