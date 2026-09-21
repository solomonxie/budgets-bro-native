import Foundation

/// Pure functions, no DB dependency — port of budgets-bro's `budgetMath.ts`.
/// See docs/DESIGN.md#core-domain-model for the definitions these implement.
enum BudgetMath {
    enum CategoryStatus {
        case funded, partial, overspent
    }

    /// Category balance(month) = cumulative assigned(≤ month) + cumulative
    /// activity(≤ month) — a running sum, so an unspent balance
    /// automatically carries forward (rollover is this formula, not a
    /// separate feature).
    static func categoryBalanceCents(cumulativeAssignedCents: Int, cumulativeActivityCents: Int) -> Int {
        cumulativeAssignedCents + cumulativeActivityCents
    }

    static func status(balanceCents: Int, assignedThisMonthCents: Int) -> CategoryStatus {
        if balanceCents < 0 { return .overspent }
        if assignedThisMonthCents > 0 && balanceCents < assignedThisMonthCents { return .partial }
        return .funded
    }

    /// Unassigned Cash = sum(uncategorized, non-transfer transactions on
    /// on-budget accounts, all time) − sum(assigned, all time). Not scoped
    /// to the viewed month — see docs/DESIGN.md for why.
    static func unassignedCashCents(uncategorizedActivityAllTimeCents: Int, assignedAllTimeCents: Int) -> Int {
        uncategorizedActivityAllTimeCents - assignedAllTimeCents
    }
}
