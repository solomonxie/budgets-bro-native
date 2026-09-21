/// Boards — the missing piece from the original: every account, category
/// group, payee, and schedule belongs to a board, so more than one budget
/// (or a demo one alongside a real one) can exist side by side. Existing
/// rows (from installs before this migration) land in a default "My Board"
/// so nothing is orphaned. See budgets-bro's `boardsRepo.ts`/`useBoards.ts`.
enum Migration005Boards {
    static let sql = """
    CREATE TABLE boards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
    );
    INSERT INTO boards (id, name) VALUES (1, 'My Board');

    -- No inline REFERENCES here: SQLite refuses ALTER TABLE ADD COLUMN when a
    -- column combines a foreign key with a non-NULL default ("Cannot add a
    -- REFERENCES column with non-NULL default value"). The board_id -> boards.id
    -- relationship is enforced in application code instead (every board_id
    -- written goes through BoardContext.shared.currentBoardId, which always
    -- names a real row).
    ALTER TABLE accounts ADD COLUMN board_id INTEGER NOT NULL DEFAULT 1;
    ALTER TABLE category_groups ADD COLUMN board_id INTEGER NOT NULL DEFAULT 1;
    ALTER TABLE payees ADD COLUMN board_id INTEGER NOT NULL DEFAULT 1;
    ALTER TABLE scheduled_transactions ADD COLUMN board_id INTEGER NOT NULL DEFAULT 1;
    """
}
