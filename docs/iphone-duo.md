# iPhone Duo compatibility plan for the September 23 build

Apple describes a 5.4-inch outer display and a 7.6-inch inner display for iPhone Duo. The production activity screen should resize continuously between them; it should not branch on a device model or a fixed screen width. See [Apple's specifications](https://www.apple.com/iphone-duo/specs/) and [Apple Developer's Duo layout talk](https://developer.apple.com/videos/play/tech-talks/111461/).

## Adaptive layout

Use `NavigationStack` for a compact action list and activity detail. Where the horizontal size class and available width allow it, `NavigationSplitView` may show today's actions next to the current activity. Keep one `TimeBiteCore` Action and ActivitySession state source for both presentations. Build the ring with its container's available size rather than a fixed phone frame. Keep controls inside the environment-provided safe area and use standard navigation/toolbar placements.

The outer display should show one column: current action, elapsed time, ring, pause/resume, and complete. The inner display can expose a second column for today's actions while the current activity remains visible. The navigation selection must persist when the layout expands or collapses, and the running session must not restart when the view hierarchy changes.

Treat fold/unfold, rotation, foreground/background, and window resizing as scene/layout changes. Re-read the persisted session and derive elapsed time from timestamps on scene activation. Do not create a new session in `onAppear`. Keep presentation state separate from session identity.

Apple describes `ReservedRegion` as an iOS 27.1 API for custom UI near system regions. This release should use standard safe areas and bars; future work may adopt `ReservedRegion` after the P0 loop is stable and deployment/toolchain requirements are checked. [Apple Developer](https://developer.apple.com/videos/play/tech-talks/111461/)

## Testing

Test compact and regular width previews, the Duo outer and inner simulator displays when available, fold/unfold during a running and paused session, rotation, background/relaunch, large Dynamic Type, and asymmetric safe areas. Confirm action selection, ring progress, and session ID remain stable through every layout change. The current iOS source in `timebite-platform` has fixed-size Action visuals and server-owned progress, so its layout is a reference only until refactored to the shared models.
