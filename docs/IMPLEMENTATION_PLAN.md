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
- [x] T3.1 Budget screen: Unassigned Cash banner, collapsible category groups, status badge (funded/partial/overspent color) + a thin progress bar + caption per category, month navigation (arrows; label is display-only, not yet tappable-to-jump). `BudgetMath.swift` ported (categoryBalanceCents, status, unassignedCashCents)
- [x] T3.2 Add/edit transaction page: autofocused amount + custom number pad, outflow/inflow toggle, category/account `Picker`s, free-text payee field with suggestion chips, date, memo, **cleared/interest toggles, a "Repeat" toggle (frequency + interval) that creates a schedule instead of a one-off, and full edit-existing-transaction support (prefills from a tapped row, Delete action)**. Still using plain `Picker`s rather than the fuzzy-search sheet convention from `components.md`
- [x] T3.3 Transactions list: grouped by date, swipe-to-delete, **search (`.searchable`, matches payee/memo), multi-select bulk delete (`EditButton`), tap a row to edit it**
- [x] T3.4 Account detail/register with running balance, "+ Transaction" pre-selecting the account, **and Correct Balance (enters actual balance → one uncategorized adjustment transaction for the difference, payee "Balance Adjustment")**
- [x] T3.5 Insights: spending-by-category breakdown for the viewed month **plus a 6-month spending trend line/area chart (Swift `Charts`, system framework)**. Not yet a stacked-area top-5-categories chart with a dashed average baseline like the original — this is a simpler single-series total

## Phase 4: Financial tools + AI analysis
- [x] T4.1 `Sources/FinanceTools/Amortization.swift`: mortgage/loan monthly payment, amortization schedule, remaining-months-to-payoff (+ extra payment), total interest remaining, simple/compound interest — ported, not yet unit-tested against the original's known-good outputs
- [x] T4.2 Mortgage/loan calculator screen (ad-hoc, reachable from Insights and from a loan account's detail page)
- [x] T4.3 AI analysis: `AIClient.swift` (`URLSession` to OpenAI/Anthropic directly, no SDK), `AIAnalysis.buildPrompt` (aggregate-by-default, opt-in detailed mode reading raw transactions), `AIAnalysisView` (provider picker, detailed-mode toggle with disclosure copy, one real request at run time). Keychain-stored key entered in Settings

**Also landed ahead of schedule**: a real `SettingsView` (App Lock, Payees rename, AI key entry, Local/iCloud/S3 backup sections, YNAB import — see Phases 5-8 below) and `Database`'s query/bind layer (`Row`, parameterized `run`/`query`, `.boardDidChange` notification, WAL checkpoint + store-replace for backup restore) that every repository depends on.

**Bug found and fixed by the test pass** (caught immediately, not shipped): `Migration001` was edited in place mid-development to add `UNIQUE(category_id, month)` on `budget_entries`, after installs already existed at schema version 1 — those DBs (including this repo's own simulator smoke-test install) never re-ran migration001's SQL, so `BudgetRepository.setAssigned`'s `ON CONFLICT` upsert crashed with "ON CONFLICT clause does not match any PRIMARY KEY or UNIQUE constraint". Fixed with a real `Migration002` (`CREATE UNIQUE INDEX IF NOT EXISTS`) instead of re-editing migration001 — the general lesson (already implicit in AGENTS.md's migration-runner rule) is that a migration's SQL is immutable once anything has run it; a schema fix is always a new migration. Also fixed in the same pass: `Amortization.buildSchedule` left a few stray cents unpaid at the end of a schedule instead of paying off exactly — the final month's payment is now adjusted to clear the remaining balance, same as a real amortization table.

## Phase 5: Backup & restore
Per [`design/DESIGN.md#storage-backup-architecture`](DESIGN.md#storage-backup-architecture).
- [x] T5.1 Local on-device snapshot (`LocalBackupRepository`: WAL checkpoint + raw `.db` file copy under `Documents/Backups/`, list/restore/delete). **Deferred**: `UIFileSharingEnabled` in Info.plist so it's actually visible in the Files app on a real device
- [x] T5.2 iCloud backup via ubiquity container (`ICloudBackupRepository`, same snapshot shape as local). Code path is complete but the iCloud container entitlement itself isn't provisioned yet (needs a paid Apple Developer account, T0.2) — `isAvailable` reports false until then, and the Settings section says so rather than pretending
- [x] T5.3 S3 backup: `SigV4.swift` (SigV4 over `CryptoKit`), `S3Client.swift` (put/get/head/delete/list over `URLSession`), `S3BackupRepository.swift`. **Simplified vs. the original's four-step checklist**: reachable → read/write → not-publicly-readable, folding the original's separate "no anonymous bucket-root access" step into the same unauthenticated-GET-on-the-marker-object check (three checks doing the job of four, not a dropped guarantee)
- [x] T5.4 Backup UI landed in `SettingsView` as three sections (Local/iCloud/S3) rather than the original's single unified list with per-row `⋯` — **UI/UX gap, tracked below**: the "one list, one hint, per-destination `⋯` menu" convention from `design/uiux/settings.md` isn't implemented; each destination has its own ad-hoc section instead

## Phase 6: Loan/mortgage, tracking accounts, recurring transactions
Domain rules already designed in the original's `docs/DESIGN.md` — port logic, not redesign.
- [x] T6.1 `LoanRepository`: rate history (`account_rate_history`), remaining principal. **Simplified vs. the original's payment-split-since-anchor estimate**: remaining principal is the latest logged reading, or the account's opening balance if none has ever been logged — no interpolation between readings yet. No linked-payee-posts-to-loan-account mechanism yet (still uses a plain account, no payee auto-mirroring)
- [x] T6.2 Tracking/investment account value-history log (`account_value_history`, shared table, `kind = 'value'`) — log/read wired into `AccountDetailView`; the two-entry-mode (exact gain vs. total) UX from the original isn't built, only "log current total"
- [x] T6.3 Recurring/scheduled transactions (`scheduled_transactions`, `ScheduledTransactionsRepository`, `Recurrence.swift`) + `AutoPostRunner` checked on launch and every foreground. Creating one is a "Repeat" toggle in Add Transaction (frequency + interval), matching the original's consolidated T8.10 shape — no separate Upcoming/approval screen, every schedule auto-posts

## Phase 7: YNAB data import
- [x] T7.1 CSV parser (`Sources/Import/CSV.swift`) — quoted fields, embedded commas/newlines
- [x] T7.2 `YNABImporter`: reads the real `.zip` (via the new `Zip.swift` reader — see AGENTS.md's dependency table), matches/creates accounts+categories+payees by name, `import_id` keyed on account+date+payee+occurrence, upserts on conflict. Wired into Settings → Data → "Import from YNAB" (`.fileImporter`). **Not yet verified against a real YNAB export** — parsing logic follows the documented column names but hasn't been round-tripped against an actual downloaded export file

## Phase 8: App lock, App Store prep
- [x] T8.1 App Lock: Off / passcode / Face ID (`AppLockController`, `LockScreenView`) — passcode in the Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), biometrics via `LAContext`'s `.deviceOwnerAuthentication` (falls back to device passcode, same guarantee as the original's `BIOMETRY_ANY_OR_DEVICE_PASSCODE`), 60s grace period on foreground
- [ ] T8.2 App icon/assets (vector where possible, per the size budget) — `AppIcon.appiconset` exists but empty
- [ ] T8.3 Privacy nutrition label, TestFlight build, submission

## Known UI/UX gaps against the spec (tracked, not hidden)
- Tab bar: now has an opaque `Theme.surface` background (was fully transparent), but iOS 27's `TabView` still renders a floating pill, not the flush edge-to-edge bar `components.md` calls for — would need a custom `UITabBar`-backed shell to match exactly
- Pickers throughout (category/account/payee-adjacent) are plain SwiftUI `Picker`s, not the fuzzy-search half-height-sheet convention from `components.md`
- Backup destinations are three separate Settings sections, not the original's unified one-list-per-destination-`⋯` pattern (Phase 5 note above)
- No drag-reorder for category groups/categories (Move Up/Down or drag) — reordering isn't implemented at all yet, groups/categories list in creation order
- S3 Settings form has no paste-to-fill, no per-connection multiple buckets (one connection only), no folder browser
- AI Analysis has no "About You" profile or Health/Comparison modes — just spending-by-category + optional detailed transactions
- Transaction entry: no "Advanced" collapsible section, no payee-based transfer detection, split transactions not supported

## Backlog
Not sequenced — pick up opportunistically, and only after the corresponding
feature exists in scope above:
- Baby Steps tracker, Tax Insights, Purchase Insights
- Cost of Living / Exchange Rates / House Hunt pages (see `design/market-data/DESIGN.md`)
- Receipt capture (see `design/receipt-capture/DESIGN.md`)
- Existing-`budgets-bro`-data import (same SQLite schema — likely a direct file copy, needs verification)
