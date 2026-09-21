import SwiftUI

/// Ranks purchase items by frequency, per docs/DESIGN.md's Purchase
/// Insights section. Exact cents, not whole dollars — the question is
/// whether an $8.40 item is now $9.20.
struct PurchaseInsightsView: View {
    private let transactionsRepo = TransactionsRepository()

    @State private var aggregates: [PurchaseItemAggregate] = []
    @State private var expanded: String?

    var body: some View {
        List {
            ForEach(aggregates) { aggregate in
                Section {
                    Button {
                        expanded = expanded == aggregate.id ? nil : aggregate.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(aggregate.name).foregroundStyle(.primary)
                                Text("\(aggregate.count)× · avg \(Money.exact(aggregate.averagePriceCents))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Money.exact(aggregate.latestPriceCents)).foregroundStyle(.secondary)
                        }
                    }
                    if expanded == aggregate.id {
                        ForEach(aggregate.occurrences.sorted { $0.date > $1.date }, id: \.transactionId) { occurrence in
                            HStack {
                                Text(occurrence.date).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(Money.exact(occurrence.priceCents)).font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Purchase Insights")
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .boardDidChange)) { _ in reload() }
    }

    private func reload() {
        aggregates = PurchaseInsights.aggregate(entries: transactionsRepo.allPurchaseItemEntries())
    }
}
