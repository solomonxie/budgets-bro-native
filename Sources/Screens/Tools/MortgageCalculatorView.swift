import SwiftUI

/// Ad-hoc "what if" mortgage/loan calculator, not tied to a real account —
/// per docs/design/uiux/insights.md and docs/DESIGN.md#financial-tools-module.
struct MortgageCalculatorView: View {
    @State private var principalText = "400000"
    @State private var rateText = "6.5"
    @State private var termYearsText = "30"
    @State private var extraPaymentText = "0"

    private var principalCents: Int { Int((Double(principalText) ?? 0) * 100) }
    private var ratePercent: Double { Double(rateText) ?? 0 }
    private var termMonths: Int { (Int(termYearsText) ?? 0) * 12 }
    private var extraPaymentCents: Int { Int((Double(extraPaymentText) ?? 0) * 100) }

    private var monthlyPaymentCents: Int {
        Amortization.monthlyPaymentCents(principalCents: principalCents, annualRatePercent: ratePercent, termMonths: termMonths)
    }

    private var payoffMonths: Int {
        Amortization.remainingMonthsToPayoff(
            balanceCents: principalCents,
            annualRatePercent: ratePercent,
            paymentCents: monthlyPaymentCents,
            extraPaymentCents: extraPaymentCents
        )
    }

    private var totalInterestCents: Int {
        Amortization.totalInterestRemainingCents(
            balanceCents: principalCents,
            annualRatePercent: ratePercent,
            paymentCents: monthlyPaymentCents,
            extraPaymentCents: extraPaymentCents
        )
    }

    var body: some View {
        Form {
            Section("Loan") {
                LabeledContent("Amount") {
                    TextField("Amount", text: $principalText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
                LabeledContent("Rate (%)") {
                    TextField("Rate", text: $rateText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
                LabeledContent("Term (years)") {
                    TextField("Term", text: $termYearsText).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                }
                LabeledContent("Extra payment/mo") {
                    TextField("Extra", text: $extraPaymentText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
            }
            Section("Result") {
                LabeledContent("Monthly payment", value: Money.exact(monthlyPaymentCents))
                LabeledContent("Payoff", value: payoffMonths >= 1200 ? "never" : "\(payoffMonths) months")
                LabeledContent("Total interest", value: Money.wholeDollars(totalInterestCents))
            }
        }
        .navigationTitle("Mortgage Calculator")
    }
}
