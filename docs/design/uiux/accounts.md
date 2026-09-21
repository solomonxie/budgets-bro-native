# Accounts

`src/screens/accounts/AccountsScreen.tsx`

```
 ⚙︎    Accounts
 ┌──────────────────────────────────────────────────┐
 │ NET WORTH                            ( Customize )│
 │ $184,210.55                                      │
 │ Assets $312,400.00      Debts $128,189.45        │
 └──────────────────────────────────────────────────┘
 Cash                                        $1,204.10
 Wallet                                        $204.10
 Checking                                    $1,000.00
 Savings                                    $18,000.00
 Emergency fund                             $18,000.00
 Credit                                      −$820.45   ← red when negative
 Visa                                         −$820.45
 Loan                                     −$127,369.00
 Mortgage                                 −$127,369.00
 Asset                                     $295,000.00
 House                                     $295,000.00
 Tracking                                    $2,196.00
 401(k)                                      $2,196.00
                   ( + Add Account )
                   ( Closed Accounts )
```

Groups in a fixed order — Cash · Savings · Tracking · Loan · Asset ·
Credit — with a subtotal each and extra space between groups. A
loan/mortgage row is negative: what's still owed.

```
 ( Customize ) ⇒ bottom sheet
 Include in Net Worth
 ✓ Wallet     ✓ Checking     ○ 401(k)   …
             [ Done ]
```

## Account detail  `AccountDetailScreen.tsx`

One screen, everything inline — no separate cards page.

```
 ‹                                             Edit
 ┌ BALANCE ─────────────────────────────────── ▾ ───┐
 │ $1,000.00                                        │
 │ (credit) Deposited $4,200.00                     │
 │ (asset)  Home Value  $295,000.00            ›    │
 │   › expands: value trend charted year by year    │
 │     (a home is re-valued rarely, not monthly),   │
 │     entry list, + Update Home Value              │
 └──────────────────────────────────────────────────┘
 ▾ expands the trend chart in place:
 ┌──────────────────────────────────────────────────┐
 │      ╱‾‾╲       balance trend (cash/savings/     │
 │  ╱‾‾╯    ╲___   credit — credit overlays monthly │
 │ ▁▁▂▂▃▃▂▂▁▁▁▁▁   spend; a paid-off card reads flat)│
 └──────────────────────────────────────────────────┘
 ┌ LOAN DETAILS ─────────────── 5.75% · $2,918/mo ›─┐
 │ Rate · Scheduled payment · Projected payoff ·    │
 │ Est. remaining interest — read-only, no inputs.  │
 │ Projected off the scheduled payment and the      │
 │ balance real transactions add up to; what-if     │
 │ extra payments live in the payoff calculators.   │
 └──────────────────────────────────────────────────┘
 ┌ SCHEDULED (2) ───────────────────────────── ▾ ───┐
 │ Dated in the future — doesn't affect balance or  │
 │ budget until its date arrives.                   │
 │ Rent            Next: Oct 1, 2026    −$1,800.00  │
 │   ( Approve )   ( Cancel Schedule )              │
 └──────────────────────────────────────────────────┘
 Sep 17, 2026
 Whole Foods                   🛒 Groceries  −$42.50
 empty   No transactions yet.
```

## Account modal  `AccountModal.tsx`

```
 ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
 New Account                              ( Cancel )
 Name          e.g. Wallet
 Type          [ CASH | Savings | Credit Card | Loan |
                 Mortgage | Tracking | Asset ]
 Starting Balance  $0.00
   hint  Balance the day this account starts here; debts negative.
   loan/mortgage: labelled "Balance When Tracking Started" and
   auto-filled as −(Mortgage Amount) until hand-edited — a new loan's
   two numbers are the same one, but someone adding a part-paid loan
   owes less now than they borrowed.
 Current Balance   $0.00      edit-only, not asset/tracking
   hint  A different number posts one balance adjustment.
 ┌ INTEREST RATE ───────────────────────────────────┐
 │ Interest Rate (annual %)   e.g. 6.25 (optional)  │
 │ Interest Rate History        ( + Add Rate Change )│
 │ No rate recorded yet.                            │
 └──────────────────────────────────────────────────┘
 ┌ LOAN TERMS ──────────────────────────────────────┐  loan/mortgage only
 │ Term (months)   e.g. 360                         │
 │   360 = 30 years, 240 = 20 years.                │
 │ Purchase Price   0.00 (optional)   mortgage only │
 │ Mortgage Amount ("Amount Borrowed" for a loan)   │
 │   What you borrowed at signing, not what's left. │
 │ ┌ Down Payment ──────────────┐     mortgage only │
 │ │ $60,000.00 (20.0% down)    │  auto-computed    │
 │ │ ⊗ Mortgage amount exceeds the purchase price   │
 │ └────────────────────────────┘                   │
 │ Origination Date                              ▾  │
 └──────────────────────────────────────────────────┘
 ┌ PAY RATE HISTORY ────────────────────────────────┐  income only
 │ No pay rate history recorded.  ( + Add Entry )   │
 └──────────────────────────────────────────────────┘
 ┌ TOOLS ───────────────────────────────────────────┐
 [[ Save ]]
 [ Close Account ]   ⇒ Close "Visa"? (keeps history, hides the row)
 [ Reopen Account ]  ← in the closed-accounts screen
```
