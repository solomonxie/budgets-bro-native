import SwiftUI

/// Ported from budgets-bro's `AddTransactionScreen.tsx` — amount pinned
/// above a calculator-style pad (real ÷×−+= arithmetic, not just digit
/// entry), one bordered field card (Payee/Category/Account/Date/Memo +
/// Advanced), a "Mark to repeat" pill in the header. Also edits an existing
/// transaction, with a Delete action.
///
/// Payee/Category/Account unfold **in place** under their own row (see
/// `ExpandingFieldGroup`/`DropdownField` in the original) rather than in a
/// sheet — the form stays visible, there's no modal transition between
/// "what I typed" and "what I'm picking", and only one panel is open at a
/// time.
struct AddTransactionView: View {
    var preselectedAccountId: Int?
    var editingTransaction: TransactionListItem?

    @Environment(\.dismiss) private var dismiss

    private let accountsRepo = AccountsRepository()
    private let categoriesRepo = CategoriesRepository()
    private let payeesRepo = PayeesRepository()
    private let transactionsRepo = TransactionsRepository()
    private let scheduledRepo = ScheduledTransactionsRepository()

    private enum ExpandableField { case payee, category, account }

    @State private var amount = AmountExpression.empty
    @State private var isOutflow = true
    @State private var accounts: [Account] = []
    @State private var categories: [Category] = []
    @State private var groups: [CategoryGroup] = []
    @State private var payees: [Payee] = []
    @State private var selectedAccountId: Int?
    @State private var selectedCategoryId: Int?
    @State private var payeeName = ""
    @State private var memo = ""
    @State private var purchaseItemsText = ""
    @State private var isAdvancedExpanded = false
    @State private var date = Date()
    @State private var isCleared = false
    @State private var isInterest = false
    @State private var isRepeating = false
    @State private var frequency: Frequency = .monthly
    @State private var intervalN = 1
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var isSplit = false
    @State private var splitRows: [SplitRow] = []

    @State private var expandedField: ExpandableField?

    private var amountCents: Int { AmountMath.cents(amount) }
    private var amountDisplay: String {
        let formatted = AmountMath.format(amount)
        return formatted.isEmpty ? "$0.00" : formatted
    }

    private var selectedAccount: Account? { accounts.first { $0.id == selectedAccountId } }
    private var takesCategory: Bool { isOutflow && (selectedAccount?.type.isSpendingType ?? true) }
    private var accountName: String { selectedAccount?.name ?? "Choose" }
    private var categoryName: String { selectedCategoryId.flatMap { id in categories.first { $0.id == id }?.displayName } ?? "" }
    private var accountLocked: Bool { preselectedAccountId != nil }

    private var filteredPayees: [Payee] {
        guard !payeeName.isEmpty else { return payees }
        return payees.filter { $0.name.localizedCaseInsensitiveContains(payeeName) }
    }

    private var splitRemainingCents: Int {
        amountCents - splitRows.reduce(0) { $0 + Int((Double($1.amountText) ?? 0) * 100) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                amountHeader
                ScrollView {
                    VStack(spacing: 12) {
                        fieldCard
                        if isRepeating { repeatFields }
                        if isSplit { splitEditor }
                        NumberPad(amount: $amount, submitLabel: "Save", onSubmit: save)
                            .padding(.horizontal)
                        if editingTransaction != nil {
                            Button("Delete", role: .destructive) { delete() }
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .background(Theme.page)
            .navigationTitle(editingTransaction == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
                if editingTransaction == nil, isOutflow {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isRepeating.toggle()
                        } label: {
                            Text(isRepeating ? "✓ Repeating" : "Mark to repeat")
                                .font(.caption.bold())
                                .padding(.vertical, 5)
                                .padding(.horizontal, 12)
                                .background(isRepeating ? Theme.accent : Color.clear, in: Capsule())
                                .overlay(Capsule().stroke(Theme.border, lineWidth: isRepeating ? 0 : 1))
                                .foregroundStyle(isRepeating ? .white : Theme.textMuted)
                        }
                    }
                }
            }
            .task { load() }
        }
    }

    private var amountHeader: some View {
        VStack(spacing: 12) {
            Text(amountDisplay)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(amountCents == 0 ? Theme.textMuted : Theme.text)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            HStack(spacing: 3) {
                segmentButton("Spending", isActive: isOutflow) { isOutflow = true }
                segmentButton("Income", isActive: !isOutflow) {
                    isOutflow = false
                    isRepeating = false
                }
            }
            .padding(3)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private func segmentButton(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isActive ? .white : Theme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isActive ? Theme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 11))
        }
    }

    private var fieldCard: some View {
        VStack(spacing: 0) {
            expandableRow(field: .payee, label: "Payee", value: payeeName.isEmpty ? nil : payeeName, placeholder: "Payee")
            if expandedField == .payee { payeePanel }
            Divider().background(Theme.border)

            if takesCategory {
                expandableRow(field: .category, label: "Category", value: categoryName.isEmpty ? nil : categoryName, placeholder: "Category")
                if expandedField == .category { categoryPanel }
                Divider().background(Theme.border)
            }

            if accountLocked {
                fieldRow(label: "Account", value: accountName, placeholder: nil, action: nil)
            } else {
                expandableRow(field: .account, label: "Account", value: accountName == "Choose" ? nil : accountName, placeholder: "Account")
                if expandedField == .account { accountPanel }
            }
            Divider().background(Theme.border)

            DatePicker(isRepeating ? "Starts" : "Date", selection: $date, displayedComponents: .date)
                .padding(.horizontal).padding(.vertical, 12)
                .tint(Theme.accent)
            Divider().background(Theme.border)
            HStack {
                Toggle("Cleared", isOn: $isCleared)
                if !isOutflow {
                    Divider().frame(height: 20)
                    Toggle("Interest", isOn: $isInterest)
                }
            }
            .padding(.horizontal).padding(.vertical, 8)
            .tint(Theme.accent)
            Divider().background(Theme.border)
            VStack(alignment: .leading, spacing: 2) {
                if !memo.isEmpty { Text("Memo").font(.caption2).foregroundStyle(Theme.textMuted) }
                TextField("Memo", text: $memo, axis: .vertical)
                    .foregroundStyle(Theme.text)
            }
            .padding(.horizontal).padding(.vertical, 12)
            Divider().background(Theme.border)
            advancedSection
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal)
    }

    /// A row that unfolds its own panel directly below itself — one open at
    /// a time (`expandedField`), matching `ExpandingFieldGroup`.
    private func expandableRow(field: ExpandableField, label: String, value: String?, placeholder: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedField = (expandedField == field ? nil : field)
            }
        } label: {
            HStack {
                if let value {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label).font(.caption2).foregroundStyle(Theme.textMuted)
                        Text(value).foregroundStyle(Theme.text)
                    }
                } else {
                    Text(placeholder).foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(expandedField == field ? Theme.accent : Theme.textMuted)
                    .rotationEffect(.degrees(expandedField == field ? 180 : 0))
            }
            .padding(.horizontal).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var payeePanel: some View {
        VStack(spacing: 0) {
            TextField("Search or type a new payee", text: $payeeName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .padding(.horizontal).padding(.vertical, 8)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredPayees) { payee in
                        optionRow(label: payee.name, isSelected: payee.name == payeeName) {
                            payeeName = payee.name
                            closeExpanded()
                        }
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .background(Theme.page)
    }

    private var categoryPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                optionRow(label: "Uncategorized", isSelected: selectedCategoryId == nil) {
                    selectedCategoryId = nil
                    closeExpanded()
                }
                ForEach(sortedGroups) { group in
                    let groupCategories = categories.filter { $0.groupId == group.id }
                    if !groupCategories.isEmpty {
                        Text(group.name.uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.textMuted)
                            .padding(.horizontal).padding(.top, 10).padding(.bottom, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(groupCategories) { category in
                            optionRow(label: category.displayName, isSelected: selectedCategoryId == category.id) {
                                selectedCategoryId = category.id
                                closeExpanded()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 260)
        .background(Theme.page)
    }

    private var accountPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(accounts) { account in
                    optionRow(label: account.name, isSelected: selectedAccountId == account.id) {
                        selectedAccountId = account.id
                        if !(account.type.isSpendingType) { selectedCategoryId = nil }
                        closeExpanded()
                    }
                }
            }
        }
        .frame(maxHeight: 220)
        .background(Theme.page)
    }

    private func optionRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack {
                    Text(label)
                        .foregroundStyle(isSelected ? Theme.accent : Theme.text)
                        .fontWeight(isSelected ? .bold : .regular)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                    }
                }
                .padding(.horizontal).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider().background(Theme.border)
        }
    }

    private var sortedGroups: [CategoryGroup] {
        groups.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func closeExpanded() {
        withAnimation(.easeInOut(duration: 0.2)) { expandedField = nil }
    }

    private func fieldRow(label: String, value: String?, placeholder: String?, action: (() -> Void)?) -> some View {
        let content = HStack {
            if let value {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.caption2).foregroundStyle(Theme.textMuted)
                    Text(value).foregroundStyle(Theme.text)
                }
            } else {
                Text(placeholder ?? label).foregroundStyle(Theme.textMuted)
            }
            Spacer()
            if action != nil {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textMuted)
            }
        }
        .padding(.horizontal).padding(.vertical, 12)
        .contentShape(Rectangle())

        return Group {
            if let action {
                Button(action: action) { content }
            } else {
                content
            }
        }
    }

    private var advancedSection: some View {
        VStack(spacing: 0) {
            Button {
                isAdvancedExpanded.toggle()
            } label: {
                HStack {
                    Text("Advanced").foregroundStyle(Theme.textMuted)
                    Spacer()
                    if !purchaseItemsText.isEmpty {
                        Text(purchaseItemsText).font(.caption).foregroundStyle(Theme.textMuted).lineLimit(1)
                    }
                    Image(systemName: isAdvancedExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption).foregroundStyle(Theme.textMuted)
                }
                .padding(.horizontal).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            if isAdvancedExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Purchase Items").font(.caption2).foregroundStyle(Theme.textMuted)
                    TextField("name=price, name=price", text: $purchaseItemsText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    Toggle("Split across categories", isOn: $isSplit)
                        .tint(Theme.accent)
                }
                .padding(.horizontal).padding(.bottom, 12)
            }
        }
    }

    private var repeatFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Frequency", selection: $frequency) {
                ForEach(Frequency.allCases) { frequency in
                    Text(frequency.displayName).tag(frequency)
                }
            }
            .pickerStyle(.segmented)
            Stepper("Every \(intervalN) \(frequency.displayName.lowercased())\(intervalN == 1 ? "" : "s")", value: $intervalN, in: 1 ... 30)
            Toggle("End date", isOn: $hasEndDate).tint(Theme.accent)
            if hasEndDate {
                DatePicker("Ends", selection: $endDate, displayedComponents: .date)
            }
        }
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal)
        .foregroundStyle(Theme.text)
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
                .foregroundStyle(splitRemainingCents == 0 ? Theme.textMuted : Theme.negative)
        }
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal)
        .foregroundStyle(Theme.text)
    }

    private func load() {
        accounts = accountsRepo.all()
        categories = categoriesRepo.categories()
        groups = categoriesRepo.groups()
        payees = payeesRepo.all()

        if let transaction = editingTransaction {
            amount = AmountExpression(digits: String(abs(transaction.amountCents)))
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
        let categoryToSave = takesCategory ? selectedCategoryId : nil

        if let editing = editingTransaction {
            transactionsRepo.update(Transaction(
                id: editing.id, accountId: accountId, categoryId: categoryToSave, payeeId: payeeId,
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
                accountId: accountId, categoryId: categoryToSave, payeeId: payeeId,
                memo: memo.isEmpty ? nil : memo, amountCents: signedCents, frequency: frequency,
                intervalN: intervalN, nextDate: formatDate(date), endDate: hasEndDate ? formatDate(endDate) : nil, isInterest: isInterest
            )
            AutoPostRunner.run()
        } else {
            transactionsRepo.create(
                accountId: accountId, categoryId: categoryToSave, payeeId: payeeId,
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

/// Ported from budgets-bro's `NumberPad.tsx` — 3 digit columns beside 2
/// narrower calculator-operator columns, real ÷×−+= arithmetic
/// (`AmountExpression`), not just cents entry.
private struct NumberPad: View {
    @Binding var amount: AmountExpression
    let submitLabel: String
    let onSubmit: () -> Void

    private let rows: [(digits: [String], ops: [String])] = [
        (["1", "2", "3"], ["÷", "×"]),
        (["4", "5", "6"], ["−", "+"]),
        (["7", "8", "9"], ["=", "⌫"]),
        (["0"], ["submit"]),
    ]

    var body: some View {
        // 3 digit columns (flex 9) beside 2 operator columns (flex 4),
        // matching NumberPad.tsx exactly — HStack alone can't express that
        // ratio, so the two blocks are sized off the measured total width.
        GeometryReader { geometry in
            let gap: CGFloat = 6
            let digitWidth = (geometry.size.width - gap) * 9 / 13
            let opWidth = geometry.size.width - gap - digitWidth
            VStack(spacing: gap) {
                ForEach(rows.indices, id: \.self) { index in
                    let row = rows[index]
                    HStack(spacing: gap) {
                        HStack(spacing: gap) {
                            ForEach(row.digits, id: \.self) { key(for: $0) }
                        }
                        .frame(width: digitWidth)
                        HStack(spacing: gap) {
                            ForEach(row.ops, id: \.self) { key(for: $0) }
                        }
                        .frame(width: opWidth)
                    }
                }
            }
        }
        .frame(height: CGFloat(rows.count) * 52 + CGFloat(rows.count - 1) * 6)
    }

    @ViewBuilder
    private func key(for symbol: String) -> some View {
        if symbol == "submit" {
            Button(action: onSubmit) {
                Text(submitLabel)
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
            }
        } else {
            Button {
                amount = AmountMath.press(amount, key(forSymbol: symbol))
            } label: {
                Text(symbol)
                    .font(isOperator(symbol) ? .title3.weight(.semibold) : .title2)
                    .foregroundStyle(isOperator(symbol) ? Theme.accent : (symbol == "⌫" ? Theme.textMuted : Theme.text))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func isOperator(_ symbol: String) -> Bool {
        ["÷", "×", "−", "+", "="].contains(symbol)
    }

    private func key(forSymbol symbol: String) -> AmountKey {
        switch symbol {
        case "÷": .op(.divide)
        case "×": .op(.multiply)
        case "−": .op(.subtract)
        case "+": .op(.add)
        case "=": .equals
        case "⌫": .backspace
        default: .digit(Character(symbol))
        }
    }
}
