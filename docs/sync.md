# Companion transport status

The iPhone is authoritative for companion execution controls. `PairedWatchBridge` uses WatchConnectivity to publish the latest aggregate display state and receive immediate, revision-checked commands. Watch never mutates its own divergent local action store. A foreground heartbeat publishes every five seconds while iPhone TimeBite is active. The latest context is retained by WatchConnectivity for reconnect; commands are not replayed offline.

Mac and CoreS3 SE use the opt-in local development relay in `Tools/CompanionRelay`. Phone and companion roles have distinct tokens. State is RAM-only; pending commands expire after 30 seconds, and clients mark snapshots stale after 120 seconds. Applied command IDs are deduplicated by iPhone; session ID and revision prevent stale controls. No durable cloud transport, offline queue, background iOS service, multiple-phone authority, or production Internet deployment is claimed.

The existing `SessionReconciler` remains a pure conflict policy for future transports. Mac Local Actions remain independent; the iPhone Companion tab explicitly displays and controls iPhone state.

See [four-platform tests](companion-testing.md). Compiler/unit checks have passed; signed installation and real paired-device transfer remain unverified.
