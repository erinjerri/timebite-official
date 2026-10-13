# Four-platform companion test loop

## Implemented boundaries

- iOS remains authoritative for local actions/session transitions and queries real HealthKit sleep, workouts, mindfulness, plus EventKit calendars selected in onboarding. Google Calendar must be added to the device's Calendar Accounts; this is not direct Google OAuth.
- `Apps/TimeBiteWatch` now consumes paired-iPhone state through WatchConnectivity and sends revision-checked Start/Pause/Resume/Complete intents back. Cached state is marked stale. No independent Watch store is mutated.
- `Apps/TimeBiteMac` retains Local Actions and adds an iPhone Companion tab. Imported iPhone Health/calendar totals and live controls use the local relay. Mac local actions remain separate and are labeled local.
- `Apps/TimeBiteMStack5` is the separate CoreS3 SE firmware repo. Touch UI shows live action, AM/PM/Total, Health/calendar totals, and acknowledged controls. No sensor or motor actuation.
- Display projections exclude raw Health samples and calendar titles. Health and calendar subtotals can overlap; combined captured seconds use interval union, not their sum. These occupancy totals never imply action execution credit.

## Compile checks

Shared package and projection/control tests run with `swift test --build-system native`. Python relay tests run with `python3 -m unittest discover -s Tools/CompanionRelay`. iOS/watchOS modules and app entry points are separately compiler-checked. Firmware builds with PlatformIO in the hardware repo. Compiler checks do not establish signed installation or runtime device connectivity.

## Real data checklist

1. Build and launch iOS. Finish Health/calendar onboarding. In the actual device Health app confirm today's sleep/workout/mindfulness entries exist and permit TimeBite read access. Simulator Health is an independent store; it does not read your physical iPhone/Watch automatically.
2. Add Google to Apple Calendar Accounts on that same device/simulator and verify today's timed Google events appear in Apple Calendar. Grant TimeBite full Calendar read access; select Google in onboarding. Refresh Actions. Note AM, PM, Total and source durations. Zero readable samples should remain zero with an explanation.
3. Pair an Apple Watch or matching Watch/iPhone simulators. Build iOS with embedded Watch app, then launch Watch TimeBite. Tap Refresh from iPhone. Verify period totals equal iPhone, and that Updated changes. Start an existing action on Watch; confirm iPhone creates one session. Pause/resume/complete from both ends. Completion must not produce a duplicate session.
4. Start the development relay using `Tools/CompanionRelay/README.md`. In iPhone Profile enter URL + phone token. In Mac iPhone Companion enter URL + companion token. Check that the exact source totals match iPhone; test controls in both directions. This companion tab controls iPhone, not Mac's separate Local Actions store.
5. After CoreS3 SE arrives, configure 2.4 GHz Wi-Fi and companion token, then flash firmware using its README. Check AM/PM/Total and source totals; choose an idle action via Next, then Start/Pause/Resume/Complete. Verify authoritative state comes back from iPhone before assuming success.
6. Disconnect Watch or Wi-Fi, background iPhone, and restart clients. Stale data must be labeled. Controls must reject stale revisions, expired commands, invalid tokens, and attempts to restart completed actions. Reconnect and refresh. Test midnight/day rollover and overlapping Health/calendar intervals.

## Current automated results

- 38 Swift tests passed, including projection privacy/overlap and duplicate/stale control handling.
- Two authenticated relay HTTP tests passed on loopback.
- iOS and watchOS modules/app entry points passed compiler checks, with existing deprecation warnings.
- CoreS3 SE firmware compiled successfully: 48,936 bytes RAM, 1,051,429 bytes flash. No upload attempted.
- Full Xcode project build remains unverified if the build planner does not complete; compiler checks do not establish app packaging/signing.

## Runtime status

No physical Watch/CoreS3 test, signed archive, paired-simulator transfer, or real Health/Google calendar end-to-end transfer has been verified by this change. The CoreS3 SE has not arrived. Background iPhone relay service is intentionally not claimed. Run the checklist above before declaring the four loops complete.
