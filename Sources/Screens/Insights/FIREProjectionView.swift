import SwiftUI

struct FIREProjectionView: View {
    @State private var netWorthText = "50000"
    @State private var monthlySavingsText = "2000"
    @State private var returnPercentText = "7"
    @State private var annualSpendingText = "40000"
    @State private var withdrawalRateText = "4"

    private var monthsToFI: Int? {
        FIREProjection.monthsToIndependence(
            currentNetWorthCents: Int((Double(netWorthText) ?? 0) * 100),
            monthlyContributionCents: Int((Double(monthlySavingsText) ?? 0) * 100),
            annualReturnPercent: Double(returnPercentText) ?? 0,
            targetNetWorthCents: FIREProjection.targetNetWorthCents(
                annualSpendingCents: Int((Double(annualSpendingText) ?? 0) * 100),
                safeWithdrawalRatePercent: Double(withdrawalRateText) ?? 4
            )
        )
    }

    var body: some View {
        Form {
            Section("Today") {
                LabeledContent("Net worth") { TextField("0", text: $netWorthText).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                LabeledContent("Monthly savings") { TextField("0", text: $monthlySavingsText).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                LabeledContent("Expected return %") { TextField("7", text: $returnPercentText).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
            }
            Section("Target") {
                LabeledContent("Annual spending") { TextField("0", text: $annualSpendingText).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                LabeledContent("Safe withdrawal rate %") { TextField("4", text: $withdrawalRateText).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
            }
            Section("Result") {
                if let months = monthsToFI {
                    LabeledContent("Years to independence", value: String(format: "%.1f", Double(months) / 12))
                } else {
                    Text("Not reachable within 100 years at this savings rate.").foregroundStyle(Theme.negative)
                }
            }
        }
        .navigationTitle("FIRE Projection")
    }
}
