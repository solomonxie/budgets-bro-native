/// Category funding targets (docs/DESIGN.md's "Category targets" backlog
/// item) and split transactions (the "largest gap" per that same doc's
/// backlog) — a split zeroes the parent's `category_id` and allocates the
/// same total across `transaction_splits` rows instead.
enum Migration004TargetsAndSplits {
    static let sql = """
    ALTER TABLE categories ADD COLUMN target_cents INTEGER;
    ALTER TABLE categories ADD COLUMN target_type TEXT;

    CREATE TABLE transaction_splits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL REFERENCES transactions(id),
        category_id INTEGER REFERENCES categories(id),
        amount_cents INTEGER NOT NULL,
        memo TEXT
    );

    CREATE TABLE house_hunt_listings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        community TEXT NOT NULL,
        asking_price_cents INTEGER NOT NULL DEFAULT 0,
        beds INTEGER,
        baths REAL,
        area_sqft INTEGER,
        down_payment_percent REAL NOT NULL DEFAULT 20,
        rate_percent REAL NOT NULL DEFAULT 6.5,
        term_months INTEGER NOT NULL DEFAULT 360,
        notes TEXT,
        rating INTEGER,
        created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
    );
    """
}
