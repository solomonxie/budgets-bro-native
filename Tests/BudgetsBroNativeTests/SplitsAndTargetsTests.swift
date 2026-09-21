import XCTest
@testable import BudgetsBroNative

/// End-to-end against the real `Database.shared`, same pattern as
/// RepositoriesTests — no mocking the DB.
final class SplitsAndTargetsTests: XCTestCase {
    private let categoriesRepo = CategoriesRepository()
    private let accountsRepo = AccountsRepository()
    private let transactionsRepo = TransactionsRepository()

    func testSplitActivityIsCreditedToEachCategory() {
        let groupId = categoriesRepo.createGroup(name: "Test Group \(UUID())")
        let groceriesId = categoriesRepo.createCategory(groupId: groupId, name: "Groceries", icon: nil)
        let householdId = categoriesRepo.createCategory(groupId: groupId, name: "Household", icon: nil)
        let accountId = accountsRepo.create(name: "Test Cash \(UUID())", type: .cash, onBudget: true, openingBalanceCents: 0)

        let month = "2026-04"
        let transactionId = transactionsRepo.create(accountId: accountId, categoryId: nil, payeeId: nil, memo: nil, amountCents: -18000, date: "\(month)-15")
        transactionsRepo.setSplits(transactionId: transactionId, splits: [
            (categoryId: groceriesId, amountCents: -12000, memo: nil),
            (categoryId: householdId, amountCents: -6000, memo: nil),
        ])

        let activity = transactionsRepo.activityCentsByCategory(month: month)
        XCTAssertEqual(activity[groceriesId], -12000)
        XCTAssertEqual(activity[householdId], -6000)
    }

    func testSplitParentIsNotDoubleCountedAsUncategorized() {
        let groupId = categoriesRepo.createGroup(name: "Test Group \(UUID())")
        let categoryId = categoriesRepo.createCategory(groupId: groupId, name: "Test Category", icon: nil)
        let accountId = accountsRepo.create(name: "Test Cash \(UUID())", type: .cash, onBudget: true, openingBalanceCents: 0)

        let before = transactionsRepo.uncategorizedActivityCentsAllTime()
        let transactionId = transactionsRepo.create(accountId: accountId, categoryId: nil, payeeId: nil, memo: nil, amountCents: -5000, date: today())
        transactionsRepo.setSplits(transactionId: transactionId, splits: [(categoryId: categoryId, amountCents: -5000, memo: nil)])

        XCTAssertEqual(transactionsRepo.uncategorizedActivityCentsAllTime(), before)
    }

    func testCategoryTargetRoundTrips() {
        let groupId = categoriesRepo.createGroup(name: "Test Group \(UUID())")
        let categoryId = categoriesRepo.createCategory(groupId: groupId, name: "Test Category", icon: nil)

        categoriesRepo.setTarget(categoryId: categoryId, monthlyCents: 25000)
        let category = categoriesRepo.categories().first { $0.id == categoryId }
        XCTAssertEqual(category?.targetCents, 25000)

        categoriesRepo.setTarget(categoryId: categoryId, monthlyCents: nil)
        let cleared = categoriesRepo.categories().first { $0.id == categoryId }
        XCTAssertNil(cleared?.targetCents)
    }

    func testMoveCategorySwapsSortOrderWithSibling() {
        let groupId = categoriesRepo.createGroup(name: "Test Group \(UUID())")
        let firstId = categoriesRepo.createCategory(groupId: groupId, name: "A", icon: nil)
        let secondId = categoriesRepo.createCategory(groupId: groupId, name: "B", icon: nil)

        categoriesRepo.moveCategory(id: secondId, direction: .up)

        let ordered = categoriesRepo.categories().filter { $0.groupId == groupId }.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(ordered.first?.id, secondId)
        XCTAssertEqual(ordered.last?.id, firstId)
    }
}
