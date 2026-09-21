import Foundation

struct Board: Identifiable, Hashable {
    var id: Int
    var name: String
}

/// CRUD for `boards` — see budgets-bro's `boardsRepo.ts`. Deleting a board
/// wipes everything scoped to it; there's no archive/hide concept the way
/// accounts and categories have, since the point of deleting one is to
/// actually reclaim the space.
final class BoardsRepository {
    private let database: Database
    init(database: Database = .shared) { self.database = database }

    func all() -> [Board] {
        database.query("SELECT id, name FROM boards ORDER BY id", row: { Board(id: $0.int(0), name: $0.text(1) ?? "") })
    }

    @discardableResult
    func create(name: String) -> Int {
        Int(database.run("INSERT INTO boards (name) VALUES (?)", [name]))
    }

    func rename(id: Int, name: String) {
        database.run("UPDATE boards SET name = ? WHERE id = ?", [name, id])
    }

    /// A name that doesn't collide with an existing board — repeated
    /// "Create Demo Board" taps get "Demo 2", "Demo 3", ... rather than
    /// piling up several boards all named "Demo".
    func uniqueName(base: String) -> String {
        let existing = Set(all().map(\.name))
        guard existing.contains(base) else { return base }
        var n = 2
        while existing.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    func delete(id: Int) {
        database.run(
            """
            DELETE FROM transaction_splits WHERE transaction_id IN (SELECT id FROM transactions WHERE account_id IN (SELECT id FROM accounts WHERE board_id = ?))
            """,
            [id]
        )
        database.run("DELETE FROM scheduled_transactions WHERE board_id = ?", [id])
        database.run("DELETE FROM transactions WHERE account_id IN (SELECT id FROM accounts WHERE board_id = ?)", [id])
        database.run("DELETE FROM account_rate_history WHERE account_id IN (SELECT id FROM accounts WHERE board_id = ?)", [id])
        database.run("DELETE FROM account_value_history WHERE account_id IN (SELECT id FROM accounts WHERE board_id = ?)", [id])
        database.run(
            """
            DELETE FROM budget_entries WHERE category_id IN (
                SELECT c.id FROM categories c JOIN category_groups g ON g.id = c.group_id WHERE g.board_id = ?
            )
            """,
            [id]
        )
        database.run("DELETE FROM categories WHERE group_id IN (SELECT id FROM category_groups WHERE board_id = ?)", [id])
        database.run("DELETE FROM category_groups WHERE board_id = ?", [id])
        database.run("DELETE FROM payees WHERE board_id = ?", [id])
        database.run("DELETE FROM accounts WHERE board_id = ?", [id])
        database.run("DELETE FROM boards WHERE id = ?", [id])
    }
}

/// The active board — every repository reads `BoardContext.shared.currentBoardId`
/// to scope its queries. Persisted so the right board is showing again next
/// launch, same as `useBootstrapActiveBoard`.
@Observable
final class BoardContext {
    static let shared = BoardContext()

    private let settings = AppSettingsRepository()
    private let boardsRepo = BoardsRepository()

    var currentBoardId: Int {
        didSet {
            guard oldValue != currentBoardId else { return }
            settings.set("active_board_id", String(currentBoardId))
            NotificationCenter.default.post(name: .boardDidChange, object: nil)
        }
    }

    private init() {
        if let saved = settings.get("active_board_id"), let id = Int(saved) {
            currentBoardId = id
        } else {
            currentBoardId = boardsRepo.all().first?.id ?? 1
        }
    }
}
