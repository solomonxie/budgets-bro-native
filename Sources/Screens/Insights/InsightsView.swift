import Charts
import SwiftUI

/// Per docs/design/uiux/insights.md — on-device only, no network. Spending
/// breakdown for the current month + a trailing 6-month trend. Baby Steps,
/// Tax Insights, Purchase Insights remain Backlog per IMPLEMENTATION_PLAN.md.
struct InsightsView: View {
    private let categoriesRepo = CategoriesRepository()
    private let transactionsRepo = TransactionsRepository()

    @State private var month = currentMonth()
    @State private var breakdown: [(category: Category, spentCents: Int)] = []
    @State private var trend: [(month: String, spentCents: Int)] = []

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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("6 MONTH TREND").font(.caption).foregroundStyle(.secondary)
                        Chart(trend, id: \.month) { point in
                            LineMark(x: .value("Month", point.month), y: .value("Spent", Double(point.spentCents) / 100))
                                .foregroundStyle(Theme.accent)
                            AreaMark(x: .value("Month", point.month), y: .value("Spent", Double(point.spentCents) / 100))
                                .foregroundStyle(Theme.accent.opacity(0.15))
                        }
                        .frame(height: 140)
                        .chartYAxis { AxisMarks(position: .leading) }
                    }
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
                    NavigationLink("AI Analysis") { AIAnalysisView() }
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

        let months = lastSixMonths()
        trend = months.map { ($0, transactionsRepo.totalSpentCents(month: $0)) }
    }

    private func lastSixMonths() -> [String] {
        let calendar = Calendar.current
        return (0 ..< 6).reversed().compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: Date()).map { monthString(from: $0) }
        }
    }
}
