import XCTest
@testable import BudgetsBroNative

final class CSVTests: XCTestCase {
    func testSimpleRows() {
        let rows = CSV.parse("a,b,c\n1,2,3\n")
        XCTAssertEqual(rows, [["a", "b", "c"], ["1", "2", "3"]])
    }

    func testQuotedFieldWithEmbeddedComma() {
        let rows = CSV.parse("Name,Memo\nGroceries,\"Milk, eggs, bread\"\n")
        XCTAssertEqual(rows[1][1], "Milk, eggs, bread")
    }

    func testDoubledQuoteEscaping() {
        let rows = CSV.parse("Memo\n\"She said \"\"hi\"\"\"\n")
        XCTAssertEqual(rows[1][0], "She said \"hi\"")
    }
}
