import SwiftUI

/// This year's income/spending from the ledger plus two manual inputs, per
/// docs/DESIGN.md's Tax Insights backlog item — clearly non-authoritative.
struct TaxInsightsView: View {
    private let transactionsRepo = TransactionsRepository()
    private let settings = AppSettingsRepository()

    @State private var incomeCents = 0
    @State private var spendingCents = 0
    @State private var additionalIncomeText = "0"
    @State private var deductionsText = "0"

    private var estimatedTaxableIncomeCents: Int {
        incomeCents + (Int(Double(additionalIncomeText) ?? 0) * 100) - (Int(Double(deductionsText) ?? 0) * 100)
    }

    var body: some View {
        Form {
            Section("From Your Ledger") {
                LabeledContent("Income this year", value: Money.wholeDollars(incomeCents))
                LabeledContent("Spending this year", value: Money.wholeDollars(spendingCents))
            }
            Section("Manual Inputs") {
                LabeledContent("Additional income") {
                    TextField("0", text: $additionalIncomeText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
                LabeledContent("Deductions") {
                    TextField("0", text: $deductionsText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
            }
            Section {
                LabeledContent("Estimated taxable income", value: Money.wholeDollars(estimatedTaxableIncomeCents))
                Text("Not tax advice — a rough estimate from your own numbers, nothing more. Talk to a real accountant.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Tax Insights")
        .task { reload() }
        .onChange(of: additionalIncomeText) { _, value in settings.set("tax_additional_income", value) }
        .onChange(of: deductionsText) { _, value in settings.set("tax_deductions", value) }
    }

    private func reload() {
        let year = String(Calendar.current.component(.year, from: Date()))
        let totals = transactionsRepo.thisYearIncomeAndSpendingCents(year: year)
        incomeCents = totals.incomeCents
        spendingCents = totals.spendingCents
        additionalIncomeText = settings.get("tax_additional_income") ?? "0"
        deductionsText = settings.get("tax_deductions") ?? "0"
    }
}
