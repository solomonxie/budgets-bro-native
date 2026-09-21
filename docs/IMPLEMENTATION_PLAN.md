# Budgets Bro Native — Implementation Plan

See [`DESIGN.md`](DESIGN.md) for the design doc these phases implement, and
[`UIUX-DESIGN.md`](UIUX-DESIGN.md) / [`design/uiux/`](design/uiux/) for the
screen-by-screen spec being ported with no UX diff. Source of truth for
domain rules being ported: [budgets-bro](https://github.com/solomonxie/budgets-bro)'s
own `docs/DESIGN.md`.

## Phase 0: Repo & Xcode project bootstrap
- [x] T0.1 Init git repo, copy design docs from `budgets-bro`, adapt for native stack
- [x] T0.2 `project.yml` (xcodegen) — single iOS app target, bundle id, deployment target; entitlements (iCloud container) still pending, needed before Phase 5
- [x] T0.3 Generate + commit `BudgetsBroNative.xcodeproj`; clean checkout builds (`xcodebuild build` verified green on iOS 27 simulator)
- [x] T0.4 App shell: `TabView` (Budget / Spend / Accounts / Insights) matching `docs/design/uiux/README.md`'s nav diagram — Spend intercepts its own tab press (`onChange` snap-back + `fullScreenCover`) instead of switching the displayed tab
- [x] T0.5 SQLite wrapper over `libsqlite3` + versioned migration runner (`PRAGMA user_version`) — `Sources/Data/Database.swift`
- [ ] T0.6 Keychain wrapper for API key / S3 credentials — `Sources/Secure/Keychain.swift`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (pulled forward to Phase 4/5 where it's first needed)
- [x] T0.7 XCTest target + one sample passing test (`DatabaseTests.testMigrationCreatesAccountsTable`)
- [ ] T0.8 SwiftLint + SwiftFormat config; GitHub Actions CI (`xcodebuild test`) — CI workflow committed, lint tools not yet added
- [x] T0.9 First size measurement against the 4.25 MB / 1.8 MB budget — Debug `.app` measured at 796 KB unstripped for the whole skeleton, well inside budget

**Frameworks finalized** (see `AGENTS.md`'s dependency table for the full list): SwiftUI/`NavigationStack`/`TabView` for nav, system `libsqlite3` for storage, `Security` Keychain for secrets, `CryptoKit` for SigV4 HMAC, `URLSession` for AI calls, Swift `Charts` for Insights. The one item that stayed open — the backup/YNAB-import zip container — is now decided too: Apple's `Archive`/`Compression` frameworks only speak the AAR format, not portable PKZIP, so backup/import zips need a **hand-rolled ZIP reader/writer over system `libz.tbd`** (deflate/inflate from zlib, container framing hand-written) — scoped to Phase 5/7 when backup and YNAB import land, not needed yet.

## Phase 1: Domain schema + Accounts/Categories CRUD
- [x] T1.1 Port SQLite schema 1:1 from `budgets-bro`'s current schema (`accounts`, `category_groups`, `categories`, `payees`, `budget_entries`, `transactions`, `app_settings` — see that repo's `docs/DESIGN.md#core-domain-model`) — `Sources/Data/Migrations/Migration001CreateCoreSchema.swift`
- [x] T1.2 `AccountsRepository` CRUD (create/update/archive, computed `balanceCents`) + Accounts screen per `docs/design/uiux/accounts.md` (Net Worth header, grouped-by-kind list with subtotals, add/edit sheet)
- [x] T1.3 `CategoriesRepository` CRUD (groups + categories) + inline management on the Budget screen (no separate Manage Categories page, matching the current/final UX — not replaying the original's now-superseded standalone-screen history)
- [x] T1.4 Shared domain types (`Sources/Domain/Models.swift`) — `Account`, `AccountType`, `CategoryGroup`, `Category`, `Payee`

## Phase 2: Transactions & budget envelope logic
- [ ] T2.1 `TransactionsRepository` CRUD incl. transfer pairing and balance-correction adjustment transactions
- [ ] T2.2 `BudgetMath.swift` pure functions: category rollover, to-be-budgeted, overspend — port with unit tests mirroring the original's `budgetMath.ts` test cases
- [ ] T2.3 `budget_entries` table + `BudgetsRepository`
- [ ] T2.4 Unit tests for `BudgetMath`

## Phase 3: Core budget UI
Per-screen specs: [`design/uiux/budget.md`](design/uiux/budget.md), [`spend.md`](design/uiux/spend.md), [`transactions.md`](design/uiux/transactions.md), [`accounts.md`](design/uiux/accounts.md).
- [x] T3.1 Budget screen: Unassigned Cash banner, collapsible category groups, status badge (funded/partial/overspent color) + caption per category, month navigation (arrows; label is display-only for now, not yet tappable-to-jump). `BudgetMath.swift` ported (categoryBalanceCents, status, unassignedCashCents) — progress bar visual still missing (color-coded number stands in for now)
- [x] T3.2 Add/edit transaction page: autofocused amount + custom number pad (`NumberPad` — grid of buttons, not the system keypad), outflow/inflow segmented toggle, category/account `Picker`s, free-text payee field with prefix-match suggestion chips, date, memo. **Deferred to a follow-up pass**: edit-existing-transaction flow (create-only today), cleared/interest toggles, recurrence builder, and the fuzzy-search picker sheet convention from `components.md` (using plain `Picker`s for now)
- [x] T3.3 Transactions list: grouped by date, swipe-to-delete. **Deferred**: search, multi-select bulk delete
- [x] T3.4 Account detail/register with running balance + "+ Transaction" pre-selecting the account. **Deferred**: Correct Balance action
- [x] T3.5 Insights: spending-by-category breakdown for the viewed month, all local. **Deferred**: category trend chart, interest-earned-this-month card

## Phase 4: Financial tools + AI analysis
- [x] T4.1 `Sources/FinanceTools/Amortization.swift`: mortgage/loan monthly payment, amortization schedule, remaining-months-to-payoff (+ extra payment), total interest remaining, simple/compound interest — ported, not yet unit-tested against the original's known-good outputs (tests come once the rest of the app catches up)
- [x] T4.2 Mortgage/loan calculator screen (ad-hoc, reachable from Insights)
- [~] T4.3 AI analysis: `Sources/Secure/Keychain.swift` (Keychain wrapper) done and wired into a Settings screen for key entry; the actual `URLSession` analysis call, aggregate/detailed payload modes, and in-app disclosure copy are not built yet

**Also landed ahead of schedule**: a real `SettingsView` (Payees rename + AI key entry; S3/Local Backup/Data sections are explicit "not built yet" stubs, not silently missing) and `Database`'s query/bind layer (`Row`, parameterized `run`/`query`, `.boardDidChange` notification posted on every write) that every repository above depends on.

**Known UI/UX gaps against the spec, to close in a follow-up pass**: the tab bar renders as iOS 27's default floating translucent pill, not the flush opaque bar `components.md` calls for; pickers are plain `Picker`s, not the fuzzy-search sheet convention; no half-height-sheet vs. full-page distinction is implemented yet (everything here uses `.sheet`); category rows have no progress bar.

**Bug found and fixed by the test pass** (caught immediately, not shipped): `Migration001` was edited in place mid-development to add `UNIQUE(category_id, month)` on `budget_entries`, after installs already existed at schema version 1 — those DBs (including this repo's own simulator smoke-test install) never re-ran migration001's SQL, so `BudgetRepository.setAssigned`'s `ON CONFLICT` upsert crashed with "ON CONFLICT clause does not match any PRIMARY KEY or UNIQUE constraint". Fixed with a real `Migration002` (`CREATE UNIQUE INDEX IF NOT EXISTS`) instead of re-editing migration001 — the general lesson (already implicit in AGENTS.md's migration-runner rule) is that a migration's SQL is immutable once anything has run it; a schema fix is always a new migration. Also fixed in the same pass: `Amortization.buildSchedule` left a few stray cents unpaid at the end of a schedule instead of paying off exactly — the final month's payment is now adjusted to clear the remaining balance, same as a real amortization table.

## Phase 5: Backup & restore
Per [`design/DESIGN.md#storage-backup-architecture`](DESIGN.md#storage-backup-architecture).
- [ ] T5.1 Local on-device snapshot (Files-app-visible) — the practical always-available destination
- [ ] T5.2 iCloud backup via ubiquity container
- [ ] T5.3 S3 backup: `SigV4.swift` over `CryptoKit`, fail-closed credential validation (reachable / read-write / not-public / no-anonymous-access) per the original's checklist
- [ ] T5.4 Backup destinations UI per [`design/uiux/settings.md`](design/uiux/settings.md) — one list, per-row `⋯` menu, no section-per-kind

## Phase 6: Loan/mortgage, tracking accounts, recurring transactions
Domain rules already designed in the original's `docs/DESIGN.md` — port logic, not redesign.
- [ ] T6.1 Loan/mortgage-linked payee mechanism, rate history, remaining-principal-as-derived
- [ ] T6.2 Tracking/investment account value-history log
- [ ] T6.3 Recurring/scheduled transactions + lazy auto-post on foreground

## Phase 7: YNAB data import
- [ ] T7.1 CSV parser for YNAB's Register/Plan export
- [ ] T7.2 Import mapper with the same `import_id` (account+date+payee+occurrence) dedupe key as the original, so a shared export can be tested against both apps for parity

## Phase 8: App lock, App Store prep
- [ ] T8.1 App Lock: Off / passcode / Face ID, same Keychain-boundary rules as the original
- [ ] T8.2 App icon/assets (vector where possible, per the size budget)
- [ ] T8.3 Privacy nutrition label, TestFlight build, submission

## Backlog
Not sequenced — pick up opportunistically, and only after the corresponding
feature exists in scope above:
- Baby Steps tracker, Tax Insights, Purchase Insights
- Cost of Living / Exchange Rates / House Hunt pages (see `design/market-data/DESIGN.md`)
- Receipt capture (see `design/receipt-capture/DESIGN.md`)
- Existing-`budgets-bro`-data import (same SQLite schema — likely a direct file copy, needs verification)
