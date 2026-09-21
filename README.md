# Budgets Bro Native

> 🚧 Work in progress. Native Swift/SwiftUI rewrite of [budgets-bro](https://github.com/solomonxie/budgets-bro) — same app, no diff on UI/UX, extremely slim.

Free, privacy-first, YNAB-style budgeting for iOS. Envelope budgeting, common financial calculators, and optional AI analysis — no backend, no subscription, and (the point of this rewrite) no app framework overhead.

See [`docs/DESIGN.md`](docs/DESIGN.md) for the design doc and [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) for the implementation plan.

## Why a separate repo
`budgets-bro` is Expo/React Native and works. This is a ground-up native
rewrite testing whether the same app can ship **at least 3/4 smaller**
(< 4.25 MB installed, < 1.8 MB zipped, vs. the RN app's 17 MB / 7.2 MB) by
dropping the JS runtime and avoiding third-party frameworks wherever DIY is
reasonable. See [`AGENTS.md`](AGENTS.md).

## Core
- YNAB-style envelope/zero-based budgeting
- Financial tools: mortgage / interest / payment calculators
- AI analysis (bring your own API key)

## Storage
- Local (SQLite via system `libsqlite3`): single source of truth
- iCloud Drive: backup option — the app's own folder, visible in Files
- S3: backup option

## Privacy
- iCloud: the user's own account and storage quota; nothing passes through a server of ours
- S3: provisioned by user, grant app access
- AI: user's own API key, usage auditable in the provider's own dashboard

## Development
Plain Swift/SwiftUI, no Expo/React Native, no Xcode Cloud/EAS. Xcode project
generated from `project.yml` via [xcodegen](https://github.com/yonaskolb/XcodeGen)
(dev tool only, generated project is committed).

```
brew install xcodegen   # once
xcodegen generate
open BudgetsBroNative.xcodeproj
```

Physical iPhone only for QA — same policy as the original, see [`AGENTS.md`](AGENTS.md).

### Xcode 26.4+ required
Same SDK/toolchain floor as the original — see `docs/DESIGN.md`.

## Status
Repo bootstrap + docs port done. Native project scaffold and screen-by-screen
port tracked in [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md).
