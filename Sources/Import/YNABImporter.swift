import Foundation

struct YNABImportResult {
    var inserted = 0
    var updated = 0
    var accountsCreated = 0
    var categoriesCreated = 0
}

enum YNABImportError: LocalizedError {
    case noRegisterCSV
    var errorDescription: String? { "No Register CSV found in that export." }
}

/// One-time, manual, user-initiated import of YNAB's "Export Budget" zip —
/// see docs/DESIGN.md#ynab-data-import. Idempotent via `import_id`
/// (account+date+payee+occurrence), so re-importing the same or a later
/// export upserts rather than duplicates.
enum YNABImporter {
    static func importZip(at url: URL) throws -> YNABImportResult {
        let data = try Data(contentsOf: url)
        let archive = try ZipArchive(data: data)
        guard let registerEntry = archive.entry(matching: { $0.contains("register") && $0.hasSuffix(".csv") }) else {
            throw YNABImportError.noRegisterCSV
        }
        let registerText = try decodeText(archive.contents(of: registerEntry))
        let planText = try archive.entry(matching: { $0.contains("plan") && $0.hasSuffix(".csv") })
            .map { try decodeText(archive.contents(of: $0)) }

        return importCSV(registerText: registerText, planText: planText)
    }

    static func importCSV(registerText: String, planText: String?) -> YNABImportResult {
        var result = YNABImportResult()
        let accountsRepo = AccountsRepository()
        let categoriesRepo = CategoriesRepository()
        let payeesRepo = PayeesRepository()
        let transactionsRepo = TransactionsRepository()
        let budgetRepo = BudgetRepository()

        var accountIdByName = Dictionary(uniqueKeysWithValues: accountsRepo.all(includeArchived: true).map { ($0.name, $0.id) })
        var groupIdByName = Dictionary(uniqueKeysWithValues: categoriesRepo.groups().map { ($0.name, $0.id) })
        var categoryIdByKey: [String: Int] = [:]
        let groupNameById = Dictionary(uniqueKeysWithValues: groupIdByName.map { ($0.value, $0.key) })
        for category in categoriesRepo.categories(includeArchived: true) {
            if let groupName = groupNameById[category.groupId] {
                categoryIdByKey["\(groupName)/\(category.name)"] = category.id
            }
        }

        func categoryId(forFullName fullName: String) -> Int? {
            guard !fullName.isEmpty else { return nil }
            let parts = fullName.components(separatedBy: ": ")
            let groupName = parts.first ?? "Imported"
            let categoryName = parts.count > 1 ? parts[1] : fullName
            let groupId = groupIdByName[groupName] ?? {
                let newGroupId = categoriesRepo.createGroup(name: groupName)
                groupIdByName[groupName] = newGroupId
                return newGroupId
            }()
            let key = "\(groupName)/\(categoryName)"
            if let existing = categoryIdByKey[key] { return existing }
            let newCategoryId = categoriesRepo.createCategory(groupId: groupId, name: categoryName, icon: nil)
            categoryIdByKey[key] = newCategoryId
            result.categoriesCreated += 1
            return newCategoryId
        }

        var occurrenceCounts: [String: Int] = [:]
        let registerRows = CSV.parse(registerText)
        if let header = registerRows.first {
            let columnIndex = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1, $0) })
            func column(_ row: [String], _ name: String) -> String {
                guard let index = columnIndex[name], index < row.count else { return "" }
                return row[index]
            }

            for row in registerRows.dropFirst() {
                let accountName = column(row, "Account")
                guard !accountName.isEmpty else { continue }
                let accountId = accountIdByName[accountName] ?? {
                    let newId = accountsRepo.create(name: accountName, type: .checking, onBudget: true, openingBalanceCents: 0)
                    accountIdByName[accountName] = newId
                    result.accountsCreated += 1
                    return newId
                }()

                let date = parseYNABDate(column(row, "Date")) ?? today()
                let payeeName = column(row, "Payee")
                let payeeId = payeeName.isEmpty ? nil : payeesRepo.ensure(name: payeeName)
                let matchedCategoryId = categoryId(forFullName: column(row, "Category Group/Category"))
                let memo = column(row, "Memo")
                let amountCents = parseAmountCents(column(row, "Inflow")) - parseAmountCents(column(row, "Outflow"))
                let cleared = column(row, "Cleared").lowercased().hasPrefix("c") || column(row, "Cleared").lowercased() == "reconciled"

                let dedupeKey = "\(accountName)|\(date)|\(payeeName)"
                let occurrence = occurrenceCounts[dedupeKey, default: 0]
                occurrenceCounts[dedupeKey] = occurrence + 1
                let importId = "\(dedupeKey)|\(occurrence)"

                let inserted = transactionsRepo.upsertImported(
                    importId: importId, accountId: accountId, categoryId: matchedCategoryId, payeeId: payeeId,
                    memo: memo.isEmpty ? nil : memo, amountCents: amountCents, date: date, cleared: cleared
                )
                if inserted { result.inserted += 1 } else { result.updated += 1 }
            }
        }

        if let planText {
            let planRows = CSV.parse(planText)
            if let header = planRows.first {
                let columnIndex = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1, $0) })
                func column(_ row: [String], _ name: String) -> String {
                    guard let index = columnIndex[name], index < row.count else { return "" }
                    return row[index]
                }
                for row in planRows.dropFirst() {
                    let fullName = column(row, "Category Group/Category")
                    guard !fullName.isEmpty, let matchedCategoryId = categoryId(forFullName: fullName) else { continue }
                    let month = parseYNABMonth(column(row, "Month")) ?? currentMonth()
                    let assigned = parseAmountCents(column(row, "Assigned"))
                    if assigned != 0 {
                        budgetRepo.setAssigned(categoryId: matchedCategoryId, month: month, cents: assigned)
                    }
                }
            }
        }

        return result
    }

    private static func decodeText(_ data: Data) throws -> String {
        String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
    }

    private static func parseAmountCents(_ text: String) -> Int {
        let cleaned = text.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, let value = Double(cleaned) else { return 0 }
        return Int((value * 100).rounded())
    }

    private static func parseYNABDate(_ text: String) -> String? {
        for format in ["MM/dd/yyyy", "yyyy-MM-dd", "dd/MM/yyyy"] {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.calendar = Calendar(identifier: .gregorian)
            if let date = formatter.date(from: text) { return formatDate(date) }
        }
        return nil
    }

    private static func parseYNABMonth(_ text: String) -> String? {
        for format in ["MMM yyyy", "yyyy-MM", "MM/yyyy"] {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.calendar = Calendar(identifier: .gregorian)
            if let date = formatter.date(from: text) { return monthString(from: date) }
        }
        return nil
    }
}
