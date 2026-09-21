# Receipt Capture

## Problem
The only way a purchase gets into the ledger is typing it. The obvious fix —
pick a photo of the receipt from the library — costs an
`NSPhotoLibraryUsageDescription`, a permission prompt, and a photos line on the
App Store privacy label. For an app whose pitch is that it asks for nothing,
that price is too high for one feature.

## Goals
- Share a photo **into** the app (Photos → Share → Budgets Bro), and get
  transactions out of it. One image handed over, nothing else reachable.
- Zero new permissions: no photo library, no camera.
- The photo itself never leaves the device — text recognition is on-device;
  only the recognized text goes to the user's own AI key.
- Results land on the **Flagged Transactions** page as unconfirmed rows, never silently in
  the ledger.
- Receipt line items land in a real field, not a prose note, so they can be
  aggregated across the whole ledger (see Purchase items below).

## Non-goals
- **Not receipt attachment.** The image is discarded once parsed — no image
  storage, no size management, no decision about whether photos ride along in
  backups. Still deferred, as in `docs/DESIGN.md`.
- **Not a line-item ledger.** One receipt is one transaction (its total).
  Splitting a receipt into per-item rows would double-count tax and subtotals
  and make Review unusable.
- **Not AI acting on data.** The model proposes; the user confirms on Review.
  The "analysis only, read-only" non-goal holds because nothing is final until
  a human taps Confirm.
- **Not multi-currency.** A foreign receipt records its number as printed and
  names the currency in the memo. `domain/money.ts` has no conversion.
- **Not camera capture.** Take the photo in Photos, share it here.

## What iOS forces
Verified against Apple's docs, because both shaped the design:

1. **A share extension cannot open its containing app.**
   `NSExtensionContext.open(_:completionHandler:)` is supported only by the
   Today and iMessage extension points
   ([docs](https://developer.apple.com/documentation/foundation/nsextensioncontext/open(_:completionhandler:))).
   So the extension **queues** the image and says so; the app **drains** the
   queue next time it is opened. Queue-and-drain is the design, not a fallback.
2. **A share extension is what puts the app in the Photos share sheet.**
   `CFBundleDocumentTypes` alone is unreliable there — an Apple engineer's
   answer in [forums/772501](https://developer.apple.com/forums/thread/772501)
   says a share extension with declared data types is what activates. Ship the
   doc types anyway: twelve plist lines, and the Files/Mail/AirDrop path they
   cover launches the app directly instead of queueing.
3. **`VNRecognizeTextRequest`** (iOS 13+, not deprecated) is the OCR API.
   `RecognizeDocumentsRequest` is iOS 26+ and the deployment target is 16.4, so
   it can only ever be a second branch behind the same method.
4. Neither path touches `PHPhotoLibrary`. The permission goal holds.

## Flow
```
Photos ─Share─▶ ReceiptShare.appex ─▶ app group container
                      │                 ReceiptInbox/<uuid>.<ext>
            "Saved — open Budgets Bro"  ReceiptInbox/<uuid>.json  ← written last = commit marker
                                               │
                                     (user opens the app)
                                               ▼
   Linking url / AppState active ─▶ useReceiptInbox drain ─▶ receipts/importReceipt.ts
        ├─ ReceiptInbox.recognizeText(id)          Vision, on device
        ├─ runWithAiKeys(db, buildReceiptMessages)  existing multi-key path
        ├─ parseReceiptReply(reply)                 pure, unit-tested
        └─ insertReceiptTransaction(…)              needs_confirm=1, purchase_items="…"
                                               ▼
                    Flagged Transactions page → "Receipt" card → Confirm
```

## Architecture
```
ios/ReceiptShare/              share extension target (plain UIViewController, no RN)
modules/receipt-inbox/         bridge module, same shape as modules/icloud-drive
  ios/ReceiptInboxStore.swift    queue + Vision; compiled into BOTH targets
  ios/ReceiptInbox{Module.swift,.m,.podspec}
  index.ts                       null when absent, base64 across the bridge
src/receipts/importReceipt.ts  orchestrator: OCR → AI → parse → insert
src/hooks/useReceiptInbox.ts   Linking + AppState → drain
src/domain/receiptParse.ts     pure: JSON repair ladder, coercion, memo, import id
src/domain/purchaseItems.ts    pure: the key-value string format
src/domain/purchaseInsights.ts pure: aggregation for the Insights page
```

`ReceiptInboxStore.swift` must stay pure Foundation — the extension target
builds with `APPLICATION_EXTENSION_API_ONLY`, so one `UIApplication` reference
breaks a build whose error points at the pod, not the file.

## Purchase items
A general transaction field, not a receipt-only one: a customizable key-value
list, stored as one string of `key=value` pairs joined by `, `. No JSON in the
database. Keys and values are sanitized on write (separators replaced with a
space) — no escaping scheme to get wrong, and a round-trip test pins it.

A pair whose value parses as money (`Milk=3.99`) is a **priced item**; one
whose value is free text (`Warranty=2 years`) still displays and round-trips,
it just isn't a data point. Receipt imports write only `item=price` pairs, so
the analysis below stays clean; shop, location and card go in the memo, which
is what makes a one-line list row readable.

On the Add form the field is folded by default — most transactions will never
use it. Typing pairs in by hand is a first-class use, not a leftover of the
receipt path: a few things are worth tracking by price over time (oil, beef,
a car repair) whether or not a receipt was ever photographed, and one typed
`Oil=8.40` feeds the analysis below exactly like a parsed one.

**Purchase Insights** (Insights → Purchase Insights) aggregates priced items
across the whole board: every distinct item ranked by how often it was bought,
each expanding in place to a price trend chart with the trailing-average
benchmark line, plus its purchase history (date, price, count). Grouping is by
trimmed, lower-cased name; the most common original spelling is what shows.

## Landing in Review
Every existing `ReviewReason` is a predicate over existing columns, and "a
receipt row whose payee and category are both filled" isn't derivable from any
of them — so it takes a real column, `needs_confirm INTEGER NOT NULL DEFAULT 0`.
Existing rows default to confirmed. `SELECT_WITH_LABELS` is `SELECT t.*` so it
picks the column up; both write statements name their columns, so editing a
receipt row in the normal form can't silently clear the flag.

Provenance rides for free on `import_id`, the same natural-key trick
`import/ynabImportId.ts` uses: `receipt:<sha256[0..16]>:<index>`, the sha taken
of the image bytes in the extension. Insert is `ON CONFLICT DO **NOTHING**`,
deliberately not `importTransaction`'s `DO UPDATE` — re-sharing a photo you
already corrected must not let a second model run clobber your edits. A
re-encoded copy of the same receipt hashes differently and inserts, but the
existing `duplicate` reason then catches it, so the two dedupe layers cover
each other.

## Privacy
Receipt text is more identifying than anything AI Analysis sends today: shop,
street address, card last-4, item names. AI Analysis has a Privacy Mode; this
has `redactReceiptText` (card-number runs next to VISA/CARD/XXXX stripped
before the text leaves the device) as a floor, and wants a one-time
confirmation the first time the feature runs. Every call still lands in
`ai_requests` and is readable verbatim in `AiKeyHistoryModal` — which also
makes prompt tuning possible.

## Risks
- **Silent extension failure.** A wrong entitlement or a missing
  `PBXTargetDependency` produces no icon and no log. The scheme's
  `buildImplicitDependencies` resolves *linked* products; an extension is
  *embedded*, so it needs an explicit dependency or the build succeeds with an
  empty `PlugIns/`. Check with `pluginkit -mAvv | grep -i budgets`.
- **JSON quality varies by vendor.** `llama-3.1-8b-instant` malforms far more
  often than `gpt-4o-mini`, and round-robin key rotation means consecutive
  receipts hit different vendors. The repair ladder plus one stricter retry is
  the mitigation; a capability preference in key ordering is the follow-up.
- **Signing.** A second bundle plus an app group means new profiles;
  `-allowProvisioningUpdates` normally mints them, but the first such build
  often needs one pass through the Xcode GUI for the Apple ID session.
- **Two share-sheet entries** if the doc types also activate from Photos. Both
  end at the same queue, so both are safe; pick one after seeing it on device.

## Later
- Sending the **image** to a vision model: `ChatMessage.content` widened to
  content parts, three wire formats across seven clients, a `supportsImages`
  map (deepseek-chat has no vision at all) so round-robin can't hand an image
  to a text model, and image redaction in `recordAiRequest` before 50 retained
  rows per key become tens of megabytes. The parse and Review halves are
  unchanged either way, so it stays a drop-in upgrade.
- `RecognizeDocumentsRequest` (iOS 26+) behind the same `recognizeText`.
- Splitting one receipt into per-item transactions from the Review card.
