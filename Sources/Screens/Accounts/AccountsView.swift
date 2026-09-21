import SwiftUI

/// Per docs/design/uiux/accounts.md — Net Worth header, grouped-by-kind
/// list with subtotals, add/edit via a sheet.
struct AccountsView: View {
    private let repository = AccountsRepository()

    @State private var accounts: [Account] = []
    @State private var balances: [Int: Int] = [:]
    @State private var isAddPresented = false

    private static let kindOrder = ["Cash", "Savings", "Tracking", "Loan", "Credit"]

    private var groupedByKind: [(kind: String, accounts: [Account])] {
        let grouped = Dictionary(grouping: accounts) { $0.type.kind }
        return Self.kindOrder.compactMap { kind in
            guard let accountsInKind = grouped[kind], !accountsInKind.isEmpty else { return nil }
            return (kind, accountsInKind)
        }
    }

    private var netWorthCents: Int {
        accounts.reduce(0) { $0 + (balances[$1.id] ?? 0) }
    }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    netWorthCard
                    ForEach(groupedByKind, id: \.kind) { group in
                        accountGroup(kind: group.kind, accounts: group.accounts)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddPresented) {
            AccountFormView(account: nil) { reload() }
        }
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .boardDidChange)) { _ in reload() }
    }

    private var netWorthCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NET WORTH").font(.caption).foregroundStyle(.secondary)
            Text(Money.wholeDollars(netWorthCents))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(netWorthCents < 0 ? Theme.negative : .white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func accountGroup(kind: String, accounts: [Account]) -> some View {
        let subtotal = accounts.reduce(0) { $0 + (balances[$1.id] ?? 0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(kind.uppercased()).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(Money.wholeDollars(subtotal)).font(.caption).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(accounts) { account in
                    NavigationLink {
                        AccountDetailView(accountId: account.id, onChange: reload)
                    } label: {
                        HStack {
                            Text(account.name).lineLimit(1).foregroundStyle(.white)
                            Spacer()
                            let balance = balances[account.id] ?? 0
                            Text(Money.wholeDollars(balance))
                                .foregroundStyle(balance < 0 ? Theme.negative : .white)
                        }
                        .padding()
                    }
                    if account.id != accounts.last?.id {
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func reload() {
        accounts = repository.all()
        balances = repository.balancesByAccountId()
    }
}

struct AccountFormView: View {
    let account: Account?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var type: AccountType
    @State private var onBudget: Bool
    @State private var openingBalanceText: String

    private let repository = AccountsRepository()

    init(account: Account?, onSave: @escaping () -> Void) {
        self.account = account
        self.onSave = onSave
        _name = State(initialValue: account?.name ?? "")
        _type = State(initialValue: account?.type ?? .checking)
        _onBudget = State(initialValue: account?.onBudget ?? true)
        _openingBalanceText = State(initialValue: account.map { String(format: "%.2f", Double($0.openingBalanceCents) / 100) } ?? "0.00")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Account name", text: $name)
                Picker("Type", selection: $type) {
                    ForEach(AccountType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                Toggle("On budget", isOn: $onBudget)
                TextField("Starting balance", text: $openingBalanceText)
                    .keyboardType(.decimalPad)
                if let account {
                    Button("Close Account", role: .destructive) {
                        repository.archive(id: account.id)
                        onSave()
                        dismiss()
                    }
                }
            }
            .navigationTitle(account == nil ? "Add Account" : "Edit Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let cents = Int((Double(openingBalanceText) ?? 0) * 100)
        if let account {
            repository.update(Account(id: account.id, name: name, type: type, onBudget: onBudget, currency: account.currency, openingBalanceCents: cents, archivedAt: account.archivedAt))
        } else {
            repository.create(name: name, type: type, onBudget: onBudget, openingBalanceCents: cents)
        }
        onSave()
        dismiss()
    }
}
