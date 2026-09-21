import Foundation

/// Invented, middle-class household finances shaped like a real board —
/// ported from budgets-bro's `db/seed/demoBoard.ts` line for line where
/// practical, same account/category/payee names, so switching to "Demo"
/// looks the same in both apps. Every number is fictional.
enum DemoBoardSeeder {
    static let demoBoardName = "Demo"

    private static func cents(_ dollars: Double) -> Int { Int((dollars * 100).rounded()) }
    private static func day(_ month: String, _ d: Int) -> String { "\(month)-\(String(format: "%02d", d))" }
    private static func rand(_ min: Double, _ max: Double) -> Double { min + Double.random(in: 0 ... 1) * (max - min) }
    private static func pick(_ items: [String]) -> String { items.randomElement()! }

    private struct AmortStep { let interestCents: Int; let principalCents: Int; let balanceCents: Int }

    /// Fixed-payment amortization off the *original* principal/term —
    /// same payment every month, split interest/principal as the balance
    /// shrinks. Real enough for a demo without modeling rate resets.
    private static func amortize(principalCents: Int, annualRateBps: Int, termMonths: Int, numMonths: Int) -> [AmortStep] {
        let r = Double(annualRateBps) / 10000 / 12
        let payment = r == 0 ? Double(principalCents) / Double(termMonths) : (Double(principalCents) * r) / (1 - pow(1 + r, -Double(termMonths)))
        var steps: [AmortStep] = []
        var balance = Double(principalCents)
        for _ in 0 ..< numMonths {
            let interest = balance * r
            let principal = min(payment - interest, balance)
            balance -= principal
            steps.append(AmortStep(interestCents: Int(interest.rounded()), principalCents: Int(principal.rounded()), balanceCents: Int(balance.rounded())))
        }
        return steps
    }

    @discardableResult
    static func seed() -> Int {
        let boardsRepo = BoardsRepository()
        let accountsRepo = AccountsRepository()
        let categoriesRepo = CategoriesRepository()
        let transactionsRepo = TransactionsRepository()
        let budgetRepo = BudgetRepository()
        let loanRepo = LoanRepository()

        let boardId = boardsRepo.create(name: boardsRepo.uniqueName(base: demoBoardName))
        BoardContext.shared.currentBoardId = boardId

        let months: [String] = (0 ..< 24).reversed().map { offset in
            monthString(from: Calendar.current.date(byAdding: .month, value: -offset, to: Date())!)
        }

        let checkingId = accountsRepo.create(name: "Everyday Chequing", type: .checking, onBudget: true, openingBalanceCents: cents(4000))
        let savingsId = accountsRepo.create(name: "High-Interest Savings", type: .savings, onBudget: true, openingBalanceCents: cents(12000))
        let ccId = accountsRepo.create(name: "Rewards Visa", type: .creditCard, onBudget: true, openingBalanceCents: 0)
        let cc2Id = accountsRepo.create(name: "Cashback Mastercard", type: .creditCard, onBudget: true, openingBalanceCents: 0)

        // Primary residence — a year into its term when the window starts.
        let houseSchedule = amortize(principalCents: cents(900_000), annualRateBps: 575, termMonths: 300, numMonths: 36)
        let houseOpeningCents = -houseSchedule[11].balanceCents
        let housePayments = Array(houseSchedule[12...])
        let houseId = accountsRepo.create(
            name: "Maple Street House Mortgage", type: .mortgage, onBudget: false, openingBalanceCents: houseOpeningCents,
            termMonths: 300, originationPrincipalCents: cents(900_000), originationDate: day(months[0], 1)
        )
        loanRepo.addRate(accountId: houseId, ratePercent: 5.75, effectiveDate: day(months[0], 1))
        loanRepo.addValueReading(accountId: houseId, kind: "principal", valueCents: -houseOpeningCents, effectiveDate: day(months[12], 1), note: "Annual statement")
        loanRepo.addValueReading(accountId: houseId, kind: "value", valueCents: cents(980_000), effectiveDate: day(months[0], 1), note: nil)
        loanRepo.addValueReading(accountId: houseId, kind: "value", valueCents: cents(1_010_000), effectiveDate: day(months[11], 1), note: nil)
        loanRepo.addValueReading(accountId: houseId, kind: "value", valueCents: cents(1_040_000), effectiveDate: day(months[23], 15), note: nil)

        // A small cabin, paid off years ago — a plain Asset, just a logged
        // value that drifts up slowly.
        let cabinId = accountsRepo.create(name: "Whistler Cabin", type: .asset, onBudget: false, openingBalanceCents: cents(350_000))
        loanRepo.addValueReading(accountId: cabinId, kind: "value", valueCents: cents(350_000), effectiveDate: day(months[0], 1), note: nil)
        loanRepo.addValueReading(accountId: cabinId, kind: "value", valueCents: cents(365_000), effectiveDate: day(months[11], 1), note: nil)
        loanRepo.addValueReading(accountId: cabinId, kind: "value", valueCents: cents(380_000), effectiveDate: day(months[23], 15), note: nil)

        let belongingsId = accountsRepo.create(name: "Personal Belongings", type: .asset, onBudget: false, openingBalanceCents: cents(9600))
        loanRepo.addValueReading(accountId: belongingsId, kind: "value", valueCents: cents(9600), effectiveDate: day(months[0], 1), note: nil)
        loanRepo.addValueReading(accountId: belongingsId, kind: "value", valueCents: cents(8700), effectiveDate: day(months[7], 1), note: nil)
        loanRepo.addValueReading(accountId: belongingsId, kind: "value", valueCents: cents(10200), effectiveDate: day(months[8], 15), note: nil)
        loanRepo.addValueReading(accountId: belongingsId, kind: "value", valueCents: cents(9300), effectiveDate: day(months[15], 1), note: nil)
        loanRepo.addValueReading(accountId: belongingsId, kind: "value", valueCents: cents(8100), effectiveDate: day(months[23], 15), note: nil)

        let belongingsPurchases: [(item: String, merchant: String, price: Double, monthIndex: Int, day: Int)] = [
            ("iPad Air", "Apple Store", 650, 2, 14),
            ("Sony WH-1000XM5 Headphones", "Best Buy", 380, 5, 20),
            ("Apple Watch Ultra 2", "Apple Store", 850, 8, 9),
            ("Dyson V15 Vacuum", "Best Buy", 650, 8, 11),
            ("PlayStation 5", "Best Buy", 500, 12, 5),
            ("Sectional Sofa", "IKEA", 700, 18, 22),
            ("Canon EOS R50 Camera", "Canon Store", 680, 21, 9),
        ]
        let payeesRepo = PayeesRepository()
        for purchase in belongingsPurchases {
            transactionsRepo.create(
                accountId: belongingsId, categoryId: nil, payeeId: payeesRepo.ensure(name: purchase.item),
                memo: purchase.merchant, amountCents: cents(purchase.price), date: day(months[purchase.monthIndex], purchase.day)
            )
        }

        // Car loan, car lease, student loan — three repayment shapes beyond
        // the mortgage above.
        let carLoanSchedule = amortize(principalCents: cents(28000), annualRateBps: 649, termMonths: 60, numMonths: 14 + months.count)
        let carLoanId = accountsRepo.create(
            name: "Highlander Auto Loan", type: .loan, onBudget: false, openingBalanceCents: -carLoanSchedule[13].balanceCents,
            termMonths: 60, originationPrincipalCents: cents(28000)
        )
        loanRepo.addRate(accountId: carLoanId, ratePercent: 6.49, effectiveDate: day(months[0], 1))
        let carLoanPayments = Array(carLoanSchedule[14...])

        let carLeasePrincipalCents = cents(420 * 36)
        let carLeaseSchedule = amortize(principalCents: carLeasePrincipalCents, annualRateBps: 0, termMonths: 36, numMonths: months.count)
        let carLeaseId = accountsRepo.create(
            name: "CR-V Lease", type: .loan, onBudget: false, openingBalanceCents: -carLeasePrincipalCents,
            termMonths: 36, originationPrincipalCents: carLeasePrincipalCents
        )
        loanRepo.addRate(accountId: carLeaseId, ratePercent: 0, effectiveDate: day(months[0], 1))

        let studentLoanSchedule = amortize(principalCents: cents(22000), annualRateBps: 549, termMonths: 120, numMonths: 30 + months.count)
        let studentLoanId = accountsRepo.create(
            name: "Student Loan", type: .loan, onBudget: false, openingBalanceCents: -studentLoanSchedule[29].balanceCents,
            termMonths: 120, originationPrincipalCents: cents(22000)
        )
        loanRepo.addRate(accountId: studentLoanId, ratePercent: 5.49, effectiveDate: day(months[0], 1))
        let studentLoanPayments = Array(studentLoanSchedule[30...])

        // Revolving line of credit — modeled like the cards below.
        let locId = accountsRepo.create(name: "Personal Line of Credit", type: .creditCard, onBudget: true, openingBalanceCents: -cents(3500))
        var locBalance = cents(3500)

        let rrspId = accountsRepo.create(name: "RRSP", type: .tracking, onBudget: false, openingBalanceCents: cents(45000))
        let tfsaId = accountsRepo.create(name: "TFSA", type: .tracking, onBudget: false, openingBalanceCents: cents(22000))
        let investId = accountsRepo.create(name: "Non-Registered Investments", type: .tracking, onBudget: false, openingBalanceCents: cents(12000))
        loanRepo.addValueReading(accountId: rrspId, kind: "value", valueCents: cents(45000), effectiveDate: day(months[0], 1), note: nil)
        loanRepo.addValueReading(accountId: tfsaId, kind: "value", valueCents: cents(22000), effectiveDate: day(months[0], 1), note: nil)
        loanRepo.addValueReading(accountId: investId, kind: "value", valueCents: cents(12000), effectiveDate: day(months[0], 1), note: nil)

        // --- categories ---
        let housingGroup = categoriesRepo.createGroup(name: "Mortgages & Housing")
        let catHouse = categoriesRepo.createCategory(groupId: housingGroup, name: "Mortgage Payment", icon: "🏡")
        let catPropertyTax = categoriesRepo.createCategory(groupId: housingGroup, name: "Property Tax", icon: "🧾")
        let catHomeInsurance = categoriesRepo.createCategory(groupId: housingGroup, name: "Home Insurance", icon: "🛡️")
        let catUtilities = categoriesRepo.createCategory(groupId: housingGroup, name: "Utilities", icon: "💡")
        let catHomeMaintenance = categoriesRepo.createCategory(groupId: housingGroup, name: "Home Maintenance", icon: "🛠️")

        let everydayGroup = categoriesRepo.createGroup(name: "Everyday Expenses")
        let catGroceries = categoriesRepo.createCategory(groupId: everydayGroup, name: "Groceries", icon: "🛒")
        let catDining = categoriesRepo.createCategory(groupId: everydayGroup, name: "Dining Out", icon: "🍽️")
        let catCoffee = categoriesRepo.createCategory(groupId: everydayGroup, name: "Coffee & Quick Stops", icon: "☕")
        let catTransport = categoriesRepo.createCategory(groupId: everydayGroup, name: "Transportation & Gas", icon: "⛽")
        let catShopping = categoriesRepo.createCategory(groupId: everydayGroup, name: "Shopping", icon: "🛍️")
        let catSubscriptions = categoriesRepo.createCategory(groupId: everydayGroup, name: "Subscriptions", icon: "📱")

        let qolGroup = categoriesRepo.createGroup(name: "Quality of Life")
        let catTravel = categoriesRepo.createCategory(groupId: qolGroup, name: "Travel & Vacation", icon: "✈️")
        let catHobbies = categoriesRepo.createCategory(groupId: qolGroup, name: "Hobbies & Recreation", icon: "🎉")
        let catGym = categoriesRepo.createCategory(groupId: qolGroup, name: "Gym & Wellness", icon: "💪")

        let givingGroup = categoriesRepo.createGroup(name: "Giving")
        let catCharity = categoriesRepo.createCategory(groupId: givingGroup, name: "Charitable Giving", icon: "🎁")

        let savingsGroup = categoriesRepo.createGroup(name: "Savings Goals")
        let catRrsp = categoriesRepo.createCategory(groupId: savingsGroup, name: "RRSP Contributions", icon: "🏦")
        let catTfsa = categoriesRepo.createCategory(groupId: savingsGroup, name: "TFSA Contributions", icon: "💰")
        let catInvest = categoriesRepo.createCategory(groupId: savingsGroup, name: "Investment Contributions", icon: "📈")

        let loansGroup = categoriesRepo.createGroup(name: "Loans & Financing")
        let catCarLoan = categoriesRepo.createCategory(groupId: loansGroup, name: "Highlander Loan Payment", icon: "🚙")
        let catCarLease = categoriesRepo.createCategory(groupId: loansGroup, name: "CR-V Lease Payment", icon: "🚗")
        let catStudentLoan = categoriesRepo.createCategory(groupId: loansGroup, name: "Student Loan Payment", icon: "🎓")
        let catLocDraw = categoriesRepo.createCategory(groupId: loansGroup, name: "Line of Credit Draws", icon: "🛠️")

        // --- 24 months of transactions + budget ---
        let groceryPayees = ["Save-On-Foods", "Whole Foods", "Costco"]
        let diningPayees = ["The Keg Steakhouse", "Uber Eats", "Local Bistro"]
        let coffeePayees = ["Tim Hortons", "Starbucks", "Circle K"]
        let shoppingPayees = ["Amazon", "Best Buy", "Apple Store"]
        let travelPayees = ["Air Canada", "WestJet"]

        var checkingBalance = cents(4000)
        var rrspBalance = cents(45000)
        var tfsaBalance = cents(22000)
        var investBalance = cents(12000)
        var savingsBalance = cents(12000)
        var ccBalance = 0
        var cc2Balance = 0
        let checkingFloor = cents(300)

        func postChecking(_ categoryId: Int?, _ payeeName: String, _ amountCents: Int, _ date: String) {
            let shortfall = amountCents < 0 ? checkingFloor - (checkingBalance + amountCents) : 0
            if shortfall > 0 {
                let coverCents = min(shortfall, max(0, savingsBalance))
                if coverCents > 0 {
                    savingsBalance -= coverCents
                    checkingBalance += coverCents
                    let overdraftPayeeId = payeesRepo.ensure(name: "Overdraft Protection Transfer")
                    transactionsRepo.create(accountId: savingsId, categoryId: nil, payeeId: overdraftPayeeId, memo: nil, amountCents: -coverCents, date: date)
                    transactionsRepo.create(accountId: checkingId, categoryId: nil, payeeId: overdraftPayeeId, memo: nil, amountCents: coverCents, date: date)
                }
            }
            checkingBalance += amountCents
            transactionsRepo.create(accountId: checkingId, categoryId: categoryId, payeeId: payeesRepo.ensure(name: payeeName), memo: nil, amountCents: amountCents, date: date)
        }
        func postIncome(_ payeeName: String, _ amountCents: Int, _ date: String) {
            postChecking(nil, payeeName, amountCents, date)
        }

        for i in 0 ..< months.count {
            let month = months[i]
            let inflation = 1 + (Double(i) / Double(months.count)) * 0.05

            postIncome("Meridian Robotics Inc", cents(rand(3400, 3600) * inflation), day(month, 1))
            postIncome("Meridian Robotics Inc", cents(rand(3400, 3600) * inflation), day(month, 15))
            postIncome("Alderbrook Consulting Group", cents(rand(1900, 2100) * inflation), day(month, 1))
            postIncome("Alderbrook Consulting Group", cents(rand(1900, 2100) * inflation), day(month, 15))
            if Double.random(in: 0 ... 1) < 0.75 {
                postIncome("Freelance Design Gigs", cents(rand(400, 1200) * inflation), day(month, [8, 22].randomElement()!))
            }

            let house = housePayments[i]
            postChecking(catHouse, "Maple Street House Mortgage", -(house.principalCents + house.interestCents), day(month, 1))
            let carLoan = carLoanPayments[i]
            postChecking(catCarLoan, "Highlander Auto Loan", -(carLoan.principalCents + carLoan.interestCents), day(month, 4))
            let carLease = carLeaseSchedule[i]
            postChecking(catCarLease, "CR-V Lease", -carLease.principalCents, day(month, 4))
            let studentLoan = studentLoanPayments[i]
            postChecking(catStudentLoan, "Student Loan", -(studentLoan.principalCents + studentLoan.interestCents), day(month, 20))

            if i % 7 == 3 {
                let drawCents = cents(rand(500, 1400))
                locBalance += drawCents
                transactionsRepo.create(accountId: locId, categoryId: catLocDraw, payeeId: payeesRepo.ensure(name: "Rona"), memo: nil, amountCents: -drawCents, date: day(month, 10))
            }
            let locInterestCents = Int((Double(locBalance) * rand(0.075, 0.095) / 12).rounded())
            locBalance += locInterestCents
            transactionsRepo.create(accountId: locId, categoryId: nil, payeeId: payeesRepo.ensure(name: "Line of Credit Interest"), memo: nil, amountCents: -locInterestCents, date: day(month, 25))
            let locPaymentCents = Int((Double(locBalance) * rand(0.1, 0.2)).rounded())
            locBalance -= locPaymentCents
            postChecking(nil, "Personal Line of Credit", -locPaymentCents, day(month, 26))

            if i % 3 == 0 {
                postChecking(catPropertyTax, "City Property Tax", -cents(rand(1000, 1200) * 3), day(month, 2))
            }
            postChecking(catHomeInsurance, "Coastal Insurance Co.", -cents(rand(130, 160)), day(month, 3))
            postChecking(catUtilities, pick(["BC Hydro", "Telus", "Shaw"]), -cents(rand(180, 260)), day(month, 8))
            if Double.random(in: 0 ... 1) < 0.3 {
                postChecking(catHomeMaintenance, "Home Depot", -cents(rand(120, 500)), day(month, 12))
            }

            for g in 0 ..< 4 {
                postChecking(catGroceries, pick(groceryPayees), -cents(rand(130, 230)), day(month, 3 + g * 6))
            }
            for d in 0 ..< 4 {
                postChecking(catDining, pick(diningPayees), -cents(rand(40, 110)), day(month, 4 + d * 6))
            }
            for g in 0 ..< 3 {
                postChecking(catTransport, "Chevron", -cents(rand(55, 90)), day(month, 6 + g * 8))
            }

            var ccCharges = 0
            for s in 0 ..< 3 {
                let amt = cents(rand(70, 180))
                ccCharges += amt
                transactionsRepo.create(accountId: ccId, categoryId: catShopping, payeeId: payeesRepo.ensure(name: pick(shoppingPayees)), memo: nil, amountCents: -amt, date: day(month, 9 + s * 7))
            }
            let subAmt = cents(rand(55, 70))
            ccCharges += subAmt
            transactionsRepo.create(accountId: ccId, categoryId: catSubscriptions, payeeId: payeesRepo.ensure(name: "Streaming Bundle"), memo: nil, amountCents: -subAmt, date: day(month, 5))
            if i % 6 == 2 {
                let travelAmt = cents(rand(1500, 3000))
                ccCharges += travelAmt
                transactionsRepo.create(accountId: ccId, categoryId: catTravel, payeeId: payeesRepo.ensure(name: pick(travelPayees)), memo: nil, amountCents: -travelAmt, date: day(month, 18))
            }

            var cc2Charges = 0
            for c in 0 ..< 6 {
                let amt = cents(rand(4, 9))
                cc2Charges += amt
                transactionsRepo.create(accountId: cc2Id, categoryId: catCoffee, payeeId: payeesRepo.ensure(name: pick(coffeePayees)), memo: nil, amountCents: -amt, date: day(month, 2 + c * 4))
            }

            for h in 0 ..< 2 {
                postChecking(catHobbies, "Local Rec Centre", -cents(rand(30, 70)), day(month, 14 + h * 10))
            }
            postChecking(catGym, "GoodLife Fitness", -cents(60), day(month, 4))
            postChecking(catCharity, "Local Food Bank", -cents(80), day(month, 20))

            let owed = ccBalance + ccCharges
            let ccPayment = Int((Double(owed) * rand(0.75, 0.95)).rounded())
            ccBalance = owed - ccPayment
            postChecking(nil, "Rewards Visa", -ccPayment, day(month, 26))
            let owed2 = cc2Balance + cc2Charges
            let cc2Payment = Int((Double(owed2) * rand(0.9, 1)).rounded())
            cc2Balance = owed2 - cc2Payment
            postChecking(nil, "Cashback Mastercard", -cc2Payment, day(month, 26))

            let rrspContribution = cents(400)
            postChecking(catRrsp, "RRSP", -rrspContribution, day(month, 27))
            let rrspGrowth = Int((Double(rrspBalance) * rand(-0.01, 0.02)).rounded())
            rrspBalance += rrspContribution + rrspGrowth
            loanRepo.addValueReading(accountId: rrspId, kind: "value", valueCents: rrspBalance, effectiveDate: day(month, 28), note: nil)
            transactionsRepo.create(accountId: rrspId, categoryId: nil, payeeId: payeesRepo.ensure(name: "RRSP Market Growth"), memo: nil, amountCents: rrspGrowth, date: day(month, 28))

            let tfsaContribution = cents(300)
            postChecking(catTfsa, "TFSA", -tfsaContribution, day(month, 27))
            let tfsaGrowth = Int((Double(tfsaBalance) * rand(-0.01, 0.02)).rounded())
            tfsaBalance += tfsaContribution + tfsaGrowth
            loanRepo.addValueReading(accountId: tfsaId, kind: "value", valueCents: tfsaBalance, effectiveDate: day(month, 28), note: nil)
            transactionsRepo.create(accountId: tfsaId, categoryId: nil, payeeId: payeesRepo.ensure(name: "TFSA Market Growth"), memo: nil, amountCents: tfsaGrowth, date: day(month, 28))

            let investContribution = cents(200)
            postChecking(catInvest, "Non-Registered Investments", -investContribution, day(month, 27))
            let investGrowth = Int((Double(investBalance) * rand(-0.015, 0.025)).rounded())
            investBalance += investContribution + investGrowth
            loanRepo.addValueReading(accountId: investId, kind: "value", valueCents: investBalance, effectiveDate: day(month, 28), note: nil)
            transactionsRepo.create(accountId: investId, categoryId: nil, payeeId: payeesRepo.ensure(name: "Investment Market Growth"), memo: nil, amountCents: investGrowth, date: day(month, 28))

            let sweepHeadroom = max(0, checkingBalance - checkingFloor - cents(200))
            let savingsTransfer = min(cents(rand(150, 350)), sweepHeadroom)
            if savingsTransfer > 0 {
                postChecking(nil, "High-Interest Savings", -savingsTransfer, day(month, 28))
            }
            let savingsInterest = Int((Double(savingsBalance) * rand(0.002, 0.004)).rounded())
            savingsBalance += savingsTransfer + savingsInterest
            transactionsRepo.create(accountId: savingsId, categoryId: nil, payeeId: payeesRepo.ensure(name: "Savings Interest"), memo: nil, amountCents: savingsInterest, date: day(month, 28))

            let assignments: [(Int, Int)] = [
                (catHouse, house.principalCents + house.interestCents),
                (catCarLoan, carLoan.principalCents + carLoan.interestCents),
                (catCarLease, carLease.principalCents),
                (catStudentLoan, studentLoan.principalCents + studentLoan.interestCents),
                (catLocDraw, cents(100)),
                (catPropertyTax, cents(370)),
                (catHomeInsurance, cents(145)),
                (catUtilities, cents(230)),
                (catHomeMaintenance, cents(200)),
                (catGroceries, cents(800)),
                (catDining, cents(400)),
                (catCoffee, cents(50)),
                (catTransport, cents(240)),
                (catShopping, cents(400)),
                (catSubscriptions, cents(60)),
                (catTravel, cents(350)),
                (catHobbies, cents(120)),
                (catGym, cents(60)),
                (catCharity, cents(80)),
                (catRrsp, rrspContribution),
                (catTfsa, tfsaContribution),
                (catInvest, investContribution),
            ]
            for (categoryId, base) in assignments {
                budgetRepo.setAssigned(categoryId: categoryId, month: month, cents: Int((Double(base) * inflation).rounded()))
            }
        }

        // Loan balances are derived from the latest logged principal reading
        // (see LoanRepository), not from transactions — log where each
        // schedule actually lands today so the account list matches the
        // payments just posted above, not just the origination balance.
        let today = day(months[months.count - 1], 28)
        loanRepo.addValueReading(accountId: carLoanId, kind: "principal", valueCents: carLoanPayments.last!.balanceCents, effectiveDate: today, note: nil)
        loanRepo.addValueReading(accountId: carLeaseId, kind: "principal", valueCents: carLeaseSchedule.last!.balanceCents, effectiveDate: today, note: nil)
        loanRepo.addValueReading(accountId: studentLoanId, kind: "principal", valueCents: studentLoanPayments.last!.balanceCents, effectiveDate: today, note: nil)
        loanRepo.addValueReading(accountId: houseId, kind: "principal", valueCents: housePayments.last!.balanceCents, effectiveDate: today, note: nil)

        NotificationCenter.default.post(name: .boardDidChange, object: nil)
        return boardId
    }
}
