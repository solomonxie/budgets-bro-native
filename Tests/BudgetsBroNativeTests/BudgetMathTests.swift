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

    func testStatusPartialWhenBalanceBelowAssigned() {
        XCTAssertEqual(BudgetMath.status(balanceCents: 3000, assignedThisMonthCents: 5000), .partial)
    }

    func testStatusFundedWhenBalanceCoversAssigned() {
        XCTAssertEqual(BudgetMath.status(balanceCents: 5000, assignedThisMonthCents: 5000), .funded)
    }

    func testStatusFundedWhenNothingAssignedYet() {
        // No assignment this month isn't "partial" — nothing was promised.
        XCTAssertEqual(BudgetMath.status(balanceCents: 0, assignedThisMonthCents: 0), .funded)
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
