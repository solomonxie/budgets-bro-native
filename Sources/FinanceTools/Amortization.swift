import Foundation

/// Self-contained pure-function module, no DB/view dependency — port of
/// budgets-bro's `finance-tools/amortization.ts`. See docs/DESIGN.md#financial-tools-module.
enum Amortization {
    struct ScheduleRow {
        let month: Int
        let paymentCents: Int
        let principalCents: Int
        let interestCents: Int
        let remainingBalanceCents: Int
    }

    /// Standard fixed-rate monthly payment formula.
    static func monthlyPaymentCents(principalCents: Int, annualRatePercent: Double, termMonths: Int) -> Int {
        guard termMonths > 0 else { return 0 }
        let monthlyRate = annualRatePercent / 100 / 12
        guard monthlyRate > 0 else {
            return Int((Double(principalCents) / Double(termMonths)).rounded())
        }
        let factor = pow(1 + monthlyRate, Double(termMonths))
        let payment = Double(principalCents) * monthlyRate * factor / (factor - 1)
        return Int(payment.rounded())
    }

    static func buildSchedule(principalCents: Int, annualRatePercent: Double, termMonths: Int) -> [ScheduleRow] {
        let payment = monthlyPaymentCents(principalCents: principalCents, annualRatePercent: annualRatePercent, termMonths: termMonths)
        let monthlyRate = annualRatePercent / 100 / 12
        var balance = principalCents
        var rows: [ScheduleRow] = []
        for month in 1...max(termMonths, 1) {
            let interest = Int((Double(balance) * monthlyRate).rounded())
            // The fixed monthly payment drifts a few cents from the exact
            // payoff amount over a long schedule (rounding each month's
            // interest to the cent) — the final month pays off whatever is
            // actually left, same as a real amortization table's adjusted
            // last payment, rather than leaving a stray cent balance.
            let isFinalMonth = month == termMonths
            let principalPortion = isFinalMonth ? balance : min(payment - interest, balance)
            let actualPayment = isFinalMonth ? interest + principalPortion : payment
            balance -= principalPortion
            rows.append(ScheduleRow(month: month, paymentCents: actualPayment, principalCents: principalPortion, interestCents: interest, remainingBalanceCents: balance))
            if balance <= 0 { break }
        }
        return rows
    }

    /// How many months to pay off `balanceCents` at `paymentCents`/month,
    /// optionally with an extra recurring payment on top.
    static func remainingMonthsToPayoff(balanceCents: Int, annualRatePercent: Double, paymentCents: Int, extraPaymentCents: Int = 0) -> Int {
        let monthlyRate = annualRatePercent / 100 / 12
        var balance = balanceCents
        var months = 0
        let totalPayment = paymentCents + extraPaymentCents
        guard totalPayment > 0 else { return .max }
        while balance > 0, months < 1200 {
            let interest = Int((Double(balance) * monthlyRate).rounded())
            let principalPortion = min(totalPayment - interest, balance)
            guard principalPortion > 0 else { return .max } // payment doesn't cover interest — never pays off
            balance -= principalPortion
            months += 1
        }
        return months
    }

    static func totalInterestRemainingCents(balanceCents: Int, annualRatePercent: Double, paymentCents: Int, extraPaymentCents: Int = 0) -> Int {
        let monthlyRate = annualRatePercent / 100 / 12
        var balance = balanceCents
        var totalInterest = 0
        let totalPayment = paymentCents + extraPaymentCents
        var months = 0
        while balance > 0, months < 1200 {
            let interest = Int((Double(balance) * monthlyRate).rounded())
            totalInterest += interest
            let principalPortion = min(totalPayment - interest, balance)
            guard principalPortion > 0 else { break }
            balance -= principalPortion
            months += 1
        }
        return totalInterest
    }
}

/// Simple/compound interest calculator — the other half of the Financial
/// Tools module.
enum Interest {
    static func simpleInterestCents(principalCents: Int, annualRatePercent: Double, years: Double) -> Int {
        Int((Double(principalCents) * annualRatePercent / 100 * years).rounded())
    }

    static func compoundInterestCents(principalCents: Int, annualRatePercent: Double, years: Double, compoundingPerYear: Int = 12) -> Int {
        let rate = annualRatePercent / 100 / Double(compoundingPerYear)
        let periods = Double(compoundingPerYear) * years
        let future = Double(principalCents) * pow(1 + rate, periods)
        return Int(future.rounded()) - principalCents
    }
}
