import Foundation

struct ColumnMapping {
    var dateColumn: Int
    var payeeColumn: Int?
    var amountColumn: Int
    var memoColumn: Int?
}

/// Generic bank CSV import with column mapping — turns a one-time YNAB
/// migration tool into a repeatable monthly workflow without a bank feed.
/// See docs/DESIGN.md's Generic bank CSV import backlog item. Reuses the
/// same `import_id` dedupe as `YNABImporter`, keyed on account+date+payee.
enum GenericCSVImporter {
    static func importRows(_ rows: [[String]], header: [String], mapping: ColumnMapping, accountId: Int) -> YNABImportResult {
        var result = YNABImportResult()
        let payeesRepo = PayeesRepository()
        let transactionsRepo = TransactionsRepository()
        var occurrenceCounts: [String: Int] = [:]

        for row in rows.dropFirst() {
            guard mapping.dateColumn < row.count, mapping.amountColumn < row.count else { continue }
            let date = parseFlexibleDate(row[mapping.dateColumn]) ?? today()
            let payeeName = mapping.payeeColumn.flatMap { $0 < row.count ? row[$0] : nil } ?? ""
            let payeeId = payeeName.isEmpty ? nil : payeesRepo.ensure(name: payeeName)
            let memo = mapping.memoColumn.flatMap { $0 < row.count ? row[$0] : nil }
            let amountCents = parseAmountCents(row[mapping.amountColumn])

            let dedupeKey = "\(accountId)|\(date)|\(payeeName)"
            let occurrence = occurrenceCounts[dedupeKey, default: 0]
            occurrenceCounts[dedupeKey] = occurrence + 1
            let importId = "csv|\(dedupeKey)|\(occurrence)"

            let inserted = transactionsRepo.upsertImported(
                importId: importId, accountId: accountId, categoryId: nil, payeeId: payeeId,
                memo: memo?.isEmpty == false ? memo : nil, amountCents: amountCents, date: date, cleared: false
            )
            if inserted { result.inserted += 1 } else { result.updated += 1 }
        }
        return result
    }

    private static func parseAmountCents(_ text: String) -> Int {
        let cleaned = text.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, let value = Double(cleaned) else { return 0 }
        return Int((value * 100).rounded())
    }

    private static func parseFlexibleDate(_ text: String) -> String? {
        for format in ["MM/dd/yyyy", "yyyy-MM-dd", "dd/MM/yyyy", "M/d/yyyy"] {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.calendar = Calendar(identifier: .gregorian)
            if let date = formatter.date(from: text) { return formatDate(date) }
        }
        return nil
    }
}
