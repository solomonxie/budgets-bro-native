import XCTest
@testable import BudgetsBroNative

final class DatabaseTests: XCTestCase {
    func testMigrationCreatesAccountsTable() {
        let database = Database.shared
        XCTAssertTrue(database.exec("SELECT 1 FROM accounts LIMIT 1"))
    }
}
