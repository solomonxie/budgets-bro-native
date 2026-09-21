import Foundation

/// Domain types mirror budgets-bro's schema — see that repo's
/// docs/DESIGN.md#core-domain-model. Dates are kept as SQLite's own
/// ISO-8601 text (`YYYY-MM-DD` for a transaction date, `YYYY-MM` for a
/// budget month) rather than `Date`, since they're only ever sorted,
/// grouped, or displayed — plain ISO strings sort correctly as text and
/// skip a `DateFormatter` round trip everywhere.

enum AccountType: String, Codable, CaseIterable {
    case checking
    case savings
    case creditCard = "credit_card"
    case cash
    case loan
    case mortgage
    case tracking

    /// Grouping used by the Accounts screen — docs/design/uiux/accounts.md.
    var kind: String {
        switch self {
        case .checking, .cash: "Cash"
        case .savings: "Savings"
        case .tracking: "Tracking"
        case .loan, .mortgage: "Loan"
        case .creditCard: "Credit"
        }
    }

    var displayName: String {
        switch self {
        case .checking: "Checking"
        case .savings: "Savings"
        case .creditCard: "Credit Card"
        case .cash: "Cash"
        case .loan: "Loan"
        case .mortgage: "Mortgage"
        case .tracking: "Tracking"
        }
    }
}

struct Account: Identifiable, Hashable {
    var id: Int
    var name: String
    var type: AccountType
    var onBudget: Bool
    var currency: String
    var openingBalanceCents: Int
    var archivedAt: String?
}

struct CategoryGroup: Identifiable, Hashable {
    var id: Int
    var name: String
    var sortOrder: Int
}

enum CategoryTargetType: String {
    case monthly
}

struct Category: Identifiable, Hashable {
    var id: Int
    var groupId: Int
    var name: String
    var icon: String?
    var sortOrder: Int
    var archivedAt: String?
    var targetCents: Int?
    var targetType: CategoryTargetType?

    var displayName: String {
        if let icon, !icon.isEmpty { return "\(icon) \(name)" }
        return name
    }
}

struct Payee: Identifiable, Hashable {
    var id: Int
    var name: String
}

struct Transaction: Identifiable, Hashable {
    var id: Int
    var accountId: Int
    var categoryId: Int?
    var payeeId: Int?
    var memo: String?
    var purchaseItems: String?
    var amountCents: Int
    var date: String
    var cleared: Bool
    var isInterest: Bool
    var transferAccountId: Int?
}

/// One allocation of a split transaction — see docs/DESIGN.md's Split
/// transactions backlog item.
struct TransactionSplit: Identifiable, Hashable {
    var id: Int
    var transactionId: Int
    var categoryId: Int?
    var amountCents: Int
    var memo: String?
}

struct HouseHuntListing: Identifiable, Hashable {
    var id: Int
    var community: String
    var askingPriceCents: Int
    var beds: Int?
    var baths: Double?
    var areaSqft: Int?
    var downPaymentPercent: Double
    var ratePercent: Double
    var termMonths: Int
    var notes: String?
    var rating: Int?
}

struct BudgetEntry: Identifiable, Hashable {
    var id: Int
    var categoryId: Int
    var month: String
    var assignedCents: Int
}

/// Whole-dollar display, exact cents kept in storage — see
/// docs/design/uiux — "Whole dollars on screen, exact cents in the data".
enum Money {
    static func wholeDollars(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return dollars.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    static func exact(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return dollars.formatted(.currency(code: "USD"))
    }
}

private let isoDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .current
    return formatter
}()

private let isoMonthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM"
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .current
    return formatter
}()

/// `YYYY-MM` for the given month — the key `budget_entries.month` and a
/// transaction's month grouping use.
func currentMonth(referenceDate: Date = Date()) -> String {
    isoMonthFormatter.string(from: referenceDate)
}

func monthString(from date: Date) -> String {
    isoMonthFormatter.string(from: date)
}

/// `YYYY-MM-DD` for today — the default value of a new transaction's date.
func today() -> String {
    isoDateFormatter.string(from: Date())
}

func formatDate(_ date: Date) -> String {
    isoDateFormatter.string(from: date)
}

func parseDate(_ string: String) -> Date {
    isoDateFormatter.date(from: string) ?? Date()
}
