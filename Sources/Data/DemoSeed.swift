import Foundation

/// Loads the bundled `demo/board.json` into the demo store, dates relative to today.
///
/// Dates: `"@today-3"`, `"@month-2 15"` (day 15 of two months ago, clamped), `"@month+1 9"`.
/// Rows dated after today are skipped, so the current month only shows what has happened.
enum DemoSeed {
    static let seededKey = "demo_seeded_day"

    /// Refreshed once a day, so "this month" stays true.
    static func seedIfNeeded(now: Date = .now) {
        guard AppData.isDemo, AppSettingsRepository().get(seededKey) != formatDate(now) else { return }
        seed(now: now)
    }

    static func seed(now: Date = .now, bundle: Bundle = .main) {
        guard AppData.isDemo,
              let url = bundle.url(forResource: "board", withExtension: "json", subdirectory: "demo"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let database = Database.shared
        database.reopen(wipe: true)
        database.postsChanges = false
        database.exec("BEGIN")
        load(json, now: now)
        let settings = AppSettingsRepository()
        // The real app's one-off "Demo" board isn't wanted on top of this one.
        settings.set("demo_board_seeded", "1")
        settings.set(seededKey, formatDate(now))
        database.exec("COMMIT")
        database.postsChanges = true
        BoardContext.shared.reload()
    }

    private static func load(_ json: [String: Any], now: Date) {
        let today = formatDate(now)
        func day(_ any: Any?) -> String? {
            guard let text = any as? String, let date = date(text, now: now) else { return nil }
            return formatDate(date)
        }
        func cents(_ any: Any?) -> Int { Int((((any as? NSNumber)?.doubleValue ?? 0) * 100).rounded()) }

        BoardsRepository().rename(id: 1, name: json["board"] as? String ?? "Household")
        AppSettingsRepository().set("active_board_id", "1")
        BoardContext.shared.currentBoardId = 1

        let accountsRepo = AccountsRepository(), loanRepo = LoanRepository()
        var accounts: [String: Int] = [:]
        for a in json["accounts"] as? [[String: Any]] ?? [] {
            guard let key = a["id"] as? String, let type = AccountType(rawValue: a["type"] as? String ?? "") else { continue }
            let id = accountsRepo.create(
                name: a["name"] as? String ?? key, type: type, onBudget: a["onBudget"] as? Bool ?? false,
                openingBalanceCents: cents(a["opening"]), termMonths: a["termMonths"] as? Int,
                originationPrincipalCents: a["originationPrincipal"] == nil ? nil : cents(a["originationPrincipal"]),
                originationDate: day(a["originationDate"])
            )
            accounts[key] = id
            for rate in a["rates"] as? [[Any]] ?? [] {
                guard rate.count == 2, let date = day(rate[1]) else { continue }
                loanRepo.addRate(accountId: id, ratePercent: (rate[0] as? NSNumber)?.doubleValue ?? 0, effectiveDate: date)
            }
        }

        let categoriesRepo = CategoriesRepository(), budgetRepo = BudgetRepository()
        let targets = json["targets"] as? [String: Any] ?? [:]
        let monthsBack = json["budgetMonths"] as? Int ?? 12
        let months = (0 ... monthsBack).compactMap { Calendar.current.date(byAdding: .month, value: -$0, to: now).map { monthString(from: $0) } }
        var categories: [String: Int] = [:]
        for group in json["categories"] as? [[Any]] ?? [] {
            guard group.count == 2, let name = group[0] as? String, let items = group[1] as? [[Any]] else { continue }
            let groupId = categoriesRepo.createGroup(name: name)
            for item in items where item.count == 4 {
                guard let key = item[0] as? String else { continue }
                let id = categoriesRepo.createCategory(groupId: groupId, name: item[1] as? String ?? key, icon: item[2] as? String)
                categories[key] = id
                if targets[key] != nil { categoriesRepo.setTarget(categoryId: id, monthlyCents: cents(targets[key])) }
                for month in months { budgetRepo.setAssigned(categoryId: id, month: month, cents: cents(item[3])) }
            }
        }

        for v in json["values"] as? [[Any]] ?? [] {
            guard v.count >= 4, let account = accounts[v[0] as? String ?? ""], let date = day(v[3]), date <= today else { continue }
            loanRepo.addValueReading(accountId: account, kind: v[1] as? String ?? "value", valueCents: cents(v[2]), effectiveDate: date, note: v.count > 4 ? v[4] as? String : nil)
        }

        let payees = PayeesRepository(), transactions = TransactionsRepository()
        for t in json["transactions"] as? [[Any]] ?? [] {
            guard t.count >= 5, let account = accounts[t[0] as? String ?? ""], let date = day(t[4]), date <= today else { continue }
            func field(_ i: Int) -> String? { t.count > i ? t[i] as? String : nil }
            transactions.create(
                accountId: account, categoryId: categories[field(1) ?? ""], payeeId: field(2).map { payees.ensure(name: $0) },
                memo: field(5), purchaseItems: field(6), amountCents: cents(t[3]), date: date,
                cleared: date < today, transferAccountId: accounts[field(7) ?? ""]
            )
        }

        let schedules = ScheduledTransactionsRepository()
        for s in json["schedules"] as? [[Any]] ?? [] {
            guard s.count == 7, let account = accounts[s[0] as? String ?? ""],
                  let frequency = Frequency(rawValue: s[4] as? String ?? ""), let next = day(s[6]) else { continue }
            schedules.create(
                accountId: account, categoryId: categories[s[1] as? String ?? ""], payeeId: payees.ensure(name: s[2] as? String ?? ""),
                memo: nil, amountCents: cents(s[3]), frequency: frequency, intervalN: s[5] as? Int ?? 1,
                nextDate: next, endDate: nil, isInterest: false
            )
        }

        let houses = HouseHuntRepository()
        for h in json["houseHunt"] as? [[String: Any]] ?? [] {
            houses.create(HouseHuntListing(
                id: 0, community: h["community"] as? String ?? "", askingPriceCents: cents(h["price"]),
                beds: h["beds"] as? Int, baths: (h["baths"] as? NSNumber)?.doubleValue, areaSqft: h["sqft"] as? Int,
                downPaymentPercent: (h["down"] as? NSNumber)?.doubleValue ?? 20, ratePercent: (h["rate"] as? NSNumber)?.doubleValue ?? 5,
                termMonths: h["term"] as? Int ?? 300, notes: h["notes"] as? String, rating: h["rating"] as? Int
            ))
        }
    }

    static func date(_ text: String, now: Date, calendar: Calendar = .current) -> Date? {
        guard let m = text.wholeMatch(of: #/@(today|month)([+-]\d+)?(?: (\d{1,2}))?/#) else { return nil }
        let amount = m.2.flatMap { Int($0) } ?? 0
        let start = calendar.startOfDay(for: now)
        if m.1 == "today" {
            guard m.3 == nil else { return nil }
            return calendar.date(byAdding: .day, value: amount, to: start)
        }
        guard let month = calendar.date(byAdding: .month, value: amount, to: start),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let days = calendar.range(of: .day, in: .month, for: first)?.count else { return nil }
        let dayOfMonth = min(max(m.3.flatMap { Int($0) } ?? 1, 1), days)
        return calendar.date(byAdding: .day, value: dayOfMonth - 1, to: first)
    }
}
