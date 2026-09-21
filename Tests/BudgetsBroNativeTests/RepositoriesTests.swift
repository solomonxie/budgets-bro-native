import XCTest
@testable import BudgetsBroNative

/// End-to-end against the real `Database.shared` (system libsqlite3, same
/// singleton the app uses) — no mocking the DB, per AGENTS.md.
final class RepositoriesTests: XCTestCase {
    private let accountsRepo = AccountsRepository()
    private let categoriesRepo = CategoriesRepository()
    private let payeesRepo = PayeesRepository()
    private let transactionsRepo = TransactionsRepository()
    private let budgetRepo = BudgetRepository()

    func testAccountBalanceReflectsOpeningPlusTransactions() {
        let accountId = accountsRepo.create(name: "Test Checking \(UUID())", type: .checking, onBudget: true, openingBalanceCents: 10_000)
        transactionsRepo.create(accountId: accountId, categoryId: nil, payeeId: nil, memo: nil, amountCents: -2_500, date: today())
        transactionsRepo.create(accountId: accountId, categoryId: nil, payeeId: nil, memo: nil, amountCents: 500, date: today())

        XCTAssertEqual(accountsRepo.balanceCents(accountId: accountId), 8_000)
    }

    func testPayeeEnsureIsIdempotentByName() {
        let name = "Test Payee \(UUID())"
        let first = payeesRepo.ensure(name: name)
        let second = payeesRepo.ensure(name: name)
        XCTAssertEqual(first, second)
    }

    func testCategoryRollsOverUnspentBalanceToNextMonth() {
        let groupId = categoriesRepo.createGroup(name: "Test Group \(UUID())")
        let categoryId = categoriesRepo.createCategory(groupId: groupId, name: "Test Category", icon: nil)
        let accountId = accountsRepo.create(name: "Test Cash \(UUID())", type: .cash, onBudget: true, openingBalanceCents: 0)

        budgetRepo.setAssigned(categoryId: categoryId, month: "2026-01", cents: 10_000)
        transactionsRepo.create(accountId: accountId, categoryId: categoryId, payeeId: nil, memo: nil, amountCents: -4_000, date: "2026-01-15")

        let cumulativeAssignedJan = budgetRepo.cumulativeAssignedCentsByCategory(throughMonth: "2026-01")[categoryId] ?? 0
        let cumulativeActivityJan = transactionsRepo.cumulativeActivityCentsByCategory(throughMonth: "2026-01")[categoryId] ?? 0
        let januaryBalance = BudgetMath.categoryBalanceCents(cumulativeAssignedCents: cumulativeAssignedJan, cumulativeActivityCents: cumulativeActivityJan)
        XCTAssertEqual(januaryBalance, 6_000)

        // No new assignment or spend in February — the $6,000 carries forward
        // automatically because the balance formula is cumulative, not reset
        // per month. See docs/DESIGN.md#core-domain-model.
        let cumulativeAssignedFeb = budgetRepo.cumulativeAssignedCentsByCategory(throughMonth: "2026-02")[categoryId] ?? 0
        let cumulativeActivityFeb = transactionsRepo.cumulativeActivityCentsByCategory(throughMonth: "2026-02")[categoryId] ?? 0
        let februaryBalance = BudgetMath.categoryBalanceCents(cumulativeAssignedCents: cumulativeAssignedFeb, cumulativeActivityCents: cumulativeActivityFeb)
        XCTAssertEqual(februaryBalance, 6_000)
    }

    func testSetAssignedUpsertsRatherThanDuplicating() {
        let groupId = categoriesRepo.createGroup(name: "Test Group \(UUID())")
        let categoryId = categoriesRepo.createCategory(groupId: groupId, name: "Test Category", icon: nil)

        budgetRepo.setAssigned(categoryId: categoryId, month: "2026-03", cents: 5_000)
        budgetRepo.setAssigned(categoryId: categoryId, month: "2026-03", cents: 7_500)

        XCTAssertEqual(budgetRepo.assignedCents(categoryId: categoryId, month: "2026-03"), 7_500)
    }
}
