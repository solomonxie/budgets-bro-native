import SwiftUI

/// Per docs/design/uiux/spend.md — amount pinned up top with a custom
/// number pad below it (not the system keyboard), outflow/inflow toggle,
/// searchable payee/category/account pickers, memo, date. Also edits an
/// existing transaction (pass `editingTransaction`), with a Delete action.
/// Repeat and Split are new-transaction-only, matching the original's own
/// scope cuts (a schedule/split is created once, not retroactively applied).
struct AddTransactionView: View {
    var preselectedAccountId: Int?
    var editingTransaction: TransactionListItem?

    @Environment(\.dismiss) private var dismiss

    private let accountsRepo = AccountsRepository()
    private let categoriesRepo = CategoriesRepository()
    private let payeesRepo = PayeesRepository()
    private let transactionsRepo = TransactionsRepository()
    private let scheduledRepo = ScheduledTransactionsRepository()

    @State private var amountDigits = "0"
    @State private var isOutflow = true
    @State private var accounts: [Account] = []
    @State private var categories: [Category] = []
    @State private var payees: [Payee] = []
    @State private var selectedAccountId: Int?
    @State private var selectedCategoryId: Int?
    @State private var payeeName = ""
    @State private var memo = ""
    @State private var purchaseItemsText = ""
    @State private var date = Date()
    @State private var isCleared = false
    @State private var isInterest = false
    @State private var isRepeating = false
    @State private var frequency: Frequency = .monthly
    @State private var intervalN = 1
    @State private var isSplit = false
    @State private var splitRows: [SplitRow] = []

    @State private var isAccountPickerPresented = false
    @State private var isCategoryPickerPresented = false
    @State private var isPayeePickerPresented = false

    private var amountCents: Int { Int(amountDigits) ?? 0 }

    private var amountDisplay: String {
        String(format: "$%d.%02d", amountCents / 100, amountCents % 100)
    }

    private var accountName: String { accounts.first { $0.id == selectedAccountId }?.name ?? "Choose" }
    private var categoryName: String { selectedCategoryId.flatMap { id in categories.first { $0.id == id }?.displayName } ?? "None" }

    private var splitRemainingCents: Int {
        amountCents - splitRows.reduce(0) { $0 + (Int(Double($1.amountText) ?? 0) * 100) }
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
                            .disabled(!canSave)
                        if editingTransaction != nil {
                            Button("Delete", role: .destructive) { delete() }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(editingTransaction == nil ? "Add Transaction" : "Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { load() }
            .sheet(isPresented: $isAccountPickerPresented) {
                SearchablePickerSheet(title: "Account", items: accounts.map { SearchablePickerItem(id: $0.id, title: $0.name) }) { item in
                    selectedAccountId = item.id
                }
            }
            .sheet(isPresented: $isCategoryPickerPresented) {
                SearchablePickerSheet(
                    title: "Category",
                    items: [SearchablePickerItem(id: -1, title: "None")] + categories.map { SearchablePickerItem(id: $0.id, title: $0.displayName) }
                ) { item in
                    selectedCategoryId = item.id == -1 ? nil : item.id
                }
            }
            .sheet(isPresented: $isPayeePickerPresented) {
                SearchablePickerSheet(
                    title: "Payee",
                    items: payees.map { SearchablePickerItem(id: $0.id, title: $0.name) },
                    onSelect: { payeeName = $0.title },
                    onCustom: { payeeName = $0 }
                )
            }
        }
    }

    private var canSave: Bool {
        guard selectedAccountId != nil, amountCents > 0 else { return false }
        return !isSplit || splitRemainingCents == 0
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
            PickerFieldButton(label: "Payee", value: payeeName.isEmpty ? "Choose" : payeeName) { isPayeePickerPresented = true }

            if !isSplit {
                PickerFieldButton(label: "Category", value: categoryName) { isCategoryPickerPresented = true }
            }

            PickerFieldButton(label: "Account", value: accountName) { isAccountPickerPresented = true }

            DatePicker(isRepeating ? "Starts" : "Date", selection: $date, displayedComponents: .date)

            Toggle("Cleared", isOn: $isCleared)
            if !isOutflow {
                Toggle("Interest income", isOn: $isInterest)
            }

            TextField("Memo", text: $memo)
                .textFieldStyle(.roundedBorder)

            TextField("Purchase items (name=price, name=price)", text: $purchaseItemsText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            if editingTransaction == nil {
                Toggle("Split", isOn: $isSplit)
                    .onChange(of: isSplit) { _, newValue in
                        if newValue, splitRows.isEmpty {
                            splitRows = [SplitRow(amountText: String(format: "%.2f", Double(amountCents) / 100))]
                        }
                    }
                if isSplit {
                    splitEditor
                }

                Toggle("Repeat", isOn: $isRepeating)
                if isRepeating {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(Frequency.allCases) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    Stepper("Every \(intervalN) \(frequency.displayName.lowercased())\(intervalN == 1 ? "" : "s")", value: $intervalN, in: 1 ... 30)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private var splitEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($splitRows) { $row in
                HStack {
                    Menu(row.categoryId.flatMap { id in categories.first { $0.id == id }?.displayName } ?? "Category") {
                        ForEach(categories) { category in
                            Button(category.displayName) { row.categoryId = category.id }
                        }
                    }
                    TextField("Amount", text: $row.amountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Button {
                        splitRows.removeAll { $0.id == row.id }
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(Theme.negative)
                    }
                }
            }
            Button("+ Add Split") { splitRows.append(SplitRow(amountText: "0.00")) }
                .foregroundStyle(Theme.accent)
            Text("Remaining: \(Money.exact(splitRemainingCents))")
                .font(.caption)
                .foregroundStyle(splitRemainingCents == 0 ? .secondary : Theme.negative)
        }
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    private func load() {
        accounts = accountsRepo.all()
        categories = categoriesRepo.categories()
        payees = payeesRepo.all()

        if let transaction = editingTransaction {
            amountDigits = String(abs(transaction.amountCents))
            isOutflow = transaction.amountCents < 0
            selectedAccountId = transaction.accountId
            selectedCategoryId = transaction.categoryId
            payeeName = transaction.payeeName ?? ""
            memo = transaction.memo ?? ""
            purchaseItemsText = transaction.purchaseItems ?? ""
            date = parseDate(transaction.date)
            isCleared = transaction.cleared
        } else if selectedAccountId == nil {
            selectedAccountId = preselectedAccountId ?? accounts.first?.id
        }
    }

    private func save() {
        guard let accountId = selectedAccountId, amountCents > 0 else { return }
        let payeeId = payeeName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : payeesRepo.ensure(name: payeeName)
        let signedCents = isOutflow ? -amountCents : amountCents
        let purchaseItems = purchaseItemsText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : purchaseItemsText

        if let editing = editingTransaction {
            transactionsRepo.update(Transaction(
                id: editing.id, accountId: accountId, categoryId: selectedCategoryId, payeeId: payeeId,
                memo: memo.isEmpty ? nil : memo, purchaseItems: purchaseItems, amountCents: signedCents, date: formatDate(date),
                cleared: isCleared, isInterest: isInterest, transferAccountId: editing.transferAccountId
            ))
        } else if isSplit {
            let newId = transactionsRepo.create(
                accountId: accountId, categoryId: nil, payeeId: payeeId,
                memo: memo.isEmpty ? nil : memo, purchaseItems: purchaseItems, amountCents: signedCents, date: formatDate(date),
                cleared: isCleared, isInterest: isInterest
            )
            let sign = isOutflow ? -1 : 1
            transactionsRepo.setSplits(transactionId: newId, splits: splitRows.map {
                (categoryId: $0.categoryId, amountCents: sign * Int((Double($0.amountText) ?? 0) * 100), memo: nil)
            })
        } else if isRepeating {
            scheduledRepo.create(
                accountId: accountId, categoryId: selectedCategoryId, payeeId: payeeId,
                memo: memo.isEmpty ? nil : memo, amountCents: signedCents, frequency: frequency,
                intervalN: intervalN, nextDate: formatDate(date), endDate: nil, isInterest: isInterest
            )
            AutoPostRunner.run()
        } else {
            transactionsRepo.create(
                accountId: accountId, categoryId: selectedCategoryId, payeeId: payeeId,
                memo: memo.isEmpty ? nil : memo, purchaseItems: purchaseItems, amountCents: signedCents, date: formatDate(date),
                cleared: isCleared, isInterest: isInterest
            )
        }
        dismiss()
    }

    private func delete() {
        if let editing = editingTransaction {
            transactionsRepo.delete(id: editing.id)
        }
        dismiss()
    }
}

private struct SplitRow: Identifiable {
    let id = UUID()
    var categoryId: Int?
    var amountText: String
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
