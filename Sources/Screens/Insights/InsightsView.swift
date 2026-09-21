import SwiftUI

/// Per docs/design/uiux/insights.md — on-device only, no network. Month
/// picker + spending breakdown for now; category trend chart, Baby Steps,
/// Tax Insights, Purchase Insights are Backlog per IMPLEMENTATION_PLAN.md.
struct InsightsView: View {
    private let categoriesRepo = CategoriesRepository()
    private let transactionsRepo = TransactionsRepository()

    @State private var month = currentMonth()
    @State private var breakdown: [(category: Category, spentCents: Int)] = []

    private var totalSpentCents: Int {
        breakdown.reduce(0) { $0 + $1.spentCents }
    }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SPENDING THIS MONTH").font(.caption).foregroundStyle(.secondary)
                        Text(Money.wholeDollars(totalSpentCents)).font(.title.bold()).foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))

                    VStack(spacing: 0) {
                        ForEach(breakdown, id: \.category.id) { entry in
                            HStack {
                                Text(entry.category.displayName).foregroundStyle(.white)
                                Spacer()
                                Text(Money.wholeDollars(entry.spentCents)).foregroundStyle(.secondary)
                            }
                            .padding()
                            if entry.category.id != breakdown.last?.category.id {
                                Divider().background(Color.white.opacity(0.1))
                            }
                        }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))

                    NavigationLink("Mortgage Calculator") { MortgageCalculatorView() }
                        .foregroundStyle(Theme.accent)
                }
                .padding()
            }
        }
        .navigationTitle("Insights")
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .boardDidChange)) { _ in reload() }
    }

    private func reload() {
        let categories = categoriesRepo.categories()
        let activity = transactionsRepo.activityCentsByCategory(month: month)
        breakdown = categories
            .compactMap { category -> (Category, Int)? in
                let spent = -min(activity[category.id] ?? 0, 0)
                guard spent > 0 else { return nil }
                return (category, spent)
            }
            .sorted { $0.1 > $1.1 }
    }
}
