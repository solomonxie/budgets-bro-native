# UI/UX mockups — Budgets Bro

Every surface drawn as it is built today. `../../UIUX-DESIGN.md` carries the
style rules and the reasoning; these files carry the pictures.

Glyphs follow the `uiux` skill (`references/notation.md` + `text-figma.md`):
`─●` on · `○─` off · `[ A | B ]` segmented (selected in CAPS) · `[[ x ]]`
primary · `[ x ]` secondary · `( x )` text link · `›` pushes · `⌄` collapse ·
`⟳` working · `←` annotation · `!` destructive · `·` disabled.

## Screen map

```
 ┌─ tabs (destinations only; ⚙︎ in every header) ──────────────┐
 │ Budget        ✛ Spend        Accounts        Insights      │
 └──┬──────────────┬───────────────┬───────────────┬──────────┘
    │              │               │               │
 BudgetScreen   (intercepts     AccountsScreen  InsightsScreen
    │  ⌄ groups   its own tab    │ Net Worth     │ breakdown + trends
    │  category ▸ press and     │ account ▸     ├─▶ BabySteps
    │  [AssignedAmount]         │ AccountDetail ├─▶ TaxInsights
    │  ( History ) ─▶ Transactions              ├─▶ Mortgage / Loan /
    │                     │ row ▸ AddTransaction│    Investment Insights
    ▼                     ▼                     └─▶ AiAnalysis
 AddTransactionScreen (a page pushed over the tabs)
    └─ [MonthPicker] [Repeat] [SearchableDropdown] pickers

 ⚙︎ ─▶ SettingsScreen  (Boards · Payees · Appearance · Language ·
                        AI Keys · Backup · Data · About)
        ├─▶ [S3ConfigModal] ─▶ [S3BrowserModal]
        ├─▶ [AiKeyModal] [AiKeyHistoryModal]
        └─▶ Import YNAB / Import backup / Export  ─▶ [OS file picker]
 [brackets] = modal or bottom sheet
```

## Files

| File | Covers |
|---|---|
| `budget.md` | budget screen, groups, assign popup, month nav |
| `spend.md` | add/edit transaction, number pad, repeat builder |
| `transactions.md` | list, filters, search, multi-select |
| `accounts.md` | accounts list, net worth, account detail, account modal |
| `insights.md` | insights, baby steps, tax, finance tools, AI analysis |
| `settings.md` | settings sections, S3, backup, data |
| `components.md` | rows, cards, pickers, chips, toasts |
