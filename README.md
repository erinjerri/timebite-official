# TimeBite

Canonical production repository for the September 23, 2026 Apple submission candidate. The release focus is one activity loop: create an action with a target duration, start it, see elapsed time and app-owned ring progress, pause/resume, complete, and retain the result after relaunch. macOS and watchOS are priorities; iOS and visionOS are compatibility targets.

This repository contains a shared Swift package, four small app entry points, and release audit documents. Experimental planning, finance/Plaid, admin, agent, and spatial work remains in its source repositories.

## Repository layout

- `Apps/`: Mac, iOS, Watch, and Vision app entry points.
- `TimeBiteCore/`: shared Action, ActivitySession, and DailyProgress models. The package target remains at this path while existing uncommitted model work is preserved.
- `Packages/TimeBiteData/`: local action/session persistence.
- `Packages/TimeBiteUI/`: shared ring and activity-loop UI.
- `Tests/`: domain and local-store tests.
- `Docs/migration-map.md`: source audit and migration gates.
- `Docs/releases/2026-09-23.md`: release build and manual QA checklist.

## Local validation

Use an installed Xcode developer directory; this host currently has `/Applications/Xcode-beta.app/Contents/Developer` while `xcode-select` points to Command Line Tools. The shared tests can run with:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

Open `TimeBite.xcodeproj` to build app schemes. The generated project is reproducible with `python3 Tools/generate_xcode_project.py`.

## Release status

Shared timer, pause/resume, completion, daily progress, and local persistence tests pass. App target builds and device QA must be recorded in the [release checklist](Docs/releases/2026-09-23.md). The Watch screen is a scaffold and currently has no Mac–Watch state relay. [Apple Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity) connects iPhone and Watch; Mac–Watch state needs another transport or an iPhone relay before submission.
