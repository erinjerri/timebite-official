# TimeBite visual migration audit

Date: 2026-10-09. Status: audit only; implementation awaits review, as requested in the supplied brief.

## Targets and navigation

| App target | Minimum app OS | Root |
| --- | --- | --- |
| TimeBiteiOS | iOS 17.0 | TimeBiteRootView → onboarding or TimeBiteTodayView |
| TimeBiteMac | macOS 14.0 | ActivityLoopView |
| TimeBiteWatch | watchOS 10.0 | WatchCurrentActionView |
| TimeBiteVision | visionOS 1.0 | ActivityLoopView |

Source: Apps/* entry points and TimeBite.xcodeproj/project.pbxproj, Debug and Release settings. Package.swift has lower library minimums: iOS 16, macOS 13, watchOS 9, visionOS 1. Shared components must honor these library minimums.

**There is no TabView or four-tab navigation in the current app.** iOS presents a single scrolling Today screen after three onboarding steps (welcome, calendar, health). Calendar and captured activity are sections, not tabs. Adding planning, goals or reflection tabs would be a separate product/navigation decision.

Only TimeBiteiOS has a checked-in shared scheme. Other targets exist, but their automatically generated scheme availability requires verification in Xcode.

## Styling inventory and file-by-file status

All paths below are relative to the repository root. No asset catalogs, bundled fonts, Theme type, Color extension, forced preferredColorScheme override, or AGENTS.md were found in the inspected repository.

| File | Current presentation and remaining work |
| --- | --- |
| Packages/TimeBiteUI/TimeBitePalette.swift | Partial light/dark migration: explicit ColorScheme functions for backgrounds, surfaces, text and borders. Fixed pastel accent colors; shadows and hero gradients retain the older card language. No adaptive accent colors. |
| Packages/TimeBiteUI/TimeBiteTypography.swift | Shared rounded system typography. Text-style overload supports Dynamic Type; fixed-size overload ignores its relativeTo argument. Needs serif medium headlines, default SF UI and monospaced metadata tokens. |
| Packages/TimeBiteUI/TimeBiteTodayView.swift | Partial light migration: adaptive surfaces/text, rounded cards, shadows, glow, round icon badges. Fixed ring frames, horizontal timer/action layouts, truncated titles, fixed-height buttons and a 30-point calendar control need accessibility review. Direct 14-point font remains. CalendarActivityController is colocated; leave service logic intact. |
| Packages/TimeBiteUI/TimeBiteOnboardingView.swift | Partial light migration: same palette and rounded typography, rounded panels, capsule step bars, fixed frames and heights. Direct pink Health colors, secondary ring track and 25-point icon font remain. SourceActivityRingView is a segmented source ring, not four concentric rings. TimeBiteRootView is in this file. Preserve system Apple sign-in treatment. |
| Packages/TimeBiteUI/ActivityRingView.swift | Reusable ring with clamping and VoiceOver percentage; rounded font, unconditional animation and fixed center layout. Needs Reduce Motion handling and a label including the denominator/context. |
| Packages/TimeBiteUI/ActivityLoopView.swift | Older functional system UI, used by Mac and Vision. Standard fonts and secondary foregrounds, single timer and daily ring, no shared square-section design. Contains ActivityLoopController; preserve its behavior. Unused legacyActionsList is a cleanup candidate. |
| Packages/TimeBiteUI/HandwrittenPlanCaptureView.swift | System capture/review sheets with a rounded material capture surface and direct body monospaced font. Review form and scanner must retain their existing controls and import behavior. |
| Apps/TimeBiteiOS/TimeBiteiOSApp.swift | Thin root entry, no additional styling. |
| Apps/TimeBiteMac/TimeBiteMacApp.swift | Thin root with minimum window dimensions; shares ActivityLoopView. |
| Apps/TimeBiteWatch/TimeBiteWatchApp.swift | Older compact current-action UI, direct headline font and fixed 110-point ring. Platform-specific follow-up after shared token/ring work. |
| Apps/TimeBiteVision/TimeBiteVisionApp.swift | Thin ActivityLoopView entry. No dedicated glasses work in this pass; shared changes may still affect it and require build verification. |

No dark-only forced screen was found. The remaining old visual language is rounded cards, shadows, gradients and pale accents, rather than an explicit dark-mode lock. No explicit accessibilityIdentifier declarations were found in these app/UI sources; preserve any subsequently discovered identifiers.

## Existing feature/component mapping

- Rings: ActivityRingView for Today, active session, Mac and Watch; SourceActivityRingView for calendar/Health onboarding preview.
- Timers: ActivityLoopController.currentSession/currentAction; session elapsed(at:) and ringProgress(at:); TimelineView periodic display; start/pause/resume/complete methods.
- Task rows: TimeBiteTodayView.plannedActions and entryRow; ActivityLoopView.todayList. Current action rows offer Start, while the active-session section offers Pause/Resume/Complete. No general checkbox completion API exists.
- Goals/projects: Goal and Project models, optional Action.goalID/projectID and Project.goalID, persisted snapshots and handwritten plan import. No standalone goals/projects screen.
- Calendar/week: CalendarActivityController uses EventKit for today's selected calendars; Today calendarSection and onboarding provider selection. No week timeline UI or capacity setting.
- Reflection: no reflection model, service or screen found. CYRA references occur in migration documentation; no active CYRA integration was found in these app sources.

## Timer source of truth

The current iOS Today view owns one ActivityLoopController via StateObject. Root onboarding does not own it. Mac's ActivityLoopView and Watch each own their own controller. currentSession selects the first non-completed session, including paused sessions; running must be tested with session.status == .running.

Proposed presentation ownership change: lift the existing iOS controller to TimeBiteRootView and inject that same instance into Today and a root safeAreaInset TimerChip. Keep store, session math and operations unchanged; do not instantiate a second controller or timer. TimelineView only refreshes displayed elapsed time. Show the chip for running sessions; retain paused controls in Today. Map Stop to the existing Complete operation with an explicit completion accessibility label, subject to review of that wording. This ownership change awaits approval with the audit.

## Ring mathematics: preserve existing behavior

Today currently displays TodayActivitySummary.trackedDayProgress: merged occupied interval duration divided by the actual calendar day's duration (23/24/25 hours across daylight-saving transitions). Calendar and Health intervals contribute. Its displayed Budget label is hard-coded to 24h. Source duration can overlap, whereas trackedDuration merges overlaps.

The active-session ring uses session.ringProgress. DailyProgress separately credits completed actions with at least their planned duration and divides credited duration by planned duration; that differs from actual executed/planned time. Do not substitute it silently. Onboarding source segments divide calendar and Health durations by 86,400.

The requested Allocated/Executed/Tasks/Goal four-ring definitions are not current ring behavior. Keep the current tracked-day and session meanings during the visual pass, with explicit legends. Do not label those values as the requested four metrics or fabricate four rings. The final ring semantics require a user decision and real denominator data.

## Gaps and decisions

1. No four-tab structure. Recommended scope is restyling existing screens; new tabs require a separate decision and content specification.
2. No daily focus budget, weekly capacity or weekly goal-hours target fields. Allocated, Goal and capacity-overflow indicators cannot be honestly wired as specified without additional product/model decisions.
3. No milestone model or stage taxonomy. AltitudePath can resolve actual Goal → Project → action links and hide absent levels. Do not invent milestone names or progress stages. Onboarding can use StagePips with its existing three named steps.
4. Planned duration, execution time and completion data exist, but Today currently filters completed actions out of plannedActions. Showing completed task checkboxes or changing action completion semantics would exceed a purely visual change. Keep existing operations.
5. No week view or reflection surface. Do not invent their data or services.
6. No supplied ring hexes beyond repository pastels. During implementation choose and document adaptive colors and measured ratios; no color adjustments have been made yet. Existing light secondary text and pale strokes need contrast correction.
7. Palette currently uses explicit ColorScheme functions, neither asset sets nor UIColor dynamic colors. Extend this shared cross-platform convention with light/dark semantic roles rather than introduce a UIKit-only dependency; review this choice alongside the audit.

## Proposed execution and review sequence

Work on branch ui/lifeos-hybrid-light; do not merge. Preserve existing unrelated working-tree changes.

1. Before UI edits, capture matching iPhone 16 screenshots into design/screens/before/: Today with empty, populated and running states, onboarding steps and capture review, in light/dark/accessibility3. Use existing data/setup paths; avoid production model changes for fixtures.
2. Commit tokens/Theme: adaptive semantic colors, typography, 4/8/12/16/24/32 spacing, zero-radius surfaces and contrast evidence. Light appearance follows the system by default; dark remains supported.
3. Commit reusable components with previews: SquareTile, HairlineDivider, Masthead, StagePips, accessible ring presentation and TimeBlockRow using existing actions. Defer unsupported CapacityBar and four-metric RingStack wiring; build AltitudePath only from actual links. Wrap or stack at accessibility3, use minimum 44-point targets and meaningful combined VoiceOver labels, encode status in shapes/text, honor Reduce Motion.
4. Commit Today restyle, preserving tracked-day/session math, filtering, creation, calendar, Health and paper capture behavior.
5. Commit remaining existing iOS surfaces in this order: onboarding (welcome → calendar → health), then capture/review sheets. There are no remaining tabs to convert. Share tokens and ring improvements with Mac/Watch; record platform layout follow-ups.
6. Commit TimerChip ownership/wiring using the single root-owned ActivityLoopController; verify no duplicate controller or independent timer state.
7. Commit cleanup of dead styles only after checking all call sites, including Mac/Watch/Vision. No glasses, M5Stack, model, persistence, network or CYRA work.
8. Run existing Swift package tests and build every available scheme, recording baseline versus new warnings. Verify iOS 16 library compatibility separately from the iOS 17 app. Capture matched after screenshots into design/screens/after/ and update this checklist and color contrast measurements.

## Verification status and checklist

- [x] Source audit and target/minimum-OS inventory.
- [x] Confirm navigation and identify data/timer gaps.
- [x] Write implementation plan; stop before UI edits.
- [ ] Capture before screenshots.
- [ ] Tokens/Theme and measured contrast adjustments.
- [ ] Shared components/previews.
- [ ] Today.
- [ ] Onboarding welcome/calendar/health.
- [ ] Capture/review sheets.
- [ ] Root timer chip and single-controller verification.
- [ ] Mac/Watch shared changes and documented follow-ups.
- [ ] Dead-style cleanup.
- [ ] Existing tests and all-scheme builds with no new warnings.
- [ ] Light/dark/accessibility3 screenshots and manual accessibility review.

An audit-time xcodebuild -list attempt failed (exit 143) with CoreSimulator service connection and log-write permission errors under the current environment. Scheme enumeration/build success and simulator availability are therefore unverified. Xcode also emitted file-type detection and provisioning-profile warnings; record them as environment baseline candidates, not UI regressions. No tests, builds or screenshot captures have been claimed as successful. No app source has changed in this audit pass.


## Implementation update — 2026-10-11

User approved implementation and requested restoration of the original tab UI. Located the original four-tab root in ../timebite-platform/apps/iOS/Views/TimeBiteRootView.swift: Actions, Goals, Track, Reflect. Restored those names and SF Symbols here, using current repository data rather than copying its persistence or authentication code.

### Implemented

- [x] Adaptive light/dark accent tokens, white light base, serif medium headlines, default SF UI, monospaced metadata.
- [x] Shared SquareTile, HairlineDivider, Masthead, StagePips and accessibility-aware AdaptiveRow, with a component preview.
- [x] Actions/Today square sections, rule masthead, wrapping titles, larger controls and planned/executed TimeBlockRow using existing start/pause/resume methods.
- [x] Goals tab lists actual goals, projects and linked actions; no invented milestones or stages.
- [x] Track tab presents the existing tracked-day ring and activity ledger; existing interval/math semantics preserved.
- [x] Reflect tab provides a clear empty state and states that saved reflections are unavailable. No fake save control or new persistence.
- [x] Onboarding square surfaces and existing-step pips; welcome/calendar scroll for large text. Apple sign-in completion/error logic unchanged.
- [x] Capture overlay square styling; native review form and scanner retained.
- [x] TimerChip mounted once above TabView; Today and chip observe the same root-owned ActivityLoopController. Stop calls the existing complete operation and has an explicit completion accessibility label.
- [x] Reduce Motion respected by ring and onboarding animations.
- [x] Removed dead palette shadow/glow and unused legacy action list. Mac shares typography and ring changes; Watch shares ring changes.

### Token evidence

Contrast calculated from sRGB luminance against white / dark base (0.06, 0.07, 0.11): teal 6.13:1 / 9.64:1, blue 5.94:1 / 8.95:1, violet 5.69:1 / 9.06:1. Replaced pale teal/sky/violet with darker light variants and lighter dark variants. Primary button and timer-chip fills use the dark teal light variant with white text (6.13:1). Secondary light text changed from (0.49, 0.51, 0.56) to (0.36, 0.38, 0.42). This is token verification, not a claim that every system control and opacity combination has been audited.

### Verification and limits

- iOS simulator and macOS app builds succeeded. Xcode emits its AppIntents metadata-extraction warning without an AppIntents dependency.
- Existing tests: 31 passed, 0 failures using swift test --build-system native. The Xcode beta default SwiftPM build system initially failed signing the test bundle; native SwiftPM avoided that environment problem.
- Captured Actions on iPhone 16 in light, dark and accessibility3 under design/screens/after/. Inspected normal and accessibility3 screenshots: masthead wraps and metrics stack. Full populated/timer/VoiceOver and every-tab screenshot coverage remains pending.
- design/screens/before/existing-reference.png is the preexisting repository screenshot, not a newly captured matched before set. Matched before captures were unavailable after the approved source edits; do not treat this reference as a full before/after validation set.
- Four requested budget/goal rings, CapacityBar and week timeline remain deferred: budgets/targets do not exist and changing ring semantics remains outside this visual pass. Goal/project hierarchy uses real data; no milestone layer is invented.
- Native capture review controls remain platform styled. Watch/Mac layout polish beyond shared tokens/ring changes remains follow-up work. Apple login testing is explicitly deferred until the user reviews the UI.
- Watch/Vision and a final incremental iOS build stalled before compilation and were stopped; these checks remain unverified. Earlier iOS/macOS builds and native SwiftPM tests succeeded as reported above.

The migration is ready for visual review, with the above gaps explicitly retained. No models, persistence schema, network integration or Apple authentication behavior were changed. Branch remains ui/lifeos-hybrid-light and is not merged.


## Requested design revision — 2026-10-12

- Health/Calendar permission and connection UI now appears only in onboarding after sign-in; removed both connection and calendar panels from Actions. Existing background data refresh and tracked-time calculations are retained.
- iOS root now explicitly uses dark appearance; background is pure black, with neutral near-black surfaces. This supersedes the earlier light-first brief.
- Bundled League Spartan variable font and OFL license from the official Google Fonts repository, registered through CoreText from SwiftPM resources. All shared text-style tokens scale with Dynamic Type. Chose League Spartan from the three requested typeface alternatives; no Century Gothic or Glacial Indifference binaries were added. Source: https://github.com/google/fonts/tree/main/ofl/leaguespartan .
- Replaced Quick Add with Create Action and the exact placeholder “Add an action to your goal or project.” Existing action creation behavior is unchanged. The placeholder is guidance; project/goal selection is not newly implemented.
- Replaced the Paper Planner panel with one labeled, 44-point scanner icon beside Create Action. Native scanner and review workflow remain intact.
- Removed Reflect and restored Profile (person.crop.circle.fill) from the later platform root. Copied original ActionSparkIcon, GoalRingsIcon and TrackWaveIcon paths from ../timebite-platform/apps/iOS/TimeBite/App/RootTabView.swift and render them as native tab template images. Profile displays existing local account information without new authentication actions.
- Apple sign-in behavior remains unchanged and testing remains deferred until visual approval. Previous screenshots describe the earlier light design and are retained as historical artifacts, not current UI evidence.

Verification for this revision: native SwiftPM TimeBiteUI build passed, including font/license resource copying; direct iOS 17 simulator type-check passed. Existing onChange deprecation warnings remain. Xcode project build stalled during planning before compilation; full app build and new simulator screenshots are unverified. Authentication tests were not run.


## Calendar setup investigation — 2026-10-12

Symptom: selecting Google Calendar produced a calendar-denied alert over the Health step.
Evidence: booted iPhone 16e (iOS 26.1) TCC row for com.timebite.official.ios / kTCCServiceCalendar has auth_value=0 (denied). Installed Info.plist includes NSCalendarsFullAccessUsageDescription. No Google OAuth client or Google Calendar API integration exists in this project: provider toggles filter device calendars from EventKit.
Root cause: denied device calendar permission, compounded by connectCalendars advancing to Health on failure and saving provider selection before successful authorization/source validation.
Fix: keep the calendar step on denial/restriction or missing account, offer the supported app Settings link, provide an explicit Continue without Calendar path, save selections only after validation or explicit skip, explain device-sync requirements and guard empty calendar selection before event fetch.
Verification: iOS simulator type-check passed (existing onChange deprecation warnings); 31 existing tests passed with zero failures using native SwiftPM. Original simulator permission denial was inspected read-only; no permission was silently granted/reset, no account login was performed. Runtime verification of the updated onboarding and new UI regression coverage remain pending.
Manual regression: with denied permission, Continue must stay on Calendar; Open Settings must open TimeBite settings; after Full Access and account sync, retry must advance to Health; a missing selected account must stay on Calendar with guidance; explicit skip must advance and clear saved selections.
Status: DONE_WITH_CONCERNS — permission-recovery code compiled, but Google authentication is not implemented and the updated permission UI has not been exercised in Simulator.
