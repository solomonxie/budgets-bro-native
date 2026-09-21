## Phase 1: Shared backup core
Extracts the pieces both the existing share-sheet export and every cloud
provider need, so upload/restore code never re-implements zip building or
parsing. Everything else depends on this.

- [x] T1.1 Extract `sync/buildBackup.ts` — move the table-dump + zip-build body out of `export/exportBoard.ts` into a pure `buildBackupZip(db, boardId, boardName): Promise<Uint8Array>`; `exportBoardZip` becomes a thin wrapper that calls it then shares — see `src/export/exportBoard.ts` — depends: none
- [x] T1.2 Extract `sync/parseBackupZip.ts` — move the zip-parsing body out of `import/pickAppExport.ts` into `parseBackupZip(bytes: Uint8Array): PickedAppExport`; `pickAppExport` becomes a thin wrapper around the file picker + this — see `src/import/pickAppExport.ts` — depends: none
- [x] T1.3 `sync/types.ts` — `CloudProvider` interface (`id`, `upload`, `downloadLatest`); dropped `isConfigured` from the interface in favor of each provider module's `create<X>Provider(db)` factory returning `null` when unconfigured — see `docs/design/cloud-sync/DESIGN.md` — depends: none

## Phase 2: Providers
Each provider is independent once Phase 1 lands — safe to build in
parallel. Both read credentials added in their own task, so no shared
file contention.

- [x] T2.1 `sync/s3Provider.ts` — SigV4-signed `fetch` PUT/GET against `<bucket>.s3.<region>.amazonaws.com/<boardId>/latest.zip`; used `@noble/hashes` for HMAC-SHA256 instead of `expo-crypto` (confirmed against SDK 57 docs: expo-crypto has no HMAC, only plain digests) — see `src/sync/s3Provider.ts` — depends: T1.3
- [x] T2.2 S3 bucket/region storage — used `settingsRepo.getSetting`/`setSetting` directly with local key constants in `s3Provider.ts` (same pattern as `hooks/useLanguage.ts`), no changes needed to `secureStore.ts`/`settingsRepo.ts` themselves; access key ID/secret stay in the existing `secureStore` fields — see `src/sync/s3Provider.ts` — depends: none
- [x] T2.2b Dropped the separate config name field (bucket name is the identifier); region auto-detected via the `x-amz-bucket-region` response header instead of typed by the user; added an optional key-prefix field for buckets shared with other stuff — see `src/sync/s3Provider.ts` — depends: T2.2
- [x] T2.6 `sync/localProvider.ts` — writes to `Paths.document/backups/<boardId>/latest.zip` (no credentials); toggle in Settings enables/disables it as a `collectProviders()` entry — see `src/sync/localProvider.ts` — depends: T1.3
- [ ] T2.3 `sync/googleDriveProvider.ts` — `expo-auth-session` PKCE auth against `drive.appdata` scope, Drive REST v3 multipart upload/download to `appDataFolder`; implements `CloudProvider` — see `docs/design/cloud-sync/DESIGN.md` (Providers → Google Drive) — depends: T1.3
- [ ] T2.4 Google Cloud Console setup (user-owned, blocking T2.3's redirect config) — create OAuth Client ID (type iOS, bundle id `com.solomonxie.budgetsbro`), add self as test user for the `drive.appdata` scope, hand back the Client ID — see `docs/design/cloud-sync/DESIGN.md` (Providers → Google Drive) — depends: none
- [ ] T2.5 `app.json` — register the custom URL scheme for the Google OAuth redirect once T2.4's Client ID is in hand — see `app.json` — depends: T2.4

## Phase 3: Sync orchestration
Wires providers into an automatic trigger. Depends on at least one real
provider existing to call.

- [x] T3.1 `sync/cloudSync.ts` — `syncNow()`/`downloadLatestBackup()`, iterates configured providers (S3 only for now, Drive slots in once T2.3 lands), updates last-synced-at, swallows/logs failures — see `src/sync/cloudSync.ts` — depends: T2.1
- [x] T3.2 `hooks/useCloudSync.ts` — debounced (5s) trigger on `dataVersion` + `AppState` `active` listener, mounted from `RootNavigator` — see `src/hooks/useCloudSync.ts`, `src/navigation/RootNavigator.tsx` — depends: T3.1

## Phase 4: Settings UI
User-facing surface — depends on providers + orchestration existing to
control.

- [x] T4.1 S3 section: added Bucket/Region fields next to existing key fields — see `src/screens/settings/SettingsScreen.tsx` — depends: T2.2
- [ ] T4.2 New Google Drive section: Connect/Disconnect, shows linked account — see `src/screens/settings/SettingsScreen.tsx` — depends: T2.3
- [x] T4.5 Local Backup section: single toggle + the on-device path shown for inspection — see `src/screens/settings/SettingsScreen.tsx` — depends: T2.6
- [x] T4.3 Auto-sync toggle, "Last synced" (absolute time, not relative — simplification, see DESIGN.md note), "Sync Now" button — see `src/screens/settings/SettingsScreen.tsx` — depends: T3.1
- [x] T4.4 "Restore Latest from Cloud" — downloads via `cloudSync.downloadLatestBackup`, parses with `parseBackupZip`, imports via existing `importAppExport` (new board, same as today's file-based restore) — see `src/screens/settings/SettingsScreen.tsx` — depends: T1.2, T2.1
