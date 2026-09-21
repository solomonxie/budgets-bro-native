# Insights

`src/screens/insights/InsightsScreen.tsx` — on-device only. Needs no key and
sends nothing off-device; the AI feature is a separate row at the bottom.

```
 ⚙︎    Insights
 ‹      September 2026      ›
 ┌──────────────────────────────────────────────────┐
 │ SPENDING BREAKDOWN                               │
 │ $2,431.90                                        │
 └──────────────────────────────────────────────────┘
 TOP CATEGORIES
 ┌──────────────────────────────────────────────────┐
 │ ███████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  one stacked bar,
 └──────────────────────────────────────────────────┘  same scale as Budget
 ■ 🛒 Groceries                              $316.00   ← tap = Transactions,
 ■ 🍽 Dining out                             $212.00     pre-filtered to that
 ■ All Others                                $412.00     category + month
 empty   No spending recorded this month.
 CATEGORY TRENDS
 All-time, top 5 categories, scroll sideways.
 ┌──────────────────────────────────────────────────┐
 │        ╱╲    ╱╲                                  │
 │   ╱╲ ╱  ╲__╱  ╲╱╲                                │  stacked area
 │ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  avg                 │  dashed 12-month
 │ ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ │  baseline
 └──────────────────────────────────────────────────┘
 empty   Not enough history yet.
 UTILITIES
 Plans and calculators built on your own accounts.
 Baby Steps                                        ›
 Mortgage Insights                                 ›
 Loan Insights                                     ›
 Investment Insights                               ›
 Tax Insights                                      ›
 AI Insights                                       ›
```

## Baby Steps  `insights/BabyStepsScreen.tsx`

Each step reads real accounts and categories; a step with nothing linked
falls back to a manual pill rather than a wrong number.

```
 ‹          Baby Steps
 Step 1: $1,000 starter emergency fund
 ▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇▇  $1,000 of $1,000            ✓ Done
 Emergency fund accounts              2 accounts ▾
 Step 2: Pay off all debt (except the mortgage)
 ▇▇▇▇▇▇▇▇▇░░░░░░░░░░░  $820.45 remaining
 Step 3: 3–6 months of expenses saved
 ▇▇▇▇▇░░░░░░░░░░░░░░░  $18,000 of ~$34,880 (avg $8,720/mo × 4)
 Not enough spending history yet                   ← when it can't compute
 Step 4: Invest 15% of income for retirement
 ▇▇▇▇▇▇░░░░░░░░░░░░░░  5% of income invested (target 15%)
 Retirement accounts                  1 accounts ▾
 Not tracked yet                                   ( Mark Done )
 Step 5: Save for kids' college fund
 Target: $50,000 (edit)      Accounts for kids' education   ▾
 Step 6: Pay off the mortgage early                ( Mark Done )
 Done (or no mortgage)
 Step 7: Build wealth and give
 $1,200 given in 2026        Categories for giving  ▾
 YOUR GOALS                                      ( + Add Goal )
 Your own goals, tracked the same way…             ← goalsHint
 (empty note when there are none)
```

## Tax Insights  `tax/TaxInsightsScreen.tsx`

```
 ‹      Tax Insights — 2026
 Country                          United States ▾
 ⚠ <disclaimer: estimates, not advice>
 ┌──────────────────────────────────────────────────┐
 │ Taxable income · deductions found · estimated    │
 │ bracket, each built from linked accounts and     │
 │ categories                                       │
 └──────────────────────────────────────────────────┘
```

## AI Insights  `ai/AiAnalysisScreen.tsx`

```
 ‹           AI Insights
 no key   Add an AI key in Settings to run an analysis.
          ( Open Settings )
 [ SPENDING | Variance | Forecast | Health | Comparison ]
 ┌ ABOUT YOU (OPTIONAL) ────────────────────────────┐
 │ City        …          Country     …             │
 │ Age         …          Family size …             │
 │ Privacy Mode                                ─●   │
 │ <what is and isn't sent>                         │
 └──────────────────────────────────────────────────┘
        [[ Run Analysis ]]        ⟳
 ⊗ That key was rejected — check it in Settings.
 ⊗ Rate limited — try again in a minute.
 ⊗ Couldn't reach OpenAI — check your connection.
 ⊗ Something went wrong running the analysis.
```

## Finance tools  `screens/finance-tools/`

A registry of calculators, each the same shape: inputs at the top, a result
block, and a schedule table where one applies.

```
 ‹          Mortgage
 Principal · Rate · Term (months) · Extra payment
 ┌──────────────────────────────────────────────────┐
 │ Monthly payment                       $1,204.10  │  ResultRow ×N
 │ Total interest                       $184,210.55 │
 └──────────────────────────────────────────────────┘
 ┌ SCHEDULE ────────────────────────────────────────┐
 │ #   Payment   Interest  Principal   Balance      │
 │ 1   1,204.10   640.10     564.00  127,369.00     │
 └──────────────────────────────────────────────────┘
 Tools: Affordability · Amortization · Auto Loan · Calc · China
 Prepayment · Compound Interest · Debt-to-Income · Investment ·
 Mortgage · Payoff · Refinance · Rent vs Buy · Tax Savings
```
