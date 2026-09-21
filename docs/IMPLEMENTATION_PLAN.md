# Budgets Bro Native — Implementation Plan

See [`DESIGN.md`](DESIGN.md) for the design doc these phases implement, and
[`UIUX-DESIGN.md`](UIUX-DESIGN.md) / [`design/uiux/`](design/uiux/) for the
screen-by-screen spec being ported with no UX diff. Source of truth for
domain rules being ported: [budgets-bro](https://github.com/solomonxie/budgets-bro)'s
own `docs/DESIGN.md`.

## Phase 0: Repo & Xcode project bootstrap
- [x] T0.1 Init git repo, copy design docs from `budgets-bro`, adapt for native stack
- [ ] T0.2 `project.yml` (xcodegen) — single iOS app target, bundle id, deployment target, entitlements (iCloud container)
- [ ] T0.3 Generate + commit `BudgetsBroNative.xcodeproj`; confirm a clean checkout builds
- [ ] T0.4 App shell: `TabView` (Budget / Spend / Accounts / Insights) matching `docs/design/uiux/README.md`'s nav diagram — Spend intercepts its own tab press and pushes Add Transaction instead of switching tabs
- [ ] T0.5 SQLite wrapper over `libsqlite3` + versioned migration runner (`PRAGMA user_version`) — `Sources/Data/Database.swift`
- [ ] T0.6 Keychain wrapper for API key / S3 credentials — `Sources/Secure/Keychain.swift`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- [ ] T0.7 XCTest target + one sample passing test
- [ ] T0.8 SwiftLint + SwiftFormat config; GitHub Actions CI (`xcodebuild test`)
- [ ] T0.9 First size measurement against the 4.25 MB / 1.8 MB budget — establish the baseline before any real feature lands

## Phase 1: Domain schema + Accounts/Categories CRUD
- [ ] T1.1 Port SQLite schema 1:1 from `budgets-bro`'s current schema (`accounts`, `category_groups`, `categories`, `payees`, `budget_entries`, `transactions` — see that repo's `docs/DESIGN.md#core-domain-model`) — `Sources/Data/Migrations/`
- [ ] T1.2 `AccountsRepository` CRUD + Accounts screen per `docs/design/uiux/accounts.md`
- [ ] T1.3 `CategoriesRepository` CRUD + grouped categories UI (inline on Budget screen, per current UX — no separate Manage Categories page)
- [ ] T1.4 Shared domain types (`Sources/Domain/Models.swift`)

## Phase 2: Transactions & budget envelope logic
- [ ] T2.1 `TransactionsRepository` CRUD incl. transfer pairing and balance-correction adjustment transactions
- [ ] T2.2 `BudgetMath.swift` pure functions: category rollover, to-be-budgeted, overspend — port with unit tests mirroring the original's `budgetMath.ts` test cases
- [ ] T2.3 `budget_entries` table + `BudgetsRepository`
- [ ] T2.4 Unit tests for `BudgetMath`

## Phase 3: Core budget UI
Per-screen specs: [`design/uiux/budget.md`](design/uiux/budget.md), [`spend.md`](design/uiux/spend.md), [`transactions.md`](design/uiux/transactions.md), [`accounts.md`](design/uiux/accounts.md).
- [ ] T3.1 Budget screen: Unassigned Cash banner, collapsible category groups, status badge/progress bar/caption per category, month navigation (arrows + tappable label)
- [ ] T3.2 Add/edit transaction page: autofocused amount + custom number pad (not the system keypad — see Forms/`components.md`), inflow/outflow toggle, payee/category/account pickers, memo, date, cleared/interest toggles, recurrence builder
- [ ] T3.3 Transactions list: grouped by date, search, multi-select delete
- [ ] T3.4 Account detail/register with running balance + Correct Balance action
- [ ] T3.5 Insights: spending breakdown, category trend (stacked area chart per `components.md`'s Diagrams convention), interest-earned — all local, no network

## Phase 4: Financial tools + AI analysis
- [ ] T4.1 `Sources/FinanceTools/` pure functions: mortgage/loan payment, amortization schedule, simple/compound interest, extra-payment payoff — unit-tested against the original's known-good outputs
- [ ] T4.2 Mortgage/loan calculator screen
- [ ] T4.3 AI analysis: Keychain-stored key, `URLSession` calls to provider REST endpoints, aggregate/detailed payload modes, in-app disclosure copy matching `DESIGN.md`'s Settings disclosure text

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
