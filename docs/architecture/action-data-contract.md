# Canonical Action contract

Use TimeBiteCore.Action, never a parallel task schema. id/title/notes/projectID/goalID/createdAt/status already exist. plannedStart maps to scheduled start; plannedDuration to estimate; scheduled end is derived when both exist. actualEnd records completion. Add optional structured source metadata so old JSON remains decodable; missing source means legacy/manual. ActionDraft → ActionNormalizer validates title and finite positive execution target before persistence. Manual and imported plans use this boundary. AI and device interpretation must produce drafts and require the same validation.

Future external commands (documentation only):

```json
{"type":"action.start","actionId":"UUID","timestamp":"ISO-8601 UTC"}
```

State projection:

```json
{"activeActionId":"UUID","status":"running","elapsedSeconds":900,"dailyProgress":0.42}
```

The receiving service must validate IDs and transitions, serialize commands, and handle duplicate delivery before networking is introduced. Do not expose UserDefaults or UI types as a wire protocol.
