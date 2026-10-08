# Production vertical slice — October 8, 2026

## Audit before implementation

Canonical code: Action, Goal, Project, ActivitySession, DailyProgress in TimeBiteCore/Models; JSON snapshot v1 in Packages/TimeBiteData/LocalActivityStore.swift. No SwiftData or backend is required. Timer uses timestamped active intervals already. iOS enters Root → onboarding → Today; Mac/Vision enter ActivityLoopView; Watch only shows a local current session, with no transport. No Reflection model exists.

Critical gaps: onboarding requires Apple identity or unverified local email; iOS headline ring uses captured wall intervals including pauses and does not tick; daily calculation excludes yesterday's actions executing today; completed actions can restart; input provenance is unstructured; Health permission-request completion is mislabeled as authorization.

Calendar EventKit reads remain separate TodayActivityEntry records. HealthKit reads are isolated and real; sleep is merged/clipped and workouts use UUID identifiers. Preserve both integrations, handwriting capture, sync reconciliation, platform presentation, and existing user workspace changes.

## Implementation

Prioritize iPhone. Keep canonical value types and existing storage. Add a production local-device onboarding path, a shared ActionDraft normalization boundary, backward-compatible source metadata, transition guards, actual-time rings and periodic Today rendering. Preserve Calendar/Health summaries separately. No AI, account, network, or accessory is necessary.

First commit: this audit and architecture documentation only. Subsequent commits group model/calculation/store changes with regression coverage, then presentation and build cleanup. Do not manufacture nine commits.

## Risks and release gates

UserDefaults remains the existing small local store; it is not cross-process transactional storage or a sync database. Decode old snapshots without losing data. Do not silently reset corrupt storage. Physical-device lock/background, process termination, permissions, signed archive, and TestFlight validation remain required; package tests cannot establish these. Existing release documents prioritize Mac/Watch and are historical; this sprint prioritizes iPhone.

## Broader system design

The [system design architecture](../architecture.md) includes M5Stack / TimeBite / Animbite as a future companion client alongside Apple devices and glasses. It documents shared commands and state without implementing hardware or changing the current app. All changes proposed above remain unimplemented by this documentation-only commit.
