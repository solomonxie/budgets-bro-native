import SwiftUI

/// Compiled city estimates converted with the Exchange Rates page's cached
/// rates, next to the user's own 6-month average spend. Simplified vs. the
/// original: one total per city, no per-category bucket mapping. See
/// docs/design/market-data/DESIGN.md and IMPLEMENTATION_PLAN.md.
struct CostOfLivingView: View {
    private let transactionsRepo = TransactionsRepository()

    @State private var userAverageMonthlyCents = 0
    @State private var rows: [(city: String, costInBaseCents: Int)] = []
    @State private var isLoading = true

    var body: some View {
        List {
            Section {
                LabeledContent("Your 6-month average", value: Money.wholeDollars(userAverageMonthlyCents))
            }
            Section("Estimated Monthly Cost (converted to USD)") {
                ForEach(rows, id: \.city) { row in
                    HStack {
                        Text(row.city)
                        Spacer()
                        Text(Money.wholeDollars(row.costInBaseCents))
                            .foregroundStyle(row.costInBaseCents > userAverageMonthlyCents ? Theme.negative : Theme.positive)
                    }
                }
            }
            Text("A dated, compiled estimate — not a live figure. See docs/design/market-data/DESIGN.md.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Cost of Living")
        .task { await reload() }
    }

    private func reload() async {
        let months = (0 ..< 6).compactMap { offset in
            Calendar.current.date(byAdding: .month, value: -offset, to: Date()).map { monthString(from: $0) }
        }
        let total = months.reduce(0) { $0 + transactionsRepo.totalSpentCents(month: $1) }
        userAverageMonthlyCents = months.isEmpty ? 0 : total / months.count

        let rates = await ExchangeRatesClient.latest(base: "USD")
        rows = CostOfLivingData.cities.map { city in
            guard city.currency != "USD", let rate = rates?.rates[city.currency], rate > 0 else {
                return (city.city, Int(city.monthlyCostLocal * 100))
            }
            return (city.city, Int(city.monthlyCostLocal / rate * 100))
        }
        isLoading = false
    }
}
