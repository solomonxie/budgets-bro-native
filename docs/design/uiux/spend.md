# Add / edit transaction

`src/screens/transactions/AddTransactionScreen.tsx` — a page pushed over the
tabs by the `✛ Spend` tab, which intercepts its own press.

```
 ‹ Back        Add Transaction              Mark to repeat
                                            ↑ header pill; becomes
 ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔    "✓ Repeating" when on
       $55.00 + $36.00                      ← pinned; no text field at all,
 ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁      shows the whole expression
 [ SPENDING | Income ]                      ← sets the sign
 ┌──────────────────────────────────────┐
 │ Payee                              › │   one card, hairline rows — no
 ├──────────────────────────────────────┤   box per field
 │ Category                             │
 │ 🛒 Groceries                       › │   hidden on an inflow and on a
 ├──────────────────────────────────────┤   tracking account
 │ Account                              │
 │ Chequing — Joint                   › │   greyed, not tappable, when
                                            opened from an account's page
                                            or on a loan row
 ├──────────────────────────────────────┤
 │ Date                                 │
 │ September 17, 2026                 › │
 ├──────────────────────────────────────┤
 │ Memo                                 │   typed in place, last row
 └──────────────────────────────────────┘
   1      2      3      ÷     ×            no boxes either: the glyph is
                                           the key, a rounded patch lights
   4      5      6      −     +            under a press
   7      8      9      =     ⌫            hold ⌫ to clear the amount
                          ┌───────────┐
   0                      │   Save    │    the one filled button
                          └───────────┘
 [ Delete Transaction ]!     ← edit mode only
```

Digits read right-to-left as cents — "4444" is $44.44, no decimal point to
type. One pending operation at a time, chained like a pocket calculator;
`×` and `÷` take the right side as the plain number typed, so `$55 × $3` is
55 × 3 and `$10 ÷ $4` splits a bill four ways. A negative result floors at
$0.00 — the toggle owns the sign. No `C` key. Save is the bottom-right key,
where the thumb already is.

Digits read right-to-left as cents — "4444" is $44.44, no decimal point to
type. One pending operation at a time, chained like a pocket calculator;
`×` and `÷` take the right side as the plain number typed, so `$55 × $3` is
55 × 3 and `$10 ÷ $4` splits a bill four ways. A negative result floors at
$0.00 — the toggle owns the sign. No `C` key: hold `⌫` to wipe the amount.
Save is the bottom-right key, where the thumb already is.

Digits read right-to-left as cents — "4444" is $44.44, no decimal point to
type. One pending operation at a time, chained like a pocket calculator;
`×` and `÷` take the right side as the plain number typed, so `$55 × $3` is
55 × 3 and `$10 ÷ $4` splits a bill four ways. A negative result floors at
$0.00 — the toggle owns the sign. No `C` key: hold `⌫` to wipe the amount.
Save is the bottom-right key, where the thumb already is.

The memo's system keyboard is the only thing that ever floats over this
page, and dragging the form dismisses it — so it can never end up covering
the pad or Save while you scroll.

An inflow drops Category: where money came from is its payee, which the
form already asks for. Payee is greyed too on a loan or mortgage row — it is
the account's own payee, and that name is what links the mirrored pair.

## Repeating

```
 tap "Mark to repeat" ↓
 ✓ Repeating                                 ← the pill, now on
 Starts                                      ← "Date" is renamed
 Sep 17, 2026                            ▾
 Repeat
 Every 1 month                           ▾   → the builder below
 ┌ Repeat ─────────────────────────────────┐
 │ Frequency  [ DAILY | Weekly | Monthly | │
 │              Yearly ]                   │
 │ Every      [ − ]  1 month  [ + ]        │
 │ On these days   ( M )( T )( W )( T )( F )│  weekly only
 └─────────────────────────────────────────┘
 ☐ Ends on a date        ✓ ⇒ End Date  Sep 17, 2027   ▾
```

A future-dated or repeating transaction does not appear in the
transactions list — it waits in the account's `Scheduled` box until
approved (see `accounts.md`).

## Delete

```
 Delete transaction?
 This cannot be undone.
      ( Cancel )        [ Delete ]!
```
