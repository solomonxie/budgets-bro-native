import Charts
import SwiftUI

struct CashflowRunwayView: View {
    private let accountsRepo = AccountsRepository()
    private let scheduledRepo = ScheduledTransactionsRepository()

    @State private var points: [Cashflow.ProjectedPoint] = []

    var body: some View {
        Form {
            if let day30 = points.first(where: { $0.dayOffset == 30 }) {
                LabeledContent("In 30 days", value: Money.wholeDollars(day30.balanceCents))
            }
            if let day90 = points.last {
                LabeledContent("In 90 days", value: Money.wholeDollars(day90.balanceCents))
            }
            Chart(points, id: \.dayOffset) { point in
                LineMark(x: .value("Day", point.dayOffset), y: .value("Balance", Double(point.balanceCents) / 100))
                    .foregroundStyle(Theme.accent)
            }
            .frame(height: 200)
            Text("Projected from on-budget account balances plus every recurring schedule — one-off future spending isn't included.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Cashflow Runway")
        .task { reload() }
    }

    private func reload() {
        let accounts = accountsRepo.all().filter(\.onBudget)
        let balances = accountsRepo.balancesByAccountId()
        let startingBalance = accounts.reduce(0) { $0 + (balances[$1.id] ?? 0) }
        points = Cashflow.project(startingBalanceCents: startingBalance, schedules: scheduledRepo.all(), daysAhead: 90)
    }
}
