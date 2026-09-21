## Phase 1: Purchase items
A transaction field in its own right — typed in by hand to track a price over
time, or filled by a receipt import later. Ships and is useful on its own,
before any of the iOS work below exists.

- [x] T1.1 Migration `031_transaction_purchase_items` — `ALTER TABLE transactions ADD COLUMN purchase_items TEXT`, `hasColumn` guard like `023_notes.ts`, registered in `src/db/migrate.ts` — see `databases/migrations/` — depends: none
- [x] T1.2 `domain/purchaseItems.ts` (+ test) — `parsePurchaseItems`/`formatPurchaseItems`/`purchaseItemCount`/`itemPriceCents`; `key=value` joined by `, `, separators sanitized out of keys and values on write; a money value makes the pair a *priced item* — see `src/domain/purchaseItems.ts` — depends: none
- [x] T1.3 Plumb the column — `TransactionRow`/`Transaction`/`mapRow`, `CreateTransactionInput`/`UpdateTransactionInput`, `INSERT_TRANSACTION`/`UPDATE_TRANSACTION`; the transfer mirror in `postLinkedAccountLeg` writes null (items belong to the purchase, not its mirror) — see `src/db/repositories/transactionsRepo.ts`, `databases/queries/transactions.ts` — depends: T1.1
- [x] T1.4 `import/appExportImporter.ts` names its columns explicitly — add `purchase_items` or a restore silently drops it. `sync/buildBackup.ts` is `SELECT *`, no change — see `src/import/appExportImporter.ts` — depends: T1.3
- [x] T1.5 `components/ui/PurchaseItemsField.tsx` — folded row reading `Items (3)` via the existing `useExpandingField()`; expanded, one key/value pair per row, delete per row, an "Add item" link — see `src/components/ui/ExpandingField.tsx` — depends: T1.2
- [x] T1.6 Wire into Add/Edit Transaction + i18n in both dictionaries — see `src/screens/transactions/AddTransactionScreen.tsx` — depends: T1.3, T1.5

## Phase 2: Purchase Insights
Reads whatever wrote the items. Depends only on Phase 1.

- [x] T2.1 `domain/purchaseInsights.ts` (+ test) — `summarizePurchaseItems` ranked by purchase count, `purchaseItemHistory`, `purchaseItemTrend` with the trailing-average benchmark; grouping by trimmed lower-cased name, most-used spelling displayed — see `src/domain/purchaseInsights.ts` — depends: T1.2
- [x] T2.2 `hooks/usePurchaseInsights.ts` — one `listTransactions` read keyed on `dataVersion` + board, same shape as `useInsights` — see `src/hooks/useInsights.ts` — depends: T2.1
- [x] T2.3 `screens/insights/PurchaseInsightsScreen.tsx` — ranked list, each row expanding in place into the trend chart and the purchase history (date, price, count), each history row tappable through to its transaction — depends: T2.2
- [x] T2.4 `screens/insights/PurchaseItemTrendChart.tsx` — SVG polyline + dashed benchmark line, wired to `useChartScrub` like every other chart — see `src/screens/accounts/BalanceTrendChart.tsx` — depends: T2.1
- [x] T2.5 Navigation + entry row — `InsightsStackParamList`, a `Stack.Screen`, a `UTILITY_ROWS` entry, i18n — see `src/screens/insights/InsightsScreen.tsx` — depends: T2.3

## Phase 3: Review lands unconfirmed rows
Everything a receipt import needs on the ledger side. Independent of the
native work, testable by flipping the flag by hand.

- [ ] T3.1 Migration `032_transaction_needs_confirm` — `ADD COLUMN needs_confirm INTEGER NOT NULL DEFAULT 0`, plumbed through schema/types/mapRow — depends: none
- [ ] T3.2 `transactionsRepo` — `clearNeedsConfirm(db, ids)` and `insertReceiptTransaction` with `ON CONFLICT(board_id, import_id) DO NOTHING` (not `DO UPDATE`: a re-shared photo must not clobber manual edits) — depends: T3.1
- [ ] T3.3 `domain/transactionReview.ts` (+ test) — `'needsConfirm'` reason, quick-fixable but appended **last** so a duplicate or broken transfer still wins `primaryQuickFix`, and never deleting — depends: T3.1
- [ ] T3.4 Flagged Transactions page — label/fix/explanation copy, `'needsConfirm'` first in the reason order, an early branch in `runQuickFix` (without it Confirm falls into `quickFixTransfer` and throws), the purchase items rendered on the card, and an account dropdown since the account is a guess — see `src/screens/transactions/ReviewTransactionsScreen.tsx` — depends: T3.3
- [ ] T3.5 Verify `hooks/useReviewCount.ts` needs no change (it counts through `reviewReasons`) — depends: T3.3

## Phase 4: Reading a receipt
Pure JS, no device needed. The repair ladder is where the risk lives.

- [ ] T4.1 `ai/prompts.ts` — `buildReceiptMessages(ocrText, { today, categoryNames })` asking for one JSON object, one transaction per receipt, a category from the board's real names or null; plus `redactReceiptText` — depends: none
- [ ] T4.2 `domain/receiptParse.ts` (+ test) — `extractJsonObject` repair ladder (plain → fences → first/last brace → brace-balance ignoring strings → trailing commas), coercion that never trusts the shape, `receiptPurchaseItems`, `receiptMemo`, `receiptImportId` — depends: T1.2, T4.1
- [ ] T4.3 `receipts/importReceipt.ts` — OCR → redact → `runWithAiKeys` → parse → resolve account/payee/category → `insertReceiptTransaction` — depends: T3.2, T4.2, T5.3

## Phase 5: The iOS share-in path
- [ ] T5.1 Probe: `CFBundleDocumentTypes` (`public.image`) in `Info.plist`, share one photo from Photos, record whether the app appears. Keep the entry either way for Files/Mail — depends: none
- [ ] T5.2 App group `group.com.solomonxie.budgetsbro` on the app entitlements; verify `containerURL(forSecurityApplicationGroupIdentifier:)` is non-nil on device — depends: none
- [ ] T5.3 `modules/receipt-inbox/` — bridge module in the `modules/icloud-drive` shape; `ReceiptInboxStore.swift` (pure Foundation, compiled into both targets) owns the queue and Vision; `recognizeText` takes an id, downscales, honours EXIF orientation, `usesLanguageCorrection = false`; one `pod` line + `pod install` — depends: T5.2
- [ ] T5.4 `ios/ReceiptShare/` extension target — `com.apple.share-services`, plain `UIViewController`, image activation rule, `loadFileRepresentation` + atomic write + sidecar-last, sha256 via CryptoKit; **not** in the Podfile — depends: T5.3
- [ ] T5.5 `project.pbxproj` by hand — the extension target, an "Embed Foundation Extensions" copy phase (`dstSubfolderSpec = 13`) and an **explicit** `PBXTargetDependency`; implicit scheme dependencies don't cover embedded extensions and the build would ship an empty `PlugIns/` — depends: T5.4

## Phase 6: Draining and the UI around it
- [ ] T6.1 `hooks/useReceiptInbox.ts` — `Linking.getInitialURL` + `'url'` + `AppState` active, one guarded `drain()`; the app's first inbound Linking listener (`AppDelegate` already forwards) — depends: T4.3
- [ ] T6.2 `navigation/navigationRef.ts` + wire it — `RootNavigator`'s body sits outside `NavigationContainer`, where `useNavigation` is unavailable — depends: none
- [ ] T6.3 `ReviewTransactions` route gains optional `focusTransactionIds`; the screen re-snapshots and scrolls to them — depends: T6.2
- [ ] T6.4 `components/ui/ReceiptImportOverlay.tsx` + a `receiptImport` slice on `useAppStore` — reading/analyzing/error with a Cancel; the failure matrix in `DESIGN.md` decides what is kept for a retry and what is dropped — depends: T6.1
- [ ] T6.5 Settings row "Receipt inbox — N waiting" with a Clear, so a stuck item is recoverable without a reinstall — depends: T5.3

## Phase 7: Docs
- [ ] T7.1 Fold the built reality back into this folder, `docs/DESIGN.md` (schema line, AI section), `docs/UIUX-DESIGN.md` and the root `README.md` — above all the share-sheet probe's result — depends: T5.5
