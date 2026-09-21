# Swift, native, no frameworks by default

This is a from-scratch native rewrite of [budgets-bro](https://github.com/solomonxie/budgets-bro)
(Expo/React Native). Goal: **identical UI/UX** (see `docs/UIUX-DESIGN.md` and
`docs/design/uiux/*.md` — ported 1:1, no diff) on top of a completely
different, much smaller runtime. See `docs/DESIGN.md` for the full design doc.

Physical iPhone only for QA builds, same policy as the original — if the
paired device isn't reachable, stop and say so; don't fall back to a
simulator for anything but a compile check.

# Lightweight is the whole point of this repo

Non-negotiable, and it outranks any feature: **at least a 3/4 size reduction**
against the RN app's measured numbers (17 MB installed / 7.2 MB zipped as of
2026-09-19) — so this app must land under **4.25 MB installed / 1.8 MB
zipped**. See `docs/DESIGN.md#size-and-speed-budget` for the exact target and
how to measure it. A feature that can't be built within this is not built as
proposed — shrink its footprint or cut it.

Rules that keep it there:

- **No third-party dependency by default.** Reach for Foundation, SwiftUI,
  UIKit, and the system frameworks (`Security`, `CryptoKit`, `Charts`,
  `CloudKit`/`FileManager` ubiquity APIs) first. Only take a pod/SPM package
  when hand-rolling it is genuinely hard — not "saves an afternoon," but
  "this is a security-sensitive primitive" (e.g. don't hand-roll AES) or
  "this is weeks of correctness-critical work with no reasonable native
  equivalent." When in doubt, write the ~50-200 lines yourself; a personal
  budgeting app's screen surface is small enough that this is usually
  cheaper than it sounds. Log the decision either way in `docs/DESIGN.md`'s
  Risks section.
- **`xcodegen` is a dev-time tool, not a dependency** — it generates
  `BudgetsBroNative.xcodeproj` from `project.yml` and ships nothing into the
  app. Regenerate with `xcodegen generate` after editing `project.yml`;
  don't hand-edit `project.pbxproj`.
- **SQLite via the system `libsqlite3` C library directly** (`import
  SQLite3`, link `libsqlite3.tbd`) — no wrapper package. Repository
  functions per table, same shape as the original's `src/db/repositories`.
- **Never read the whole board to render part of it** — same rule as the
  original. Ask SQL for the rows/columns a screen actually shows; add an
  index rather than filtering in Swift after a broad `SELECT`.
- **Weigh every dependency in the binary, not in the README.** Measure with
  `du -sh` on the built `.app` before and after. A pod that costs 500 KB to
  serve an optional feature is not a fair trade at this budget.
- **Aggregate in memory only over rows already read for another reason**,
  and cache it (`@State`/a small memoized store) rather than recomputing a
  whole-ledger roll-up on every view update.
- **No work on a screen that isn't showing it.** No polling, no background
  timers, no eager prefetch of a page nobody opened.
- **Assets**: SF Symbols or hand-drawn `Path`/`Shape` over bitmap images
  wherever the original used an icon; PDF/vector asset catalogs (auto-scaled,
  no @1x/@2x/@3x triplication) for anything that must be a raster.
- **No CocoaPods/SPM tree to audit** unless a dependency was actually taken
  per the rule above — keep `project.yml`'s `packages:`/`Podfile` (if either
  ever exists) short enough to read in one sitting.

# What each RN dependency becomes here

| budgets-bro (RN) | budgets-bro-native (Swift) |
|---|---|
| `expo-sqlite` | `libsqlite3` (system), hand-rolled `Database` wrapper |
| `expo-secure-store` | `Security` framework Keychain calls directly |
| React Navigation (native-stack + bottom-tabs) | SwiftUI `NavigationStack` + `TabView` |
| Zustand | SwiftUI `@Observable`/`@State`, repository calls |
| `react-native-svg` (Insights line chart) | Swift `Charts` (system framework, iOS 16+) or `Canvas`/`Path` |
| `@noble/hashes` (S3 SigV4 HMAC) | `CryptoKit`'s `HMAC<SHA256>` (system) |
| `jszip` (YNAB import's `.zip` reader — this app's own backups are raw SQLite file copies, not zips, so nothing here *writes* one) | hand-rolled ZIP container parsing (`Sources/Backup/Zip.swift`) over the `Compression` framework's raw-DEFLATE codec (`compression_decode_buffer` with `COMPRESSION_ZLIB`, RFC 1951 — exactly ZIP method 8, no zlib/gzip wrapper). Revised from an earlier plan to link `libz` directly: `Compression` is already a proper Swift-importable system framework, so this needs no custom C module map |
| Direct `fetch` to AI providers | `URLSession` directly |
| Jest | XCTest |
| ESLint + Prettier | SwiftLint + SwiftFormat (dev-tool only) |
| EAS cloud builds | plain `xcodebuild`/`devicectl`, local |

If a row above turns out to need a real dependency after attempting the DIY
path, say so in `docs/DESIGN.md`'s Risks section with the reason — don't
silently add it.
