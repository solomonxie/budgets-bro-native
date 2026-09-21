# Budget

`src/screens/budget/BudgetScreen.tsx` — the first tab and the app's home.

```
 ⚙︎    Budget                                 History
 ┌──────────────────────────────────────────────────┐
 │ SPENT THIS MONTH            12 MONTHS AVG        │
 │ $2,431.90                   $2,180.00            │
 │ Unassigned: $120.40         112% reached         │ ← colour-coded, and
 │ ⚑ 2 scheduled pending approval               ›   │   never the big number
 └──────────────────────────────────────────────────┘
 ‹      September 2026      ›          ← label is tappable too (month picker)
 ⌄ Everyday Expenses                      $1,204.00   ⋯
   🛒 Groceries              ▇▇▇▇▇▇▁▁▁▁       $84 left
      Spent $316 of $400
   🍽 Dining out             ▇▇▇▇▇▇▇▇▇▇      −$12 over    ← red
      Spent $212 of $200
 › Bills                                     $890.00   ⋯
   (collapsed — one rotated chevron glyph, not two characters)
 ⌄ Savings                                      $0.00   ⋯
   No categories yet.
                     ( + New Group )
```

Availability badge colours: green funded · amber partial · red overspent.

## Group menu  ⋯

```
 Add Category
 Rename Group
 Move Up
 Move Down
 Delete Group          !   ⇒ Delete "Bills"?  (message names the fallout)
```

## Category row — long-press / ⋯

```
 Rename
 Move Up
 Move Down
 Delete                !   ⇒ Delete "Groceries"?  This cannot be undone.
```

## Assign popup — tapping a category

`src/components/ui/AssignedAmountModal.tsx`

```
 ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
 🛒 Groceries
 Assigned this month
 ┌────────────────────────────────┐
 │ $400.00▌                       │  ← already focused: no second tap
 └────────────────────────────────┘
 Carried over: $24.10
 Unassigned cash: $120.40
 ⊗ Exceeds unassigned cash by $80.00
 History                                ›
        ( Cancel )        [[ Save ]]
```

## Naming prompts

```
 ┌──────────────────────────────────────┐
 │ New Group                            │
 │ ┌──────────────────────────────────┐ │
 │ │ e.g. Bills                       │ │
 │ └──────────────────────────────────┘ │
 │      ( Cancel )      [[ Save ]]      │
 └──────────────────────────────────────┘
 New Category ⇒ placeholder "e.g. 🛒 Groceries"   ← the emoji is part of
                                                    the name, not a picker
```
