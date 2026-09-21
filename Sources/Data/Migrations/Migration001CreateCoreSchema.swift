/// Ported from budgets-bro's core schema — see that repo's
/// docs/DESIGN.md#core-domain-model. Phase 1 (T1.1) extends this with the
/// remaining columns (icon, is_interest, purchase_items, etc.) as each
/// screen that needs them is built.
enum Migration001CreateCoreSchema {
    static let sql = """
    CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        on_budget INTEGER NOT NULL DEFAULT 1,
        currency TEXT NOT NULL DEFAULT 'USD',
        opening_balance_cents INTEGER NOT NULL DEFAULT 0,
        archived_at TEXT,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
    );

    CREATE TABLE category_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL REFERENCES category_groups(id),
        name TEXT NOT NULL,
        icon TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        archived_at TEXT
    );

    CREATE TABLE payees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
    );

    CREATE TABLE budget_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES categories(id),
        month TEXT NOT NULL,
        assigned_cents INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL REFERENCES accounts(id),
        category_id INTEGER REFERENCES categories(id),
        payee_id INTEGER REFERENCES payees(id),
        memo TEXT,
        purchase_items TEXT,
        amount_cents INTEGER NOT NULL,
        date TEXT NOT NULL,
        cleared INTEGER NOT NULL DEFAULT 0,
        is_interest INTEGER NOT NULL DEFAULT 0,
        transfer_account_id INTEGER REFERENCES accounts(id),
        import_id TEXT UNIQUE,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
        updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
    );

    CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
    );
    """
}
