/// Adds loan/mortgage rate history, a generic value-history log (shared by
/// mortgage home-value and tracking-account value per docs/DESIGN.md's
/// "Tracking/investment accounts" section), the loan-linked-payee column,
/// and recurring/scheduled transactions. See DESIGN.md's Phase 6 sections.
enum Migration003LoanTrackingRecurring {
    static let sql = """
    ALTER TABLE accounts ADD COLUMN origination_principal_cents INTEGER;
    ALTER TABLE accounts ADD COLUMN origination_date TEXT;
    ALTER TABLE accounts ADD COLUMN term_months INTEGER;

    ALTER TABLE payees ADD COLUMN linked_account_id INTEGER REFERENCES accounts(id);

    CREATE TABLE account_rate_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        rate_bps INTEGER NOT NULL,
        effective_date TEXT NOT NULL
    );

    CREATE TABLE account_value_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        kind TEXT NOT NULL, -- 'value' (home/tracking worth) or 'principal' (loan remaining principal reading)
        value_cents INTEGER NOT NULL,
        effective_date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
    );

    CREATE TABLE scheduled_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        category_id INTEGER REFERENCES categories(id),
        payee_id INTEGER REFERENCES payees(id),
        memo TEXT,
        amount_cents INTEGER NOT NULL,
        frequency TEXT NOT NULL, -- 'daily' | 'weekly' | 'monthly' | 'yearly'
        interval_n INTEGER NOT NULL DEFAULT 1,
        next_date TEXT NOT NULL,
        end_date TEXT,
        auto_post INTEGER NOT NULL DEFAULT 1,
        is_interest INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
    );
    """
}
