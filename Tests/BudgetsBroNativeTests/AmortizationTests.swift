import XCTest
@testable import BudgetsBroNative

final class AmortizationTests: XCTestCase {
    func testMonthlyPaymentKnownGoodValue() {
        // $400,000 @ 6.5% / 30yr ≈ $2,528.27/mo — a standard published reference figure.
        let payment = Amortization.monthlyPaymentCents(principalCents: 40_000_000, annualRatePercent: 6.5, termMonths: 360)
        XCTAssertEqual(payment, 252_827, accuracy: 200)
    }

    func testMonthlyPaymentZeroInterestIsPrincipalOverTerm() {
        let payment = Amortization.monthlyPaymentCents(principalCents: 120_000, annualRatePercent: 0, termMonths: 12)
        XCTAssertEqual(payment, 10_000)
    }

    func testScheduleFullyAmortizesToZero() {
        let schedule = Amortization.buildSchedule(principalCents: 1_000_000, annualRatePercent: 5, termMonths: 24)
        XCTAssertEqual(schedule.last?.remainingBalanceCents, 0)
        XCTAssertEqual(schedule.count, 24)
    }

    func testExtraPaymentShortensPayoff() {
        let payment = Amortization.monthlyPaymentCents(principalCents: 20_000_000, annualRatePercent: 5, termMonths: 360)
        let withoutExtra = Amortization.remainingMonthsToPayoff(balanceCents: 20_000_000, annualRatePercent: 5, paymentCents: payment)
        let withExtra = Amortization.remainingMonthsToPayoff(balanceCents: 20_000_000, annualRatePercent: 5, paymentCents: payment, extraPaymentCents: 20_000)
        XCTAssertLessThan(withExtra, withoutExtra)
    }

    func testCompoundInterestExceedsSimpleInterestOverTime() {
        let simple = Interest.simpleInterestCents(principalCents: 100_000, annualRatePercent: 5, years: 10)
        let compound = Interest.compoundInterestCents(principalCents: 100_000, annualRatePercent: 5, years: 10)
        XCTAssertGreaterThan(compound, simple)
    }
}
