import Foundation

/// CRUD + computed balance for `accounts`, scoped to the active board — see
/// docs/DESIGN.md#core-domain-model and `BoardContext`.
final class AccountsRepository {
    private let database: Database
    private let loanRepo: LoanRepository
    init(database: Database = .shared) {
        self.database = database
        loanRepo = LoanRepository(database: database)
    }

    private var boardId: Int { BoardContext.shared.currentBoardId }

    func all(includeArchived: Bool = false) -> [Account] {
        let sql = """
        SELECT id, name, type, on_budget, currency, opening_balance_cents, archived_at, term_months
        FROM accounts
        WHERE board_id = ? \(includeArchived ? "" : "AND archived_at IS NULL")
        ORDER BY name
        """
        return database.query(sql, [boardId], row: Self.map)
    }

    @discardableResult
    func create(
        name: String, type: AccountType, onBudget: Bool, currency: String = "USD", openingBalanceCents: Int,
        termMonths: Int? = nil, originationPrincipalCents: Int? = nil, originationDate: String? = nil
    ) -> Int {
        Int(database.run(
            """
            INSERT INTO accounts
                (name, type, on_budget, currency, opening_balance_cents, board_id, term_months, origination_principal_cents, origination_date)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [name, type.rawValue, onBudget, currency, openingBalanceCents, boardId, termMonths, originationPrincipalCents, originationDate]
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

    /// opening + transactions — the plain ledger balance. Correct for
    /// checking/savings/credit/cash; a tracking/asset/loan/mortgage account
    /// overrides this via `resolvedBalanceCents` below, same split as the
    /// original's `accountsRepo.resolveBalanceCents`.
    private func ledgerBalanceCents(accountId: Int) -> Int {
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

    /// The balance actually shown everywhere — a tracking/asset account's
    /// is its latest logged value (transactions on it are deposits/growth,
    /// not the balance itself); a loan/mortgage's is negative remaining
    /// principal. Falls back to the ledger balance when nothing's been
    /// logged yet, so a brand-new account isn't blank.
    func resolvedBalanceCents(account: Account) -> Int {
        if account.type.usesLoggedValue, let value = loanRepo.latestValueCents(accountId: account.id, kind: "value") {
            return value
        }
        if account.type.isLoanLike {
            return -loanRepo.remainingPrincipalCents(account: account)
        }
        return ledgerBalanceCents(accountId: account.id)
    }

    func balanceCents(accountId: Int) -> Int {
        guard let account = all(includeArchived: true).first(where: { $0.id == accountId }) else {
            return ledgerBalanceCents(accountId: accountId)
        }
        return resolvedBalanceCents(account: account)
    }

    /// Balance through a given date (inclusive) — the Net Worth trend
    /// chart's per-month point. Simplified vs. the original's
    /// `useNetWorthTrend`: reads opening + transactions only, so a
    /// tracking/asset/mortgage account shows flat between loggings rather
    /// than a value-history-aware curve — noted here rather than hidden.
    func balanceCentsAsOf(accountId: Int, throughDate: String) -> Int {
        database.query(
            """
            SELECT a.opening_balance_cents + COALESCE(SUM(t.amount_cents), 0)
            FROM accounts a
            LEFT JOIN transactions t ON t.account_id = a.id AND t.date <= ?
            WHERE a.id = ?
            GROUP BY a.id
            """,
            [throughDate, accountId],
            row: { $0.int(0) }
        ).first ?? 0
    }

    /// One query for every account's ledger balance, then resolved-balance
    /// overrides applied for the tracking/asset/loan/mortgage accounts among
    /// them — avoids an N+1 fan-out on the Accounts list.
    func balancesByAccountId() -> [Int: Int] {
        let accounts = all(includeArchived: true)
        let rows = database.query(
            """
            SELECT a.id, a.opening_balance_cents + COALESCE(SUM(t.amount_cents), 0)
            FROM accounts a
            LEFT JOIN transactions t ON t.account_id = a.id
            WHERE a.board_id = ?
            GROUP BY a.id
            """,
            [boardId],
            row: { ($0.int(0), $0.int(1)) }
        )
        var ledger = Dictionary(uniqueKeysWithValues: rows)
        for account in accounts where account.type.usesLoggedValue || account.type.isLoanLike {
            ledger[account.id] = resolvedBalanceCents(account: account)
        }
        return ledger
    }

    private static func map(_ row: Row) -> Account {
        Account(
            id: row.int(0),
            name: row.text(1) ?? "",
            type: AccountType(rawValue: row.text(2) ?? "") ?? .cash,
            onBudget: row.int(3) != 0,
            currency: row.text(4) ?? "USD",
            openingBalanceCents: row.int(5),
            archivedAt: row.text(6),
            termMonths: row.isNull(7) ? nil : row.int(7)
        )
    }
}
