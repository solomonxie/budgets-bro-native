import SwiftUI

/// Per docs/design/uiux/transactions.md — grouped by date, most recent
/// first, search + multi-select bulk delete, tap a row to edit it.
struct TransactionsListView: View {
    var accountId: Int?

    private let repository = TransactionsRepository()

    @State private var items: [TransactionListItem] = []
    @State private var searchText = ""
    @State private var editingTransaction: TransactionListItem?
    @State private var selection = Set<Int>()
    @Environment(\.editMode) private var editMode

    private var filteredItems: [TransactionListItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            ($0.payeeName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.memo?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var groupedByDate: [(date: String, items: [TransactionListItem])] {
        let grouped = Dictionary(grouping: filteredItems, by: \.date)
        return grouped.keys.sorted(by: >).map { (date: $0, items: grouped[$0] ?? []) }
    }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            List(selection: $selection) {
                ForEach(groupedByDate, id: \.date) { group in
                    Section(group.date) {
                        ForEach(group.items) { item in
                            row(item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if editMode?.wrappedValue.isEditing != true {
                                        editingTransaction = item
                                    }
                                }
                                .tag(item.id)
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
            .searchable(text: $searchText)
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            if editMode?.wrappedValue.isEditing == true, !selection.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    Button("Delete \(selection.count)", role: .destructive) {
                        for id in selection { repository.delete(id: id) }
                        selection.removeAll()
                        reload()
                    }
                }
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            AddTransactionView(editingTransaction: transaction)
        }
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
        items = accountId.map(repository.forAccount) ?? repository.all()
    }
}
