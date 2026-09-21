import XCTest
@testable import BudgetsBroNative

final class CashflowTests: XCTestCase {
    func testProjectsRecurringScheduleForward() {
        let schedule = ScheduledTransaction(
            id: 1, accountId: 1, categoryId: nil, payeeId: nil, memo: nil,
            amountCents: -1000, frequency: .weekly, intervalN: 1,
            nextDate: today(), endDate: nil, autoPost: true, isInterest: false
        )
        let points = Cashflow.project(startingBalanceCents: 10000, schedules: [schedule], daysAhead: 30)
        XCTAssertEqual(points.first?.balanceCents, 9000) // day 0 includes today's occurrence
        XCTAssertEqual(points.last?.dayOffset, 30)
        XCTAssertLessThan(points.last!.balanceCents, 9000) // more occurrences posted by day 30
    }

    func testNoSchedulesLeavesBalanceFlat() {
        let points = Cashflow.project(startingBalanceCents: 5000, schedules: [], daysAhead: 10)
        XCTAssertTrue(points.allSatisfy { $0.balanceCents == 5000 })
    }
}

final class FIREProjectionTests: XCTestCase {
    func testAlreadyIndependentReturnsZero() {
        let months = FIREProjection.monthsToIndependence(currentNetWorthCents: 2_000_000, monthlyContributionCents: 0, annualReturnPercent: 7, targetNetWorthCents: 1_000_000)
        XCTAssertEqual(months, 0)
    }

    func testGrowingContributionsReachTarget() {
        let months = FIREProjection.monthsToIndependence(currentNetWorthCents: 0, monthlyContributionCents: 100_000, annualReturnPercent: 7, targetNetWorthCents: 10_000_000)
        XCTAssertNotNil(months)
        XCTAssertGreaterThan(months ?? 0, 0)
    }

    func testZeroContributionAndBelowTargetNeverReaches() {
        let months = FIREProjection.monthsToIndependence(currentNetWorthCents: 100, monthlyContributionCents: 0, annualReturnPercent: 0, targetNetWorthCents: 1_000_000)
        XCTAssertNil(months)
    }

    func testTargetNetWorthUsesSafeWithdrawalRate() {
        let target = FIREProjection.targetNetWorthCents(annualSpendingCents: 4_000_000, safeWithdrawalRatePercent: 4)
        XCTAssertEqual(target, 100_000_000)
    }
}
