import SwiftUI

/// Per docs/design/uiux/transactions.md — grouped by date, most recent
/// first. Search/multi-select are deferred (tracked in IMPLEMENTATION_PLAN).
struct TransactionsListView: View {
    var accountId: Int?

    private let repository = TransactionsRepository()

    @State private var items: [TransactionListItem] = []

    private var groupedByDate: [(date: String, items: [TransactionListItem])] {
        let grouped = Dictionary(grouping: items, by: \.date)
        return grouped.keys.sorted(by: >).map { (date: $0, items: grouped[$0] ?? []) }
    }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            List {
                ForEach(groupedByDate, id: \.date) { group in
                    Section(group.date) {
                        ForEach(group.items) { item in
                            row(item)
                        }
                        .onDelete { offsets in
                            for offset in offsets {
                                repository.delete(id: group.items[offset].id)
                            }
                            reload()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("History")
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .boardDidChange)) { _ in reload() }
    }

    private func row(_ item: TransactionListItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.payeeName ?? "No Payee").foregroundStyle(.white)
                Text([item.categoryName, item.accountName].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let memo = item.memo, !memo.isEmpty {
                    Text(memo).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(Money.wholeDollars(item.amountCents))
                .foregroundStyle(item.amountCents < 0 ? Theme.negative : Theme.positive)
        }
    }

    private func reload() {
        if let accountId {
            items = repository.forAccount(accountId: accountId)
        } else {
            items = repository.all()
        }
    }
}
