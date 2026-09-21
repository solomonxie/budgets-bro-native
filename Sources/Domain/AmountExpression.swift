import Foundation

/// Port of budgets-bro's `domain/amountExpression.ts` — the amount field is
/// a small calculator: digits are read right-to-left as cents, an operator
/// banks what's typed as the left side, only one operation pending at a
/// time (a pocket calculator's chaining behavior).
enum AmountOperator: String {
    case add = "+", subtract = "−", multiply = "×", divide = "÷"
}

struct AmountExpression: Equatable {
    var leftCents: Int?
    var operatorSymbol: AmountOperator?
    var digits: String = ""

    static let empty = AmountExpression()
}

private let maxDigits = 9
private let maxCents = Int(pow(10.0, Double(maxDigits))) - 1

enum AmountKey: Equatable {
    case digit(Character)
    case op(AmountOperator)
    case equals, clear, backspace
}

enum AmountMath {
    static func isEmpty(_ expr: AmountExpression) -> Bool {
        expr.leftCents == nil && expr.digits.isEmpty
    }

    private static func digitsToCents(_ digits: String) -> Int {
        digits.isEmpty ? 0 : (Int(digits) ?? 0)
    }

    private static func apply(_ left: Int, _ op: AmountOperator, _ right: Int) -> Int {
        switch op {
        case .add: return left + right
        case .subtract: return left - right
        case .multiply: return Int((Double(left) * Double(right) / 100).rounded())
        case .divide: return right == 0 ? left : Int((Double(left) * 100 / Double(right)).rounded())
        }
    }

    /// A magnitude, never a sign — direction is the Spending/Income
    /// toggle's job, so "$5 − $8" floors at zero instead of going negative.
    private static func clamp(_ cents: Int) -> Int {
        min(max(0, cents), maxCents)
    }

    static func cents(_ expr: AmountExpression) -> Int {
        guard let left = expr.leftCents, let op = expr.operatorSymbol else {
            return digitsToCents(expr.digits)
        }
        guard !expr.digits.isEmpty else { return left }
        return clamp(apply(left, op, digitsToCents(expr.digits)))
    }

    static func press(_ expr: AmountExpression, _ key: AmountKey) -> AmountExpression {
        switch key {
        case .clear:
            return .empty
        case .backspace:
            if !expr.digits.isEmpty { return AmountExpression(leftCents: expr.leftCents, operatorSymbol: expr.operatorSymbol, digits: String(expr.digits.dropLast())) }
            if expr.operatorSymbol != nil {
                return AmountExpression(digits: expr.leftCents.map(String.init) ?? "")
            }
            return .empty
        case .equals:
            guard expr.operatorSymbol != nil else { return expr }
            return AmountExpression(digits: String(cents(expr)))
        case let .op(newOp):
            if isEmpty(expr) { return expr }
            if expr.digits.isEmpty, expr.leftCents != nil {
                return AmountExpression(leftCents: expr.leftCents, operatorSymbol: newOp, digits: "")
            }
            return AmountExpression(leftCents: cents(expr), operatorSymbol: newOp, digits: "")
        case let .digit(d):
            guard expr.digits.count < maxDigits else { return expr }
            var digits = expr.digits + String(d)
            while digits.count > 1, digits.hasPrefix("0") { digits.removeFirst() }
            return AmountExpression(leftCents: expr.leftCents, operatorSymbol: expr.operatorSymbol, digits: digits)
        }
    }

    private static func formatCents(_ cents: Int, symbol: String) -> String {
        let dollars = Double(cents) / 100
        let formatted = dollars.formatted(.number.precision(.fractionLength(2)).grouping(.automatic))
        return "\(symbol)\(formatted)"
    }

    static func format(_ expr: AmountExpression, symbol: String = "$") -> String {
        let right = expr.digits.isEmpty ? "" : formatCents(digitsToCents(expr.digits), symbol: symbol)
        guard let left = expr.leftCents, let op = expr.operatorSymbol else { return right }
        return "\(formatCents(left, symbol: symbol)) \(op.rawValue) \(right)".trimmingCharacters(in: .whitespaces)
    }
}
