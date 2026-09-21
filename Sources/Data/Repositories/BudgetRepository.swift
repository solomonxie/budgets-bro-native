import Foundation

/// CRUD for `budget_entries` — one row per category per month, scoped to
/// the active board via a join through `categories`/`category_groups`
/// (`budget_entries` carries no `board_id` of its own). See
/// docs/DESIGN.md#core-domain-model for the rollover math this feeds.
final class BudgetRepository {
    private let database: Database
    init(database: Database = .shared) { self.database = database }

    private var boardId: Int { BoardContext.shared.currentBoardId }

    /// This month's assigned amount for every category in one query — avoids
    /// an N+1 fan-out on the Budget screen.
    func assignedCentsByCategory(month: String) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: database.query(
            """
            SELECT be.category_id, be.assigned_cents FROM budget_entries be
            JOIN categories c ON c.id = be.category_id
            JOIN category_groups g ON g.id = c.group_id
            WHERE g.board_id = ? AND be.month = ?
            """,
            [boardId, month],
            row: { ($0.int(0), $0.int(1)) }
        ))
    }

    func assignedCents(categoryId: Int, month: String) -> Int {
        database.query(
            "SELECT assigned_cents FROM budget_entries WHERE category_id = ? AND month = ?",
            [categoryId, month],
            row: { $0.int(0) }
        ).first ?? 0
    }

    /// All assigned amounts up to and including `month` — needed for a
    /// category's cumulative rollover balance and for Unassigned Cash,
    /// which counts every assignment ever made, future months included.
    func cumulativeAssignedCentsByCategory(throughMonth month: String) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: database.query(
            """
            SELECT be.category_id, SUM(be.assigned_cents) FROM budget_entries be
            JOIN categories c ON c.id = be.category_id
            JOIN category_groups g ON g.id = c.group_id
            WHERE g.board_id = ? AND be.month <= ?
            GROUP BY be.category_id
            """,
            [boardId, month],
            row: { ($0.int(0), $0.int(1)) }
        ))
    }

    /// Every assignment ever made, any month — see
    /// docs/DESIGN.md#core-domain-model's Unassigned Cash definition.
    func totalAssignedCentsAllTime() -> Int {
        database.query(
            """
            SELECT COALESCE(SUM(be.assigned_cents), 0) FROM budget_entries be
            JOIN categories c ON c.id = be.category_id
            JOIN category_groups g ON g.id = c.group_id
            WHERE g.board_id = ?
            """,
            [boardId],
            row: { $0.int(0) }
        ).first ?? 0
    }

    func setAssigned(categoryId: Int, month: String, cents: Int) {
        database.run(
            """
            INSERT INTO budget_entries (category_id, month, assigned_cents) VALUES (?, ?, ?)
            ON CONFLICT(category_id, month) DO UPDATE SET assigned_cents = excluded.assigned_cents
            """,
            [categoryId, month, cents]
        )
    }
}
