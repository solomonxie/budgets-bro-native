import Foundation

/// Key-value store for non-secret app state (theme, active board, app-lock
/// mode) — never a secret; see docs/DESIGN.md#secrets-vs-backups.
final class AppSettingsRepository {
    private let database: Database
    init(database: Database = .shared) { self.database = database }

    func get(_ key: String) -> String? {
        database.query("SELECT value FROM app_settings WHERE key = ?", [key], row: { $0.text(0) }).first ?? nil
    }

    func set(_ key: String, _ value: String?) {
        database.run(
            "INSERT INTO app_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            [key, value]
        )
    }
}
