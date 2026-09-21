import Foundation

/// CRUD for `budget_entries` — one row per category per month. See
/// docs/DESIGN.md#core-domain-model for the rollover math this feeds.
final class BudgetRepository {
    private let database: Database
    init(database: Database = .shared) { self.database = database }

    /// This month's assigned amount for every category in one query — avoids
    /// an N+1 fan-out on the Budget screen.
    func assignedCentsByCategory(month: String) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: database.query(
            "SELECT category_id, assigned_cents FROM budget_entries WHERE month = ?",
            [month],
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
            "SELECT category_id, SUM(assigned_cents) FROM budget_entries WHERE month <= ? GROUP BY category_id",
            [month],
            row: { ($0.int(0), $0.int(1)) }
        ))
    }

    /// Every assignment ever made, any month — see
    /// docs/DESIGN.md#core-domain-model's Unassigned Cash definition.
    func totalAssignedCentsAllTime() -> Int {
        database.query("SELECT COALESCE(SUM(assigned_cents), 0) FROM budget_entries", row: { $0.int(0) }).first ?? 0
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
