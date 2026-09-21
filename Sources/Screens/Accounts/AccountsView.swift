import Charts
import SwiftUI

/// Ported from budgets-bro's `AccountsScreen.tsx` — Net Worth card with a
/// Customize (include/exclude) link, Assets/Debts breakdown, a touch-to-read
/// trend chart, and each account as its own bordered card grouped by kind.
struct AccountsView: View {
    private let repository = AccountsRepository()

    @State private var accounts: [Account] = []
    @State private var balances: [Int: Int] = [:]
    @State private var isAddPresented = false
    @State private var isCustomizePresented = false
    @State private var excludedAccountIds: Set<Int> = []
    @State private var trend: [NetWorthPoint] = []
    @State private var selectedTrendIndex: Int?

    private static let kindOrder = ["Cash", "Savings", "Tracking", "Loan", "Credit"]

    private var groupedByKind: [(kind: String, accounts: [Account])] {
        let grouped = Dictionary(grouping: accounts) { $0.type.kind }
        return Self.kindOrder.compactMap { kind in
            guard let accountsInKind = grouped[kind], !accountsInKind.isEmpty else { return nil }
            return (kind, accountsInKind)
        }
    }

    private var includedAccounts: [Account] {
        accounts.filter { !excludedAccountIds.contains($0.id) }
    }

    private var netWorthCents: Int {
        includedAccounts.reduce(0) { $0 + (balances[$1.id] ?? 0) }
    }

    private var assetsCents: Int {
        includedAccounts.reduce(0) { $0 + max(0, balances[$1.id] ?? 0) }
    }

    private var debtsCents: Int {
        includedAccounts.reduce(0) { $0 + max(0, -(balances[$1.id] ?? 0)) }
    }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    netWorthCard
                    ForEach(groupedByKind, id: \.kind) { group in
                        accountGroup(kind: group.kind, accounts: group.accounts)
                    }
                    Button("+ Add Account") { isAddPresented = true }
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    Color.clear.frame(height: 40)
                }
                .padding()
            }
        }
        .background(Theme.page)
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddPresented) {
            AccountFormView(account: nil) { reload() }
        }
        .sheet(isPresented: $isCustomizePresented) {
            customizeSheet
        }
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .boardDidChange)) { _ in reload() }
    }

    private var netWorthCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("NET WORTH").font(.caption.bold()).foregroundStyle(Theme.textMuted)
                Spacer()
                Button("Customize") { isCustomizePresented = true }
                    .font(.caption.bold())
                    .foregroundStyle(Theme.accent)
            }
            Text(Money.wholeDollars(netWorthCents))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(netWorthCents < 0 ? Theme.negative : Theme.text)
            HStack(spacing: 16) {
                Text("Assets \(Money.wholeDollars(assetsCents))").font(.caption.bold()).foregroundStyle(Theme.textMuted)
                Text("Debts \(Money.wholeDollars(debtsCents))").font(.caption.bold()).foregroundStyle(Theme.textMuted)
            }
            if trend.count > 1 {
                netWorthChart
                Text("Touch the line, or hold and slide along it, to read a month.")
                    .font(.caption2).foregroundStyle(Theme.textMuted)
            }
        }
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var netWorthChart: some View {
        VStack(alignment: .leading, spacing: 2) {
            let selected = selectedTrendIndex.flatMap { trend.indices.contains($0) ? trend[$0] : nil }
            Text(selected.map { monthLabel($0.month) } ?? "").font(.caption).foregroundStyle(Theme.textMuted)
            Text(Money.wholeDollars(selected?.netWorthCents ?? trend.last?.netWorthCents ?? 0))
                .font(.subheadline.bold()).foregroundStyle(Theme.text)
            Chart(Array(trend.enumerated()), id: \.offset) { index, point in
                LineMark(x: .value("Month", index), y: .value("Net Worth", Double(point.netWorthCents) / 100))
                    .foregroundStyle(Theme.accent)
                AreaMark(x: .value("Month", index), y: .value("Net Worth", Double(point.netWorthCents) / 100))
                    .foregroundStyle(Theme.accent.opacity(0.2))
                if let selectedTrendIndex, selectedTrendIndex == index {
                    PointMark(x: .value("Month", index), y: .value("Net Worth", Double(point.netWorthCents) / 100))
                        .foregroundStyle(Theme.accent)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisValueLabel().foregroundStyle(Theme.textMuted) } }
            .frame(height: 130)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let originX = geometry[proxy.plotAreaFrame].origin.x
                                    guard let index: Int = proxy.value(atX: value.location.x - originX) else { return }
                                    selectedTrendIndex = max(0, min(trend.count - 1, index))
                                }
                                .onEnded { _ in }
                        )
                }
            }
        }
    }

    private var customizeSheet: some View {
        NavigationStack {
            List {
                ForEach(accounts) { account in
                    Button {
                        if excludedAccountIds.contains(account.id) { excludedAccountIds.remove(account.id) } else { excludedAccountIds.insert(account.id) }
                        reload()
                    } label: {
                        HStack {
                            Text(account.name).foregroundStyle(Theme.text)
                            Spacer()
                            Image(systemName: excludedAccountIds.contains(account.id) ? "square" : "checkmark.square.fill")
                                .foregroundStyle(excludedAccountIds.contains(account.id) ? Theme.textMuted : Theme.accent)
                        }
                    }
                }
            }
            .navigationTitle("Include in Net Worth")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isCustomizePresented = false }
                }
            }
        }
    }

    private func accountGroup(kind: String, accounts: [Account]) -> some View {
        let subtotal = accounts.reduce(0) { $0 + (balances[$1.id] ?? 0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(kind.uppercased()).font(.caption.bold()).foregroundStyle(Theme.textMuted)
                Spacer()
                Text(Money.wholeDollars(subtotal)).font(.caption.bold()).foregroundStyle(Theme.textMuted)
            }
            ForEach(accounts) { account in
                NavigationLink {
                    AccountDetailView(accountId: account.id, onChange: reload)
                } label: {
                    HStack {
                        Text(account.name).lineLimit(1).foregroundStyle(Theme.text).fontWeight(.semibold)
                        Spacer()
                        let balance = balances[account.id] ?? 0
                        Text(Money.wholeDollars(balance))
                            .fontWeight(.bold)
                            .foregroundStyle(balance < 0 ? Theme.negative : Theme.text)
                    }
                    .padding()
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                }
            }
        }
    }

    private func monthLabel(_ month: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: month) else { return month }
        let display = DateFormatter()
        display.dateFormat = "MMMM yyyy"
        return display.string(from: date)
    }

    private func reload() {
        accounts = repository.all()
        balances = repository.balancesByAccountId()

        let months = (0 ..< 12).reversed().compactMap { offset -> String? in
            Calendar.current.date(byAdding: .month, value: -offset, to: Date()).map { monthString(from: $0) }
        }
        trend = months.map { month in
            let total = includedAccounts.reduce(0) { $0 + repository.balanceCentsAsOf(accountId: $1.id, throughDate: "\(month)-31") }
            return NetWorthPoint(month: month, netWorthCents: total)
        }
    }
}

struct NetWorthPoint {
    let month: String
    let netWorthCents: Int
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
            repository.update(Account(id: account.id, name: name, type: type, onBudget: onBudget, currency: account.currency, openingBalanceCents: cents, archivedAt: account.archivedAt, termMonths: account.termMonths))
        } else {
            repository.create(name: name, type: type, onBudget: onBudget, openingBalanceCents: cents)
        }
        onSave()
        dismiss()
    }
}
