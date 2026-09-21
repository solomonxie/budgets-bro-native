import Foundation

/// A transaction row with its joined labels — what the Transactions list and
/// an account register actually render, per docs/design/uiux/transactions.md.
struct TransactionListItem: Identifiable, Hashable {
    var id: Int
    var accountId: Int
    var accountName: String
    var categoryId: Int?
    var categoryName: String?
    var payeeId: Int?
    var payeeName: String?
    var memo: String?
    var amountCents: Int
    var date: String
    var cleared: Bool
    var transferAccountId: Int?
}

final class TransactionsRepository {
    private let database: Database
    init(database: Database = .shared) { self.database = database }

    private static let joinedSelect = """
    SELECT t.id, t.account_id, a.name, t.category_id, c.name, t.payee_id, p.name,
           t.memo, t.amount_cents, t.date, t.cleared, t.transfer_account_id
    FROM transactions t
    JOIN accounts a ON a.id = t.account_id
    LEFT JOIN categories c ON c.id = t.category_id
    LEFT JOIN payees p ON p.id = t.payee_id
    """

    func all(limit: Int = 500) -> [TransactionListItem] {
        database.query(
            "\(Self.joinedSelect) ORDER BY t.date DESC, t.id DESC LIMIT ?",
            [limit],
            row: Self.map
        )
    }

    func forAccount(accountId: Int) -> [TransactionListItem] {
        database.query(
            "\(Self.joinedSelect) WHERE t.account_id = ? ORDER BY t.date DESC, t.id DESC",
            [accountId],
            row: Self.map
        )
    }

    func forMonth(_ month: String) -> [TransactionListItem] {
        database.query(
            "\(Self.joinedSelect) WHERE substr(t.date, 1, 7) = ? ORDER BY t.date DESC, t.id DESC",
            [month],
            row: Self.map
        )
    }

    @discardableResult
    func create(
        accountId: Int,
        categoryId: Int?,
        payeeId: Int?,
        memo: String?,
        amountCents: Int,
        date: String,
        cleared: Bool = false,
        isInterest: Bool = false,
        transferAccountId: Int? = nil
    ) -> Int {
        Int(database.run(
            """
            INSERT INTO transactions
                (account_id, category_id, payee_id, memo, amount_cents, date, cleared, is_interest, transfer_account_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [accountId, categoryId, payeeId, memo, amountCents, date, cleared, isInterest, transferAccountId]
        ))
    }

    func update(_ transaction: Transaction) {
        database.run(
            """
            UPDATE transactions
            SET account_id = ?, category_id = ?, payee_id = ?, memo = ?, amount_cents = ?,
                date = ?, cleared = ?, is_interest = ?, transfer_account_id = ?,
                updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
            WHERE id = ?
            """,
            [
                transaction.accountId, transaction.categoryId, transaction.payeeId, transaction.memo,
                transaction.amountCents, transaction.date, transaction.cleared, transaction.isInterest,
                transaction.transferAccountId, transaction.id,
            ]
        )
    }

    func delete(id: Int) {
        database.run("DELETE FROM transactions WHERE id = ?", [id])
    }

    /// Category activity for a month — the "spent" half of a budget row's
    /// funded/overspent math (Phase 2's `BudgetMath` combines this with
    /// `budget_entries.assigned_cents`).
    func activityCentsByCategory(month: String) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: database.query(
            """
            SELECT category_id, SUM(amount_cents) FROM transactions
            WHERE category_id IS NOT NULL AND substr(date, 1, 7) = ? AND transfer_account_id IS NULL
            GROUP BY category_id
            """,
            [month],
            row: { ($0.int(0), $0.int(1)) }
        ))
    }

    /// Cumulative activity through `month` (inclusive) per category — the
    /// running side of the rollover sum in `BudgetMath.categoryBalance`.
    func cumulativeActivityCentsByCategory(throughMonth month: String) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: database.query(
            """
            SELECT category_id, SUM(amount_cents) FROM transactions
            WHERE category_id IS NOT NULL AND substr(date, 1, 7) <= ? AND transfer_account_id IS NULL
            GROUP BY category_id
            """,
            [month],
            row: { ($0.int(0), $0.int(1)) }
        ))
    }

    /// Sum of uncategorized, non-transfer transactions on on-budget
    /// accounts, all time — the "cash" half of Unassigned Cash. See
    /// docs/DESIGN.md#core-domain-model: deliberately not scoped to a month.
    func uncategorizedActivityCentsAllTime() -> Int {
        database.query(
            """
            SELECT COALESCE(SUM(t.amount_cents), 0) FROM transactions t
            JOIN accounts a ON a.id = t.account_id
            WHERE t.category_id IS NULL AND t.transfer_account_id IS NULL AND a.on_budget = 1
            """,
            row: { $0.int(0) }
        ).first ?? 0
    }

    private static func map(_ row: Row) -> TransactionListItem {
        TransactionListItem(
            id: row.int(0),
            accountId: row.int(1),
            accountName: row.text(2) ?? "",
            categoryId: row.isNull(3) ? nil : row.int(3),
            categoryName: row.text(4),
            payeeId: row.isNull(5) ? nil : row.int(5),
            payeeName: row.text(6),
            memo: row.text(7),
            amountCents: row.int(8),
            date: row.text(9) ?? "",
            cleared: row.int(10) != 0,
            transferAccountId: row.isNull(11) ? nil : row.int(11)
        )
    }
}
