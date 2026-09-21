import Foundation

struct ScheduledTransaction: Identifiable, Hashable {
    var id: Int
    var accountId: Int
    var categoryId: Int?
    var payeeId: Int?
    var memo: String?
    var amountCents: Int
    var frequency: Frequency
    var intervalN: Int
    var nextDate: String
    var endDate: String?
    var autoPost: Bool
    var isInterest: Bool
}

/// CRUD for `scheduled_transactions` — see docs/DESIGN.md's Recurring/
/// scheduled transactions section. Every schedule auto-posts (no manual
/// "Upcoming" approval queue), matching the original's simplified T8.10.
final class ScheduledTransactionsRepository {
    private let database: Database
    init(database: Database = .shared) { self.database = database }

    private var boardId: Int { BoardContext.shared.currentBoardId }

    func all() -> [ScheduledTransaction] {
        database.query(
            """
            SELECT id, account_id, category_id, payee_id, memo, amount_cents, frequency,
                   interval_n, next_date, end_date, auto_post, is_interest
            FROM scheduled_transactions
            WHERE board_id = ?
            """,
            [boardId],
            row: Self.map
        )
    }

    @discardableResult
    func create(
        accountId: Int,
        categoryId: Int?,
        payeeId: Int?,
        memo: String?,
        amountCents: Int,
        frequency: Frequency,
        intervalN: Int,
        nextDate: String,
        endDate: String?,
        isInterest: Bool
    ) -> Int {
        Int(database.run(
            """
            INSERT INTO scheduled_transactions
                (account_id, category_id, payee_id, memo, amount_cents, frequency, interval_n, next_date, end_date, is_interest, board_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [accountId, categoryId, payeeId, memo, amountCents, frequency.rawValue, intervalN, nextDate, endDate, isInterest, boardId]
        ))
    }

    func updateNextDate(id: Int, nextDate: String) {
        database.run("UPDATE scheduled_transactions SET next_date = ? WHERE id = ?", [nextDate, id])
    }

    func delete(id: Int) {
        database.run("DELETE FROM scheduled_transactions WHERE id = ?", [id])
    }

    private static func map(_ row: Row) -> ScheduledTransaction {
        ScheduledTransaction(
            id: row.int(0),
            accountId: row.int(1),
            categoryId: row.isNull(2) ? nil : row.int(2),
            payeeId: row.isNull(3) ? nil : row.int(3),
            memo: row.text(4),
            amountCents: row.int(5),
            frequency: Frequency(rawValue: row.text(6) ?? "") ?? .monthly,
            intervalN: row.int(7),
            nextDate: row.text(8) ?? "",
            endDate: row.text(9),
            autoPost: row.int(10) != 0,
            isInterest: row.int(11) != 0
        )
    }
}

/// Lazily checked on app launch/foreground (no push notifications or OS
/// background jobs — out of scope per docs/DESIGN.md), catching up any
/// number of missed occurrences in one pass.
enum AutoPostRunner {
    static func run() {
        let schedules = ScheduledTransactionsRepository()
        let transactions = TransactionsRepository()
        let cutoff = today()

        for schedule in schedules.all() where schedule.autoPost {
            var nextDate = schedule.nextDate
            var postedCount = 0
            while nextDate <= cutoff, postedCount < 366 {
                if let endDate = schedule.endDate, nextDate > endDate { break }
                transactions.create(
                    accountId: schedule.accountId,
                    categoryId: schedule.categoryId,
                    payeeId: schedule.payeeId,
                    memo: schedule.memo,
                    amountCents: schedule.amountCents,
                    date: nextDate,
                    isInterest: schedule.isInterest
                )
                nextDate = formatDate(Recurrence.nextOccurrenceDate(from: parseDate(nextDate), frequency: schedule.frequency, intervalN: schedule.intervalN))
                postedCount += 1
            }
            if postedCount > 0 {
                schedules.updateNextDate(id: schedule.id, nextDate: nextDate)
            }
        }
    }
}
