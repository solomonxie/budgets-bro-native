import Foundation

/// Pure projection function, no DB dependency — every input already exists
/// (scheduled transactions), nothing currently reads them forward except
/// the auto-post check. See docs/DESIGN.md's Cashflow runway backlog item.
enum Cashflow {
    struct ProjectedPoint {
        let dayOffset: Int
        let balanceCents: Int
    }

    static func project(startingBalanceCents: Int, schedules: [ScheduledTransaction], daysAhead: Int, from startDate: Date = Date()) -> [ProjectedPoint] {
        var dailyDelta: [Int: Int] = [:]
        for schedule in schedules {
            var occurrenceDate = parseDate(schedule.nextDate)
            var guardCount = 0
            while true {
                let offset = Calendar.current.dateComponents([.day], from: startDate, to: occurrenceDate).day ?? -1
                guard offset >= 0, offset <= daysAhead, guardCount < 500 else { break }
                dailyDelta[offset, default: 0] += schedule.amountCents
                occurrenceDate = Recurrence.nextOccurrenceDate(from: occurrenceDate, frequency: schedule.frequency, intervalN: schedule.intervalN)
                guardCount += 1
            }
        }

        var points: [ProjectedPoint] = []
        var runningBalance = startingBalanceCents
        for day in 0 ... daysAhead {
            runningBalance += dailyDelta[day] ?? 0
            points.append(ProjectedPoint(dayOffset: day, balanceCents: runningBalance))
        }
        return points
    }
}

/// Pure function — "at this savings rate, you're independent in N years."
/// See docs/DESIGN.md's FIRE / coast-FIRE backlog item.
enum FIREProjection {
    /// Months until `currentNetWorthCents` + monthly contributions (growing
    /// at `annualReturnPercent`) reaches `targetNetWorthCents`. Returns nil
    /// if it never does within 100 years.
    static func monthsToIndependence(currentNetWorthCents: Int, monthlyContributionCents: Int, annualReturnPercent: Double, targetNetWorthCents: Int) -> Int? {
        guard currentNetWorthCents < targetNetWorthCents else { return 0 }
        let monthlyRate = annualReturnPercent / 100 / 12
        var balance = Double(currentNetWorthCents)
        let target = Double(targetNetWorthCents)
        var months = 0
        while balance < target, months < 1200 {
            balance = balance * (1 + monthlyRate) + Double(monthlyContributionCents)
            months += 1
        }
        return balance >= target ? months : nil
    }

    /// Target net worth for a given annual spending, using a safe
    /// withdrawal rate (4% is the common default).
    static func targetNetWorthCents(annualSpendingCents: Int, safeWithdrawalRatePercent: Double = 4) -> Int {
        Int(Double(annualSpendingCents) / (safeWithdrawalRatePercent / 100))
    }
}
