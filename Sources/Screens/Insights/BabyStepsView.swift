import SwiftUI

/// Dave Ramsey's 7 steps — 1/2/3/6 computed from ledger data, 4/5/7 manual
/// checkboxes. See docs/DESIGN.md's Baby Steps backlog item. Simplified vs.
/// the original: no linked-account picker for "which account is my
/// emergency fund" — uses every Savings-kind account's total.
struct BabyStepsView: View {
    private let accountsRepo = AccountsRepository()
    private let transactionsRepo = TransactionsRepository()
    private let settings = AppSettingsRepository()

    @State private var savingsTotalCents = 0
    @State private var nonMortgageDebtCents = 0
    @State private var mortgageDebtCents = 0
    @State private var avgMonthlySpendCents = 0
    @State private var step4 = false
    @State private var step5 = false
    @State private var step7 = false

    var body: some View {
        Form {
            Section("Step 1 — $1,000 Starter Emergency Fund") {
                statusRow(done: savingsTotalCents >= 100_000, detail: Money.wholeDollars(savingsTotalCents))
            }
            Section("Step 2 — Pay Off All Debt (Except Mortgage)") {
                statusRow(done: nonMortgageDebtCents == 0, detail: Money.wholeDollars(nonMortgageDebtCents) + " remaining")
            }
            Section("Step 3 — 3-6 Months of Expenses Saved") {
                let target = avgMonthlySpendCents * 3
                statusRow(done: savingsTotalCents >= target, detail: "\(Money.wholeDollars(savingsTotalCents)) of \(Money.wholeDollars(target))+")
            }
            Section("Step 4 — Invest 15% for Retirement") {
                Toggle("Done", isOn: $step4).onChange(of: step4) { _, value in settings.set("baby_step_4", value ? "1" : "0") }
            }
            Section("Step 5 — Save for Kids' College") {
                Toggle("Done", isOn: $step5).onChange(of: step5) { _, value in settings.set("baby_step_5", value ? "1" : "0") }
            }
            Section("Step 6 — Pay Off Home Early") {
                statusRow(done: mortgageDebtCents == 0, detail: Money.wholeDollars(mortgageDebtCents) + " remaining")
            }
            Section("Step 7 — Build Wealth & Give") {
                Toggle("Done", isOn: $step7).onChange(of: step7) { _, value in settings.set("baby_step_7", value ? "1" : "0") }
            }
        }
        .navigationTitle("Baby Steps")
        .task { reload() }
    }

    private func statusRow(done: Bool, detail: String) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Theme.positive : .secondary)
            Text(detail)
        }
    }

    private func reload() {
        let accounts = accountsRepo.all()
        let balances = accountsRepo.balancesByAccountId()
        savingsTotalCents = accounts.filter { $0.type == .savings }.reduce(0) { $0 + (balances[$1.id] ?? 0) }
        nonMortgageDebtCents = accounts.filter { $0.type == .loan }.reduce(0) { $0 + abs(min(balances[$1.id] ?? 0, 0)) }
        mortgageDebtCents = accounts.filter { $0.type == .mortgage }.reduce(0) { $0 + abs(min(balances[$1.id] ?? 0, 0)) }

        let months = (0 ..< 6).compactMap { offset in
            Calendar.current.date(byAdding: .month, value: -offset, to: Date()).map { monthString(from: $0) }
        }
        let total = months.reduce(0) { $0 + transactionsRepo.totalSpentCents(month: $1) }
        avgMonthlySpendCents = months.isEmpty ? 0 : total / months.count

        step4 = settings.get("baby_step_4") == "1"
        step5 = settings.get("baby_step_5") == "1"
        step7 = settings.get("baby_step_7") == "1"
    }
}
