import Foundation

struct BackupFile: Identifiable, Hashable {
    var id: String { url.path }
    var url: URL
    var name: String
    var sizeBytes: Int
    var createdAt: Date
}

/// On-device snapshot — the practical always-available backup destination.
/// Primary format is a raw SQLite file copy (per docs/DESIGN.md), visible
/// under Files app "On My iPhone" via `UIFileSharingEnabled` (Info.plist,
/// still pending — see IMPLEMENTATION_PLAN.md).
enum LocalBackupRepository {
    private static var backupsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    static func createSnapshot() throws -> URL {
        Database.shared.checkpoint()
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = backupsDirectory.appendingPathComponent("budgetsbronative-\(timestamp).db")
        try FileManager.default.copyItem(at: Database.storeURL, to: destination)
        return destination
    }

    static func list() -> [BackupFile] {
        let files = (try? FileManager.default.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])) ?? []
        return files
            .filter { $0.pathExtension == "db" }
            .compactMap { url -> BackupFile? in
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                return BackupFile(
                    url: url,
                    name: url.lastPathComponent,
                    sizeBytes: values?.fileSize ?? 0,
                    createdAt: values?.creationDate ?? Date()
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func restore(from url: URL) throws {
        let data = try Data(contentsOf: url)
        try Database.shared.replaceStore(with: data)
    }

    static func delete(_ file: BackupFile) throws {
        try FileManager.default.removeItem(at: file.url)
    }
}
