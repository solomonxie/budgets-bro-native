import SwiftUI

/// Per docs/design/uiux/spend.md — amount pinned up top with a custom
/// number pad below it (not the system keyboard), outflow/inflow toggle,
/// payee/category/account pickers, memo, date.
struct AddTransactionView: View {
    var preselectedAccountId: Int?

    @Environment(\.dismiss) private var dismiss

    private let accountsRepo = AccountsRepository()
    private let categoriesRepo = CategoriesRepository()
    private let payeesRepo = PayeesRepository()
    private let transactionsRepo = TransactionsRepository()

    @State private var amountDigits = "0"
    @State private var isOutflow = true
    @State private var accounts: [Account] = []
    @State private var categories: [Category] = []
    @State private var payees: [Payee] = []
    @State private var selectedAccountId: Int?
    @State private var selectedCategoryId: Int?
    @State private var payeeName = ""
    @State private var memo = ""
    @State private var date = Date()

    private var amountCents: Int { Int(amountDigits) ?? 0 }

    private var amountDisplay: String {
        let dollars = amountCents / 100
        let cents = amountCents % 100
        return String(format: "$%d.%02d", dollars, cents)
    }

    private var payeeSuggestions: [Payee] {
        guard !payeeName.isEmpty else { return [] }
        return payees.filter { $0.name.localizedCaseInsensitiveContains(payeeName) }.prefix(5).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.page.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        amountHeader
                        NumberPad(digits: $amountDigits)
                        formFields
                        Button("Save") { save() }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.black)
                            .disabled(selectedAccountId == nil || amountCents == 0)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { load() }
        }
    }

    private var amountHeader: some View {
        VStack(spacing: 8) {
            Text(amountDisplay)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(isOutflow ? Theme.negative : Theme.positive)
            Picker("Direction", selection: $isOutflow) {
                Text("Outflow").tag(true)
                Text("Inflow").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Payee", text: $payeeName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                if !payeeSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(payeeSuggestions) { payee in
                                Button(payee.name) { payeeName = payee.name }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            Picker("Category", selection: $selectedCategoryId) {
                Text("None").tag(Int?.none)
                ForEach(categories) { category in
                    Text(category.displayName).tag(Optional(category.id))
                }
            }

            Picker("Account", selection: $selectedAccountId) {
                ForEach(accounts) { account in
                    Text(account.name).tag(Optional(account.id))
                }
            }

            DatePicker("Date", selection: $date, displayedComponents: .date)

            TextField("Memo", text: $memo)
                .textFieldStyle(.roundedBorder)
        }
        .foregroundStyle(.white)
    }

    private func load() {
        accounts = accountsRepo.all()
        categories = categoriesRepo.categories()
        payees = payeesRepo.all()
        if selectedAccountId == nil { selectedAccountId = preselectedAccountId ?? accounts.first?.id }
    }

    private func save() {
        guard let accountId = selectedAccountId, amountCents > 0 else { return }
        let payeeId = payeeName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : payeesRepo.ensure(name: payeeName)
        transactionsRepo.create(
            accountId: accountId,
            categoryId: selectedCategoryId,
            payeeId: payeeId,
            memo: memo.isEmpty ? nil : memo,
            amountCents: isOutflow ? -amountCents : amountCents,
            date: formatDate(date)
        )
        dismiss()
    }
}

/// Ordinary page content, not the system keypad or a pinned bar — per
/// docs/design/uiux/spend.md.
private struct NumberPad: View {
    @Binding var digits: String

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["C", "0", "⌫"],
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            tap(key)
                        } label: {
                            Text(key)
                                .font(.title2)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func tap(_ key: String) {
        switch key {
        case "C":
            digits = "0"
        case "⌫":
            digits = digits.count > 1 ? String(digits.dropLast()) : "0"
        default:
            guard digits.count < 9 else { return }
            digits = digits == "0" ? key : digits + key
        }
    }
}
