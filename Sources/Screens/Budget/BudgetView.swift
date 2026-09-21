import SwiftUI

/// Ported from budgets-bro's `BudgetScreen.tsx` — summary card with a
/// 12-month compare and an Unassigned Cash breakdown disclosure,
/// collapsible category groups, a status-pill + 2-segment progress bar +
/// caption per category. Category management (add/rename/delete/move) is
/// inline, matching the current UX.
struct BudgetView: View {
    private let categoriesRepo = CategoriesRepository()
    private let budgetRepo = BudgetRepository()
    private let transactionsRepo = TransactionsRepository()

    @State private var month = currentMonth()
    @State private var groups: [CategoryGroup] = []
    @State private var categoriesByGroup: [Int: [Category]] = [:]
    @State private var assignedThisMonth: [Int: Int] = [:]
    @State private var activityThisMonth: [Int: Int] = [:]
    @State private var balanceThroughMonth: [Int: Int] = [:]
    @State private var unassignedCents = 0
    @State private var spentThisMonthCents = 0
    @State private var avgMonthlySpentCents: Int?
    @State private var isBreakdownOpen = false
    @State private var uncategorizedAllTimeCents = 0
    @State private var assignedAllTimeCents = 0
    @State private var collapsedGroups: Set<Int> = []
    @State private var assigningCategory: Category?
    @State private var isAddGroupPresented = false
    @State private var newGroupName = ""
    @State private var addingCategoryToGroup: CategoryGroup?
    @State private var renamingCategory: Category?
    @State private var renameText = ""
    @State private var underfundedCents = 0
    @State private var settingTargetCategory: Category?
    @State private var targetText = ""

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MonthNav(month: $month, onChange: reload)
                    summaryCard
                    if isBreakdownOpen { breakdownCard }
                    ForEach(groups) { group in
                        groupSection(group)
                    }
                    Button("+ New Group") { isAddGroupPresented = true }
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    Color.clear.frame(height: 40)
                }
                .padding()
            }
        }
        .background(Theme.page)
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("History") { TransactionsListView() }
                    .foregroundStyle(Theme.accent)
            }
        }
        .sheet(item: $assigningCategory) { category in
            AssignCategoryView(category: category, month: month, currentAssignedCents: assignedThisMonth[category.id] ?? 0) {
                reload()
            }
        }
        .sheet(isPresented: $isAddGroupPresented) { addGroupSheet }
        .sheet(item: $addingCategoryToGroup) { group in addCategorySheet(group: group) }
        .sheet(item: $renamingCategory) { category in renameCategorySheet(category: category) }
        .sheet(item: $settingTargetCategory) { category in targetSheet(category: category) }
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .boardDidChange)) { _ in reload() }
    }

    private var summaryCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SPENT THIS MONTH").font(.caption.bold()).foregroundStyle(Theme.textMuted)
                Text(Money.wholeDollars(spentThisMonthCents)).font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.text)
                Button {
                    isBreakdownOpen.toggle()
                } label: {
                    Text("Unassigned \(Money.wholeDollars(unassignedCents)) \(isBreakdownOpen ? "▴" : "▾")")
                        .font(.caption.bold())
                        .foregroundStyle(unassignedCents < 0 ? Theme.negative : (unassignedCents > 0 ? Theme.positive : Theme.textMuted))
                }
            }
            Spacer()
            if let avg = avgMonthlySpentCents {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("12 MONTHS AVG").font(.caption2.bold()).foregroundStyle(Theme.textMuted)
                    Text(Money.wholeDollars(avg)).font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.textMuted)
                    if avg > 0 {
                        Text("\(Int((Double(spentThisMonthCents) / Double(avg) * 100).rounded()))% reached")
                            .font(.caption2.bold())
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
        }
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            breakdownRow("Cash on hand", uncategorizedAllTimeCents)
            breakdownRow("− Assigned to envelopes", -assignedAllTimeCents)
            Divider().background(Theme.border)
            HStack {
                Text("Unassigned Cash").font(.caption.bold()).foregroundStyle(Theme.text)
                Spacer()
                Text(Money.wholeDollars(unassignedCents)).font(.caption.bold()).foregroundStyle(Theme.text)
            }
            Text("This is a stock, not a flow — it counts every assignment ever made, future months included.")
                .font(.caption2).foregroundStyle(Theme.textMuted)
        }
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func breakdownRow(_ label: String, _ cents: Int) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(Theme.textMuted)
            Spacer()
            Text(Money.wholeDollars(cents)).font(.caption.bold()).foregroundStyle(Theme.text)
        }
    }

    private func groupSection(_ group: CategoryGroup) -> some View {
        let categories = categoriesByGroup[group.id] ?? []
        let isCollapsed = collapsedGroups.contains(group.id)
        let subtotal = categories.reduce(0) { $0 + (balanceThroughMonth[$1.id] ?? 0) }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    if isCollapsed { collapsedGroups.remove(group.id) } else { collapsedGroups.insert(group.id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down").font(.caption)
                        Text(group.name.uppercased()).font(.caption.bold())
                    }
                    .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Text(Money.exact(subtotal)).font(.caption.bold()).foregroundStyle(Theme.textMuted)
                Menu {
                    Button("Add Category") { addingCategoryToGroup = group }
                    Button("Move Up") { categoriesRepo.moveGroup(id: group.id, direction: .up); reload() }
                    Button("Move Down") { categoriesRepo.moveGroup(id: group.id, direction: .down); reload() }
                    Button("Delete Group", role: .destructive) { categoriesRepo.deleteGroup(id: group.id); reload() }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(Theme.textMuted)
                }
            }
            if !isCollapsed {
                ForEach(categories) { category in
                    categoryRow(category)
                    if category.id != categories.last?.id {
                        Divider().background(Theme.border)
                    }
                }
            }
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        let assigned = assignedThisMonth[category.id] ?? 0
        let activity = activityThisMonth[category.id] ?? 0
        let balance = balanceThroughMonth[category.id] ?? 0
        let spent = -min(activity, 0)
        let status = BudgetMath.status(balanceCents: balance, assignedThisMonthCents: assigned)
        let segments = BudgetMath.categoryBarSegments(balanceCents: balance, spentThisMonthCents: spent)
        return Button {
            assigningCategory = category
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(category.displayName).font(.subheadline.bold()).foregroundStyle(Theme.text)
                    Spacer()
                    Text(Money.exact(balance))
                        .font(.footnote.bold())
                        .foregroundStyle(statusFg(status))
                        .padding(.vertical, 4).padding(.horizontal, 10)
                        .background(statusBg(status), in: Capsule())
                }
                progressBar(status: status, segments: segments)
                HStack {
                    Text(BudgetMath.caption(status: status, spentThisMonthCents: spent, assignedThisMonthCents: assigned, balanceCents: balance))
                        .font(.caption2).foregroundStyle(Theme.textMuted)
                    if let target = category.targetCents, target > assigned {
                        Spacer()
                        Text("Needed: \(Money.wholeDollars(target - assigned))").font(.caption2).foregroundStyle(Theme.amber)
                    }
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .contextMenu {
            Button("Rename") { renameText = category.name; renamingCategory = category }
            Button("Set Target") {
                targetText = category.targetCents.map { String(format: "%.2f", Double($0) / 100) } ?? ""
                settingTargetCategory = category
            }
            if let target = category.targetCents, target > assigned {
                Button("Fill Target from Unassigned") {
                    let fillCents = min(target - assigned, max(unassignedCents, 0)) + assigned
                    BudgetRepository().setAssigned(categoryId: category.id, month: month, cents: fillCents)
                    reload()
                }
            }
            Button("Move Up") { categoriesRepo.moveCategory(id: category.id, direction: .up); reload() }
            Button("Move Down") { categoriesRepo.moveCategory(id: category.id, direction: .down); reload() }
            Button("Delete", role: .destructive) { categoriesRepo.archive(categoryId: category.id); reload() }
        }
    }

    /// Overspent reads as one full red run; unbudgeted/fully-spent leave
    /// the bare track (nothing to show); funded splits remaining (solid)
    /// vs. spent (faded) — one hue, two weights. Matches ProgressBar.tsx.
    private func progressBar(status: BudgetMath.CategoryStatus, segments: BudgetMath.CategoryBarSegments) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border)
                if status == .overspent {
                    Capsule().fill(Theme.negative).frame(width: geometry.size.width)
                } else {
                    HStack(spacing: 0) {
                        Capsule().fill(Theme.positive).frame(width: geometry.size.width * segments.remainingPercent / 100)
                        Capsule().fill(Theme.positiveFaded).frame(width: geometry.size.width * segments.spentPercent / 100)
                    }
                }
            }
        }
        .frame(height: 5)
    }

    private func statusBg(_ status: BudgetMath.CategoryStatus) -> Color {
        switch status {
        case .overspent: Theme.negativeTint
        case .fullySpent: Theme.border
        case .funded: Theme.positiveTint
        case .unbudgeted: Theme.border
        }
    }

    private func statusFg(_ status: BudgetMath.CategoryStatus) -> Color {
        switch status {
        case .overspent: Theme.negative
        case .fullySpent: Theme.textMuted
        case .funded: Theme.positive
        case .unbudgeted: Theme.textMuted
        }
    }

    private var addGroupSheet: some View {
        NavigationStack {
            Form {
                TextField("Group name", text: $newGroupName)
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isAddGroupPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        categoriesRepo.createGroup(name: newGroupName)
                        newGroupName = ""
                        isAddGroupPresented = false
                        reload()
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    @State private var newCategoryName = ""

    private func addCategorySheet(group: CategoryGroup) -> some View {
        NavigationStack {
            Form {
                TextField("Category name", text: $newCategoryName)
            }
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { addingCategoryToGroup = nil } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        categoriesRepo.createCategory(groupId: group.id, name: newCategoryName, icon: nil)
                        newCategoryName = ""
                        addingCategoryToGroup = nil
                        reload()
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func renameCategorySheet(category: Category) -> some View {
        NavigationStack {
            Form {
                TextField("Category name", text: $renameText)
            }
            .navigationTitle("Rename")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { renamingCategory = nil } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        categoriesRepo.rename(categoryId: category.id, name: renameText, icon: category.icon)
                        renamingCategory = nil
                        reload()
                    }
                    .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func targetSheet(category: Category) -> some View {
        NavigationStack {
            Form {
                TextField("Monthly target", text: $targetText).keyboardType(.decimalPad)
                Button("Clear Target", role: .destructive) {
                    categoriesRepo.setTarget(categoryId: category.id, monthlyCents: nil)
                    settingTargetCategory = nil
                    reload()
                }
            }
            .navigationTitle("Target")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { settingTargetCategory = nil } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let value = Double(targetText) {
                            categoriesRepo.setTarget(categoryId: category.id, monthlyCents: Int((value * 100).rounded()))
                        }
                        settingTargetCategory = nil
                        reload()
                    }
                }
            }
        }
    }

    private func reload() {
        groups = categoriesRepo.groups()
        let categories = categoriesRepo.categories()
        categoriesByGroup = Dictionary(grouping: categories, by: \.groupId)

        assignedThisMonth = budgetRepo.assignedCentsByCategory(month: month)
        activityThisMonth = transactionsRepo.activityCentsByCategory(month: month)
        let cumulativeAssigned = budgetRepo.cumulativeAssignedCentsByCategory(throughMonth: month)
        let cumulativeActivity = transactionsRepo.cumulativeActivityCentsByCategory(throughMonth: month)
        balanceThroughMonth = Dictionary(uniqueKeysWithValues: categories.map { category in
            (category.id, BudgetMath.categoryBalanceCents(
                cumulativeAssignedCents: cumulativeAssigned[category.id] ?? 0,
                cumulativeActivityCents: cumulativeActivity[category.id] ?? 0
            ))
        })

        uncategorizedAllTimeCents = transactionsRepo.uncategorizedActivityCentsAllTime()
        assignedAllTimeCents = budgetRepo.totalAssignedCentsAllTime()
        unassignedCents = BudgetMath.unassignedCashCents(uncategorizedActivityAllTimeCents: uncategorizedAllTimeCents, assignedAllTimeCents: assignedAllTimeCents)

        spentThisMonthCents = -min(activityThisMonth.values.reduce(0, +), 0)

        let priorMonths = (1 ... 12).compactMap { offset -> String? in
            Calendar.current.date(byAdding: .month, value: -offset, to: parseDate(month + "-01")).map { monthString(from: $0) }
        }
        let total = priorMonths.reduce(0) { $0 + transactionsRepo.totalSpentCents(month: $1) }
        avgMonthlySpentCents = priorMonths.isEmpty ? nil : total / priorMonths.count

        underfundedCents = categories.reduce(0) { total, category in
            guard let target = category.targetCents else { return total }
            let assigned = assignedThisMonth[category.id] ?? 0
            return total + max(0, target - assigned)
        }
    }
}

private struct AssignCategoryView: View {
    let category: Category
    let month: String
    let currentAssignedCents: Int
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    private let repository = BudgetRepository()

    init(category: Category, month: String, currentAssignedCents: Int, onSave: @escaping () -> Void) {
        self.category = category
        self.month = month
        self.currentAssignedCents = currentAssignedCents
        self.onSave = onSave
        _amountText = State(initialValue: String(format: "%.2f", Double(currentAssignedCents) / 100))
    }

    var body: some View {
        NavigationStack {
            Form {
                Text(category.displayName)
                TextField("Assigned amount", text: $amountText)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Assign")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let cents = Int((Double(amountText) ?? 0) * 100)
                        repository.setAssigned(categoryId: category.id, month: month, cents: cents)
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
