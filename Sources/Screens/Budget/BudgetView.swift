import SwiftUI

/// Per docs/design/uiux/budget.md — Unassigned Cash banner, collapsible
/// category groups, per-category status/progress/caption, month nav.
/// Category management (add/rename/delete group or category) is inline
/// here, matching the current/final UX (no separate Manage Categories page).
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
    @State private var collapsedGroups: Set<Int> = []
    @State private var assigningCategory: Category?
    @State private var isAddGroupPresented = false
    @State private var newGroupName = ""
    @State private var addingCategoryToGroup: CategoryGroup?
    @State private var renamingCategory: Category?
    @State private var renameText = ""

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard
                    monthNav
                    ForEach(groups) { group in
                        groupSection(group)
                    }
                    Button("+ Add Group") { isAddGroupPresented = true }
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                }
                .padding()
            }
        }
        .navigationTitle("Budget")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("History") { TransactionsListView() }
            }
        }
        .sheet(item: $assigningCategory) { category in
            AssignCategoryView(category: category, month: month, currentAssignedCents: assignedThisMonth[category.id] ?? 0) {
                reload()
            }
        }
        .sheet(isPresented: $isAddGroupPresented) {
            addGroupSheet
        }
        .sheet(item: $addingCategoryToGroup) { group in
            addCategorySheet(group: group)
        }
        .sheet(item: $renamingCategory) { category in
            renameCategorySheet(category: category)
        }
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .boardDidChange)) { _ in reload() }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("SPENT THIS MONTH").font(.caption).foregroundStyle(.secondary)
                    Text(Money.wholeDollars(spentThisMonthCents)).font(.title2.bold()).foregroundStyle(.white)
                }
                Spacer()
            }
            Text("Unassigned \(Money.wholeDollars(unassignedCents))")
                .font(.subheadline)
                .foregroundStyle(unassignedCents < 0 ? Theme.negative : Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var monthNav: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(month)
            Spacer()
            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .foregroundStyle(.white)
    }

    private func groupSection(_ group: CategoryGroup) -> some View {
        let categories = categoriesByGroup[group.id] ?? []
        let isCollapsed = collapsedGroups.contains(group.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    if isCollapsed { collapsedGroups.remove(group.id) } else { collapsedGroups.insert(group.id) }
                } label: {
                    HStack {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        Text(group.name.uppercased()).font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Add Category") { addingCategoryToGroup = group }
                    Button("Delete Group", role: .destructive) {
                        categoriesRepo.deleteGroup(id: group.id)
                    }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(.secondary)
                }
            }
            if !isCollapsed {
                VStack(spacing: 0) {
                    ForEach(categories) { category in
                        categoryRow(category)
                        if category.id != categories.last?.id {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        let assigned = assignedThisMonth[category.id] ?? 0
        let activity = activityThisMonth[category.id] ?? 0
        let balance = balanceThroughMonth[category.id] ?? 0
        let spent = -min(activity, 0)
        let status = BudgetMath.status(balanceCents: balance, assignedThisMonthCents: assigned)
        return Button {
            assigningCategory = category
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.displayName).foregroundStyle(.white)
                    Spacer()
                    Text(Money.wholeDollars(balance))
                        .foregroundStyle(statusColor(status))
                }
                Text("Spent \(Money.wholeDollars(spent)) of \(Money.wholeDollars(assigned))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .contextMenu {
            Button("Rename") {
                renameText = category.name
                renamingCategory = category
            }
            Button("Delete", role: .destructive) { categoriesRepo.archive(categoryId: category.id) }
        }
    }

    private func statusColor(_ status: BudgetMath.CategoryStatus) -> Color {
        switch status {
        case .funded: Theme.positive
        case .partial: Theme.partial
        case .overspent: Theme.negative
        }
    }

    private var addGroupSheet: some View {
        NavigationStack {
            Form {
                TextField("Group name", text: $newGroupName)
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isAddGroupPresented = false }
                }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { addingCategoryToGroup = nil }
                }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { renamingCategory = nil }
                }
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

    private func shiftMonth(by delta: Int) {
        var components = DateComponents()
        components.month = delta
        let referenceDate = parseDate(month + "-01")
        if let newDate = Calendar.current.date(byAdding: components, to: referenceDate) {
            month = monthString(from: newDate)
            reload()
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

        let uncategorized = transactionsRepo.uncategorizedActivityCentsAllTime()
        let assignedAllTime = budgetRepo.totalAssignedCentsAllTime()
        unassignedCents = BudgetMath.unassignedCashCents(uncategorizedActivityAllTimeCents: uncategorized, assignedAllTimeCents: assignedAllTime)

        spentThisMonthCents = -min(activityThisMonth.values.reduce(0, +), 0)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
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
