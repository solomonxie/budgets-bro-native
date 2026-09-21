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

    /// Runs an INSERT/UPDATE/DELETE, returns the last inserted rowid, and
    /// broadcasts `.boardDidChange` — the "every write bumps a version"
    /// invalidation rule from docs/DESIGN.md#size-and-speed-budget, done
    /// here once instead of at every call site.
    @discardableResult
    func run(_ sql: String, _ params: [Any?] = []) -> Int64 {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            assertionFailure("SQL prepare error: \(lastError) — statement: \(sql)")
            return 0
        }
        defer { sqlite3_finalize(statement) }
        bind(params, to: statement)
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            assertionFailure("SQL step error: \(lastError) — statement: \(sql)")
            return 0
        }
        NotificationCenter.default.post(name: .boardDidChange, object: nil)
        return sqlite3_last_insert_rowid(handle)
    }

    /// Runs a SELECT and maps each row via `row`.
    func query<T>(_ sql: String, _ params: [Any?] = [], row: (Row) -> T) -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            assertionFailure("SQL prepare error: \(lastError) — statement: \(sql)")
            return []
        }
        defer { sqlite3_finalize(statement) }
        bind(params, to: statement)
        var results: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(row(Row(statement: statement)))
        }
        return results
    }

    private var lastError: String {
        String(cString: sqlite3_errmsg(handle))
    }

    private func bind(_ params: [Any?], to statement: OpaquePointer?) {
        for (offset, param) in params.enumerated() {
            let index = Int32(offset + 1)
            guard let param else {
                sqlite3_bind_null(statement, index)
                continue
            }
            switch param {
            case let value as Int:
                sqlite3_bind_int64(statement, index, Int64(value))
            case let value as Int64:
                sqlite3_bind_int64(statement, index, value)
            case let value as Bool:
                sqlite3_bind_int64(statement, index, value ? 1 : 0)
            case let value as Double:
                sqlite3_bind_double(statement, index, value)
            case let value as String:
                sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
            default:
                assertionFailure("Unsupported bind type: \(type(of: param))")
            }
        }
    }
}

/// Column accessors for one row of a `Database.query` result.
struct Row {
    fileprivate let statement: OpaquePointer?

    func int(_ index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }

    func double(_ index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }

    func text(_ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }

    func isNull(_ index: Int32) -> Bool {
        sqlite3_column_type(statement, index) == SQLITE_NULL
    }
}

/// `sqlite3_destructor_type`'s `SQLITE_TRANSIENT` value (-1) isn't imported
/// as a symbol from the C header — this is the standard Swift equivalent.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension Notification.Name {
    static let boardDidChange = Notification.Name("boardDidChange")
}

/// Runs each not-yet-applied migration in `Migrator.migrations`, in order,
/// tracked by `PRAGMA user_version` — no framework provides this for free
/// on any platform, so it's hand-rolled here same as the original.
enum Migrator {
    static let migrations: [(version: Int32, sql: String)] = [
        (1, Migration001CreateCoreSchema.sql),
        (2, Migration002AddBudgetEntriesUniqueIndex.sql),
    ]

    static func run(on database: Database) {
        let currentVersion = database.userVersion
        for migration in migrations where migration.version > currentVersion {
            database.exec(migration.sql)
            database.userVersion = migration.version
        }
    }
}
