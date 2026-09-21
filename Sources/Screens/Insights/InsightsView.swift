import Charts
import SwiftUI

/// Ported from budgets-bro's `InsightsScreen.tsx` — month nav, a spending
/// breakdown stacked bar, a Top Categories legend list, a stacked-area
/// Category Trends chart (top 5 categories, dashed 12-month average,
/// toggleable legend), and a Utilities list of every sub-page.
struct InsightsView: View {
    private let categoriesRepo = CategoriesRepository()
    private let transactionsRepo = TransactionsRepository()

    /// Validated categorical palette from budgets-bro's dataviz skill —
    /// fixed order, never cycled, so a category keeps its color across
    /// sessions as long as its rank among the top 5 doesn't change.
    private static let seriesColors: [Color] = [
        Color(hex: 0x3987E5), Color(hex: 0xD95926), Color(hex: 0x199E70), Color(hex: 0xC98500), Color(hex: 0xD55181),
    ]
    private static let topN = 5

    @State private var month = currentMonth()
    @State private var breakdown: [(category: Category, spentCents: Int)] = []
    @State private var trendSeries: [(category: Category, values: [Int])] = []
    @State private var trendMonths: [String] = []
    @State private var hiddenCategoryIds: Set<Int> = []
    @State private var scrubIndex: Int?

    private var totalSpentCents: Int { breakdown.reduce(0) { $0 + $1.spentCents } }
    private var topCategories: [(category: Category, spentCents: Int)] { Array(breakdown.prefix(Self.topN)) }
    private var otherCents: Int { breakdown.dropFirst(Self.topN).reduce(0) { $0 + $1.spentCents } }

    private var visibleSeries: [(category: Category, values: [Int], color: Color)] {
        trendSeries.enumerated().compactMap { index, entry in
            hiddenCategoryIds.contains(entry.category.id) ? nil : (entry.category, entry.values, Self.seriesColors[index % Self.seriesColors.count])
        }
    }

    private var monthTotals: [Int] {
        guard !trendMonths.isEmpty else { return [] }
        return trendMonths.indices.map { i in visibleSeries.reduce(0) { $0 + $1.values[i] } }
    }

    private var averageCents: Int? {
        let priorTotals = monthTotals.dropLast()
        guard !priorTotals.isEmpty else { return nil }
        return priorTotals.reduce(0, +) / priorTotals.count
    }

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MonthNav(month: $month, onChange: reload)
                    breakdownCard
                    topCategoriesCard
                    trendCard
                    utilitiesSection
                    Color.clear.frame(height: 40)
                }
                .padding()
            }
        }
        .background(Theme.page)
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .boardDidChange)) { _ in reload() }
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SPENDING BREAKDOWN").font(.caption.bold()).foregroundStyle(Theme.textMuted)
            Text(Money.wholeDollars(totalSpentCents)).font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.text)
            HStack(spacing: 0) {
                ForEach(Array(topCategories.enumerated()), id: \.offset) { index, entry in
                    Self.seriesColors[index].frame(width: barWidth(entry.spentCents))
                }
                if otherCents > 0 {
                    Theme.textMuted.frame(width: barWidth(otherCents))
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private func barWidth(_ cents: Int) -> CGFloat {
        guard totalSpentCents > 0 else { return 0 }
        // Proportional share of a fixed reference width; SwiftUI HStack with
        // per-segment `.frame(width:)` needs a concrete number, not a percent.
        return CGFloat(Double(cents) / Double(totalSpentCents)) * 300
    }

    private var topCategoriesCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TOP CATEGORIES").font(.caption.bold()).foregroundStyle(Theme.textMuted)
            ForEach(Array(topCategories.enumerated()), id: \.offset) { index, entry in
                legendRow(color: Self.seriesColors[index], name: entry.category.displayName, cents: entry.spentCents)
            }
            if otherCents > 0 {
                legendRow(color: Theme.textMuted, name: "All Others", cents: otherCents)
            }
            if breakdown.isEmpty {
                Text("No spending this month").font(.subheadline).foregroundStyle(Theme.textMuted)
            }
        }
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private func legendRow(color: Color, name: String, cents: Int) -> some View {
        HStack {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(name).foregroundStyle(Theme.text)
            Spacer()
            Text(Money.wholeDollars(cents)).fontWeight(.bold).foregroundStyle(Theme.text)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Divider().background(Theme.border) }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORY TRENDS").font(.caption.bold()).foregroundStyle(Theme.textMuted)
            if let scrubIndex, trendMonths.indices.contains(scrubIndex) {
                Text("\(monthLabel(trendMonths[scrubIndex])) · \(Money.wholeDollars(monthTotals[scrubIndex]))")
                    .font(.subheadline.bold()).foregroundStyle(Theme.text)
            } else {
                Text("Drag along the chart to read a month").font(.caption2).foregroundStyle(Theme.textMuted)
            }

            if trendSeries.isEmpty {
                Text("Not enough history yet").font(.subheadline).foregroundStyle(Theme.textMuted)
            } else {
                stackedAreaChart
                legendChips
            }
        }
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var stackedAreaChart: some View {
        Chart {
            ForEach(visibleSeries, id: \.category.id) { entry in
                ForEach(Array(entry.values.enumerated()), id: \.offset) { i, value in
                    AreaMark(
                        x: .value("Month", i),
                        y: .value("Spent", Double(value) / 100),
                        stacking: .standard
                    )
                    .foregroundStyle(entry.color.opacity(0.55))
                }
            }
            if let average = averageCents {
                RuleMark(y: .value("Average", Double(average) / 100))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                if let i = value.as(Int.self), trendMonths.indices.contains(i) {
                    AxisValueLabel(monthShort(trendMonths[i])).foregroundStyle(Theme.textMuted)
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) { _ in AxisValueLabel().foregroundStyle(Theme.textMuted) } }
        .frame(height: 140)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let originX = geometry[proxy.plotAreaFrame].origin.x
                                guard let index: Int = proxy.value(atX: value.location.x - originX) else { return }
                                scrubIndex = max(0, min(trendMonths.count - 1, index))
                            }
                    )
            }
        }
    }

    private var legendChips: some View {
        FlowLayout(spacing: 10) {
            ForEach(trendSeries.indices, id: \.self) { index in
                let category = trendSeries[index].category
                let hidden = hiddenCategoryIds.contains(category.id)
                Button {
                    if hidden { hiddenCategoryIds.remove(category.id) } else { hiddenCategoryIds.insert(category.id) }
                } label: {
                    HStack(spacing: 4) {
                        Circle().fill(hidden ? Theme.border : Self.seriesColors[index % Self.seriesColors.count]).frame(width: 8, height: 8)
                        Text(category.displayName).font(.caption2)
                    }
                    .foregroundStyle(Theme.textMuted)
                    .opacity(hidden ? 0.4 : 1)
                }
            }
        }
    }

    private var utilitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Utilities").font(.title3.bold()).foregroundStyle(Theme.text)
                Text("Every sub-page here reads your real ledger and its own calculators.")
                    .font(.caption2).foregroundStyle(Theme.textMuted)
            }
            VStack(spacing: 0) {
                toolRow("Baby Steps") { BabyStepsView() }
                toolRow("Purchase Insights") { PurchaseInsightsView() }
                toolRow("Mortgage Calculator") { MortgageCalculatorView() }
                toolRow("Tax Insights") { TaxInsightsView() }
                toolRow("Exchange Rates") { ExchangeRatesView() }
                toolRow("Cost of Living") { CostOfLivingView() }
                toolRow("House Hunt") { HouseHuntView() }
                toolRow("Cashflow Runway") { CashflowRunwayView() }
                toolRow("FIRE Projection") { FIREProjectionView() }
                toolRow("Import Bank CSV") { GenericCSVImportView() }
                toolRow("AI Analysis", isLast: true) { AIAnalysisView() }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        }
    }

    private func toolRow(_ label: String, isLast: Bool = false, @ViewBuilder destination: () -> some View) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(label).font(.subheadline.bold()).foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Theme.textMuted)
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            if !isLast { Divider().background(Theme.border) }
        }
    }

    private func monthLabel(_ month: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: month) else { return month }
        let display = DateFormatter()
        display.dateFormat = "MMMM yyyy"
        return display.string(from: date)
    }

    private func monthShort(_ month: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: month) else { return month }
        let display = DateFormatter()
        display.dateFormat = "MMM"
        return display.string(from: date)
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

        let months = (0 ..< 12).reversed().compactMap { offset -> String? in
            Calendar.current.date(byAdding: .month, value: -offset, to: parseDate(month + "-01")).map { monthString(from: $0) }
        }
        trendMonths = months

        var totalsByCategory: [Int: (category: Category, total: Int)] = [:]
        var activityByMonth: [String: [Int: Int]] = [:]
        for m in months {
            let monthActivity = transactionsRepo.activityCentsByCategory(month: m)
            activityByMonth[m] = monthActivity
            for category in categories {
                let spent = -min(monthActivity[category.id] ?? 0, 0)
                guard spent > 0 else { continue }
                totalsByCategory[category.id, default: (category, 0)].total += spent
            }
        }
        let topCategoryIds = totalsByCategory.values.sorted { $0.total > $1.total }.prefix(Self.topN).map { $0.category.id }
        trendSeries = topCategoryIds.compactMap { id in
            guard let category = categories.first(where: { $0.id == id }) else { return nil }
            let values = months.map { m in -min(activityByMonth[m]?[id] ?? 0, 0) }
            return (category, values)
        }
    }
}

/// Minimal wrapping HStack for the trend chart's legend chips — SwiftUI has
/// no built-in flow layout pre-iOS 17's `Layout` protocol default, and a
/// fixed-column grid doesn't fit a variable number of category names.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
