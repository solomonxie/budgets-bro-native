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

    private func loanCard(account: Account) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOAN").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("Remaining Principal").foregroundStyle(.white)
                Spacer()
                Text(Money.wholeDollars(remainingPrincipalCents)).foregroundStyle(.white)
            }
            HStack {
                Text("Rate").foregroundStyle(.white)
                Spacer()
                Text(currentRatePercent.map { String(format: "%.3f%%", $0) } ?? "—").foregroundStyle(.secondary)
            }
            Button("+ Add Rate") { isAddRatePresented = true }.foregroundStyle(Theme.accent)
            NavigationLink("Mortgage Calculator") {
                MortgageCalculatorView()
            }
            .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func trackingCard(account: Account) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRACKING VALUE").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("Current Value").foregroundStyle(.white)
                Spacer()
                Text(trackingValueCents.map { Money.wholeDollars($0) } ?? "—").foregroundStyle(.white)
            }
            Button("+ Log Value") { isLogValuePresented = true }.foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
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
        }
        if let account, account.type == .tracking {
            trackingValueCents = loanRepo.latestValueCents(accountId: accountId, kind: "value")
        }
    }
}
