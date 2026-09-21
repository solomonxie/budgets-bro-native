import XCTest
@testable import BudgetsBroNative

final class BudgetMathTests: XCTestCase {
    func testCategoryBalanceIsCumulativeAssignedPlusActivity() {
        let balance = BudgetMath.categoryBalanceCents(cumulativeAssignedCents: 40000, cumulativeActivityCents: -31600)
        XCTAssertEqual(balance, 8400)
    }

    func testStatusOverspentWhenBalanceNegative() {
        XCTAssertEqual(BudgetMath.status(balanceCents: -100, assignedThisMonthCents: 5000), .overspent)
    }

    func testStatusUnbudgetedWhenNothingAssigned() {
        XCTAssertEqual(BudgetMath.status(balanceCents: 0, assignedThisMonthCents: 0), .unbudgeted)
    }

    func testStatusFullySpentWhenBalanceExactlyZeroAndAssigned() {
        XCTAssertEqual(BudgetMath.status(balanceCents: 0, assignedThisMonthCents: 5000), .fullySpent)
    }

    func testStatusFundedWhenBalancePositiveAndAssigned() {
        XCTAssertEqual(BudgetMath.status(balanceCents: 3000, assignedThisMonthCents: 5000), .funded)
    }

    func testCaptionOverspentShowsExactShortfall() {
        let text = BudgetMath.caption(status: .overspent, spentThisMonthCents: 4000, assignedThisMonthCents: 0, balanceCents: -40)
        XCTAssertTrue(text.contains("Overspent by"))
    }

    func testCaptionFundedWithNoSpendReadsFunded() {
        XCTAssertEqual(BudgetMath.caption(status: .funded, spentThisMonthCents: 0, assignedThisMonthCents: 5000, balanceCents: 5000), "Funded")
    }

    func testCategoryBarSegmentsSplitSpentVsRemaining() {
        let segments = BudgetMath.categoryBarSegments(balanceCents: 3000, spentThisMonthCents: 1000)
        XCTAssertEqual(segments.spentPercent, 25, accuracy: 0.01)
        XCTAssertEqual(segments.remainingPercent, 75, accuracy: 0.01)
    }

    func testUnassignedCashIsUncategorizedActivityMinusAssignedAllTime() {
        let cents = BudgetMath.unassignedCashCents(uncategorizedActivityAllTimeCents: 200000, assignedAllTimeCents: 190000)
        XCTAssertEqual(cents, 10000)
    }

    func testUnassignedCashCanGoNegative() {
        // A balance-correction adjustment can be negative and uncategorized —
        // must reduce Unassigned Cash, not floor at zero. See docs/DESIGN.md.
        let cents = BudgetMath.unassignedCashCents(uncategorizedActivityAllTimeCents: -500, assignedAllTimeCents: 0)
        XCTAssertEqual(cents, -500)
    }
}
