import SwiftUI

/// Register + running balance for one account, per docs/design/uiux/accounts.md.
/// Editing/closing the account lives behind the header's Edit button; a
/// "+ Transaction" button pre-selects this account — this screen owns both,
/// not the Accounts list.
struct AccountDetailView: View {
    let accountId: Int
    let onChange: () -> Void

    private let accountsRepo = AccountsRepository()

    @State private var account: Account?
    @State private var balanceCents = 0
    @State private var isEditPresented = false
    @State private var isAddTransactionPresented = false

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(Money.wholeDollars(balanceCents))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(balanceCents < 0 ? Theme.negative : .white)
                    Button("+ Transaction") { isAddTransactionPresented = true }
                        .foregroundStyle(Theme.accent)
                }
                .padding()
                TransactionsListView(accountId: accountId)
            }
        }
        .navigationTitle(account?.name ?? "Account")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditPresented = true }
            }
        }
        .sheet(isPresented: $isEditPresented) {
            AccountFormView(account: account) { reload(); onChange() }
        }
        .sheet(isPresented: $isAddTransactionPresented) {
            AddTransactionView(preselectedAccountId: accountId)
        }
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .boardDidChange)) { _ in reload() }
    }

    private func reload() {
        account = accountsRepo.all(includeArchived: true).first { $0.id == accountId }
        balanceCents = accountsRepo.balanceCents(accountId: accountId)
    }
}
