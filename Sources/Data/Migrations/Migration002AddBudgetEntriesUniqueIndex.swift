/// Migration001 was edited in place to add `UNIQUE(category_id, month)`
/// after some installs had already applied it at schema version 1 — those
/// DBs never re-ran migration001's SQL, so `budget_entries.setAssigned`'s
/// `ON CONFLICT` failed against them. A real migration, not another edit to
/// migration001, so every already-migrated DB (including this repo's own
/// simulator installs) catches up too.
enum Migration002AddBudgetEntriesUniqueIndex {
    static let sql = """
    CREATE UNIQUE INDEX IF NOT EXISTS idx_budget_entries_category_month
    ON budget_entries(category_id, month);
    """
}
