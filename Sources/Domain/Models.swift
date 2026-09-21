import Foundation

/// Mirrors budgets-bro's `accounts.type` enum — see that repo's
/// docs/DESIGN.md#core-domain-model.
enum AccountType: String, Codable {
    case checking
    case savings
    case creditCard = "credit_card"
    case cash
    case loan
    case mortgage
    case tracking
}

struct Account: Identifiable, Codable {
    let id: Int
    var name: String
    var type: AccountType
    var onBudget: Bool
    var currency: String
    var openingBalanceCents: Int
    var archivedAt: Date?
    var createdAt: Date
}
