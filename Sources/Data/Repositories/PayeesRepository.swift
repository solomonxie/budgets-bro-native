import Foundation

final class PayeesRepository {
    private let database: Database
    init(database: Database = .shared) { self.database = database }

    private var boardId: Int { BoardContext.shared.currentBoardId }

    func all() -> [Payee] {
        database.query("SELECT id, name FROM payees WHERE board_id = ? ORDER BY name", [boardId], row: { Payee(id: $0.int(0), name: $0.text(1) ?? "") })
    }

    /// Match-or-create by name, scoped to the active board — the same
    /// pattern the original's YNAB importer and transaction form use for a
    /// free-typed payee.
    @discardableResult
    func ensure(name: String) -> Int {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = database.query("SELECT id FROM payees WHERE name = ? AND board_id = ?", [trimmed, boardId], row: { $0.int(0) }).first {
            return existing
        }
        return Int(database.run("INSERT INTO payees (name, board_id) VALUES (?, ?)", [trimmed, boardId]))
    }

    func rename(id: Int, to name: String) {
        database.run("UPDATE payees SET name = ? WHERE id = ?", [name, id])
    }
}
