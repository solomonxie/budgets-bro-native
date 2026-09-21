import Foundation
import SQLite3

/// Thin wrapper over the system `libsqlite3` C API — no dependency, mirrors
/// budgets-bro's `src/db` role (open once, WAL, versioned migrations).
/// See docs/DESIGN.md#storage-backup-architecture.
final class Database {
    static let shared = Database()

    private let handle: OpaquePointer

    private init() {
        let url = Database.storeURL()
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            fatalError("Failed to open SQLite database at \(url.path)")
        }
        handle = db
        exec("PRAGMA journal_mode = WAL")
        exec("PRAGMA synchronous = NORMAL")
        exec("PRAGMA foreign_keys = ON")
        Migrator.run(on: self)
    }

    private static func storeURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("budgetsbronative.db")
    }

    @discardableResult
    func exec(_ sql: String) -> Bool {
        if sqlite3_exec(handle, sql, nil, nil, nil) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(handle))
            assertionFailure("SQL error: \(message) — statement: \(sql)")
            return false
        }
        return true
    }

    var userVersion: Int32 {
        get {
            var version: Int32 = 0
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(handle, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK else {
                return 0
            }
            defer { sqlite3_finalize(statement) }
            if sqlite3_step(statement) == SQLITE_ROW {
                version = sqlite3_column_int(statement, 0)
            }
            return version
        }
        set {
            exec("PRAGMA user_version = \(newValue)")
        }
    }
}

/// Runs each not-yet-applied migration in `Migrator.migrations`, in order,
/// tracked by `PRAGMA user_version` — no framework provides this for free
/// on any platform, so it's hand-rolled here same as the original.
enum Migrator {
    static let migrations: [(version: Int32, sql: String)] = [
        (1, Migration001CreateCoreSchema.sql),
    ]

    static func run(on database: Database) {
        let currentVersion = database.userVersion
        for migration in migrations where migration.version > currentVersion {
            database.exec(migration.sql)
            database.userVersion = migration.version
        }
    }
}
