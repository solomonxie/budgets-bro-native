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
    var purchaseItems: String?
    var amountCents: Int
    var date: String
    var cleared: Bool
    var transferAccountId: Int?
    var isSplit: Bool
}

/// Every query here is scoped to the active board, almost always via a join
/// on `accounts.board_id` — `transactions` itself carries no `board_id`
/// column, since every transaction's account already belongs to exactly
/// one board (see `BoardContext`).
final class TransactionsRepository {
    private let database: Database
    init(database: Database = .shared) { self.database = database }

    private var boardId: Int { BoardContext.shared.currentBoardId }

    private static let joinedSelect = """
    SELECT t.id, t.account_id, a.name, t.category_id, c.name, t.payee_id, p.name,
           t.memo, t.purchase_items, t.amount_cents, t.date, t.cleared, t.transfer_account_id,
           EXISTS(SELECT 1 FROM transaction_splits ts WHERE ts.transaction_id = t.id)
    FROM transactions t
    JOIN accounts a ON a.id = t.account_id
    LEFT JOIN categories c ON c.id = t.category_id
    LEFT JOIN payees p ON p.id = t.payee_id
    """

    func all(limit: Int = 500) -> [TransactionListItem] {
        database.query(
            "\(Self.joinedSelect) WHERE a.board_id = ? ORDER BY t.date DESC, t.id DESC LIMIT ?",
            [boardId, limit],
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
            "\(Self.joinedSelect) WHERE a.board_id = ? AND substr(t.date, 1, 7) = ? ORDER BY t.date DESC, t.id DESC",
            [boardId, month],
            row: Self.map
        )
    }

    @discardableResult
    func create(
        accountId: Int,
        categoryId: Int?,
        payeeId: Int?,
        memo: String?,
        purchaseItems: String? = nil,
        amountCents: Int,
        date: String,
        cleared: Bool = false,
        isInterest: Bool = false,
        transferAccountId: Int? = nil
    ) -> Int {
        Int(database.run(
            """
            INSERT INTO transactions
                (account_id, category_id, payee_id, memo, purchase_items, amount_cents, date, cleared, is_interest, transfer_account_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [accountId, categoryId, payeeId, memo, purchaseItems, amountCents, date, cleared, isInterest, transferAccountId]
        ))
    }

    func update(_ transaction: Transaction) {
        database.run(
            """
            UPDATE transactions
            SET account_id = ?, category_id = ?, payee_id = ?, memo = ?, purchase_items = ?, amount_cents = ?,
                date = ?, cleared = ?, is_interest = ?, transfer_account_id = ?,
                updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
            WHERE id = ?
            """,
            [
                transaction.accountId, transaction.categoryId, transaction.payeeId, transaction.memo, transaction.purchaseItems,
                transaction.amountCents, transaction.date, transaction.cleared, transaction.isInterest,
                transaction.transferAccountId, transaction.id,
            ]
        )
    }

    func delete(id: Int) {
        database.run("DELETE FROM transaction_splits WHERE transaction_id = ?", [id])
        database.run("DELETE FROM transactions WHERE id = ?", [id])
    }

    // MARK: Splits — see docs/DESIGN.md's Split transactions backlog item.

    func splits(transactionId: Int) -> [TransactionSplit] {
        database.query(
            "SELECT id, transaction_id, category_id, amount_cents, memo FROM transaction_splits WHERE transaction_id = ?",
            [transactionId],
            row: { TransactionSplit(id: $0.int(0), transactionId: $0.int(1), categoryId: $0.isNull(2) ? nil : $0.int(2), amountCents: $0.int(3), memo: $0.text(4)) }
        )
    }

    /// Replaces every split for a transaction in one go — simplest correct
    /// operation for an editable list of rows that can be added/removed
    /// freely, and the parent's own `category_id` is cleared so activity
    /// queries below read the splits instead of a stale parent category.
    func setSplits(transactionId: Int, splits: [(categoryId: Int?, amountCents: Int, memo: String?)]) {
        database.run("DELETE FROM transaction_splits WHERE transaction_id = ?", [transactionId])
        for split in splits {
            database.run(
                "INSERT INTO transaction_splits (transaction_id, category_id, amount_cents, memo) VALUES (?, ?, ?, ?)",
                [transactionId, split.categoryId, split.amountCents, split.memo]
            )
        }
        database.run("UPDATE transactions SET category_id = NULL WHERE id = ?", [transactionId])
    }

    /// Category activity for a month — the "spent" half of a budget row's
    /// funded/overspent math. Unions plain transactions with split
    /// allocations, since a split transaction carries no `category_id`
    /// of its own (docs/DESIGN.md#core-domain-model note above).
    func activityCentsByCategory(month: String) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: database.query(
            """
            SELECT category_id, SUM(amount_cents) FROM (
                SELECT t.category_id, t.amount_cents, t.date FROM transactions t
                JOIN accounts a ON a.id = t.account_id
                WHERE a.board_id = ? AND t.category_id IS NOT NULL AND t.transfer_account_id IS NULL
                UNION ALL
                SELECT ts.category_id, ts.amount_cents, t.date FROM transaction_splits ts
                JOIN transactions t ON t.id = ts.transaction_id
                JOIN accounts a ON a.id = t.account_id
                WHERE a.board_id = ? AND ts.category_id IS NOT NULL AND t.transfer_account_id IS NULL
            )
            WHERE substr(date, 1, 7) = ?
            GROUP BY category_id
            """,
            [boardId, boardId, month],
            row: { ($0.int(0), $0.int(1)) }
        ))
    }

    /// Cumulative activity through `month` (inclusive) per category — the
    /// running side of the rollover sum in `BudgetMath.categoryBalance`.
    func cumulativeActivityCentsByCategory(throughMonth month: String) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: database.query(
            """
            SELECT category_id, SUM(amount_cents) FROM (
                SELECT t.category_id, t.amount_cents, t.date FROM transactions t
                JOIN accounts a ON a.id = t.account_id
                WHERE a.board_id = ? AND t.category_id IS NOT NULL AND t.transfer_account_id IS NULL
                UNION ALL
                SELECT ts.category_id, ts.amount_cents, t.date FROM transaction_splits ts
                JOIN transactions t ON t.id = ts.transaction_id
                JOIN accounts a ON a.id = t.account_id
                WHERE a.board_id = ? AND ts.category_id IS NOT NULL AND t.transfer_account_id IS NULL
            )
            WHERE substr(date, 1, 7) <= ?
            GROUP BY category_id
            """,
            [boardId, boardId, month],
            row: { ($0.int(0), $0.int(1)) }
        ))
    }

    /// Total spend (negative activity, non-transfer) for one month — the
    /// per-month figure the Insights trend chart plots.
    func totalSpentCents(month: String) -> Int {
        -min(database.query(
            """
            SELECT COALESCE(SUM(t.amount_cents), 0) FROM transactions t
            JOIN accounts a ON a.id = t.account_id
            WHERE a.board_id = ? AND t.transfer_account_id IS NULL AND substr(t.date, 1, 7) = ?
            """,
            [boardId, month],
            row: { $0.int(0) }
        ).first ?? 0, 0)
    }

    /// Upsert keyed on `import_id` — the idempotency mechanism for YNAB
    /// import (see docs/DESIGN.md#ynab-data-import). Returns true if this
    /// created a new row, false if it updated an existing one.
    @discardableResult
    func upsertImported(importId: String, accountId: Int, categoryId: Int?, payeeId: Int?, memo: String?, amountCents: Int, date: String, cleared: Bool) -> Bool {
        if let existingId = database.query("SELECT id FROM transactions WHERE import_id = ?", [importId], row: { $0.int(0) }).first {
            database.run(
                """
                UPDATE transactions
                SET account_id = ?, category_id = ?, payee_id = ?, memo = ?, amount_cents = ?, date = ?, cleared = ?,
                    updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
                WHERE id = ?
                """,
                [accountId, categoryId, payeeId, memo, amountCents, date, cleared, existingId]
            )
            return false
        }
        database.run(
            "INSERT INTO transactions (account_id, category_id, payee_id, memo, amount_cents, date, cleared, import_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            [accountId, categoryId, payeeId, memo, amountCents, date, cleared, importId]
        )
        return true
    }

    /// Sum of uncategorized, non-transfer transactions on on-budget
    /// accounts, all time — the "cash" half of Unassigned Cash. Excludes a
    /// split transaction's parent row (its `category_id` is NULL but it's
    /// not "uncategorized" — its money is accounted for via its splits).
    func uncategorizedActivityCentsAllTime() -> Int {
        database.query(
            """
            SELECT COALESCE(SUM(t.amount_cents), 0) FROM transactions t
            JOIN accounts a ON a.id = t.account_id
            WHERE a.board_id = ? AND t.category_id IS NULL AND t.transfer_account_id IS NULL AND a.on_budget = 1
              AND NOT EXISTS (SELECT 1 FROM transaction_splits ts WHERE ts.transaction_id = t.id)
            """,
            [boardId],
            row: { $0.int(0) }
        ).first ?? 0
    }

    /// This calendar year's income (positive, non-transfer, on-budget) and
    /// spending (negative, non-transfer, on-budget) — Tax Insights' ledger
    /// half. See docs/DESIGN.md's Tax Insights backlog item.
    func thisYearIncomeAndSpendingCents(year: String) -> (incomeCents: Int, spendingCents: Int) {
        let rows = database.query(
            """
            SELECT COALESCE(SUM(CASE WHEN t.amount_cents > 0 THEN t.amount_cents ELSE 0 END), 0),
                   COALESCE(SUM(CASE WHEN t.amount_cents < 0 THEN -t.amount_cents ELSE 0 END), 0)
            FROM transactions t
            JOIN accounts a ON a.id = t.account_id
            WHERE a.board_id = ? AND t.transfer_account_id IS NULL AND a.on_budget = 1 AND substr(t.date, 1, 4) = ?
            """,
            [boardId, year],
            row: { ($0.int(0), $0.int(1)) }
        )
        return rows.first ?? (0, 0)
    }

    /// Every transaction's non-empty `purchase_items` string, for Purchase
    /// Insights — see `Sources/Domain/PurchaseItems.swift`.
    func allPurchaseItemEntries() -> [(date: String, purchaseItems: String, transactionId: Int)] {
        database.query(
            """
            SELECT t.date, t.purchase_items, t.id FROM transactions t
            JOIN accounts a ON a.id = t.account_id
            WHERE a.board_id = ? AND t.purchase_items IS NOT NULL AND t.purchase_items != ''
            """,
            [boardId],
            row: { ($0.text(0) ?? "", $0.text(1) ?? "", $0.int(2)) }
        )
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
            purchaseItems: row.text(8),
            amountCents: row.int(9),
            date: row.text(10) ?? "",
            cleared: row.int(11) != 0,
            transferAccountId: row.isNull(12) ? nil : row.int(12),
            isSplit: row.int(13) != 0
        )
    }
}
