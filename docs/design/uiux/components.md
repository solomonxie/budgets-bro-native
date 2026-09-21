# Components

`src/components/ui/`

```
 Card                  bordered group; sections are cards, rows are not
 ┌──────────────────────────────────────┐
 │ row                              ›   │
 ├──────────────────────────────────────┤  hairline between rows only
 │ row                              ─●  │
 └──────────────────────────────────────┘

 Chip / ChipRow        ( Groceries )  ( 2026 )      selected = filled
 StatusBadge           green funded · amber partial · red overspent
 ProgressBar           ▇▇▇▇▇▇▁▁▁▁  thin, spent vs assigned
 DisclosureChevron     ›  collapsed      ⌄  open     one glyph, rotated
 RowMenuButton         ⋯  → action sheet (rename / move / delete !)
 SettingsButton        ⚙︎  in every screen header, same row as the
                          screen's own action

 FieldCard / FieldRow  a whole form as one rounded panel, hairline rows:
                       caption over value, chevron at the end; empty rows
                       show their label alone. `row` on DropdownField /
                       SearchableDropdown / DateField renders them like this
 TextField             label above, value in the field
 SecretField           ••••••  ( Show )  + "N characters — this key is
                                            usually M." on a bad paste
 NumberField /         tap = the app's own number pad, never the
 UnitAmountField       system keypad
 DateField             Sep 17, 2026  ▾   → wheel picker
 MonthNav              [  ‹  ]  September 2026  [  ›  ]  ← wide steppers; the
                       label unfolds a wheel in place to jump, and turns
                       accent while it is open — no chevron, the wheel
                       under the bar is the affordance
 NumberWheel           spin to a value; the readout taps back to default
 DropdownField         value ▾
 SearchableDropdown    ▾ + search box + "Use “<text>”" to create in place
 RepeatField           frequency segmented · every stepper · day chips
 BottomSheet           everything modal here; ( Cancel ) top-right
 PromptModal           title · one field · ( Cancel ) [[ Save ]]
 ResultToast           one line, auto-dismiss, no action
 StubScreen            "not built yet", named, never a blank page
```

## Money and numbers

```
 −$42.50   red        spending
 +$3,200.00 green     income
 $0.00                never a bare 0
 $84 left / −$12 over  availability, in words, not just colour
 12 MONTHS AVG        comparisons are labelled with their window
```

## Tabs

```
 Budget      ✛ Spend      Accounts      Insights
 ↑ flush in the bar, explicit background and border — iOS's translucent
   blur reads as a stray dark bar against a near-black theme
 ✗ no FAB: one global entry point beats two buttons with different
   behaviour (and Android elevation renders a rounded pill's shadow as a
   rectangular smudge)
```
