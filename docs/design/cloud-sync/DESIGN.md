# Cloud Sync

## Problem
Backup today is manual-only: "Export Board as .zip" hands a zip to the OS
share sheet; the S3 credential fields in Settings are wired to nothing. No
way to keep a board automatically backed up, or pull it onto a new device,
without remembering to export by hand.

## Goals
- Auto-backup the current board to cloud storage: on every data change
  (debounced) and whenever the app returns to the foreground.
- Support AWS S3 first (finishes the existing stub), then Google Drive.
- No manual sync actions at all: one switch per destination means "every
  change", and off means nothing. See Settings UI below for why the menu
  this replaced was unusable.
- Provider-agnostic core so a third provider is a new file, not a rewrite.

## Non-goals
- **Not bidirectional multi-device live sync.** No merge/conflict
  resolution across devices editing concurrently. This is one-way
  device→cloud backup, plus a manual pull that restores as a *new* board
  (same shape as today's "Import App Backup") — same limitation the app
  already has, just automated on the push side.
- **Not true background execution.** `expo-task-manager`/`expo-background-task`
  would each need their own entitlement and a background task registered at
  launch, which this app does not ship. "Auto" here means triggered while the app is open
  (foreground + on-save), not while closed or killed.
- **Not a user-picked iCloud Drive folder** (`Directory.pickDirectoryAsync()`):
  iOS grants that folder only for the current app session — Expo's JS API
  persists no security-scoped bookmark — so it could only ever be a manual
  "pick folder, sync now" re-prompted every cold start. The app's own
  ubiquity container (Providers → iCloud Drive below) needs no picker.
- Encrypting the backup blob itself (S3/Drive both support transport TLS;
  provider credentials already never leave the device — see secureStore.ts).

## Architecture
```
src/sync/
  types.ts             CloudProvider interface + SyncSettings shape
  buildBackup.ts        zip-bytes builder, extracted from export/exportBoard.ts
  s3Provider.ts          SigV4-signed fetch, no AWS SDK
  localProvider.ts       writes to Paths.document — rollback snapshot, dies with the app
  icloudProvider.ts      the app's own iCloud Drive folder, via modules/icloud-drive
  autoRestore.ts         pulls the board back from iCloud once, on a fresh install
  googleDriveProvider.ts expo-auth-session (PKCE) + Drive REST v3, appDataFolder scope
  cloudSync.ts            orchestrator: debounce + AppState trigger, calls each enabled provider
```

`CloudProvider`:
```ts
interface CloudProvider {
  id: 'aws-s3' | 'google-drive';
  isConfigured(): Promise<boolean>;
  upload(bytes: Uint8Array, fileName: string): Promise<void>;
  downloadLatest(): Promise<Uint8Array | null>; // for "Restore Latest from Cloud"
}
```

`export/exportBoard.ts` currently couples "build the zip" with "open the
share sheet". Split into `sync/buildBackup.ts` (pure, returns `Uint8Array`)
reused by both the share-sheet export and every `CloudProvider.upload()` —
no duplicated table-dump logic.

Restore side reuses `import/appExportImporter.ts` unchanged: cloud download
returns the same zip bytes shape as a picked file, so `pickAppExport.ts`'s
zip-parsing is extracted into a `parseBackupZip(bytes)` helper callable from
both the file-picker path and the cloud-download path.

## Providers

**S3** — raw `fetch` with an AWS Signature V4 header (`expo-crypto` for
SHA-256/HMAC; no SDK — the AWS JS SDK assumes Node APIs RN doesn't have). No
separate display name — the bucket name is the identifier. **Region** is
never typed by the user: S3 stamps the real region on the
`x-amz-bucket-region` response header for any request to the region-less
global endpoint, even an unauthenticated one that 403s, so
`testS3Connection` detects it automatically before running its checks
(store via `settingsRepo`, alongside access key ID/secret which stay in
`secureStore`). Optional **key prefix** nests backups under a folder, for a
bucket shared with other stuff — object key:
`<keyPrefix>/<YYYYMM>-<board-slug>.zip` — readable straight out of an S3
console (which board, roughly when, without opening it). One object per board
per month: every sync that month replaces that month's file, so a year of
history is twelve files on one screen instead of hundreds of
near-identical zips nobody restores a specific day from. Keys older versions
wrote (`<YYYYMM>/<board-slug>-<YYYYMMDD>.zip`, and `<boardId>/latest.zip`
before that) are still recognised when looking for the newest backup.

**Local** — no credentials, no network: writes the same zip to
`Paths.document/backups/<YYYYMM>-<board-slug>.zip`. Not off-device
protection —
expo-sqlite's own database already lives at `Documents/SQLite/`, the same
sandbox this zip sits in, so both disappear together on app deletion and
both get restored together by a full device restore either way. Its real
job is a rollback snapshot (undo a bad import, recover from DB corruption)
independent of whatever happened to the live file, plus a manually-
retrievable copy: the `expo-file-system` config plugin (`app.json`) sets
`UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` so a real
device build exposes it in the Files app under "On My iPhone" for the user
to copy elsewhere by hand — that flag only takes effect in a built
app. One toggle in Settings (no bucket/account
concept to manage, unlike S3/Drive).

**iCloud Drive** — the same zip written into the app's own ubiquity
container at `Documents/<board-slug>-latest.zip`. No credentials, no account
setup, no third party: the user is already signed in, and the folder shows up
in Files under iCloud Drive → Budgets Bro, where they can drag a backup out or
one back in.

One file per board, overwritten every sync — no dates, no history. iCloud's
whole job here is surviving a reinstall, and only the current copy does that
job; a dated history would spend the user's own iCloud quota on zips nobody
opens. A bucket, which is cheap and browsable, keeps the history instead.
Restore still lists the folder rather than naming the file, so an install
that backed up under the old dated layout still finds its newest zip
(`latest` sorts past every date — `backupPath.ts`). This is the destination that closes
localProvider's gap — it survives losing the phone and it reaches their other
devices — without S3's provisioning.

Costs real infra, which is why it took a native module:
`modules/icloud-drive` (local Expo module, Apple-only) wraps
`NSFileManager.url(forUbiquityContainerIdentifier:)` plus `NSFileCoordinator`
reads/writes. Coordinated, not bare `Data.write` — another device's sync
daemon can be touching the same file. Reads first wait on
`startDownloadingUbiquitousItem`: a file can be listed in the container
without its bytes being on this device, and the listing itself has to turn
`.<name>.icloud` placeholders back into the name the file will have once it
lands. `app.json` carries the entitlement
(`com.apple.developer.ubiquity-container-identifiers`) and the
`NSUbiquitousContainers` key with `NSUbiquitousContainerIsDocumentScopePublic`
— without that last flag the container syncs but stays invisible in Files.
Container id is never repeated in Swift; the native side passes `nil` and gets
the first container from the entitlement.

A nil ubiquity container has several unrelated causes, and the row separates
them because only one is the user's to fix. The checks are **ordered**, and the
order matters: `ubiquityIdentityToken` needs the entitlement itself, so in an
unentitled build it reads nil and looks exactly like a signed-out user.

| Status | Test | Row says |
|---|---|---|
| `available` | container resolves | location + last sync |
| `notEntitled` | embedded profile grants no ubiquity container | blames the build, no instruction |
| `icloudOff` | token is nil (covers signed out *and* file syncing off) | the state, plus the Settings path |
| `notReady` | entitled, signed in, still nil | try again shortly |

`SecTaskCopyValueForEntitlement` is not in the iOS SDK, so `notEntitled` is
read out of `Bundle.main`'s `embedded.mobileprovision`. Only `icloudOff` gets
a second line telling the user what to do — an earlier cut guessed "signed
out" for everything and told an already-signed-in user to sign in, which sent
them somewhere that could not help. The section re-checks on AppState
`active`, since the fix happens in iOS Settings and the user comes back
expecting the row to know.

Unsupported (Android — the native module is absent) hides the row
entirely. None of the blocked states is a failed sync: `createICloudProviders`
returns nothing and `syncNow` skips the destination, same as an unconfigured
bucket.

Needs a **paid** Apple Developer Program membership (Individual is enough — no
company entity, no D-U-N-S, no entitlement request form). A free personal team
cannot sign the iCloud capability at all, so the entitlement in `app.json` now
gates every local device build too, not just EAS ones.

**Google Drive** — OAuth via `expo-auth-session`'s PKCE flow (no native
module) against scope **`drive.appdata`** specifically
(not full `drive` scope): stores the backup in the user's hidden per-app
`appDataFolder`, invisible in their normal Drive UI, and — practically
important — narrow enough that Google's consent screen works fine in
**Testing** mode with the user added as a test user, no verification review
needed for personal use. Refresh token stored in `secureStore`; access
token refreshed on demand.

User-side setup (Google Cloud Console, one-time): create an OAuth 2.0
Client ID (type: iOS), add the app's bundle ID (`com.solomonxie.budgetsbro`) and
a custom URL scheme for the redirect. Hand the Client ID back for
`app.json`'s scheme config — no client secret needed for the PKCE/installed
-app flow.

## Sync trigger
`cloudSync.ts` exposes `scheduleSync()`:
- Called from `bumpDataVersion()`'s call sites indirectly — simplest hook:
  subscribe to `useAppStore`'s `dataVersion` in one place (a root-level
  effect, e.g. `RootNavigator`) and debounce (~5s) before running.
- Also runs once on `AppState` transitioning to `active` (covers "left the
  app mid-edit, came back later").
- Skips silently if no provider is configured/enabled — not an error state.
- Failures are non-blocking (toast/inline Settings status only) — never
  interrupt the money-entry flow for a sync problem.

## Settings UI
**One switch per destination row, and nothing else.** The row menu this
replaced held four items — a "keep a copy here" toggle, an "auto-sync"
toggle, "Sync Now" and "Restore Latest" — and no user could predict what any
combination of the first two did. The switch now *is* the feature: on means
every change is backed up there, off means nothing is. Flipping one on syncs
immediately rather than waiting for the next edit, so "did that work" has an
answer.

Two settings collapsed into that one switch ("is this destination on" and
"auto-sync to it", plus a global auto-sync switch above both) — see
`autoSync.ts` for how an existing install's stored pair resolves, so nobody's
choice flips on upgrade.

- Tapping an S3 row opens its browser, which also owns "Delete Connection" —
  rare and destructive, so one level down behind a deliberate tap.
- The iCloud row opens the same browser over its folder. "What is actually up
  there" is the same question wherever the files live.

## Manual backup, from the browser
Automatic backups name themselves `<YYYYMMDD>-<board-slug>.zip`, which is
right for a history nobody reads until they need it and wrong for the copy
taken deliberately before something risky. So each browser ends in "Back Up
This Board Here": type a name, and the same zip lands under it — in the S3
folder being browsed, or the iCloud folder. Typed names are outside the
automatic shape, so pruning never touches them (`backupPath.ts`).

## Restore
Three paths, none of which overwrites a board:

- **From a destination, by hand**: every file in either browser restores in
  place — download, `parseBackupZip`, `importAppExport`. It arrives as a
  board of its own and the app switches to it, so a file opened out of
  curiosity costs a switch back and nothing else. Listing-only was the
  earlier answer, on the reasoning that restoring goes through "Import a
  backup" — but that means getting the object onto the phone first, which is
  no use when the phone is what you have.
- **iCloud, automatic** (`autoRestore.ts`): deleting the app takes the
  database with it — iCloud is the only destination that outlives a
  reinstall. So a fresh install pulls its board back by itself, once, before
  the demo board seeds. No prompt: on first launch the user has no context
  for the question, and getting their data back is the entire point of
  having backed it up.
- **From a file the user picked**: the "Import a backup" link under the
  backup destinations, same importer.
- New Google Drive section: "Connect"/"Disconnect", shows connected
  account email once linked.
- Per-provider: "Auto-sync" toggle (default on once configured), "Last
  synced: <relative time>", "Sync Now" button.
- "Restore Latest from Cloud" (per provider) — same confirmation/behavior
  as today's "Import App Backup": always creates a new board.

## Risks / open questions
- SigV4 signing by hand is easy to get subtly wrong (canonical request
  edge cases) — needs a real test against a live bucket before trusting it,
  not just unit tests against fixtures.
- Google's PKCE redirect on iOS needs a custom URL scheme registered in
  `app.json` — the first deep-link config in this app; confirm
  `expo-auth-session`'s native redirect flow on SDK 57 (docs should be
  re-checked at implementation time, not assumed).
- Debounce window (5s) is a guess — fine to tune after real use.
- "Last synced" timestamp storage: per-provider, per-board, in
  `settingsRepo` (small KV, already used for exactly this kind of thing).
