import XCTest
@testable import BudgetsBroNative

final class PurchaseItemsTests: XCTestCase {
    func testParseRoundTrip() {
        let items = PurchaseItems.parse("Milk=4.50, Eggs=3.20")
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].name, "Milk")
        XCTAssertEqual(items[0].priceCents, 450)
        XCTAssertEqual(items[1].priceCents, 320)
    }

    func testFormatRoundTrip() {
        let text = PurchaseItems.format([PurchaseItemEntry(name: "Milk", priceCents: 450)])
        XCTAssertEqual(text, "Milk=4.50")
    }

    func testAggregateRanksByFrequency() {
        let entries: [(date: String, purchaseItems: String, transactionId: Int)] = [
            ("2026-01-01", "Milk=4.50", 1),
            ("2026-01-08", "Milk=4.80", 2),
            ("2026-01-15", "Bread=3.00", 3),
        ]
        let aggregates = PurchaseInsights.aggregate(entries: entries)
        XCTAssertEqual(aggregates.first?.name, "Milk")
        XCTAssertEqual(aggregates.first?.count, 2)
    }
}
