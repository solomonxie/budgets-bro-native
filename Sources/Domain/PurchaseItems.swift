import Foundation

struct PurchaseItemEntry {
    let name: String
    let priceCents: Int
}

/// Parses `transactions.purchase_items`'s `key=value, key=value` string —
/// see docs/DESIGN.md#core-domain-model. One column rather than a child
/// table because it's only ever read whole.
enum PurchaseItems {
    static func parse(_ text: String) -> [PurchaseItemEntry] {
        text.components(separatedBy: ",").compactMap { pair in
            let parts = pair.components(separatedBy: "=")
            guard parts.count == 2 else { return nil }
            let name = parts[0].trimmingCharacters(in: .whitespaces)
            let priceText = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "$", with: "")
            guard !name.isEmpty, let price = Double(priceText) else { return nil }
            return PurchaseItemEntry(name: name, priceCents: Int((price * 100).rounded()))
        }
    }

    static func format(_ items: [PurchaseItemEntry]) -> String {
        items.map { "\($0.name)=\(String(format: "%.2f", Double($0.priceCents) / 100))" }.joined(separator: ", ")
    }
}

struct PurchaseItemAggregate: Identifiable {
    var id: String { name }
    let name: String
    let occurrences: [(date: String, priceCents: Int, transactionId: Int)]
    var count: Int { occurrences.count }
    var averagePriceCents: Int { occurrences.isEmpty ? 0 : occurrences.reduce(0) { $0 + $1.priceCents } / occurrences.count }
    var latestPriceCents: Int { occurrences.max(by: { $0.date < $1.date })?.priceCents ?? 0 }
}

enum PurchaseInsights {
    static func aggregate(entries: [(date: String, purchaseItems: String, transactionId: Int)]) -> [PurchaseItemAggregate] {
        var byName: [String: [(date: String, priceCents: Int, transactionId: Int)]] = [:]
        for entry in entries {
            for item in PurchaseItems.parse(entry.purchaseItems) {
                byName[item.name, default: []].append((entry.date, item.priceCents, entry.transactionId))
            }
        }
        return byName.map { PurchaseItemAggregate(name: $0.key, occurrences: $0.value) }
            .sorted { $0.count > $1.count }
    }
}
