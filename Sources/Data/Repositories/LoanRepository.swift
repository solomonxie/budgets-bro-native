import Foundation

/// Rate history + the generic value-history log shared by a mortgage's home
/// value and a tracking account's value (`kind`: "value" or "principal") —
/// see docs/DESIGN.md's Loan/mortgage v2 and Tracking/investment sections.
final class LoanRepository {
    private let database: Database
    init(database: Database = .shared) { self.database = database }

    @discardableResult
    func addRate(accountId: Int, ratePercent: Double, effectiveDate: String) -> Int {
        Int(database.run(
            "INSERT INTO account_rate_history (account_id, rate_bps, effective_date) VALUES (?, ?, ?)",
            [accountId, Int((ratePercent * 100).rounded()), effectiveDate]
        ))
    }

    func rateHistory(accountId: Int) -> [(ratePercent: Double, effectiveDate: String)] {
        database.query(
            "SELECT rate_bps, effective_date FROM account_rate_history WHERE account_id = ? ORDER BY effective_date DESC",
            [accountId],
            row: { (Double($0.int(0)) / 100, $0.text(1) ?? "") }
        )
    }

    func currentRatePercent(accountId: Int) -> Double? {
        rateHistory(accountId: accountId).first?.ratePercent
    }

    @discardableResult
    func addValueReading(accountId: Int, kind: String, valueCents: Int, effectiveDate: String, note: String?) -> Int {
        Int(database.run(
            "INSERT INTO account_value_history (account_id, kind, value_cents, effective_date, note) VALUES (?, ?, ?, ?, ?)",
            [accountId, kind, valueCents, effectiveDate, note]
        ))
    }

    func valueHistory(accountId: Int, kind: String) -> [(valueCents: Int, effectiveDate: String, note: String?)] {
        database.query(
            "SELECT value_cents, effective_date, note FROM account_value_history WHERE account_id = ? AND kind = ? ORDER BY effective_date DESC",
            [accountId, kind],
            row: { ($0.int(0), $0.text(1) ?? "", $0.text(2)) }
        )
    }

    func latestValueCents(accountId: Int, kind: String) -> Int? {
        valueHistory(accountId: accountId, kind: kind).first?.valueCents
    }

    /// The reading that was current as of a given date — the latest one
    /// logged at or before it. Powers the Net Worth trend chart and a
    /// mortgage's equity chart with a real curve instead of today's figure
    /// held flat across every month.
    func valueCents(accountId: Int, kind: String, asOf date: String) -> Int? {
        database.query(
            "SELECT value_cents FROM account_value_history WHERE account_id = ? AND kind = ? AND effective_date <= ? ORDER BY effective_date DESC LIMIT 1",
            [accountId, kind, date],
            row: { $0.int(0) }
        ).first
    }

    /// Remaining principal: the latest logged reading if one exists, else
    /// the account's opening balance. Simplified vs. the original's
    /// payment-split-since-anchor estimate between readings (see
    /// docs/DESIGN.md) — logging an actual statement reading is the
    /// accurate path either way, so the estimate is the part deferred.
    func remainingPrincipalCents(account: Account) -> Int {
        latestValueCents(accountId: account.id, kind: "principal") ?? abs(account.openingBalanceCents)
    }
}
