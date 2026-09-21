import Foundation

/// Pure functions, no DB dependency — ported from budgets-bro's
/// `domain/budgetMath.ts` line for line, including its exact 4-state status
/// and caption text, so the native app reads identically to the original.
enum BudgetMath {
    enum CategoryStatus {
        case overspent, fullySpent, funded, unbudgeted
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
        if assignedThisMonthCents == 0 { return .unbudgeted }
        if balanceCents == 0 { return .fullySpent }
        return .funded
    }

    /// Exact cents, not whole dollars — a category sitting at −40¢ is
    /// overspent, and rounding it to "Overspent by $0" reads as a bug.
    static func caption(status: CategoryStatus, spentThisMonthCents: Int, assignedThisMonthCents: Int, balanceCents: Int) -> String {
        switch status {
        case .overspent:
            "Overspent by \(Money.exact(-balanceCents))"
        case .unbudgeted:
            "Not budgeted"
        case .fullySpent:
            "Fully spent \(Money.exact(spentThisMonthCents))"
        case .funded:
            spentThisMonthCents > 0
                ? "Spent \(Money.exact(spentThisMonthCents)) of \(Money.exact(assignedThisMonthCents))"
                : "Funded"
        }
    }

    struct CategoryBarSegments {
        let spentPercent: Double
        let remainingPercent: Double
    }

    /// How a category's bar splits between spent and remaining, against the
    /// two together rather than this month's assignment — so a rolled-over
    /// balance reads truthfully instead of pinning at 100%.
    static func categoryBarSegments(balanceCents: Int, spentThisMonthCents: Int) -> CategoryBarSegments {
        let spent = max(0, spentThisMonthCents)
        let remaining = max(0, balanceCents)
        let total = spent + remaining
        guard total > 0 else { return CategoryBarSegments(spentPercent: 0, remainingPercent: 0) }
        let spentPercent = Double(spent) / Double(total) * 100
        return CategoryBarSegments(spentPercent: spentPercent, remainingPercent: 100 - spentPercent)
    }

    /// Unassigned Cash = sum(uncategorized, non-transfer transactions on
    /// on-budget accounts, all time) − sum(assigned, all time). Not scoped
    /// to the viewed month — see docs/DESIGN.md for why.
    static func unassignedCashCents(uncategorizedActivityAllTimeCents: Int, assignedAllTimeCents: Int) -> Int {
        uncategorizedActivityAllTimeCents - assignedAllTimeCents
    }
}
