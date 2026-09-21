# Settings

`src/screens/settings/SettingsScreen.tsx` — reached by the ⚙︎ in every
screen's header, same place on every screen. Each section: uppercase muted
heading, one-paragraph hint, a bordered group of rows, a centred accent add
link.

```
 ‹              Settings
 BUDGET BOARDS
 <hint: what a board is>
 Personal Budget                                    ⋯
 Side Business                                      ⋯
                  ( + New Board )
                  ( Create Demo Board )   ⟳ Creating…
 ⋯ ▸ Rename · Delete !
 ⇒ Delete "Side Business"?  (message names the fallout)
 ⇒ Can't delete your only board · Create another board first.
 MANAGE PAYEES
 <hint>
 Whole Foods                                        ⋯
 Select or create…                                  ▾
 ⋯ ▸ Rename · Delete !   ⇒ Delete "Whole Foods"?
 APPEARANCE
 [ DARK | Light ]          ← Light carries its own hint
 LANGUAGE
 [ ENGLISH | 简体中文 ]      ← each written in its own language
 AI KEYS
 <hint>                                    Sequential ▾
 OpenAI                                  ⌃ ⌄ ⋯
 42 requests sent                            ›   → key history
                  ( + Add AI Key )
 ⋯ ▸ Delete !  ⇒ Delete this key?
 BACKUP
 Each switch backs this board up automatically, every time it changes.
 iCloud also brings the board back by itself if you reinstall the app.
 API keys never leave this device, including in backups.
 iCloud Drive                                        ─●
 In Files → iCloud Drive → Budgets Bro · 2 h ago
 my-bucket                                           ─●
 s3://my-bucket/byo-budget/ · never synced
                  ( + Add S3 Backup )
 DATA
 Import from YNAB                                    ›
 Import a backup                                     ›
 Export this board                                   ›
 ABOUT
 Version                                        1.4.0
```

## Blocked iCloud, all three

The reason replaces the location line; only the fixable one carries
directions.

```
 iCloud Drive                                     ·   ○─
 iCloud Drive is off on this device
 Settings → your name → iCloud → Drive → turn on     ← accent, here only

 iCloud Drive                                     ·   ○─
 This build of the app isn't signed for iCloud

 iCloud Drive                                     ·   ○─
 iCloud isn't ready yet — try again shortly
```

## Add S3 backup  `components/ui/S3ConfigModal.tsx`

```
 ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
 Add S3 Backup                            ( Cancel )
 ┌ S3 bucket (paste info to add) ─────────────────┐  ← the "(…)" is the
 │ Bucket                                         │    button
 │ Access Key ID                                  │
 │ Secret Access Key            ••••••     ( Show )│
 │ 18 characters — this key is usually 20.        │  ← paste sanity hint
 │ Folder (key prefix, optional)                  │
 └────────────────────────────────────────────────┘
        [[ Save ]]
 ⟳ Detecting region & testing connection…
 ⊗ Fill in the bucket and both keys.
 ⊗ Could not connect: <error>
 DRAFTS                                  ← an unfinished add is kept
 <hint>   (no bucket yet)                        🗑

 tap (paste info to add) ↓
 ┌ S3 bucket (back to fields) ────────────────────┐
 │ bucket: my-bucket                              │
 │ access_key_id: AKIA…                           │
 │ secret_access_key: …                           │
 └────────────────────────────────────────────────┘
 <hint: "name: value" or "name=value", any spelling; region detected>
```

## Bucket browser  `components/ui/S3BrowserModal.tsx`

Per-connection sync controls live here — in the bucket's own menu — not in
a settings section of their own.

```
 ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
 Browse Bucket                                    ⋯
 📁 ..                                              ← up one level
 📁 byo-budget                                     ›
 📄 board-personal.json                     12 KB
 empty   Nothing here yet.
 ⋯ ▸ Sync Now · Delete Connection !
```

## AI key history  `components/ui/AiKeyHistoryModal.tsx`

```
 Sep 17, 2026 09:02   gpt-4o-mini   1,204 → 88 tokens   $0.004
   ▾ prompt and reply behind the tap
 failures are kept, with the vendor's own words
```

## Data — import and export

```
 Import from YNAB     ─▶ [OS file picker] ─▶
   IMPORTED
   Transactions imported            1,204
   Transactions updated                12
   Budgeted amounts written            84
   Accounts created                     6
   Categories created                  21
 Import a backup      ─▶
   RESTORED
   Restored into board    Personal Budget
   Accounts 6 · Categories 21 · Transactions 1,204
 Export this board    ─▶ [OS share sheet]
 ⊗ Import failed. / Restore failed. / Export failed
```
