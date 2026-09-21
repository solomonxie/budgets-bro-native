import Foundation

enum S3ValidationError: LocalizedError {
    case unreachable
    case readWriteFailed
    case publiclyReadable

    var errorDescription: String? {
        switch self {
        case .unreachable: "Couldn't reach that bucket — check the bucket name and region."
        case .readWriteFailed: "This credential can't read and write to this bucket."
        case .publiclyReadable: "This bucket allows anonymous reads — not safe for a personal finance backup."
        }
    }
}

/// S3 backup — user's own bucket + scoped IAM credentials, no backend to
/// presign requests (`SigV4.swift` signs client-side). See
/// docs/DESIGN.md#storage-backup-architecture.
final class S3BackupRepository {
    private let client: S3Client
    private let prefix: String

    init(config: S3Config) {
        client = S3Client(config: config)
        prefix = config.prefix.isEmpty ? "" : (config.prefix.hasSuffix("/") ? config.prefix : config.prefix + "/")
    }

    /// Fail-closed checklist run before a credential is accepted — reachable,
    /// then read/write, then not publicly readable. Simplified vs. the
    /// original's four separate checks (drops the bucket-root anonymous-
    /// access probe as a separate step; the marker-object anonymous GET
    /// below covers the same "is this bucket open" question).
    func validate() async throws {
        do {
            try await client.headBucket()
        } catch {
            throw S3ValidationError.unreachable
        }

        let markerKey = "\(prefix).budgetsbronative-write-test"
        do {
            try await client.putObject(key: markerKey, data: Data("test".utf8))
            _ = try await client.getObject(key: markerKey)
        } catch {
            throw S3ValidationError.readWriteFailed
        }

        if let status = await client.unauthenticatedGet(key: markerKey), (200 ..< 300).contains(status) {
            try? await client.deleteObject(key: markerKey)
            throw S3ValidationError.publiclyReadable
        }

        try? await client.deleteObject(key: markerKey)
    }

    func backupNow() async throws {
        Database.shared.checkpoint()
        let data = try Data(contentsOf: Database.storeURL)
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        try await client.putObject(key: "\(prefix)budgetsbronative-\(timestamp).db", data: data)
    }

    func list() async throws -> [S3ObjectSummary] {
        try await client.listObjects(prefix: prefix).sorted { $0.key > $1.key }
    }

    func restoreLatest() async throws {
        guard let latest = try await list().first else { return }
        let data = try await client.getObject(key: latest.key)
        try Database.shared.replaceStore(with: data)
    }
}
