import Charts
import SwiftUI

/// ECB rates via frankfurter.app, no key — see docs/design/market-data/DESIGN.md.
struct ExchangeRatesView: View {
    @State private var base = "USD"
    @State private var target = "EUR"
    @State private var currentRate: Double?
    @State private var history: [(date: String, rate: Double)] = []
    @State private var isLoading = false

    private let currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CNY", "SGD"]

    var body: some View {
        Form {
            Section {
                Picker("From", selection: $base) {
                    ForEach(currencies, id: \.self) { Text($0) }
                }
                Picker("To", selection: $target) {
                    ForEach(currencies, id: \.self) { Text($0) }
                }
                if let currentRate {
                    LabeledContent("1 \(base) =", value: "\(String(format: "%.4f", currentRate)) \(target)")
                }
            }
            if !history.isEmpty {
                Section("Last 90 Days") {
                    Chart(history, id: \.date) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Rate", point.rate))
                            .foregroundStyle(Theme.accent)
                    }
                    .frame(height: 160)
                    .chartXAxis(.hidden)
                }
            }
        }
        .navigationTitle("Exchange Rates")
        .task { await reload() }
        .onChange(of: base) { _, _ in Task { await reload() } }
        .onChange(of: target) { _, _ in Task { await reload() } }
    }

    private func reload() async {
        isLoading = true
        let rates = await ExchangeRatesClient.latest(base: base)
        currentRate = rates?.rates[target]
        history = await ExchangeRatesClient.history(base: base, target: target, days: 90)
        isLoading = false
    }
}
