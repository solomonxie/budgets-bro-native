# Transactions

`src/screens/transactions/TransactionsScreen.tsx` — reached from Budget's
`History`, or from any Insights chart segment (which arrives pre-filtered).

```
 ‹ Back           Transactions
 ┌──────────────────────────────────────────────────┐
 │ 🔍 Search payee or memo                          │        ( Select )
 └──────────────────────────────────────────────────┘
 Category   All Categories   ▾      Month   All Months   ▾
 Sep 17, 2026                                        ← date group header
 Whole Foods                                    −$42.50
 🛒 Groceries · Wallet
 weekly shop, paid cash                              ← memo, one line, clipped
 ─────────────────────────────────────────────────
 Paycheck                                    +$3,200.00   ← green
 Salary · Checking
 Sep 14, 2026
 …
 empty     No transactions match.
```

Most recent first. Future-dated rows never appear here.

## Multi-select

```
 tap ( Select ) ↓
 ✓ Whole Foods                                  −$42.50
 ✓ Target                                       −$86.20
 ○ Paycheck                                  +$3,200.00
 ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔
             [ Delete 2 selected ]!
 ( Done ) replaces ( Select ) while selecting
```

Filters combine: the category dropdown also offers `All Others` (everything
outside the top categories an Insights chart drew).
