import Charts
import SwiftUI

/// Register + running balance for one account, per docs/design/uiux/accounts.md.
/// Editing/closing the account lives behind the header's Edit button; a
/// "+ Transaction" button pre-selects this account. Loan/mortgage accounts
/// get a rate + remaining-principal card; tracking accounts get a value log.
struct AccountDetailView: View {
    let accountId: Int
    let onChange: () -> Void

    private let accountsRepo = AccountsRepository()
    private let loanRepo = LoanRepository()

    @State private var account: Account?
    @State private var balanceCents = 0
    @State private var isEditPresented = false
    @State private var isAddTransactionPresented = false
    @State private var isCorrectBalancePresented = false
    @State private var correctedBalanceText = ""
    @State private var currentRatePercent: Double?
    @State private var remainingPrincipalCents = 0
    @State private var isAddRatePresented = false
    @State private var newRateText = ""
    @State private var trackingValueCents: Int?
    @State private var isLogValuePresented = false
    @State private var newValueText = ""
    @State private var homeValueCents = 0
    @State private var homeValueHistory: [(valueCents: Int, effectiveDate: String, note: String?)] = []
    @State private var monthlyPaymentCents = 0
    @State private var valueTrend: [(month: String, owedCents: Int, equityCents: Int)] = []

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(Money.wholeDollars(balanceCents))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(balanceCents < 0 ? Theme.negative : .white)
                        Button("+ Transaction") { isAddTransactionPresented = true }
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.top)

                    if let account, account.type == .loan || account.type == .mortgage {
                        loanCard(account: account)
                    }
                    if let account, account.type == .tracking {
                        trackingCard(account: account)
                    }
                    if let account, account.type == .creditCard {
                        creditCardCard(account: account)
                    }

                    TransactionsListView(accountId: accountId)
                        .frame(minHeight: 400)
                }
            }
        }
        .navigationTitle(account?.name ?? "Account")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit") { isEditPresented = true }
                    Button("Correct Balance") {
                        correctedBalanceText = String(format: "%.2f", Double(balanceCents) / 100)
                        isCorrectBalancePresented = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditPresented) {
            AccountFormView(account: account) { reload(); onChange() }
        }
        .sheet(isPresented: $isAddTransactionPresented) {
            AddTransactionView(preselectedAccountId: accountId)
        }
        .sheet(isPresented: $isCorrectBalancePresented) {
            correctBalanceSheet
        }
        .sheet(isPresented: $isAddRatePresented) {
            addRateSheet
        }
        .sheet(isPresented: $isLogValuePresented) {
            logValueSheet
        }
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .boardDidChange)) { _ in reload() }
    }

    /// Ported from budgets-bro's `LoanDetailsCard`/`HouseValueDetails` —
    /// Remaining Principal (red, big) beside Home Value, an Owed/Equity
    /// stat block over a two-line chart, the value-history log, and a
    /// "Loan Details" row linking to the payoff calculator.
    private func loanCard(account: Account) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("REMAINING PRINCIPAL").font(.caption2.bold()).foregroundStyle(Theme.textMuted)
                    Text(Money.wholeDollars(-remainingPrincipalCents)).font(.title2.bold()).foregroundStyle(Theme.negative)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("HOME VALUE").font(.caption2.bold()).foregroundStyle(Theme.textMuted)
                    Text(Money.wholeDollars(homeValueCents)).font(.title3.bold()).foregroundStyle(Theme.text)
                }
            }

            if homeValueCents > 0 {
                Divider().background(Theme.border)
                Text("Equity: \(Money.wholeDollars(homeValueCents - remainingPrincipalCents))")
                    .font(.caption).foregroundStyle(Theme.textMuted)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OWED").font(.caption2.bold()).foregroundStyle(Theme.textMuted)
                        Text(Money.wholeDollars(remainingPrincipalCents)).font(.subheadline.bold()).foregroundStyle(Theme.negative)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("EQUITY").font(.caption2.bold()).foregroundStyle(Theme.textMuted)
                        Text(Money.wholeDollars(homeValueCents - remainingPrincipalCents)).font(.subheadline.bold()).foregroundStyle(Theme.positive)
                    }
                }
                equityChart
            }

            ForEach(homeValueHistory, id: \.effectiveDate) { entry in
                HStack {
                    Text(Money.wholeDollars(entry.valueCents)).font(.subheadline.bold()).foregroundStyle(Theme.text)
                    Spacer()
                    Text("effective \(entry.effectiveDate)").font(.caption).foregroundStyle(Theme.textMuted)
                }
                .padding(.horizontal).padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            }
            Button("+ Update Home Value") { isLogValuePresented = true }
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)

            Divider().background(Theme.border)
            HStack {
                Text("LOAN DETAILS").font(.caption2.bold()).foregroundStyle(Theme.textMuted)
                Spacer()
                NavigationLink {
                    MortgageCalculatorView()
                } label: {
                    HStack(spacing: 4) {
                        Text(currentRatePercent.map { String(format: "%.3g%% · %@/mo", $0, Money.exact(monthlyPaymentCents)) } ?? "Add rate")
                            .font(.subheadline.bold())
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .foregroundStyle(Theme.text)
                }
            }
            Button("+ Add Rate") { isAddRatePresented = true }.foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal)
    }

    private var equityChart: some View {
        Chart {
            ForEach(Array(valueTrend.enumerated()), id: \.offset) { _, point in
                LineMark(x: .value("Month", point.month), y: .value("Owed", Double(point.owedCents) / 100))
                    .foregroundStyle(Theme.negative)
                AreaMark(x: .value("Month", point.month), y: .value("Owed", Double(point.owedCents) / 100))
                    .foregroundStyle(Theme.negative.opacity(0.25))
                LineMark(x: .value("Month", point.month), y: .value("Equity", Double(point.equityCents) / 100))
                    .foregroundStyle(Theme.positive)
                AreaMark(x: .value("Month", point.month), y: .value("Equity", Double(point.equityCents) / 100))
                    .foregroundStyle(Theme.positive.opacity(0.35))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis { AxisMarks(position: .leading) { _ in AxisValueLabel().foregroundStyle(Theme.textMuted) } }
        .frame(height: 130)
    }

    private func trackingCard(account: Account) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRACKING VALUE").font(.caption2.bold()).foregroundStyle(Theme.textMuted)
            HStack {
                Text("Current Value").foregroundStyle(Theme.text)
                Spacer()
                Text(trackingValueCents.map { Money.wholeDollars($0) } ?? "—").foregroundStyle(Theme.text)
            }
            Button("+ Log Value") { isLogValuePresented = true }.foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal)
    }

    /// "Can I pay this statement in full" derives from rows already
    /// stored, no schema change — see docs/DESIGN.md's Credit-card payment
    /// envelope backlog item. Simplified vs. spending-a-reserved-category
    /// tracking: the balance itself already nets every categorized charge
    /// and payment, so "what's owed" is exactly `abs(balanceCents)`.
    private func creditCardCard(account: Account) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CREDIT CARD").font(.caption2.bold()).foregroundStyle(Theme.textMuted)
            HStack {
                Text("Statement Balance (owed)").foregroundStyle(Theme.text)
                Spacer()
                Text(Money.wholeDollars(abs(min(balanceCents, 0)))).foregroundStyle(Theme.text)
            }
            Text("Already reserved in the categories it was charged to — paying this off doesn't need new money set aside.")
                .font(.caption2)
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal)
    }

    private var correctBalanceSheet: some View {
        NavigationStack {
            Form {
                TextField("Current balance", text: $correctedBalanceText)
                    .keyboardType(.numbersAndPunctuation)
                Text("Budgets Bro posts one uncategorized adjustment transaction for the difference.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Correct Balance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isCorrectBalancePresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { correctBalance() }
                }
            }
        }
    }

    private var addRateSheet: some View {
        NavigationStack {
            Form {
                TextField("Rate %", text: $newRateText).keyboardType(.decimalPad)
            }
            .navigationTitle("Add Rate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isAddRatePresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let rate = Double(newRateText) {
                            loanRepo.addRate(accountId: accountId, ratePercent: rate, effectiveDate: today())
                        }
                        newRateText = ""
                        isAddRatePresented = false
                        reload()
                    }
                }
            }
        }
    }

    private var logValueSheet: some View {
        NavigationStack {
            Form {
                TextField("Current value", text: $newValueText).keyboardType(.decimalPad)
            }
            .navigationTitle("Log Value")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isLogValuePresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let value = Double(newValueText) {
                            loanRepo.addValueReading(accountId: accountId, kind: "value", valueCents: Int((value * 100).rounded()), effectiveDate: today(), note: nil)
                        }
                        newValueText = ""
                        isLogValuePresented = false
                        reload()
                    }
                }
            }
        }
    }

    private func correctBalance() {
        guard let target = Double(correctedBalanceText) else { return }
        let targetCents = Int((target * 100).rounded())
        let difference = targetCents - balanceCents
        guard difference != 0 else {
            isCorrectBalancePresented = false
            return
        }
        let payeesRepo = PayeesRepository()
        let payeeId = payeesRepo.ensure(name: "Balance Adjustment")
        TransactionsRepository().create(accountId: accountId, categoryId: nil, payeeId: payeeId, memo: nil, amountCents: difference, date: today())
        isCorrectBalancePresented = false
        reload()
    }

    private func reload() {
        account = accountsRepo.all(includeArchived: true).first { $0.id == accountId }
        balanceCents = accountsRepo.balanceCents(accountId: accountId)
        if let account, account.type == .loan || account.type == .mortgage {
            currentRatePercent = loanRepo.currentRatePercent(accountId: accountId)
            remainingPrincipalCents = loanRepo.remainingPrincipalCents(account: account)
            homeValueHistory = loanRepo.valueHistory(accountId: accountId, kind: "value")
            homeValueCents = homeValueHistory.first?.valueCents ?? 0
            if let rate = currentRatePercent {
                monthlyPaymentCents = Amortization.monthlyPaymentCents(principalCents: remainingPrincipalCents, annualRatePercent: rate, termMonths: account.termMonths ?? 360)
            }
            let months = (0 ..< 12).reversed().compactMap { offset -> String? in
                Calendar.current.date(byAdding: .month, value: -offset, to: Date()).map { monthString(from: $0) }
            }
            // A real curve: each month's owed/value is whatever reading was
            // actually current as of that month's end, not today's figure
            // held flat — see LoanRepository.valueCents(asOf:).
            valueTrend = months.map { month in
                let asOf = "\(month)-28"
                let owed = loanRepo.valueCents(accountId: accountId, kind: "principal", asOf: asOf) ?? abs(account.openingBalanceCents)
                let value = loanRepo.valueCents(accountId: accountId, kind: "value", asOf: asOf) ?? 0
                return (month: month, owedCents: owed, equityCents: value - owed)
            }
        }
        if let account, account.type == .tracking {
            trackingValueCents = loanRepo.latestValueCents(accountId: accountId, kind: "value")
        }
    }
}
