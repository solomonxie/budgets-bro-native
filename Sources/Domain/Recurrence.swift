import Foundation

enum Frequency: String, CaseIterable, Identifiable {
    case daily, weekly, monthly, yearly
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// Pure function, no DB dependency — port of budgets-bro's `domain/recurrence.ts`.
enum Recurrence {
    static func nextOccurrenceDate(from date: Date, frequency: Frequency, intervalN: Int) -> Date {
        let component: Calendar.Component
        switch frequency {
        case .daily: component = .day
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        case .yearly: component = .year
        }
        return Calendar.current.date(byAdding: component, value: max(intervalN, 1), to: date) ?? date
    }
}
