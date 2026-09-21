import Foundation

/// Export of the raw SQLite file into the app's own iCloud container — the
/// user's own account/quota, nothing through a server of ours. Needs the
/// iCloud container entitlement + a paid Apple Developer account before
/// `containerURL` resolves to non-nil on a real device; see
/// IMPLEMENTATION_PLAN.md T0.2 (still pending) and docs/DESIGN.md.
enum ICloudBackupRepository {
    enum ICloudError: LocalizedError {
        case unavailable
        var errorDescription: String? {
            "iCloud isn't available — sign in to iCloud on this device, and (for this app specifically) the iCloud container entitlement needs to be provisioned first."
        }
    }

    private static var backupsDirectory: URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let dir = container.appendingPathComponent("Documents/Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var isAvailable: Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }

    @discardableResult
    static func createSnapshot() throws -> URL {
        guard let dir = backupsDirectory else { throw ICloudError.unavailable }
        Database.shared.checkpoint()
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = dir.appendingPathComponent("budgetsbronative-\(timestamp).db")
        try FileManager.default.copyItem(at: Database.storeURL, to: destination)
        return destination
    }

    static func list() -> [BackupFile] {
        guard let dir = backupsDirectory else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])) ?? []
        return files
            .filter { $0.pathExtension == "db" }
            .compactMap { url -> BackupFile? in
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                return BackupFile(url: url, name: url.lastPathComponent, sizeBytes: values?.fileSize ?? 0, createdAt: values?.creationDate ?? Date())
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func restore(from url: URL) throws {
        let data = try Data(contentsOf: url)
        try Database.shared.replaceStore(with: data)
    }
}
