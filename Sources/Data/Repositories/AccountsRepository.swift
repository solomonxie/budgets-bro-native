import Foundation

/// CRUD + computed balance for `accounts` — see docs/DESIGN.md#core-domain-model.
/// Account balance = opening_balance + sum(transactions.amount_cents), computed
/// not stored, to avoid drift bugs (same rule as the original).
final class AccountsRepository {
    private let database: Database
    init(database: Database = .shared) { self.database = database }

    func all(includeArchived: Bool = false) -> [Account] {
        let sql = """
        SELECT id, name, type, on_budget, currency, opening_balance_cents, archived_at
        FROM accounts
        \(includeArchived ? "" : "WHERE archived_at IS NULL")
        ORDER BY name
        """
        return database.query(sql, row: Self.map)
    }

    @discardableResult
    func create(name: String, type: AccountType, onBudget: Bool, currency: String = "USD", openingBalanceCents: Int) -> Int {
        Int(database.run(
            "INSERT INTO accounts (name, type, on_budget, currency, opening_balance_cents) VALUES (?, ?, ?, ?, ?)",
            [name, type.rawValue, onBudget, currency, openingBalanceCents]
        ))
    }

    func update(_ account: Account) {
        database.run(
            "UPDATE accounts SET name = ?, type = ?, on_budget = ?, opening_balance_cents = ? WHERE id = ?",
            [account.name, account.type.rawValue, account.onBudget, account.openingBalanceCents, account.id]
        )
    }

    func archive(id: Int) {
        database.run("UPDATE accounts SET archived_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?", [id])
    }

    func balanceCents(accountId: Int) -> Int {
        database.query(
            """
            SELECT a.opening_balance_cents + COALESCE(SUM(t.amount_cents), 0)
            FROM accounts a
            LEFT JOIN transactions t ON t.account_id = a.id
            WHERE a.id = ?
            GROUP BY a.id
            """,
            [accountId],
            row: { $0.int(0) }
        ).first ?? 0
    }

    /// One query for every account's balance — avoids an N+1 fan-out on the
    /// Accounts list, per AGENTS.md's "never read the whole board to render
    /// part of it" (here the inverse: don't run the board query N times).
    func balancesByAccountId() -> [Int: Int] {
        let rows = database.query(
            """
            SELECT a.id, a.opening_balance_cents + COALESCE(SUM(t.amount_cents), 0)
            FROM accounts a
            LEFT JOIN transactions t ON t.account_id = a.id
            GROUP BY a.id
            """,
            row: { ($0.int(0), $0.int(1)) }
        )
        return Dictionary(uniqueKeysWithValues: rows)
    }

    private static func map(_ row: Row) -> Account {
        Account(
            id: row.int(0),
            name: row.text(1) ?? "",
            type: AccountType(rawValue: row.text(2) ?? "") ?? .cash,
            onBudget: row.int(3) != 0,
            currency: row.text(4) ?? "USD",
            openingBalanceCents: row.int(5),
            archivedAt: row.text(6)
        )
    }
}
